# Part 6: Practical Assertion Sets

This part applies Parts 4 and 5 to four small designs: a synchronous FIFO, a valid/ready handshake, a counter and the course ALU. Each example follows the same method, which is also the method to describe in an interview when asked "how would you write assertions for this block?".

**The method**

1. Read the specification and write each rule as one English sentence.
2. Classify each rule: reset behaviour, combinational (same-cycle) relationship, next-cycle behaviour, stability, timing window, "never" condition, X check.
3. Translate each sentence into one property. One rule, one assertion, one clear label.
4. Decide which rules are about the **DUT** (assert) and which are about how the **environment** must drive it (assume, in formal terms).
5. Add `cover property` statements for the scenarios that prove the assertions were exercised.

| English pattern | Assertion pattern |
|---|---|
| "X and Y are never both true" | `!(x && y)` |
| "When X, Y must be true in the same cycle" | `x \|-> y` |
| "After X, Y must be true in the next cycle" | `x \|=> y` |
| "After X, Y within N cycles" | `x \|-> ##[1:N] y` |
| "While X, signal S must not change" | `x \|=> $stable(s)` |
| "S changes only when X" | `$changed(s) \|-> x` |
| "After reset, S has value V" | `!rst_n \|-> s == v` (not disabled by reset) |
| "S is never unknown" | `!$isunknown(s)` |
| "The new value is the old value plus one" | `x \|=> s == $past(s) + 1'b1` (mind the width) |

All four checkers use the same header:

```systemverilog
default clocking cb @(posedge clk); endclocking
default disable iff (!rst_n);
```

and all testbenches use the timing scheme of this module: the clock rises at 5, 15, 25 ..., and stimulus changes at falling edges.

## 6.1 Assertions for a Synchronous FIFO

### The DUT

`sync_fifo` is an 8-bit wide, 16-entry synchronous FIFO. A write is accepted on a rising clock edge when `wr_en` is 1 and the FIFO is not full. A read is accepted when `rd_en` is 1 and the FIFO is not empty; the data appears on `dout` after that edge. Writes when full and reads when empty are ignored.

```systemverilog file=sync_fifo.sv
module sync_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             wr_en,
  input  logic             rd_en,
  input  logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout,
  output logic             full,
  output logic             empty
);

  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW-1:0]    wr_ptr, rd_ptr;
  logic [AW:0]      count;              // 0 .. DEPTH
  logic             do_wr, do_rd;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign do_wr = wr_en && !full;
  assign do_rd = rd_en && !empty;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
      dout   <= '0;
    end
    else begin
      if (do_wr) begin
        mem[wr_ptr] <= din;
        wr_ptr      <= wr_ptr + 1'b1;
      end
      if (do_rd) begin
        dout   <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
      if (do_wr && !do_rd)      count <= count + 1'b1;
      else if (do_rd && !do_wr) count <= count - 1'b1;
    end
  end

endmodule
```

### The rules

| # | Rule in English | Kind | Label |
|---|---|---|---|
| 1 | During reset the FIFO is empty, not full, and holds zero entries | Reset | `a_reset_state` |
| 2 | The FIFO is never full and empty at the same time | Never | `a_not_full_and_empty` |
| 3 | The entry count never exceeds the depth | Never | `a_count_range` |
| 4 | `full` is high exactly when the count equals the depth; `empty` exactly when it is zero | Same cycle | `a_full_flag`, `a_empty_flag` |
| 5 | Control and status signals are never unknown; `din` is known when written | X check | `a_ctrl_known`, `a_din_known` |
| 6 | A write alone increases the count by one | Next cycle | `a_wr_incr` |
| 7 | A read alone decreases the count by one | Next cycle | `a_rd_decr` |
| 8 | A simultaneous accepted write and read leaves the count unchanged | Next cycle | `a_rw_same` |
| 9 | With no write and no read, the count does not change | Stability | `a_idle_stable` |
| 10 | A write to a full FIFO (with no read) is ignored: it stays full | Next cycle | `a_full_hold` |
| 11 | A read from an empty FIFO (with no write) is ignored: it stays empty | Next cycle | `a_empty_hold` |
| 12 | `full` can only fall because of a read; `empty` can only fall because of a write | Cause | `a_full_fell`, `a_empty_fell` |
| 13 | The environment should not write when full or read when empty | Environment | `a_wr_when_full`, `a_rd_when_empty` |

### The checker

