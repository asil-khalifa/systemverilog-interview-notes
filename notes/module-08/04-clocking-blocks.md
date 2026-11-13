# Part 4: Clocking Blocks

## 4.1 The Problem: Races Between the Testbench and the DUT

### In plain English

A synchronous design reads its inputs at the rising edge of the clock. A testbench that changes those inputs **at the same rising edge** creates a question with no defined answer: does the design see the old value or the new one? Both the design and the testbench are waiting for the same edge. When it arrives, the simulator runs one of them first, and the language does not say which. The result depends on the simulator, on the order of the files, sometimes on an unrelated edit elsewhere in the code. This is a **race condition**.

In real hardware the question does not arise, because the previous flip-flop needs some time to change its output after the clock edge (clock-to-output delay), and the receiving flip-flop has long since captured the old value. A zero-delay RTL simulation has no such delay, so the testbench has to create that separation itself.

### A racy testbench

The design is a single flip-flop.

```systemverilog file=dff.sv
module dff (input logic clk, input logic d, output logic q);
  always_ff @(posedge clk) q <= d;
endmodule
```

Compile `dff.sv` first, then this file.

```systemverilog file=tb_race.sv
module tb_race;

  logic clk = 0, d = 0, q;
  always #5 clk = ~clk;

  dff dut (.*);

  initial begin
    @(posedge clk);          // time 5: wake up at the rising edge
    d = 1;                   // change the DUT input at that same edge (blocking)
    @(posedge clk);          // time 15
    $display("[%0t] q = %b", $time, q);
    $finish;
  end

endmodule
```

**There is no single expected output.** At time 5 two processes are woken by the same edge: the `always_ff` block in the DUT and the `initial` block in the testbench.

| If the simulator runs... | At time 5 the DUT samples | `q` after time 5 | Printed at time 15 |
|---|---|---|---|
| the DUT's `always_ff` first | `d` = 0 (old value) | 0 | `q = 0` |
| the testbench's `initial` first | `d` = 1 (new value) | 1 | `q = 1` |

Both are legal behaviours of a standard-compliant simulator. (At time 15 the DUT samples `d` = 1 in both cases, but that update of `q` is a nonblocking assignment and has not taken effect yet when `$display` runs.)

### The two races

| Race | What happens | Consequence |
|---|---|---|
| **Drive race** | The testbench changes a DUT input in the same time step in which the DUT samples it | The DUT may capture the new value one cycle too early |
| **Sample race** | The testbench reads a DUT output in the same time step in which the DUT changes it | The testbench may read the value from before or after the edge |

For a pure RTL design whose outputs come from nonblocking assignments, the sample race is milder, because the outputs change only after all sampling in the Active region is done (next section). It becomes real with behavioural models that use blocking assignments, with zero-delay gate-level netlists, and when the clock reaches the testbench and the DUT through different paths.

### Ways to avoid the race

| Technique | How it separates drive from sample | Weakness |
|---|---|---|
| Drive on the opposite (falling) edge | Half a cycle of separation | Wrong timing for protocols that use both edges; hand-written everywhere |
| Drive with a small delay after the edge: `@(posedge clk); #1 d = 1;` | The DUT has sampled before the delay ends | Delays scattered through the code; must be smaller than the clock period |
| Drive with a nonblocking assignment: `@(posedge clk); d <= 1;` | The update happens in the NBA region, after the DUT has sampled | Solves driving only; easy to break by one `=` somewhere |
| **Clocking block** | Sampling and driving times are declared once, in one place, and applied automatically | None in practice; this is the standard solution |

Parts 1 to 3 used the first technique. The rest of this part explains the last one.

### Interview questions

**Q1. What is a race condition between the testbench and the DUT?**
The testbench drives or samples a signal in the same simulation time step in which the DUT samples or drives it, so the result depends on the order in which the simulator happens to execute the two processes. The simulation result is then not deterministic.

**Q2. Why does the race not exist in real hardware?**
Real flip-flops have a clock-to-output delay, and data arrives through logic with delay, so an input changes after the capturing edge, not exactly at it. RTL simulation has zero delay and loses this separation.

**Q3. Give three ways to avoid a testbench-DUT race.**
Drive on the inactive clock edge; drive with nonblocking assignments or after a small delay; use a clocking block (optionally together with a program block).

