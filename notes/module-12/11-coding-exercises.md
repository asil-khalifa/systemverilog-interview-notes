# Coding Exercises with Solutions

These ten exercises are larger than the write-the-code questions. Each has a complete, self-contained solution that is also saved as a `.sv` file in the `examples/module-12/` folder. Every program prints a result that does not depend on the random seed, so you can check your simulator's output against the expected output shown.

Attempt each exercise from the problem statement alone before reading the solution. In an interview you would be given 20 to 40 minutes for one of these.

## Exercise 1: A Parameterised FIFO Class

**Problem.** Write a class that models a FIFO of any element type and any depth. `push` must refuse an item when the FIFO is full and `pop` must report when it is empty. Test it with a depth of 3 by pushing four bytes and popping until empty.

```systemverilog file=fx01_fifo_class.sv
module fx01_fifo_class;

  class fifo #(type T = int, int DEPTH = 4);
    local T items [$];

    function bit is_full();
      return items.size() == DEPTH;
    endfunction

    function bit is_empty();
      return items.size() == 0;
    endfunction

    function int count();
      return items.size();
    endfunction

    function bit push(T item);
      if (is_full()) return 0;
      items.push_back(item);
      return 1;
    endfunction

    function bit pop(output T item);
      if (is_empty()) return 0;
      item = items.pop_front();
      return 1;
    endfunction
  endclass

  fifo #(bit [7:0], 3) f = new();
  bit [7:0] d;
  bit       ok;

  initial begin
    for (int i = 1; i <= 4; i++) begin
      d  = 8'(i * 16);
      ok = f.push(d);
      $display("push %h -> ok=%b count=%0d full=%b", d, ok, f.count(), f.is_full());
    end
    while (f.pop(d))
      $display("pop  %h    count=%0d empty=%b", d, f.count(), f.is_empty());
  end

endmodule
```

```output
push 10 -> ok=1 count=1 full=0
push 20 -> ok=1 count=2 full=0
push 30 -> ok=1 count=3 full=1
push 40 -> ok=0 count=3 full=1
pop  10    count=2 empty=0
pop  20    count=1 empty=0
pop  30    count=0 empty=1
```

**Points to explain.** The queue is `local`, so users can reach it only through the methods (encapsulation). Items enter at the back and leave at the front (first in, first out). `fifo #(bit [7:0], 3)` is one specialisation of the generic class. The fourth push is refused and the value `40` never appears on the pop side.

## Exercise 2: A Synchronous FIFO and a Self-Checking Testbench

**Problem.** Write the RTL of `sync_fifo` (8 bits wide, 16 deep, with `full` and `empty`), and a directed self-checking testbench that uses a queue as the reference model. The testbench must fill the FIFO, attempt an overflow, drain it, attempt an underflow, and report the number of checks and errors.

```systemverilog file=fx02_sync_fifo_tb.sv
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
  logic [AW:0]      count;
  logic             do_wr, do_rd;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign do_wr = wr_en && !full;      // a write when full is ignored
  assign do_rd = rd_en && !empty;     // a read when empty is ignored

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
      case ({do_wr, do_rd})
        2'b10  : count <= count + 1'b1;
        2'b01  : count <= count - 1'b1;
        default: ;                    // both or neither: count unchanged
      endcase
    end
  end
endmodule

module fx02_sync_fifo_tb;

  logic       clk = 0;
  logic       rst_n, wr_en, rd_en;
  logic [7:0] din, dout;
  logic       full, empty;

  logic [7:0] model [$];              // reference model
  int         checks, errors;

  sync_fifo dut (.*);

  always #5 clk = ~clk;

  // Stimulus changes on the falling edge, so it is stable at the rising edge.
  task automatic write(input logic [7:0] data);
    @(negedge clk);
    wr_en = 1;
    din   = data;
    if (!full) model.push_back(data); // the DUT will accept it only if not full
    @(negedge clk);
    wr_en = 0;
  endtask

  task automatic read();
    logic [7:0] expected;
    bit         accepted;
    @(negedge clk);
    rd_en    = 1;
    accepted = !empty;
    if (accepted) expected = model.pop_front();
    @(negedge clk);                   // dout was updated at the rising edge in between
    rd_en = 0;
    if (accepted) begin
      checks++;
      if (dout !== expected) begin
        errors++;
        $display("[%0t] FAIL: dout=%h expected=%h", $time, dout, expected);
      end
    end
  endtask

  initial begin
    rst_n = 0;  wr_en = 0;  rd_en = 0;  din = '0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    $display("after reset    : full=%b empty=%b", full, empty);

    for (int i = 0; i < 16; i++) write(8'hA0 + i);
    $display("after 16 writes: full=%b empty=%b", full, empty);

    write(8'hFF);                     // overflow attempt: must be ignored
    repeat (16) read();
    $display("after 16 reads : full=%b empty=%b", full, empty);

    read();                           // underflow attempt: must be ignored
    write(8'h11);
    read();

    $display("checks=%0d errors=%0d model_left=%0d", checks, errors, model.size());
    if (errors == 0 && checks == 17 && model.size() == 0) $display("TEST PASSED");
    else                                                  $display("TEST FAILED");
    $finish;
  end

endmodule
```