```systemverilog file=sync_fifo_sva.sv
module sync_fifo_sva #(
  parameter int DEPTH = 16
) (
  input logic                 clk,
  input logic                 rst_n,
  input logic                 wr_en,
  input logic                 rd_en,
  input logic [7:0]           din,
  input logic                 full,
  input logic                 empty,
  input logic [$clog2(DEPTH):0] count       // internal signal of the FIFO
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // ---------------- reset (must NOT be disabled by reset) ----------------
  a_reset_state: assert property (disable iff (1'b0)
    !rst_n |-> (empty && !full && count == 0));

  // ---------------- invariants ----------------
  a_not_full_and_empty: assert property (!(full && empty));
  a_count_range       : assert property (count <= DEPTH);
  a_full_flag         : assert property (full  == (count == DEPTH));
  a_empty_flag        : assert property (empty == (count == 0));

  // ---------------- no unknown values ----------------
  a_ctrl_known: assert property (!$isunknown({wr_en, rd_en, full, empty}));
  a_din_known : assert property (wr_en |-> !$isunknown(din));

  // ---------------- counting ----------------
  a_wr_incr: assert property (
    (wr_en && !full && !(rd_en && !empty)) |=> count == $past(count) + 1);

  a_rd_decr: assert property (
    (rd_en && !empty && !(wr_en && !full)) |=> count == $past(count) - 1);

  a_rw_same: assert property (
    (wr_en && !full && rd_en && !empty) |=> $stable(count));

  a_idle_stable: assert property ((!wr_en && !rd_en) |=> $stable(count));

  // ---------------- overflow / underflow protection ----------------
  a_full_hold : assert property ((full  && wr_en && !rd_en) |=> full);
  a_empty_hold: assert property ((empty && rd_en && !wr_en) |=> empty);

  // ---------------- cause of flag changes ----------------
  a_full_fell : assert property ($fell(full)  |-> $past(rd_en));
  a_empty_fell: assert property ($fell(empty) |-> $past(wr_en));

  // ---------------- rules for the environment ----------------
  a_wr_when_full: assert property (wr_en |-> !full)
    else $display("[%0t] a_wr_when_full FAILED: write attempted while the FIFO is full",
                  $time);

  a_rd_when_empty: assert property (rd_en |-> !empty)
    else $display("[%0t] a_rd_when_empty FAILED: read attempted while the FIFO is empty",
                  $time);

  // ---------------- coverage of interesting scenarios ----------------
  c_became_full  : cover property ($rose(full));
  c_full_to_empty: cover property (full ##[1:$] empty);
  c_simul_rw     : cover property (wr_en && rd_en && !full && !empty);

endmodule
```

**Line by line**

| Assertion | Explanation |
|---|---|
| `a_reset_state` | Checks the reset values. It overrides the default with `disable iff (1'b0)`, otherwise it would be disabled exactly when it should check. |
| `a_not_full_and_empty` | A pure Boolean property: checked at every clock tick. |
| `a_full_flag` | `full == (count == DEPTH)` compares two 1-bit values: the flag must agree with the count in both directions. |
| `a_ctrl_known` | Concatenates four signals and checks them together. |
| `a_din_known` | Data is checked only when qualified by `wr_en`. |
| `a_wr_incr` | Antecedent: a write is accepted and no read is accepted. Consequent, one tick later: the count is the previous count plus one. `count` is 5 bits and never exceeds 16, so the 32-bit addition `$past(count) + 1` cannot wrap and the comparison is safe here. (Section 6.3 shows a case where it is not.) |
| `a_rd_decr` | The mirror image. The antecedent contains `!empty`, so `$past(count)` is at least 1 and the subtraction cannot go negative. |
| `a_rw_same` | Simultaneous accepted write and read. |
| `a_full_hold` | A write when full, with no read, must leave the FIFO full: the overflow is ignored. |
| `a_full_fell` | Looks backwards: if `full` has just fallen, there must have been a read request in the previous cycle. |
| `a_wr_when_full`, `a_rd_when_empty` | Rules about the stimulus, not about the FIFO. In simulation they flag a testbench or upstream-block error. In formal verification they would be `assume property`. They are the only assertions here with a custom fail statement, so that the example has exact output. |
| `c_became_full` | Proves that the FIFO was filled at least once, so the full-related assertions were not vacuous. |
| `c_full_to_empty` | A cover with an unbounded delay is fine: it is hit when `empty` eventually follows `full`. |

### The testbench