## 4.2 How the Simulator Orders Events in One Time Step

To understand exactly what a clocking block does, you need a simplified picture of the **scheduler**. Everything that happens at one value of simulation time (one *time step* or *time slot*) is processed in ordered **regions**.

```text
   one time step, for example t = 25 (a rising clock edge)

   +-----------+  values are still those from the end of the previous time step
   | Preponed  |  -> clocking block inputs with skew #1step are sampled here
   +-----------+     (concurrent assertions also sample here)
         |
   +-----------+  module code runs: blocking assignments, continuous assignments,
   |  Active   |  evaluation of the right-hand side of nonblocking assignments.
   +-----------+  The DUT's always_ff blocks READ their inputs here.
         |
   +-----------+
   | Inactive  |  statements delayed with #0
   +-----------+
         |
   +-----------+  nonblocking assignments update their left-hand sides.
   |    NBA    |  The DUT's flip-flop OUTPUTS change here.
   +-----------+
         |
   +-----------+  concurrent assertions are evaluated;
   | Observed  |  clocking block inputs with skew #0 are sampled;
   +-----------+  the clocking block's own event (@(cb)) is triggered
         |
   +-----------+
   | Reactive  |  program block code and assertion action blocks run
   +-----------+
         |
   +-----------+
   |  Re-NBA   |  clocking block outputs with skew #0 are driven here
   +-----------+
         |
   +-----------+
   | Postponed |  $monitor and $strobe print; nothing can change any more
   +-----------+

   If a later region schedules new activity for an earlier region, the simulator loops
   back (for example Re-NBA -> Active) until the time step is quiet, then advances time.
```

Three facts from this picture explain everything else in Part 4:

1. **The DUT reads in Active and writes in NBA.** At a clock edge, flip-flops sample their inputs in the Active region and their outputs change in the NBA region.
2. **Preponed is before everything.** A value sampled in the Preponed region is the value the signal had just before the clock edge, which is exactly what a flip-flop clocked by that edge captures.
3. **Re-NBA and "edge + delay" are after the DUT has sampled.** A drive made there cannot be seen by the DUT at this edge. It is seen at the next edge.

### Interview questions

**Q1. In which region are nonblocking assignments updated? In which region are blocking assignments executed?**
Blocking assignments execute in the Active region. The right-hand side of a nonblocking assignment is evaluated in the Active region and its left-hand side is updated in the NBA region.

**Q2. What is the Preponed region used for?**
For sampling. Clocking block inputs with `#1step` skew and concurrent assertions take their values there, before any activity of the time step, so they see the stable values from just before the clock edge.

**Q3. In which region does program block code run?**
In the Reactive region, after the design has finished its Active and NBA processing for that time step.

## 4.3 What Is a Clocking Block?

### In plain English

A clocking block is a statement of timing discipline. It says: "these signals are synchronous to this clock edge; whenever I read one of them, give me the value it had just before the edge; whenever I write one of them, apply the value a little after the edge". After that, the testbench code just reads and writes through the clocking block and never thinks about races again.

### Technical definition

A `clocking` block, declared between `clocking` and `endclocking`, groups signals that are synchronous to a particular **clocking event** (such as `posedge clk`) and specifies, for each one, a direction and a **skew**:

- an **input** is *sampled* by the clocking block at the clocking event minus the input skew;
- an **output** is *driven* by the clocking block at the clocking event plus the output skew.

The direction is from the testbench's point of view: an input of the clocking block is something the testbench reads (a DUT output); an output is something the testbench drives (a DUT input).

### Why it is required

| Need | How the clocking block meets it |
|---|---|
| No drive race | Outputs change after the clock edge, when the DUT has already sampled |
| No sample race | Inputs are captured before the clock edge, when nothing is changing |
| Cycle-accurate testbench code | Code waits for `@(cb)` and thinks in clock cycles, not in time units |
| One place for the timing | Skews are declared once in the interface instead of `#1` delays spread over the driver |
| Works with any DUT timing | RTL, gate-level with delays: only the skew values change, not the testbench code |
| Models setup and hold | The input skew corresponds to sampling "setup time before the edge"; the output skew to "clock-to-output delay after the edge" |