```output
after reset    : full=0 empty=1
after 16 writes: full=1 empty=0
after 16 reads : full=0 empty=1
checks=17 errors=0 model_left=0
TEST PASSED
```

**Points to explain.**

- The pointer for a 16-deep FIFO is 4 bits, so it wraps naturally. The counter is one bit wider so that it can hold the value 16.
- `dout` is registered: the data appears after the clock edge at which the read was accepted. The testbench therefore checks `dout` one half-cycle after that edge.
- The reference model mirrors the DUT's acceptance rule. On the overflow attempt the model does not push `FF`; if the DUT wrongly stored it, a later read would mismatch.
- The final check is more than "errors == 0": it also requires the expected number of checks and an empty model, so a testbench that compared nothing cannot pass.

## Exercise 3: Transaction Copy and Compare

**Problem.** Write the `alu_txn` class with `print`, `copy` and `compare`. Show the difference between assigning a handle and copying an object.

```systemverilog file=fx03_txn_copy_compare.sv
package fx03_pkg;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function void print(string tag);
      $display("%s: id=%0d a=%0d b=%0d op=%s result=%0d", tag, id, a, b, op.name(), result);
    endfunction

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      return c;
    endfunction

    virtual function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a == rhs.a) && (b == rhs.b) && (op === rhs.op) && (result === rhs.result);
    endfunction
  endclass

endpackage

module fx03_txn_copy_compare;
  import fx03_pkg::*;

  alu_txn t1, t2, t3;

  initial begin
    t1 = new();
    t1.id = 1;  t1.a = 200;  t1.b = 100;  t1.op = ALU_ADD;  t1.result = 300;

    t2 = t1;                 // second handle to the same object
    t3 = t1.copy();          // second object

    t2.a = 5;                // also changes what t1 sees
    t3.b = 7;                // changes only the copy

    t1.print("t1");
    t2.print("t2");
    t3.print("t3");
    $display("t1 == t2 (handles): %b   t1 == t3 (handles): %b", t1 == t2, t1 == t3);
    $display("t1.compare(t2): %b   t1.compare(t3): %b", t1.compare(t2), t1.compare(t3));
  end
endmodule
```

```output
t1: id=1 a=5 b=100 op=ALU_ADD result=300
t2: id=1 a=5 b=100 op=ALU_ADD result=300
t3: id=1 a=200 b=7 op=ALU_ADD result=300
t1 == t2 (handles): 1   t1 == t3 (handles): 0
t1.compare(t2): 1   t1.compare(t3): 0
```

**Points to explain.** `==` on handles tests identity; `compare()` tests contents. The four-state fields are compared with `===` so that an X in `result` is a mismatch instead of an unknown. The methods are virtual so that an extended transaction can override them and still be handled through an `alu_txn` handle.

## Exercise 4: Polymorphism with an Abstract Base Class

**Problem.** Model ALU operations as classes. An abstract base class declares a pure virtual `calc` function; one derived class per operation implements it. Store the objects in a queue of base handles and call them in a loop.