```systemverilog file=tb_fifo_sva.sv
// compile order: sync_fifo.sv  sync_fifo_sva.sv  tb_fifo_sva.sv
module tb_fifo_sva;

  logic       clk   = 0;
  logic       rst_n = 1;
  logic       wr_en = 0;
  logic       rd_en = 0;
  logic [7:0] din   = '0;
  logic [7:0] dout;
  logic       full, empty;

  sync_fifo dut (.*);

  // attach the checker to every instance of sync_fifo; 'count' is internal to the FIFO
  bind sync_fifo sync_fifo_sva #(.DEPTH(DEPTH)) u_sync_fifo_sva (
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en), .din(din),
    .full(full), .empty(empty), .count(count)
  );

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;                      // assert reset at time 1
    @(negedge clk);  rst_n = 1;        // release at time 10

    // 17 writes into a 16-entry FIFO: the last one is attempted while full
    for (int i = 0; i < 17; i++) begin
      wr_en = 1;
      din   = 8'hA0 + i;
      @(negedge clk);
    end
    wr_en = 0;

    rd_en = 1;                         // one read
    @(negedge clk);
    rd_en = 0;
    @(negedge clk);

    $display("[%0t] full=%b empty=%b dout=%h", $time, full, empty, dout);
    $finish;
  end

endmodule
```

```output
[175] a_wr_when_full FAILED: write attempted while the FIFO is full
[200] full=0 empty=0 dout=a0
```

**Execution flow**

| Time | Event |
|---|---|
| 1 | Reset asserted. The FIFO's count becomes 0 asynchronously. |
| 5 | First clock tick, in reset: `a_reset_state` checks `empty`, `!full`, `count == 0`. All other assertions are disabled. |
| 10 | Reset released. The first write (`A0`) is driven. |
| 15, 25 ... 165 | Sixteen writes are accepted. After the edge at 165 the count is 16 and `full` rises. At each of these ticks `a_wr_incr` starts an attempt that passes at the next tick. `a_empty_fell` passes at time 25. |
| 170 | The seventeenth write is driven although `full` is 1. |
| 175 | The tick samples `wr_en` = 1 and `full` = 1. **`a_wr_when_full` fails.** The FIFO ignores the write; `a_full_hold` starts an attempt. |
| 185 | `rd_en` = 1 is sampled: the first entry (`A0`) is read, the count drops to 15. `a_full_hold` passes (the FIFO was still full before this edge). |
| 195 | `a_rd_decr` passes (15 = 16 - 1). `a_full_fell` passes (`rd_en` was 1 at the previous tick). |
| 200 | The testbench prints the state: not full, not empty, `dout` = `a0`. |

The design is correct, so none of the DUT assertions fails. The one failure comes from the environment rule, and it points at the exact cycle in which the testbench misbehaved.

**Points to notice**

| Code | Explanation |
|---|---|
| `#1 rst_n = 0;` | Reset is asserted a little after time 0, so that the falling edge of `rst_n` is certain to be seen by the `always_ff` block. Driving it at time 0 would race with the start of the block. |
| `bind sync_fifo sync_fifo_sva #(.DEPTH(DEPTH)) ...` | The port connections and the parameter are resolved **inside** `sync_fifo`. That is how the checker reaches the internal signal `count` and the FIFO's own `DEPTH`. |
| The `bind` statement is inside `tb_fifo_sva` | It could equally be in a file of its own, compiled with the testbench. |
| No data check | The assertions verify flags and counting. That each word comes out unchanged and in order is checked by a scoreboard with a queue as reference model (Module 9). It can be written as an assertion with local variables, but the scoreboard is simpler and clearer. |

> **Interview trap:** "Write an assertion that a FIFO never overflows." Be precise about what is meant. If the **design** must be safe, the property is "a write when full does not change the state": `full && wr_en && !rd_en |=> full` (and the count is stable). If the **environment** must never try, the property is `wr_en |-> !full`. Interviewers like candidates who ask which one is wanted.

> **Verification application:** FIFO checkers like this one are bound to every FIFO instance in a chip. A system-level test that overflows an internal FIFO then fails immediately at the FIFO, instead of thousands of cycles later at a scoreboard far downstream.

## 6.2 Assertions for a Valid/Ready Handshake

### The protocol

A sender presents `data` and raises `valid`. The receiver raises `ready` when it can accept. A **transfer** happens on a rising clock edge at which `valid` and `ready` are both 1. This is the handshake used by AXI and many other protocols.

```text
   clk     ___/‾‾\___/‾‾\___/‾‾\___/‾‾\___/‾‾\___
   valid   _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\________
   ready   _____________________/‾‾‾‾‾‾‾\________
   data    -------<      D0             >--------
                  |<---- waiting ---->|  ^
                                         transfer (valid && ready at this edge)
```

### The rules