### Syntax

```systemverilog
clocking <name> @(<clocking event>);
  default input <input skew> output <output skew>;   // optional; applies to all signals
  input  <signals>;                                  // sampled by the testbench
  output <signals>;                                  // driven by the testbench
  inout  <signals>;                                  // both
  input  #<skew> <signal>;                           // per-signal skew overrides default
  output negedge <signal>;                           // a skew can also be an edge
endclocking
```

```systemverilog
// Example: the driver's clocking block of the ALU interface
clocking drv_cb @(posedge clk);
  default input #1step output #1;
  output valid_in, a, b, op;         // the driver drives the DUT inputs
  input  valid_out, result;          // and may look at the DUT outputs
endclocking
```

- The names inside the clocking block refer to signals of the same name in the enclosing interface (or module). The clocking block's own versions are called **clockvars** and are accessed as `<clocking_block>.<signal>`, for example `drv_cb.a`.
- A clocking block may be declared in a module, an interface, a program or a checker. It may not be declared in a class or a package. In verification it is almost always inside the interface.
- A signal may appear in several clocking blocks (the ALU inputs appear in both `drv_cb` and `mon_cb`).
- Clocking blocks are simulation-only. They are ignored by synthesis.

### How it works internally

```text
                         interface alu_if
     +-------------------------------------------------------------+
     |   raw signals:   valid_in  a  b  op      valid_out  result  |
     |                     ^      ^  ^  ^           |         |    |
     |                     |      |  |  |           |         |    |
     |      driven at edge + output skew     sampled at edge - input skew
     |                     |      |  |  |           |         |    |
     |   clocking drv_cb @(posedge clk)             v         v    |
     |     output clockvars: valid_in a b op    input clockvars:   |
     |                                          valid_out result   |
     +-----------------------^---------------------------+---------+
                             |                           |
                 vif.drv_cb.a <= 5;          x = vif.drv_cb.result;
                 (testbench writes)          (testbench reads the SAMPLED copy)
```

- For every **input**, the clocking block keeps a sampled copy. At each clocking event the copy is refreshed with the value of the raw signal at "edge minus input skew". Reading `cb.sig` returns the copy, not the live signal. The copy stays constant until the next clocking event.
- For every **output**, a write `cb.sig <= value` does not change the raw signal immediately. The clocking block applies it to the raw signal at "edge plus output skew".

### Interview questions

**Q1. What is a clocking block?**
A construct that groups signals synchronous to a clock and defines when the testbench samples them (input skew before the clock event) and when it drives them (output skew after the clock event).

**Q2. Why are clocking blocks needed?**
To remove races between the testbench and the DUT and to let the testbench work in terms of clock cycles. Sampling happens before the edge and driving after it, so the order in which the simulator executes processes at the edge no longer matters.

**Q3. From whose point of view are the directions in a clocking block?**
The testbench's. `input` means the testbench samples it; `output` means the testbench drives it.

**Q4. Where can a clocking block be declared?**
In an interface, module, program or checker. Not in a class or a package.

**Q5. Is a clocking block synthesizable?**
No. It is a testbench construct.

## 4.4 Input and Output Skews

### Definition

A **skew** is the distance in time between the clocking event and the moment a signal is sampled or driven.

```text
                 input skew                output skew
              <------------->            <------------->
                            |            |
       sample point         | clock edge |         drive point
            v               v            |              v
   ---------+---------------+------------+--------------+----------> time
                            ^
                    the clocking event (for example posedge clk)

   Inputs are sampled BEFORE the edge.      Outputs are driven AFTER the edge.
```

### Skew values

| Skew | For an input: sampled... | For an output: driven... |
|---|---|---|
| `#1step` | In the Preponed region of the clock edge's time step: the last value before the edge | Not used for outputs |
| `#0` | In the **Observed** region of the clock edge's time step: **after** the DUT's NBA updates | In the Re-NBA region of the clock edge's time step |
| `#N` (a number, for example `#2`) | N time units before the clock edge | N time units after the clock edge |
| `#2ns` | A time literal may be used | |
| `posedge` / `negedge` | At that edge of the clock | At that edge of the clock |

### The defaults

If a clocking block gives no skew, the language uses:

| Direction | Default skew | Meaning |
|---|---|---|
| `input` | `#1step` | Sample the value from just before the clock edge |
| `output` | `#0` | Drive in the Re-NBA region of the same time step as the clock edge |

`#1step` is the smallest possible step back: one unit of the simulator's global time precision before the clock edge, which is the same as the value in the Preponed region. It is the right choice for inputs in almost every testbench.

The ALU interface uses `default input #1step output #1;`. The explicit output skew of one time unit makes the driven signals change visibly after the edge in the waveform, which is easier to debug than a change at exactly the edge.

### The #0 input skew trap

`input #0` does **not** mean "the value at the edge as the DUT sees it". It means "sample in the Observed region", which is after the DUT's flip-flops have already updated. The testbench then sees the **new** value of a DUT output, one cycle earlier than a flip-flop clocked by the same edge would.

### Complete example: #1step versus #0

```systemverilog file=tb_cb_skew.sv
module tb_cb_skew;

  logic       clk = 0;
  logic [3:0] count = 0;

  always #5 clk = ~clk;

  // A stand-in for the DUT: a register that changes at every rising edge
  always @(posedge clk) count <= count + 1'b1;

  clocking cb_step @(posedge clk);
    input #1step count;          // the value just before the edge
  endclocking

  clocking cb_zero @(posedge clk);
    input #0 count;              // the value after the edge has been processed
  endclocking

  initial begin
    repeat (3) begin
      @(negedge clk);            // look at the samples in the quiet middle of the cycle
      $display("[%0t] count now = %0d   #1step sample = %0d   #0 sample = %0d",
               $time, count, cb_step.count, cb_zero.count);
    end
    $finish;
  end

endmodule
```

```output
[10] count now = 1   #1step sample = 0   #0 sample = 1
[20] count now = 2   #1step sample = 1   #0 sample = 2
[30] count now = 3   #1step sample = 2   #0 sample = 3
```

**Line by line**

| Line | Explanation |
|---|---|
| `always @(posedge clk) count <= count + 1'b1;` | The register is updated by a nonblocking assignment, so it changes in the NBA region of each rising edge: to 1 at time 5, 2 at time 15, 3 at time 25. |
| `clocking cb_step ... input #1step count;` | A clocking block declared directly in a module. Its copy of `count` is taken in the Preponed region. |
| `clocking cb_zero ... input #0 count;` | The same signal with an explicit zero skew: its copy is taken in the Observed region. |
| `@(negedge clk);` | The samples are printed at the falling edge, when nothing is changing, so the printout itself has no race. |
| `cb_step.count`, `cb_zero.count` | The sampled copies held by the two clocking blocks. They keep their value until the next rising edge. |

**What happened at the rising edge at time 15**

| Region | Event |
|---|---|
| Preponed | `cb_step` samples `count` = 1 (the value before the edge) |
| Active | The `always` block evaluates `count + 1` = 2 |
| NBA | `count` becomes 2 |
| Observed | `cb_zero` samples `count` = 2 (the value after the edge) |

The `#1step` sample is what another flip-flop would have captured at that edge. The `#0` sample is already one step ahead.

> **Interview trap:** "What are the default input and output skews of a clocking block?" Input `#1step`, output `#0`. A common wrong answer is "`#0` for both".

> **Interview trap:** "What is the difference between `input #0` and `input #1step`?" `#1step` samples in the Preponed region, before the clock edge is processed: the old, stable value. `#0` samples in the Observed region, after the design's nonblocking updates: the new value. A monitor with `#0` reports DUT outputs one cycle earlier than the DUT's neighbours would see them, which shifts the scoreboard's comparison by a cycle.

### Interview questions

**Q1. What is skew in a clocking block?**
The offset between the clocking event and the point at which a signal is sampled (input skew, before the event) or driven (output skew, after the event).

**Q2. What does `#1step` mean?**
Sample one time step before the clocking event, that is, the value of the signal in the Preponed region of the clock edge's time step: the last stable value before the edge.

**Q3. What does `default input #2 output #3;` mean in a clocking block with `@(posedge clk)`?**
Inputs are sampled 2 time units before each rising clock edge, and outputs are driven 3 time units after it.

**Q4. Can each signal have its own skew?**
Yes. A skew written in a signal's own declaration (`input #4 data;`) overrides the default of the clocking block.