```systemverilog file=fx04_polymorphism.sv
module fx04_polymorphism;

  virtual class alu_operation;
    string name;

    function new(string name);
      this.name = name;
    endfunction

    pure virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);

    function void show(logic [7:0] a, logic [7:0] b);
      $display("%-4s %0d, %0d -> %0d", name, a, b, calc(a, b));
    endfunction
  endclass

  class op_add extends alu_operation;
    function new();
      super.new("add");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      logic [8:0] r;
      r = a + b;
      return r;
    endfunction
  endclass

  class op_sub extends alu_operation;
    function new();
      super.new("sub");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      logic [8:0] r;
      r = a - b;
      return r;
    endfunction
  endclass

  class op_xor extends alu_operation;
    function new();
      super.new("xor");
    endfunction
    virtual function logic [8:0] calc(logic [7:0] a, logic [7:0] b);
      return {1'b0, a ^ b};
    endfunction
  endclass

  alu_operation ops [$];
  op_add        h_add;
  op_sub        h_sub;
  op_xor        h_xor;

  initial begin
    h_add = new();
    h_sub = new();
    h_xor = new();
    ops.push_back(h_add);          // derived handles stored as base handles
    ops.push_back(h_sub);
    ops.push_back(h_xor);

    foreach (ops[i]) ops[i].show(200, 100);
    ops[1].show(100, 200);
  end

endmodule
```

```output
add  200, 100 -> 300
sub  200, 100 -> 100
xor  200, 100 -> 172
sub  100, 200 -> 412
```

**Points to explain.** `show` is written once in the base class and calls `calc`; because `calc` is virtual, each object runs its own version. `alu_operation` cannot be constructed. Adding a new operation means adding one class, with no change to the loop. The results are 9 bits wide: 100 - 200 is -100, which as a 9-bit pattern is 512 - 100 = 412 (bit 8 is the borrow). 200 XOR 100 is `1100_1000 ^ 0110_0100` = `1010_1100` = 172.

## Exercise 5: Constraints with a Procedural Self-Check

**Problem.** Write a class with a random dynamic array of 4 to 8 elements such that every element is a multiple of 5 between 10 and 200, the elements are strictly ascending, and their sum is at most 600. Verify the constraints by checking 50 randomizations with ordinary procedural code. Then show a call that cannot be solved.

```systemverilog file=fx05_constraints_check.sv
module fx05_constraints_check;

  class sorted_arr;
    rand bit [7:0] a [];

    constraint size_c { a.size() inside {[4:8]}; }
    constraint elem_c { foreach (a[i]) { a[i] inside {[10:200]}; a[i] % 5 == 0; } }
    constraint asc_c  { foreach (a[i]) if (i > 0) a[i] > a[i-1]; }
    constraint sum_c  { a.sum() with (int'(item)) <= 600; }

    // The same rules written procedurally, as an independent check
    function bit is_legal();
      int total;
      total = 0;
      if (a.size() < 4 || a.size() > 8) return 0;
      foreach (a[i]) begin
        if (a[i] < 10 || a[i] > 200 || a[i] % 5 != 0) return 0;
        if (i > 0 && a[i] <= a[i-1])                  return 0;
        total += a[i];
      end
      return total <= 600;
    endfunction
  endclass

  sorted_arr s;
  int        solver_failures, illegal_results, ok;

  initial begin
    s = new();
    repeat (50) begin
      if (!s.randomize())      solver_failures++;
      else if (!s.is_legal())  illegal_results++;
    end
    $display("50 calls: solver failures=%0d illegal results=%0d",
             solver_failures, illegal_results);

    // Eight ascending multiples of 5 starting at 180 or more do not exist below 200
    ok = s.randomize() with { a.size() == 8; a[0] >= 180; };
    $display("over-constrained call returned %0d", ok);

    if (solver_failures == 0 && illegal_results == 0 && ok == 0) $display("TEST PASSED");
    else                                                         $display("TEST FAILED");
  end

endmodule
```

```output
50 calls: solver failures=0 illegal results=0
over-constrained call returned 0
TEST PASSED
```

The simulator also prints a constraint-solver warning for the last call; its wording differs between tools.