| # | Rule in English | Label |
|---|---|---|
| 1 | During reset, `valid` is low | `a_reset_valid` |
| 2 | Once `valid` is raised it must stay high until the transfer happens (the sender may not withdraw a request) | `a_valid_hold` |
| 3 | While `valid` is high and `ready` is low, `data` must not change | `a_data_stable` |
| 4 | `valid` and `ready` are never unknown | `a_ctrl_known` |
| 5 | `data` is not unknown while `valid` is high | `a_data_known` |
| 6 | After `valid` rises, `ready` must come within a limited number of cycles (here: the same cycle or up to 3 cycles later) | `a_ready_timeout` |

### The checker

```systemverilog file=handshake_sva.sv
module handshake_sva #(
  parameter int MAX_WAIT = 3
) (
  input logic       clk,
  input logic       rst_n,
  input logic       valid,
  input logic       ready,
  input logic [7:0] data
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_reset_valid: assert property (disable iff (1'b0) !rst_n |-> !valid);

  a_valid_hold: assert property (valid && !ready |=> valid)
    else $display("[%0t] a_valid_hold    FAILED: valid dropped before ready", $time);

  a_data_stable: assert property (valid && !ready |=> $stable(data))
    else $display("[%0t] a_data_stable   FAILED: data changed while waiting for ready",
                  $time);

  a_ready_timeout: assert property ($rose(valid) |-> ##[0:MAX_WAIT] ready)
    else $display("[%0t] a_ready_timeout FAILED: no ready within %0d cycles",
                  $time, MAX_WAIT);

  a_ctrl_known: assert property (!$isunknown({valid, ready}));
  a_data_known: assert property (valid |-> !$isunknown(data));

  // scenarios worth seeing
  c_transfer    : cover property (valid && ready);
  c_stall       : cover property (valid && !ready);
  c_back_to_back: cover property ((valid && ready) [*2]);

endmodule
```

### The testbench

The stimulus deliberately breaks three rules, at three different times.

```systemverilog file=tb_handshake_sva.sv
// compile order: handshake_sva.sv  tb_handshake_sva.sv
module tb_handshake_sva;

  logic       clk = 0;
  logic       rst_n, valid, ready;
  logic [7:0] data;

  // stimulus for cycles 0..11 (cycle k is the posedge at time 10k+5)
  bit [0:11]  rst_v   = 12'b0111_1111_1111;
  bit [0:11]  valid_v = 12'b0111_0100_1110;
  bit [0:11]  ready_v = 12'b0001_0000_0110;
  logic [7:0] data_v [12] = '{8'h00, 8'hA1, 8'hA1, 8'hA1, 8'h00, 8'hB2,
                              8'hB2, 8'h00, 8'hC3, 8'hC4, 8'hC4, 8'h00};

  handshake_sva u_sva (.*);

  always #5 clk = ~clk;

  initial begin
    for (int i = 0; i < 12; i++) begin
      rst_n = rst_v[i];
      valid = valid_v[i];
      ready = ready_v[i];
      data  = data_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[65] a_valid_hold    FAILED: valid dropped before ready
[85] a_ready_timeout FAILED: no ready within 3 cycles
[95] a_data_stable   FAILED: data changed while waiting for ready
```

**Stimulus**

```text
   cycle    0    1    2    3    4    5    6    7    8    9   10   11
   time     5   15   25   35   45   55   65   75   85   95  105  115
   rst_n    0    1    1    1    1    1    1    1    1    1    1    1
   valid    0    1    1    1    0    1    0    0    1    1    1    0
   ready    0    0    0    1    0    0    0    0    0    1    1    0
   data    00   A1   A1   A1   00   B2   B2   00   C3   C4   C4   00
```

**Evaluation**

| Cycles | What happens | Result |
|---|---|---|
| 1 to 3 | `valid` rises at cycle 1 and waits; `data` holds `A1`; `ready` arrives at cycle 3 | A legal transfer. `a_valid_hold` and `a_data_stable` pass at cycles 2 and 3; `a_ready_timeout` passes at cycle 3 |
| 5 to 6 | `valid` rises at cycle 5 with `ready` low, then **drops at cycle 6** without a transfer | `a_valid_hold` fails at cycle 6 (time 65). `data` is still `B2` at cycle 6, so `a_data_stable` passes |
| 5 to 8 | After the rise of `valid` at cycle 5, `ready` stays low in cycles 5, 6, 7 and 8 | `a_ready_timeout` fails at cycle 8 (time 85), the end of its window |
| 8 to 9 | `valid` rises at cycle 8 with `data` = `C3`; at cycle 9 `data` has **changed to `C4`** while still waiting | `a_data_stable` fails at cycle 9 (time 95). `ready` is high at cycle 9, so the timeout check for this request passes |
| 9 to 10 | Two transfers in consecutive cycles | `c_back_to_back` is covered |