## 4.5 Sampling and Driving Through a Clocking Block

### The four operations

| Operation | Syntax | Meaning |
|---|---|---|
| Wait for the clocking event | `@(cb);` or `@(vif.cb);` | Suspend until the next clock event of this clocking block. On waking, the input samples for that event are available |
| Read an input | `x = cb.sig;` | Returns the value sampled at the most recent clocking event |
| Drive an output | `cb.sig <= value;` | A **synchronous drive**: the value is applied to the signal at the clocking event plus the output skew |
| Wait for a sampled value to change | `@(cb.sig);` `@(posedge cb.sig);` | Wakes when the sampled copy changes, which can only happen at a clocking event |

### Rules

| Rule | Example | Result |
|---|---|---|
| Outputs are driven only with `<=` | `cb.a <= 8'h10;` | Legal |
| Blocking assignment to a clockvar | `cb.a = 8'h10;` | **Compile error** |
| Reading an output-only clockvar | `x = cb.a;` (when `a` is an `output`) | **Compile error**. Declare it `inout` if it must also be read |
| Writing an input clockvar | `cb.result <= 0;` | **Compile error** |
| A drive executed exactly at a clocking event | After `@(cb);` | Takes effect at that event plus the output skew |
| A drive executed at any other time | After `#3;` or `@(negedge clk);` | Takes effect as if it had been executed at the **next** clocking event |
| Several drives to the same output for the same event | Two `cb.a <= ...` statements in one cycle | The last one wins |
| The drive statement does not block | `cb.a <= 1;` | The process continues at once; the signal changes later |

The `<=` used for a synchronous drive looks like a nonblocking assignment but its timing is defined by the clocking block: clock event plus output skew.

### Do not mix raw clock edges with clocking block samples

```systemverilog
// Risky
@(posedge vif.clk);
x = vif.mon_cb.result;      // has the clocking block refreshed its sample yet?

// Correct
@(vif.mon_cb);
x = vif.mon_cb.result;      // guaranteed to be the sample taken at this event
```

A process that waits on the raw signal `@(posedge clk)` and then reads a clockvar is racing against the clocking block's own update of that clockvar: it may get the sample of this edge or of the previous one. A process that waits on the clocking block itself, `@(cb)`, is guaranteed by the language to see the updated samples.

> **Key point:** Once a signal is behind a clocking block, use the clocking block for everything: wait with `@(vif.cb)`, read `vif.cb.sig`, drive `vif.cb.sig <= value`. Do not go around it with `@(posedge vif.clk)` or `vif.sig`.

### Timing of one driven value and one sampled value

The diagram shows the ALU with a clock period of 10, rising edges at 25, 35 and 45, and the driver's clocking block `default input #1step output #1`. The driver executes `vif.drv_cb.valid_in <= 1` when it wakes at edge 25 and `vif.drv_cb.valid_in <= 0` when it wakes at edge 35.

```text
  time       20        25        30        35        40        45
                         26                  36
             |         | |       |         | |       |         |
                       +---------+         +---------+         +-----
  clk        __________|         |_________|         |_________|

                         +-------------------+
  valid_in   ____________|                   |_______________________

                                           +-------------------+
  valid_out  ______________________________|                   |_____

  edge 25:  DUT samples valid_in = 0.   Driver wakes, writes 1 -> applied at 26.
  edge 35:  DUT samples valid_in = 1 -> valid_out becomes 1 (NBA region of 35).
            Clocking blocks sample (Preponed): valid_in = 1, valid_out = 0.
            Driver wakes, writes 0 -> applied at 36.
  edge 45:  DUT samples valid_in = 0 -> valid_out becomes 0.
            Clocking blocks sample (Preponed): valid_in = 0, valid_out = 1.
```

Read the diagram as a rule: **a value driven through the clocking block in one cycle is seen by the DUT at the next rising edge, and a value produced by the DUT at one rising edge is seen through the clocking block at the next rising edge.** That is exactly how one flip-flop sees another, so the testbench behaves like a synchronous neighbour of the DUT.

### Interview questions

**Q1. How do you drive a signal through a clocking block?**
With the synchronous drive `cb.signal <= value;`. Only the `<=` form is allowed. The value is applied at the clocking event plus the output skew.