**Points to explain.** The size is solved first, then the elements. `sum()` is widened with `int'(item)` because eight 8-bit values can exceed 255. Ascending order already implies that all elements differ. The inline constraints leave only 180, 185, 190, 195 and 200 as candidates, five values for eight strictly ascending positions, so the solver reports failure and returns 0. Writing the rules a second time procedurally is how constraint classes are unit-tested in practice.

## Exercise 6: A Three-Stage Pipeline with Mailboxes

**Problem.** A producer sends the numbers 1, 2 and 3, one every 10 time units. A processing stage doubles each number, taking 3 time units per item. A consumer prints what it receives. Connect them with two mailboxes and end the test when the consumer has received three items.

```systemverilog file=fx06_mailbox_pipeline.sv
module fx06_mailbox_pipeline;

  mailbox #(int) stage1_mbx = new();
  mailbox #(int) stage2_mbx = new();

  task automatic producer(int n);
    for (int i = 1; i <= n; i++) begin
      #10;
      stage1_mbx.put(i);
      $display("[%0t] producer : sent %0d", $time, i);
    end
  endtask

  task automatic doubler();
    int v;
    forever begin
      stage1_mbx.get(v);        // blocks while there is no work
      #3;
      stage2_mbx.put(2 * v);
    end
  endtask

  task automatic consumer(int n);
    int v;
    repeat (n) begin
      stage2_mbx.get(v);
      $display("[%0t] consumer : got %0d", $time, v);
    end
  endtask

  initial begin
    fork
      producer(3);
      doubler();
    join_none
    consumer(3);                // returns after the third item
    $display("[%0t] done", $time);
    $finish;
  end

endmodule
```

```output
[10] producer : sent 1
[13] consumer : got 2
[20] producer : sent 2
[23] consumer : got 4
[30] producer : sent 3
[33] consumer : got 6
[33] done
```

**Points to explain.** No stage knows about the others; each only knows its mailboxes. `get()` blocks, so there is no polling. The `doubler` task never ends, so it is started with `join_none`, and the test ends on the consumer's count, not on the producer finishing (at time 30 the last item is still inside the pipeline).

## Exercise 7: Three Users, Two Keys

**Problem.** Three threads need a resource that can serve two users at a time. Each uses it for 10 time units. The threads request the resource at times 0, 1 and 2. Use a semaphore and print when each thread enters and leaves.

```systemverilog file=fx07_semaphore.sv
module fx07_semaphore;

  semaphore slots = new(2);

  task automatic user(string name, int start);
    #start;
    slots.get(1);
    $display("[%0t] %s enters", $time, name);
    #10;
    $display("[%0t] %s leaves", $time, name);
    slots.put(1);
  endtask

  initial begin
    fork
      user("A", 0);
      user("B", 1);
      user("C", 2);
    join
    $display("[%0t] all done", $time);
  end

endmodule
```

```output
[0] A enters
[1] B enters
[10] A leaves
[10] C enters
[11] B leaves
[20] C leaves
[20] all done
```

**Points to explain.** A and B take the two keys. C asks at time 2 and blocks until A returns a key at time 10. At no time are more than two users inside. If `user` forgot `put(1)`, C would block forever and `join` would never complete.

## Exercise 8: Killing Slow Threads with Process Handles

**Problem.** Start three jobs in parallel that take 10, 40 and 90 time units. At time 50, report which jobs have finished and kill those that have not.

```systemverilog file=fx08_process_control.sv
module fx08_process_control;

  string  names [3] = '{"fast", "medium", "slow"};
  int     durs  [3] = '{10, 40, 90};
  process p [3];

  task automatic job(string name, int dur);
    #dur;
    $display("[%0t] %s finished", $time, name);
  endtask

  initial begin
    foreach (p[i])
      fork
        automatic int k = i;
        begin
          p[k] = process::self();     // remember the handle of this thread
          job(names[k], durs[k]);
        end
      join_none

    #50;                              // the deadline
    foreach (p[i])
      if (p[i].status() == process::FINISHED)
        $display("[%0t] %s: finished in time", $time, names[i]);
      else begin
        $display("[%0t] %s: still running, killed", $time, names[i]);
        p[i].kill();
      end

    #100 $display("[%0t] end of test", $time);
  end

endmodule
```