**Points to notice**

| Code | Explanation |
|---|---|
| `valid && !ready \|=> valid` | The antecedent is "waiting". The consequent only requires `valid` to still be high in the next cycle. Applied at every waiting cycle, this forces `valid` to stay high for the whole wait. |
| `valid && !ready \|=> $stable(data)` | The non-overlapped operator is essential: the stability is required in the cycle **after** a waiting cycle. |
| `$rose(valid) \|-> ##[0:MAX_WAIT] ready` | `##[0:...]` includes the same cycle, because `ready` may already be high when `valid` rises. `$rose` gives one attempt per request. The bound uses a parameter, which is legal because parameters are constants. |
| `handshake_sva u_sva (.*);` | Here the checker is instantiated directly in the testbench, because there is no DUT module to bind to. In a real environment it would be placed in, or bound to, the interface. |

> **Interview trap:** "Can `ready` depend on `valid`?" In AXI, a receiver **may** wait for `valid` before raising `ready`, but a sender must **not** wait for `ready` before raising `valid`. So "`valid` must not depend on `ready`" is a rule, and it cannot be fully checked by a simple simulation assertion; it is a design-review and formal-verification item. Knowing which rules assertions can and cannot check is a mark of experience.

> **Common mistake:** Writing rule 2 as `$rose(valid) |-> valid until ready` without checking tool support, or as `valid |=> valid`, which forbids `valid` from ever falling. The waiting condition `valid && !ready` must be in the antecedent.

> **Verification application:** These six assertions, parameterised by data width and timeout, are instantiated on every valid/ready channel of a design. For the five channels of an AXI interface, the same properties are asserted five times with different signal arguments.

## 6.3 Assertions for a Simple Counter

### The DUT

```systemverilog file=counter.sv
module counter (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       en,
  output logic [3:0] count
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  count <= '0;
    else if (en) count <= count + 1'b1;
  end

endmodule
```

### The rules

| # | Rule in English | Label |
|---|---|---|
| 1 | During reset the count is 0 | `a_reset` |
| 2 | When `en` is 1, the count increases by one (modulo 16) | `a_incr` |
| 3 | When `en` is 0, the count does not change | `a_hold` |
| 4 | When enabled at 15, the count wraps to 0 | `a_wrap` |
| 5 | The count is never unknown | `a_known` |

### The checker, including one deliberately wrong assertion

```systemverilog file=counter_sva.sv
module counter_sva (
  input logic       clk,
  input logic       rst_n,
  input logic       en,
  input logic [3:0] count
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_reset: assert property (disable iff (1'b0) !rst_n |-> count == 4'd0);

  a_incr : assert property (en |=> count == $past(count) + 4'd1);

  a_hold : assert property (!en |=> $stable(count));

  a_wrap : assert property (en && count == 4'hF |=> count == 4'h0);

  a_known: assert property (!$isunknown(count));

  // WRONG on purpose: the literal 1 is 32 bits wide, so the sum does not wrap at 15
  a_incr_bad: assert property (en |=> count == $past(count) + 1)
    else $display("[%0t] a_incr_bad FAILED: the assertion is wrong, not the counter",
                  $time);

  c_wrap: cover property (en && count == 4'hF ##1 count == 4'h0);

endmodule
```

### The testbench

```systemverilog file=tb_counter_sva.sv
// compile order: counter.sv  counter_sva.sv  tb_counter_sva.sv
module tb_counter_sva;

  logic       clk   = 0;
  logic       rst_n = 1;
  logic       en    = 0;
  logic [3:0] count;

  counter dut (.*);

  bind counter counter_sva u_counter_sva (.*);

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;
    @(negedge clk);                    // time 10
    rst_n = 1;
    en    = 1;
    repeat (17) @(negedge clk);        // 17 enabled clock edges: 15, 25, ... 175
    en = 0;                            // time 180
    repeat (2) @(negedge clk);         // time 200
    $display("[%0t] count=%0d", $time, count);
    $finish;
  end

endmodule
```

```output
[175] a_incr_bad FAILED: the assertion is wrong, not the counter
[200] count=1
```

**Execution flow**