**Q2. How do you sample a signal through a clocking block?**
Wait for the clocking event with `@(cb);` and read `cb.signal`, which returns the value captured at the input skew before that event.

**Q3. What does `@(vif.drv_cb)` wait for?**
The next occurrence of the clocking event of `drv_cb`, for example the next rising edge of `clk`. On waking, the block's input samples for that edge are valid.

**Q4. What happens if `cb.a <= 1;` is executed between two clock edges?**
The drive is treated as if it were executed at the next clocking event, so the signal changes at that event plus the output skew.

**Q5. Why should you not write `@(posedge vif.clk)` and then read `vif.cb.sig`?**
There is a race between that process and the clocking block's update of its sampled values, so the read may return the previous sample. Waiting on `@(vif.cb)` guarantees the samples are current.

## 4.6 Race Prevention with a Clocking Block

This is the racy flip-flop testbench of Section 4.1, rewritten with an interface and a clocking block.

Compile `dff.sv` first, then this file.

```systemverilog file=tb_race_fixed.sv
interface dff_if (input logic clk);
  logic d = 0;
  logic q;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output d;                 // the testbench drives d
    input  q;                 // the testbench samples q
  endclocking
endinterface

module tb_race_fixed;

  logic clk = 0;
  always #5 clk = ~clk;

  dff_if dif (clk);
  dff    dut (.clk(clk), .d(dif.d), .q(dif.q));

  initial begin
    @(dif.cb);                // time 5
    dif.cb.d <= 1;            // applied at time 6: after the DUT has sampled
    @(dif.cb);                // time 15
    $display("[%0t] sampled q = %b", $time, dif.cb.q);
    @(dif.cb);                // time 25
    $display("[%0t] sampled q = %b", $time, dif.cb.q);
    $finish;
  end

endmodule
```

```output
[15] sampled q = 0
[25] sampled q = 1
```

**Line by line**

| Line | Explanation |
|---|---|
| `logic d = 0;` | `d` starts at 0 instead of X, so the first sampled value is known. |
| `clocking cb @(posedge clk);` | All timing is relative to the rising edge of `clk`. |
| `default input #1step output #1;` | Sample just before the edge; drive one time unit after it. |
| `output d; input q;` | From the testbench's side: it drives `d` and observes `q`. |
| `@(dif.cb);` | Wait for the clocking event. The module accesses the clocking block as `<interface instance>.<clocking block>`. |
| `dif.cb.d <= 1;` | Synchronous drive. Executed at time 5, applied to `dif.d` at time 6. |
| `dif.cb.q` | The sampled copy of `q`. |

**Execution flow**

| Time | Region | Event |
|---|---|---|
| 5 | Active | The DUT samples `d` = 0 and schedules `q` = 0. The testbench wakes and requests `d` = 1. |
| 5 | NBA | `q` becomes 0. |
| 6 | | The clocking block applies `d` = 1. |
| 15 | Preponed | `cb` samples `q` = 0. |
| 15 | Active / NBA | The DUT samples `d` = 1; `q` becomes 1. |
| 15 | | The testbench wakes and prints the **sampled** `q` = 0. |
| 25 | Preponed | `cb` samples `q` = 1. |
| 25 | | The testbench prints the sampled `q` = 1. |

The output is the same on every simulator, whatever order the processes are executed in, because the DUT's sampling (Active region of the edge), the testbench's sampling (Preponed region of the edge) and the testbench's driving (one time unit later) never coincide.

### Racy and fixed versions side by side

| | Racy version (`tb_race.sv`) | Fixed version (`tb_race_fixed.sv`) |
|---|---|---|
| Wait for the clock | `@(posedge clk);` | `@(dif.cb);` |
| Drive | `d = 1;` at the edge, in the Active region | `dif.cb.d <= 1;` applied at edge + 1 |
| Sample | `q` read directly at the edge | `dif.cb.q`, captured before the edge |
| DUT sees the new `d` | At this edge or the next, depending on the simulator | Always at the next edge |
| Result | Simulator-dependent | Deterministic |

### Interview questions