```output
[10] fast finished
[40] medium finished
[50] fast: finished in time
[50] medium: finished in time
[50] slow: still running, killed
[150] end of test
```

**Points to explain.** Each thread stores its own `process` handle as its first action. `status()` tells the parent the state of each thread, and `kill()` terminates only the selected one, which `disable fork` cannot do. The slow job never prints its "finished" message, although the simulation runs beyond time 90.

## Exercise 9: A Counter with Assertions and Coverage

**Problem.** Write a 2-bit counter with enable and asynchronous reset. In the testbench add two concurrent assertions (it increments when enabled, it holds when not enabled) and a covergroup that covers every count value and the wrap-around transition. Report assertion failures and coverage.

```systemverilog file=fx09_counter_sva_cov.sv
module counter2 (
  input  logic       clk, rst_n, en,
  output logic [1:0] count
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)  count <= '0;
    else if (en) count <= count + 2'd1;
endmodule

module fx09_counter_sva_cov;

  logic       clk = 0;
  logic       rst_n, en;
  logic [1:0] count;
  int         fail_cnt;

  counter2 dut (.*);

  always #5 clk = ~clk;

  // ---------------- assertions ----------------
  a_inc: assert property (@(posedge clk) disable iff (!rst_n)
                          en |=> count == $past(count) + 2'd1)
         else begin fail_cnt++; $error("counter did not increment"); end

  a_hold: assert property (@(posedge clk) disable iff (!rst_n)
                           !en |=> count == $past(count))
          else begin fail_cnt++; $error("counter changed while disabled"); end

  // ---------------- coverage ----------------
  covergroup count_cg @(posedge clk iff rst_n);
    cp_value: coverpoint count;                       // four automatic bins
    cp_wrap : coverpoint count { bins wrap = (2'd3 => 2'd0); }
  endgroup

  count_cg cg = new();

  // ---------------- stimulus ----------------
  initial begin
    rst_n = 0;
    en    = 0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    en    = 1;
    repeat (6) @(negedge clk);        // six rising edges with en = 1
    en = 0;
    repeat (2) @(negedge clk);        // two rising edges with en = 0
    $display("count=%0d", count);
    $display("assertion failures=%0d", fail_cnt);
    $display("coverage=%0.2f%%", cg.get_coverage());
    $finish;
  end

endmodule
```

```output
count=2
assertion failures=0
coverage=100.00%
```

**Points to explain.**

- The counter is enabled for six clock edges: 0 → 1 → 2 → 3 → 0 → 1 → 2. It then holds 2.
- The assertions use `|=>` because the effect of `en` is visible one clock later, and `$past(count)` is the value at the clock where `en` was sampled. The comparison is done in 2 bits, so 3 + 1 correctly wraps to 0.
- `disable iff (!rst_n)` stops the checks during reset.
- The covergroup samples on each rising clock edge while reset is inactive. The values 0, 1, 2 and 3 are all seen, and so is the transition from 3 to 0, so both coverpoints are fully covered and the covergroup reports 100%.

## Exercise 10: A Compact Layered Testbench for the ALU

**Problem.** Build a complete layered testbench for the course ALU in one file: interface with clocking blocks, transaction, generator, driver, monitor, scoreboard with a reference model, environment, test and top. Send 20 random transactions and report a summary. (M9 develops the same structure in full, one file per class, with line-by-line explanation; this exercise is the version you should be able to write from memory.)