| Time | Sampled `count` | Event |
|---|---|---|
| 5 | 0 | Tick during reset: `a_reset` passes |
| 15 | 0 | First enabled tick. The count becomes 1 after the edge |
| 25 ... 155 | 1 ... 14 | `a_incr` passes at every tick |
| 165 | 15 | Enabled at 15: `a_incr`, `a_incr_bad` and `a_wrap` start attempts. The count wraps to 0 after the edge |
| 175 | 0 | `a_incr`: 0 == 15 + 4'd1 in 4 bits → 0 == 0: **pass**. `a_wrap`: pass. `a_incr_bad`: 0 == 15 + 1 in 32 bits → 0 == 16: **FAIL** |
| 185 | 1 | `en` is now 0 (changed at 180): `a_hold` starts an attempt |
| 195 | 1 | `a_hold` passes |
| 200 | | Seventeen increments from 0, modulo 16: the count is 1 |

**Why `a_incr_bad` fails**

```text
   count == $past(count) + 1            count == $past(count) + 4'd1

   operand widths:  4      4       32    operand widths:  4      4        4
   expression width = 32 bits            expression width = 4 bits

   $past(count) = 15:                    $past(count) = 15:
      15 + 1 = 16   (no wrap in 32 bits)    15 + 1 = 0    (wraps in 4 bits, as in hardware)
      count = 0  -> 0 == 16 is FALSE        count = 0  -> 0 == 0 is TRUE
```

This is the expression-width rule of Module 1 (Section 4.4) appearing in an assertion. The counter is correct; the assertion is wrong. A failing assertion does not always mean a design bug: **the assertion is code too and can itself be wrong**.

**Points to notice**

| Code | Explanation |
|---|---|
| `bind counter counter_sva u_counter_sva (.*);` | The checker's port names equal the counter's port names, so `.*` connects everything. |
| `a_reset` with `disable iff (1'b0)` | The reset check must be active during reset. |
| `a_wrap` | Technically implied by `a_incr`, but stating the corner case explicitly documents it and gives it its own pass/fail and coverage entry. |
| `c_wrap` | A cover on a two-tick sequence: enabled at 15, then 0. It proves that the wrap-around was reached, without which `a_wrap` would be vacuous. |

> **Interview trap:** "Write an assertion that a counter increments by one." The expected follow-up is "what happens at the maximum value?". Mention the wrap-around and the width of the `+ 1` before you are asked.

> **Common mistake:** Checking the increment with `|->` instead of `|=>`: `en |-> count == $past(count) + 4'd1`. In the cycle where `en` is sampled high, the counter has not yet incremented; the new value is visible one tick later.

## 6.4 Assertions for the ALU

### The rules

The ALU of Module 1 registers its result: when `valid_in` is 1 at a rising edge, `result` is updated and `valid_out` is 1 during the next cycle.

| # | Rule in English | Label |
|---|---|---|
| 1 | During reset, `valid_out` is 0 and `result` is 0 | `a_reset` |
| 2 | `valid_out` is high one cycle after every `valid_in` | `a_valid_follow` |
| 3 | `valid_out` is low one cycle after every cycle without `valid_in` | `a_no_spurious_valid` |
| 4 | `result` changes only as a consequence of `valid_in` | `a_result_hold` |
| 5 | `valid_out` is never unknown; `result` is not unknown when `valid_out` is high | `a_valid_known`, `a_result_known` |
| 6 | Inputs are not unknown when `valid_in` is high (rule for the environment) | `a_inputs_known` |
| 7 | An addition gives the 9-bit sum of the previous inputs | `a_add` |
| 8 | A NOT operation gives the inverted `a` with bit 8 clear | `a_not` |

Rules 7 and 8 show that simple data checks can be written as assertions. Checking **all eight** operations is the scoreboard's job; an assertion per opcode would duplicate the reference model.

### The DUT

`alu_pkg.sv` was listed in Section 3.5. The ALU is repeated here so that this module's examples are complete.

```systemverilog file=alu.sv
module alu
  import alu_pkg::*;
(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       valid_in,
  input  logic [7:0] a,
  input  logic [7:0] b,
  input  alu_op_e    op,
  output logic       valid_out,
  output logic [8:0] result
);

  logic [8:0] result_nxt;

  always_comb begin
    unique case (op)
      ALU_ADD: result_nxt = a + b;
      ALU_SUB: result_nxt = a - b;
      ALU_AND: result_nxt = {1'b0, a & b};
      ALU_OR : result_nxt = {1'b0, a | b};
      ALU_XOR: result_nxt = {1'b0, a ^ b};
      ALU_NOT: result_nxt = {1'b0, ~a};
      ALU_SHL: result_nxt = {a, 1'b0};
      ALU_SHR: result_nxt = {2'b00, a[7:1]};
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 1'b0;
      result    <= '0;
    end
    else begin
      valid_out <= valid_in;
      if (valid_in) result <= result_nxt;
    end
  end

endmodule
```