**Q1. How does a clocking block prevent race conditions?**
It separates the three activities in time. The DUT samples its inputs in the Active region of the clock edge. The clocking block samples DUT outputs before that, in the Preponed region. It drives DUT inputs after that, at the edge plus the output skew (or in the Re-NBA region for zero skew). Because they never happen at the same point, the execution order chosen by the simulator cannot change the result.

**Q2. Is a clocking block the only way to avoid races?**
No. Driving on the opposite clock edge, driving with nonblocking assignments, adding a small delay, or putting the testbench in a program block also work. The clocking block is the most complete: it covers both sampling and driving, keeps the timing in one place, and works unchanged for gate-level simulation.

## 4.7 Cycle Delays (##N) and Default Clocking

### Definition

Inside a module, interface or program, one clocking block can be made the **default clocking**. The cycle delay operator `##N` then means "wait N clocking events of the default clocking block".

```systemverilog
default clocking cb @(posedge clk);     // declares a clocking block, makes it the default
  ...
endclocking

default clocking cb;                     // or: makes an existing clocking block the default

##1;                    // wait for 1 clocking event
##5;                    // wait for 5 clocking events
##(n + 1);              // an expression needs parentheses
cb.sig <= ##2 value;    // drive 'value' two clocking events from now (does not block)
```

| Form | Meaning |
|---|---|
| `##N;` as a statement | Blocks the process for N clocking events. Equivalent to `repeat (N) @(cb);` |
| `cb.sig <= ##N value;` | The value is evaluated now and driven N clocking events later (plus the output skew). The process is not blocked |
| `##N` inside a sequence or property | Delay of N cycles in an assertion (Module 10). The same symbol, a related meaning |

### Complete example

```systemverilog file=tb_cycle_delay.sv
module tb_cycle_delay;

  logic       clk = 0;
  logic [3:0] d   = 0;

  always #5 clk = ~clk;

  default clocking cb @(posedge clk);
    default input #1step output #2;
    output d;
  endclocking

  always @(d) $display("[%0t] d changed to %0d", $time, d);

  initial begin
    ##1;                            // wait for 1 clocking event: time 5
    $display("[%0t] after ##1", $time);
    cb.d <= 4'd7;                   // applied at 5 + 2 = 7

    ##3;                            // three more events: 15, 25, 35
    $display("[%0t] after ##3", $time);
    cb.d <= ##2 4'd9;               // two events later (55), plus skew: 57

    ##3;                            // 45, 55, 65
    $display("[%0t] done", $time);
    $finish;
  end

endmodule
```

```output
[5] after ##1
[7] d changed to 7
[35] after ##3
[57] d changed to 9
[65] done
```

**Line by line**

| Line | Explanation |
|---|---|
| `default clocking cb @(posedge clk);` | Declares `cb` and makes it the default clocking of this module. |
| `always @(d) $display(...)` | Reports every change of the raw signal `d`, to show when the drives really happen. |
| `##1;` | Executed at time 0. Waits for the next clocking event, the rising edge at time 5. |
| `cb.d <= 4'd7;` | Executed at the clocking event of time 5. With output skew `#2`, `d` changes at time 7. |
| `##3;` | Waits for the events at 15, 25 and 35. |
| `cb.d <= ##2 4'd9;` | Executed at 35. The drive is scheduled two events later (55) plus the skew: time 57. The statement does not wait; execution continues immediately. |
| `##3;` | Waits for 45, 55 and 65. The scheduled change at 57 is printed while this wait is in progress. |

### The limitation in classes

`##N` needs a default clocking in the scope where it is written. A class, and a package, has no default clocking, so `##2;` inside a class method is a compile error. In class-based testbenches the equivalent is:

```systemverilog
repeat (2) @(vif.drv_cb);
```

> **Interview trap:** "Can you use `##5` in a driver class?" No. There is no default clocking block in a class. Use `repeat (5) @(vif.cb);`.

### Interview questions

**Q1. What does `##3` mean?**
As a procedural statement it waits for three clocking events of the default clocking block of the current module, interface or program.

**Q2. What is needed for `##N` to compile as a statement?**
A `default clocking` declaration in the enclosing module, interface or program.

**Q3. What is the difference between `#5` and `##5`?**
`#5` is a delay of 5 time units. `##5` is a delay of 5 clock cycles (clocking events).