```systemverilog file=fx10_alu_layered_tb.sv
package alu_pkg;
  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;
endpackage

module alu
  import alu_pkg::*;
(
  input  logic       clk, rst_n, valid_in,
  input  logic [7:0] a, b,
  input  alu_op_e    op,
  output logic       valid_out,
  output logic [8:0] result
);
  logic [8:0] result_nxt;

  always_comb begin
    result_nxt = '0;
    case (op)
      ALU_ADD: result_nxt = a + b;
      ALU_SUB: result_nxt = a - b;
      ALU_AND: result_nxt = {1'b0, a & b};
      ALU_OR : result_nxt = {1'b0, a | b};
      ALU_XOR: result_nxt = {1'b0, a ^ b};
      ALU_NOT: result_nxt = {1'b0, ~a};
      ALU_SHL: result_nxt = {a, 1'b0};
      ALU_SHR: result_nxt = {2'b00, a[7:1]};
      default: result_nxt = 'x;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      valid_out <= 1'b0;
      result    <= '0;
    end
    else begin
      valid_out <= valid_in;
      if (valid_in) result <= result_nxt;
    end
endmodule

interface alu_if (input logic clk);
  import alu_pkg::*;
  logic       rst_n, valid_in, valid_out;
  logic [7:0] a, b;
  alu_op_e    op;
  logic [8:0] result;

  clocking drv_cb @(posedge clk);
    output valid_in, a, b, op;
  endclocking

  clocking mon_cb @(posedge clk);
    input valid_in, a, b, op, valid_out, result;
  endclocking
endinterface

package alu_tb_pkg;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;
  endclass

  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    int unsigned       num_txn;

    function new(mailbox #(alu_txn) mbx, int unsigned num_txn);
      this.gen2drv_mbx = mbx;
      this.num_txn     = num_txn;
    endfunction

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();                         // one object per transaction
        txn.id = i;
        if (!txn.randomize()) $fatal(1, "randomize failed");
        gen2drv_mbx.put(txn);
      end
    endtask
  endclass

  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    virtual alu_if     vif;

    function new(mailbox #(alu_txn) mbx, virtual alu_if vif);
      this.gen2drv_mbx = mbx;
      this.vif         = vif;
    endfunction

    task run();
      alu_txn txn;
      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;              // idle value during reset
      wait (vif.rst_n === 1'b1);
      forever begin
        gen2drv_mbx.get(txn);
        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b1;
        vif.drv_cb.a        <= txn.a;
        vif.drv_cb.b        <= txn.b;
        vif.drv_cb.op       <= txn.op;
        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b0;            // one idle cycle between transactions
      end
    endtask
  endclass

  class alu_monitor;
    mailbox #(alu_txn) mon2scb_mbx;
    virtual alu_if     vif;

    function new(mailbox #(alu_txn) mbx, virtual alu_if vif);
      this.mon2scb_mbx = mbx;
      this.vif         = vif;
    endfunction

    task run();
      alu_txn txn;                              // inputs seen, result still to come
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid_out === 1'b1 && txn != null) begin
          txn.result = vif.mon_cb.result;       // result of the inputs captured earlier
          mon2scb_mbx.put(txn);
          txn = null;
        end
        if (vif.mon_cb.valid_in === 1'b1) begin
          txn    = new();
          txn.a  = vif.mon_cb.a;
          txn.b  = vif.mon_cb.b;
          txn.op = vif.mon_cb.op;
        end
      end
    endtask
  endclass

  class alu_scoreboard;
    mailbox #(alu_txn) mon2scb_mbx;
    int unsigned       pass_cnt, fail_cnt;

    function new(mailbox #(alu_txn) mbx);
      this.mon2scb_mbx = mbx;
    endfunction

    function logic [8:0] predict(bit [7:0] a, bit [7:0] b, alu_op_e op);
      logic [8:0] r;
      case (op)
        ALU_ADD: r = a + b;
        ALU_SUB: r = a - b;
        ALU_AND: r = {1'b0, a & b};
        ALU_OR : r = {1'b0, a | b};
        ALU_XOR: r = {1'b0, a ^ b};
        ALU_NOT: r = {1'b0, ~a};
        ALU_SHL: r = {a, 1'b0};
        ALU_SHR: r = {2'b00, a[7:1]};
        default: r = 'x;
      endcase
      return r;
    endfunction

    task run();
      alu_txn     txn;
      logic [8:0] expected;
      forever begin
        mon2scb_mbx.get(txn);
        expected = predict(txn.a, txn.b, txn.op);
        if (txn.result !== expected) begin
          fail_cnt++;
          $error("a=%0d b=%0d op=%s: result=%0d expected=%0d",
                 txn.a, txn.b, txn.op.name(), txn.result, expected);
        end
        else pass_cnt++;
      end
    endtask

    function void report(int unsigned sent);
      $display("scoreboard: sent=%0d checked=%0d passed=%0d failed=%0d",
               sent, pass_cnt + fail_cnt, pass_cnt, fail_cnt);
      if (fail_cnt == 0 && pass_cnt == sent) $display("TEST PASSED");
      else                                   $display("TEST FAILED");
    endfunction
  endclass

  class alu_env;
    alu_generator      gen;
    alu_driver         drv;
    alu_monitor        mon;
    alu_scoreboard     scb;
    mailbox #(alu_txn) gen2drv_mbx, mon2scb_mbx;
    int unsigned       num_txn;

    function new(virtual alu_if vif, int unsigned num_txn);
      this.num_txn = num_txn;
      gen2drv_mbx  = new();
      mon2scb_mbx  = new();
      gen = new(gen2drv_mbx, num_txn);
      drv = new(gen2drv_mbx, vif);
      mon = new(mon2scb_mbx, vif);
      scb = new(mon2scb_mbx);
    endfunction

    task run();
      fork
        gen.run();
        drv.run();
        mon.run();
        scb.run();
      join_none
      fork
        wait (scb.pass_cnt + scb.fail_cnt == num_txn);
        begin
          #100000;
          $error("timeout: the scoreboard did not receive all transactions");
        end
      join_any
      disable fork;                             // end of test: stop all components
      scb.report(num_txn);
    endtask
  endclass

  class alu_test;
    alu_env env;

    function new(virtual alu_if vif);
      env = new(vif, 20);
    endfunction

    task run();
      env.run();
    endtask
  endclass

endpackage

module fx10_alu_layered_tb;
  import alu_tb_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if vif (clk);

  alu dut (
    .clk       (clk),
    .rst_n     (vif.rst_n),
    .valid_in  (vif.valid_in),
    .a         (vif.a),
    .b         (vif.b),
    .op        (vif.op),
    .valid_out (vif.valid_out),
    .result    (vif.result)
  );

  alu_test test;

  initial begin
    vif.rst_n = 0;
    repeat (2) @(negedge clk);
    vif.rst_n = 1;
  end

  initial begin
    test = new(vif);
    test.run();
    $finish;
  end
endmodule
```