### The checker

```systemverilog file=alu_sva.sv
module alu_sva
  import alu_pkg::*;
(
  input logic       clk,
  input logic       rst_n,
  input logic       valid_in,
  input logic [7:0] a,
  input logic [7:0] b,
  input alu_op_e    op,
  input logic       valid_out,
  input logic [8:0] result
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // ---------------- reset ----------------
  a_reset: assert property (disable iff (1'b0)
    !rst_n |-> (!valid_out && result == 9'd0));

  // ---------------- valid_out follows valid_in by exactly one cycle ----------------
  a_valid_follow     : assert property ( valid_in |=>  valid_out);
  a_no_spurious_valid: assert property (!valid_in |=> !valid_out);

  // ---------------- result only changes after valid_in ----------------
  a_result_hold: assert property (!valid_in |=> $stable(result));

  // ---------------- no X ----------------
  a_valid_known : assert property (!$isunknown(valid_out));
  a_result_known: assert property (valid_out |-> !$isunknown(result));
  a_inputs_known: assert property (valid_in  |-> !$isunknown({a, b, op}));

  // ---------------- two functional checks ----------------
  a_add: assert property (
    (valid_in && op == ALU_ADD) |=> result == $past(a) + $past(b));

  a_not: assert property (
    (valid_in && op == ALU_NOT) |=> result == {1'b0, ~$past(a)});

  // ---------------- scenarios ----------------
  c_carry       : cover property (valid_out && result[8]);
  c_back_to_back: cover property (valid_in ##1 valid_in);
  c_idle_gap    : cover property (valid_in ##1 !valid_in ##1 valid_in);

endmodule
```

**Line by line**

| Assertion | Explanation |
|---|---|
| `a_valid_follow` and `a_no_spurious_valid` | Together they state that `valid_out` is exactly `valid_in` delayed by one cycle. The first catches a lost output; the second catches an output that appears from nowhere. |
| `a_result_hold` | If nothing was accepted, the result register must keep its value. This catches a missing enable on the register. |
| `a_result_known` | The X check on data is qualified by `valid_out`. After reset the result is 0, so here it would also hold unconditionally, but the qualified form is the general pattern. |
| `a_inputs_known` | A rule for the driver: when it presents an operation, all inputs must be driven. |
| `a_add` | At the tick after an accepted addition, `result` must equal the sum of the **previous** inputs. The comparison is made in 9 bits (the width of `result`), so the two 8-bit `$past` values are extended before the addition and the carry is included. |
| `a_not` | The concatenation makes the expected value 9 bits wide with bit 8 clear. |
| `c_carry` | Was a result with bit 8 set ever produced? |
| `c_back_to_back`, `c_idle_gap` | Were operations sent in consecutive cycles, and with a one-cycle gap? Both are needed to trust the two valid assertions. |

### The testbench

```systemverilog file=tb_alu_sva.sv
// compile order: alu_pkg.sv  alu.sv  alu_sva.sv  tb_alu_sva.sv
module tb_alu_sva;
  import alu_pkg::*;

  logic       clk      = 0;
  logic       rst_n    = 1;
  logic       valid_in = 0;
  logic [7:0] a        = '0;
  logic [7:0] b        = '0;
  alu_op_e    op       = ALU_ADD;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  bind alu alu_sva u_alu_sva (.*);

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;
    @(negedge clk);  rst_n = 1;                                      // time 10

    @(negedge clk);  valid_in = 1;  a = 8'd200;  b = 8'd100;         // time 20
                     op = ALU_ADD;

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     a = 8'h0F;  op = ALU_NOT;                       // time 30

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     valid_in = 0;                                   // time 40

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     $finish;                                        // time 50
  end

endmodule
```

```output
[30] valid_out=1 result=300
[40] valid_out=1 result=240
[50] valid_out=0 result=240
```

No assertion fails, so the only output is that of the testbench.

**Execution flow**

| Time | Sampled at this tick | Assertion activity |
|---|---|---|
| 5 | Reset active | `a_reset` passes. Everything else is disabled |
| 15 | `valid_in` = 0 | `a_no_spurious_valid` and `a_result_hold` start attempts |
| 25 | `valid_in` = 1, ADD, 200, 100 | The attempts from 15 pass (`valid_out` = 0, `result` still 0). `a_valid_follow` and `a_add` start attempts. The DUT stores 300 |
| 35 | `valid_in` = 1, NOT, `a` = `0F`; `valid_out` = 1, `result` = 300 | `a_valid_follow` passes. `a_add` passes: 300 == 200 + 100. `a_not` starts an attempt. The DUT stores `{0, ~0F}` = `0F0` = 240 |
| 45 | `valid_in` = 0; `valid_out` = 1, `result` = 240 | `a_valid_follow` passes. `a_not` passes: 240 == `{1'b0, 8'hF0}`. `c_back_to_back` was covered at time 35 |

### The same rules inside the interface

In the layered testbench the port-level rules are normally placed in `alu_if`, so that they travel with the interface:

```systemverilog
interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n, valid_in, valid_out;
  logic [7:0] a, b;
  alu_op_e    op;
  logic [8:0] result;

  // clocking blocks drv_cb and mon_cb, modports DUT, DRV, MON  (Module 8)

  default clocking cb_sva @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_valid_follow     : assert property ( valid_in |=>  valid_out);
  a_no_spurious_valid: assert property (!valid_in |=> !valid_out);
  a_result_known     : assert property (valid_out |-> !$isunknown(result));
  a_inputs_known     : assert property (valid_in  |-> !$isunknown({a, b, op}));
endinterface
```

| Placement | Used for |
|---|---|
| In `alu_if` | Rules that involve only the interface signals. Active in every testbench that uses the interface |
| In `alu_sva`, bound to `alu` | Rules that need internal signals, or that the design team owns |

> **Interview trap:** "The scoreboard already compares every result. Why add `a_valid_follow`?" Because the scoreboard only sees what the monitor delivers. If `valid_out` never rises, the monitor never produces a transaction, the scoreboard compares nothing, and a naive testbench reports "0 errors". The assertion catches the missing response directly. (A good scoreboard also checks, at the end of the test, that the number of received transactions equals the number sent.)

> **Verification application:** The complete verification of the ALU therefore has four parts: the scoreboard with its reference model (all eight operations, every transaction), `alu_sva` and the interface assertions (timing and X rules at every clock), `alu_coverage` (which operations and operand classes were exercised), and the cover properties (which signal scenarios occurred). Together they answer: is it right, is it always well-behaved, and have we tried enough.

## 6.5 Interview Questions on Practical Assertions

**Q1. Write assertions for a FIFO.**
State the rules first, then code them: never full and empty together (`!(full && empty)`); after reset, empty and not full; a write when full does not change the state (`full && wr_en && !rd_en |=> full`); a read when empty does not change the state; a write alone increments the count and a read alone decrements it (using `$past`); flags agree with the count; no X on the flags. Add covers for full, empty and simultaneous read/write.

**Q2. Write an assertion: `valid` must remain high until `ready` is high.**
`assert property (@(posedge clk) disable iff (!rst_n) valid && !ready |=> valid);`

**Q3. Write an assertion: data must be stable while `valid` is high and `ready` is low.**
`assert property (@(posedge clk) disable iff (!rst_n) valid && !ready |=> $stable(data));`

**Q4. Write an assertion: after `req`, `ack` must arrive within 2 to 5 cycles.**
`assert property (@(posedge clk) disable iff (!rst_n) $rose(req) |-> ##[2:5] ack);`

**Q5. Write an assertion that a 4-bit counter increments when enabled.**
`assert property (@(posedge clk) disable iff (!rst_n) en |=> count == $past(count) + 4'd1);` The sized literal makes the comparison wrap at 15 like the hardware.

**Q6. Write an assertion: `valid_out` is asserted exactly one cycle after `valid_in`.**
Two assertions: `valid_in |=> valid_out` and `!valid_in |=> !valid_out`. Or, looking backwards: `valid_out == $past(valid_in)`, with care for the first cycle after reset.

**Q7. Write an assertion that a signal is never X after reset.**
`assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(sig));`

**Q8. How would you check FIFO data integrity?**
With a scoreboard: push each written word into a reference queue and compare each read word with the front of the queue. It can also be done in SVA with local variables that capture a written word and count the writes and reads until that word must appear, but the scoreboard is simpler and is the normal choice.

**Q9. A design-team assertion fires in your simulation. What do you do?**
Read the property to see which rule was broken, and use the start and failure times to find the cause in the waveform. Then decide whether the stimulus was illegal (a testbench bug, or a missing constraint), the DUT is wrong (file a bug), or the assertion itself is wrong (as with the 32-bit `+ 1`). Do not disable the assertion to make the test pass.

**Q10. How do you know that your assertions were actually exercised?**
From assertion coverage: each assertion should have non-vacuous passes. For each important antecedent a `cover property` is written, and the cover must be hit in the regression.