```output
scoreboard: sent=20 checked=20 passed=20 failed=0
TEST PASSED
```

**How the pieces fit.**

| Step | What happens |
|---|---|
| Top | Creates the clock, the interface instance and the DUT; applies reset for two clocks; constructs the test with the interface and runs it. |
| Environment constructor | Creates the two mailboxes once and hands the same handle to both ends of each connection; passes the virtual interface to the driver and monitor. |
| Generator | Creates a new object for every transaction, randomizes it, checks the result, and puts it in `gen2drv_mbx`. It needs no simulation time. |
| Driver | Waits for reset to end. For each transaction: waits for a clock, drives the inputs with `valid_in` = 1 through `drv_cb`, and one clock later sets `valid_in` back to 0. |
| DUT | Samples the inputs at the next rising edge; `result` and `valid_out` are visible after that edge. |
| Monitor | On every clock, through `mon_cb`: if `valid_out` is 1, it completes the pending transaction with `result` and sends it; if `valid_in` is 1, it starts a new transaction with the sampled inputs. The result check comes first so that back-to-back transactions would also be paired correctly. |
| Scoreboard | Computes the expected 9-bit result from the observed inputs and compares with `!==`. |
| End of test | The environment waits until the scoreboard has checked all 20 transactions (or a timeout), stops the components and prints the report. |

**Points an interviewer will probe.**

- Why a new `alu_txn` per loop iteration in the generator and the monitor (Q172, Q183).
- Why the driver and monitor use clocking blocks instead of the raw clock (Q113).
- Why the monitor pairs inputs with the result one clock later (Q184).
- Why the summary line checks `pass_cnt == sent`, not only `fail_cnt == 0` (Q305).
- What `disable fork` kills here and why that is acceptable at the end of the test (Q135).
- How a test would restrict the stimulus to additions only without editing the generator (Q254).
