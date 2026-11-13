# Module 3 Overview

Module 1 covered the data that a SystemVerilog program stores. Module 2 covered collections of that data. This module covers **behaviour**: how statements are executed, how they are grouped into reusable subroutines (functions and tasks), how data is passed in and out of those subroutines, and how long the variables inside them live.

Everything in a class-based testbench is built from these pieces. A driver is a class whose main method is a task. A scoreboard's reference model is a function. A transaction's `print`, `copy` and `compare` are functions. If you are unsure why one is a task and the other a function, or why a value did not come back from a call, the answer is in this module.

**What this module covers**

| Part | Content |
|---|---|
| Part 1 | Procedural blocks (`initial`, `always`, `always_comb`, `always_ff`, `always_latch`, `final`), statement blocks, blocking and nonblocking assignments, the simulation event regions |
| Part 2 | Functions: declaration, returning values, `void` functions, why a function cannot consume simulation time |
| Part 3 | Tasks: declaration, timing control inside tasks, functions versus tasks, subroutines calling other subroutines |
| Part 4 | Arguments: `input`, `output`, `inout`, `ref`, `const ref`, pass by value, pass by reference, default values, binding by name |
| Part 5 | Lifetime (`static` and `automatic`), the shared-variable bug, recursion, functions and tasks inside classes |
| Part 6 | Revision summary, interview questions, output-prediction, find-the-error, coding exercises |

**What you need from earlier modules**

- Module 1: two-state and four-state types, `logic` and `int`, signedness, expression width, `typedef`, enums, the ALU design (`alu_pkg`, `alu`).
- Module 2: fixed-size arrays, dynamic arrays and queues at the level of declaring them and using `foreach`.

**Conventions.** The naming is the same as in the other modules: demonstration modules are called `tb_<topic>`, exercises `exNN_<name>`, the DUT is the 8-bit `alu`, and the transaction class is `alu_txn`. Every example with a file name is extracted to `examples/module-03/`.

> **Note:** The "Expected output" blocks were worked out by hand from the IEEE 1800 rules; they were not captured from a simulator run. Where the standard leaves an order undefined (for example which of two parallel processes starts first), the text says so. Run each example yourself.

# Part 1: Procedural Blocks and Assignments

## 1.1 Procedural Blocks: initial, always and final

### In plain English

SystemVerilog code is of two kinds.

- **Declarations and structure**: "this signal exists", "this module contains that module", "this wire always equals `a & b`". These statements describe things that exist for the whole simulation.
- **Procedural code**: "do this, then do that, then wait for the clock, then do something else". These statements are executed one after another, like a program in C.

Procedural statements cannot be written just anywhere inside a module. They must be placed inside a **procedural block**, which tells the simulator when to start executing them and whether to repeat them.

### Technical definition

A procedural block is a construct that creates one **process** (also called a thread). Each process executes its statements sequentially. All processes in the design run concurrently with each other.

| Block | Starts | Repeats? | Synthesizable | Purpose |
|---|---|---|---|---|
| `initial` | At time 0 | No, runs once | No (ignored by ASIC synthesis) | Testbench stimulus, initialisation, starting the test |
| `always` | At time 0 | Yes, forever | Yes, when written in a synthesizable style | General-purpose; Verilog legacy |
| `always_comb` | At time 0, then on any change of an input | Yes | Yes | Combinational logic |
| `always_ff` | On the specified clock/reset edge | Yes | Yes | Flip-flops |
| `always_latch` | At time 0, then on any change of an input | Yes | Yes | Latches (intended ones) |
| `final` | When the simulation ends | No, runs once | No | End-of-test reports |

A module can contain any number of each. There is **no defined order** between different blocks that become active at the same simulation time. Two `initial` blocks both start at time 0, and the standard does not say which executes first.

### Why they are needed

Hardware is concurrent: every gate and flip-flop operates at the same time. A simulator runs on a sequential computer, so it models concurrency with many small processes that each run for a moment and then wait. Procedural blocks are how you create those processes. `always` blocks model hardware that reacts to its inputs for ever. `initial` blocks model the one-off sequence of actions that a test performs.

### How it works internally

```text
   Time 0:  every initial and always block becomes a process and is put on the
            simulator's "ready" list.

            +-----------+     runs until it reaches a timing control     +-----------+
            |  process  | ---------------------------------------------> | suspended |
            |  running  |      ( #delay,  @(event),  wait(cond) )        |  waiting  |
            +-----------+ <--------------------------------------------- +-----------+
                              the delay expires / the event occurs

   - Only one process actually executes at any instant.
   - A process is never interrupted: it runs until IT reaches a timing control or ends.
   - When no process is ready at the current time, simulation time advances to the
     next scheduled event.
   - initial : when the last statement finishes, the process ends for good.
   - always  : when the last statement finishes, execution jumps back to the first.
```

The second point matters. Because a process runs without interruption until it suspends itself, an `always` block that contains **no timing control** never suspends, never lets time advance, and hangs the simulation at time 0.

### Syntax

```systemverilog
initial begin
  // statements, executed once
end

always @(posedge clk) begin        // general always with an event control
  // statements, executed at every rising edge
end

always #5 clk = ~clk;              // general always with a delay: clock generator

always_comb begin                  // no sensitivity list: it is inferred
  // combinational logic
end

always_ff @(posedge clk or negedge rst_n) begin
  // sequential logic, nonblocking assignments
end

always_latch begin
  if (en) q <= d;                  // intended latch
end

final begin
  // statements executed in zero time when simulation finishes
end
```

### Complete example

```systemverilog file=tb_procedural_blocks.sv
module tb_procedural_blocks;

  logic clk = 0;
  int   count;

  always #5 clk = ~clk;

  initial begin
    $display("[%0t] initial block 1 starts", $time);
    #12;
    $display("[%0t] initial block 1 ends", $time);
  end

  initial begin
    #3;
    $display("[%0t] initial block 2 runs in parallel", $time);
  end

  always @(posedge clk) begin
    count++;
    $display("[%0t] always block, count=%0d", $time, count);
  end

  initial #27 $finish;

  final $display("[%0t] final block, count=%0d", $time, count);

endmodule
```

```output
[0] initial block 1 starts
[3] initial block 2 runs in parallel
[5] always block, count=1
[12] initial block 1 ends
[15] always block, count=2
[25] always block, count=3
[27] final block, count=3
```

**Line by line**

| Line | Explanation |
|---|---|
| `always #5 clk = ~clk;` | A process that waits 5 time units, inverts `clk`, and repeats for ever. Rising edges occur at 5, 15, 25... |
| First `initial` | Starts at time 0, prints, suspends for 12 time units, prints again and ends. |
| Second `initial` | Also starts at time 0. It is a separate process, so its `#3` runs in parallel with the `#12` of the first block. Its message appears at time 3, between the two messages of block 1. |
| `always @(posedge clk)` | Suspends until a rising edge, executes the body, then returns to the top and suspends again. |
| `initial #27 $finish;` | A third `initial` block with a single statement. `begin`...`end` is needed only for more than one statement. |
| `final` | Runs once when `$finish` is executed (or when no events remain). The time is still 27. |

### The always family compared

| Property | `always @*` | `always_comb` | `always_ff` | `always_latch` |
|---|---|---|---|---|
| Sensitivity list | Inferred from signals read in the block | Inferred, **including** signals read inside called functions | Written explicitly | Inferred |
| Executes once at time 0 | No (waits for an input change) | Yes | No | Yes |
| Same variable written by another process | Allowed | Error | Error | Error |
| Timing controls inside the body | Allowed | Not allowed | Only the one at the top | Not allowed |
| Tool checks the intent | No | Warns if a latch is inferred | Requires sequential logic | Requires latch behaviour |

### initial versus always versus final

| Property | `initial` | `always` | `final` |
|---|---|---|---|
| Starts | Time 0 | Time 0 | End of simulation |
| Executions | One | Unlimited | One |
| May contain delays and event controls | Yes | Yes (must contain at least one) | No, it must execute in zero time |
| Number allowed per module | Any | Any | Any |
| Order among several of the same kind | Undefined | Undefined | Undefined |
| Typical use | Stimulus, starting the test | Clocks, RTL, monitors | Summary of pass/fail counts, coverage |

> **Interview trap:** "Two `initial` blocks in one module: which runs first?" The standard does not define it. Most simulators run them in source order, but code must never depend on that. If the order matters, put the statements in one block or synchronise them explicitly.

> **Common mistake:** Writing `always clk = ~clk;` without a delay. The process never suspends, so simulation time cannot advance and the simulator hangs at time 0 (some tools report a zero-delay loop).

> **Common mistake:** Expecting a `final` block to run when a simulation is killed or stopped by a fatal run-time crash. It runs on a normal end: an explicit `$finish`, or when the event queue becomes empty. A `final` block behaves like a function: it cannot contain `#`, `@` or `wait`.

> **Verification application:** `tb_top` normally contains one `always` for the clock, one `initial` for reset, and one `initial` that creates the test object and calls its `run()` task (Module 9). The scoreboard's totals are printed either at the end of the test's `run()` task or from a `final` block, so that they appear even when the test ends through `$finish` elsewhere.

### Interview questions

**Q1. What is the difference between `initial` and `always`?**
Both start at time 0. An `initial` block executes its statements once and terminates. An `always` block returns to its first statement after the last one and repeats for the whole simulation.

**Q2. Is `initial` synthesizable?**
Not for ASIC synthesis, which ignores it. Some FPGA tools use it to set power-up values of registers and memory contents.

**Q3. What happens with an `always` block that has no timing control?**
It becomes a zero-delay infinite loop. Simulation time never advances and the simulation hangs.

**Q4. What is a `final` block?**
A block that executes once at the end of simulation, in zero time. It may not contain delays, event controls or task calls that consume time. It is used to print summaries.

**Q5. Why prefer `always_comb` to `always @*`?**
It executes once at time 0 so the outputs are consistent with the inputs from the start, its sensitivity includes signals read in called functions, it forbids other processes from writing the same variables, and tools check that the result is really combinational.

**Q6. How many `initial` blocks can a module have, and in what order do they execute?**
Any number. They all start at time 0 as separate concurrent processes; the order of execution within that time step is not defined.

## 1.2 Statement Blocks: begin-end, Named Blocks and Local Variables

### In plain English

Wherever SystemVerilog expects one statement (the body of an `if`, a loop, an `always`), you can supply several by wrapping them in `begin` and `end`. It plays the role of the braces `{ }` in C.

### Technical definition

A **sequential block** `begin`...`end` groups statements that are executed one after another, in order. A **parallel block** `fork`...`join` groups statements that are executed concurrently, each as its own process (Module 7). Either kind of block may be given a **name**, and may declare its own local variables.

### Syntax

```systemverilog
begin : block_name          // the name is optional
  int local_var;            // declarations first
  statement_1;
  statement_2;
end : block_name            // the closing name is optional and must match
```

### What a block name gives you

| Feature | Use |
|---|---|
| Readability | A long `end` can be matched to its `begin` |
| `disable block_name;` | Abandons execution of that block and continues after its `end` |
| Hierarchical access | A variable declared inside is reachable as `block_name.local_var` in waveforms and debug |
| Coverage and assertion reports | Named blocks appear by name |

### Local variables and the initialiser rule

A variable may be declared at the start of any `begin`...`end` block. It is visible only inside that block.

There is a rule here that produces a compile error which confuses beginners. Inside a **static** context (an `initial` or `always` block in a module, or a task or function that is not `automatic`), a local variable is static: one copy exists for the whole simulation. If such a declaration has an initial value, the standard requires you to write the keyword `static` or `automatic` explicitly, so that it is clear whether the initialisation happens once or on every entry.

```systemverilog
initial begin
  int a;                  // legal: static, starts at 0
  // int b = 5;           // not legal in strict IEEE 1800: lifetime keyword required
  static    int c = 5;    // legal: initialised once, before time 0
  automatic int d = 5;    // legal: initialised each time the block is entered
  a = 5;                  // the simplest alternative: declare, then assign
end
```

Simulators differ in how strictly they apply this: some reject the commented line, others accept it with a warning. Section 5.1 explains lifetime in full. A loop variable declared in the loop header, `for (int i = 0; ...)`, is always automatic and needs no keyword.

### Complete example

```systemverilog file=tb_blocks.sv
module tb_blocks;

  int data [5] = '{3, 8, 12, 7, 20};

  initial begin : main_blk
    int found_at;
    found_at = -1;

    for (int i = 0; i < 5; i++) begin : scan
      if (data[i] > 10) begin
        found_at = i;
        break;
      end
    end : scan
    $display("1. first value above 10 is at index %0d", found_at);

    begin : guarded
      $display("2. inside guarded block");
      if (found_at == 2) disable guarded;
      $display("   this line is skipped");
    end : guarded
    $display("3. after guarded block");
  end : main_blk

endmodule
```

```output
1. first value above 10 is at index 2
2. inside guarded block
3. after guarded block
```

**Line by line**

| Line | Explanation |
|---|---|
| `initial begin : main_blk` | A named sequential block. |
| `int found_at;` then `found_at = -1;` | Declared without an initialiser and assigned separately, which avoids the lifetime-keyword rule described above. |
| `begin : scan` | The loop body is itself a named block. |
| `break;` | Leaves the nearest enclosing loop. `data[2]` is 12, the first value above 10. |
| `disable guarded;` | Terminates the block named `guarded`. Execution continues after `end : guarded`, so the next `$display` is skipped. |

### Ways to leave code early

| Statement | Effect | Where it can be used |
|---|---|---|
| `break;` | Leaves the innermost loop | Inside loops |
| `continue;` | Skips to the next iteration of the innermost loop | Inside loops |
| `return;` / `return value;` | Leaves the current task or function | Inside tasks and functions |
| `disable name;` | Terminates the named block or task, including every process started inside it | Anywhere the name is visible |
| `disable fork;` | Terminates all processes spawned by the current process | Module 7 |

`break`, `continue` and `return` were added by SystemVerilog. In Verilog the only way to do any of these was `disable`.

> **Common mistake:** Forgetting `begin`...`end` around a multi-statement body. In `if (x) a = 1; b = 2;` only the first assignment belongs to the `if`; `b = 2` always executes. Indentation means nothing to the compiler.

### Interview questions

**Q1. What is the difference between `begin`...`end` and `fork`...`join`?**
Statements in `begin`...`end` execute sequentially; a delay in one statement postpones all the following ones. Statements in `fork`...`join` start at the same time as separate processes; the block finishes when all of them have finished.

**Q2. What is a named block and why use it?**
A `begin`...`end` or `fork`...`join` with a label. The name allows the block to be disabled, lets its local variables be seen hierarchically, and documents the code.

**Q3. What is the difference between `break` and `disable`?**
`break` leaves the innermost loop only. `disable` terminates any named block or task, wherever it is called from, and also kills processes that were started inside that block.

## 1.3 Blocking and Nonblocking Assignments

### In plain English

SystemVerilog has two assignment operators for procedural code.

- `=` is the **blocking** assignment: "do it now". The left-hand side has its new value before the next statement is executed. It is the ordinary assignment of a programming language.
- `<=` is the **nonblocking** assignment: "work out the value now, but hand it over later, at the end of this time step". Statements that follow in the same block still see the old value.

The second form exists to model flip-flops. All flip-flops clocked by the same edge capture their inputs at the same instant; none of them sees the new output of another. Nonblocking assignment reproduces that: first every right-hand side is evaluated using old values, then every left-hand side is updated.

### Technical definition

| | Blocking `=` | Nonblocking `<=` |
|---|---|---|
| Step 1 | Evaluate the right-hand side | Evaluate the right-hand side |
| Step 2 | Update the left-hand side immediately, in the Active region | Schedule the update for the NBA (nonblocking assignment) region of the same time step |
| Next statement sees | The new value | The old value |
| "Blocks" the next statement | Yes: the next statement cannot run until the assignment is complete | No |

### How it works internally

```text
   c = 1;  d = 2;                              c      d
   -------------------------------------    -----  -----
   c <= d;     RHS evaluated: 2  (saved)       1      2
   d <= c;     RHS evaluated: 1  (saved)       1      2
   ...rest of the active processes run...      1      2
   --- NBA region of this time step ---
   apply saved updates: c = 2, d = 1           2      1      values swapped

   a = 1;  b = 2;                              a      b
   -------------------------------------    -----  -----
   a = b;      a becomes 2 immediately         2      2
   b = a;      b = new a = 2                   2      2      value 1 is lost
```

### Complete example

```systemverilog file=tb_blocking_nonblocking.sv
module tb_blocking_nonblocking;

  int a, b, c, d;

  initial begin
    a = 1;  b = 2;
    a = b;
    b = a;
    $display("1. blocking            : a=%0d b=%0d", a, b);

    c = 1;  d = 2;
    c <= d;
    d <= c;
    $display("2. nonblocking, before : c=%0d d=%0d", c, d);
    #1;
    $display("3. nonblocking, after  : c=%0d d=%0d", c, d);
  end

endmodule
```

```output
1. blocking            : a=2 b=2
2. nonblocking, before : c=1 d=2
3. nonblocking, after  : c=2 d=1
```

**Line by line**

| Line | Explanation |
|---|---|
| `a = b; b = a;` | `a` becomes 2 at once. The second statement then copies the new `a`. Both end up 2. |
| `c <= d; d <= c;` | Both right-hand sides are read immediately (2 and 1), but neither variable changes yet. |
| Line 2 of the output | The `$display` runs in the same Active region, before the NBA region, so it still shows the old values. |
| `#1;` | Lets the time step finish. The NBA updates have been applied: the values are swapped. |

### The reason nonblocking exists: a pipeline

```systemverilog file=tb_pipeline.sv
module tb_pipeline;

  logic     clk = 0;
  bit [3:0] d = 4'd5;
  bit [3:0] q1, q2, q3;      // written with nonblocking assignments
  bit [3:0] b1, b2, b3;      // written with blocking assignments

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    q1 <= d;
    q2 <= q1;
    q3 <= q2;
  end

  always @(posedge clk) begin
    b1 = d;
    b2 = b1;
    b3 = b2;
  end

  initial begin
    repeat (3) begin
      @(negedge clk);
      $display("[%0t] nonblocking q1 q2 q3 = %0d %0d %0d    blocking b1 b2 b3 = %0d %0d %0d",
               $time, q1, q2, q3, b1, b2, b3);
    end
    $finish;
  end

endmodule
```

```output
[10] nonblocking q1 q2 q3 = 5 0 0    blocking b1 b2 b3 = 5 5 5
[20] nonblocking q1 q2 q3 = 5 5 0    blocking b1 b2 b3 = 5 5 5
[30] nonblocking q1 q2 q3 = 5 5 5    blocking b1 b2 b3 = 5 5 5
```

With nonblocking assignments the value 5 moves one stage per clock, which is what three flip-flops in series do. With blocking assignments the value passes through all three variables in a single clock edge: the code describes one flip-flop with three names, not a three-stage pipeline.

### Races

When two processes run at the same time step, their order is undefined. With blocking assignments this causes a **race condition**:

```systemverilog
always @(posedge clk) x = y;      // process A
always @(posedge clk) y = x;      // process B
```

If A runs first, both variables end up with the old `y`. If B runs first, both end up with the old `x`. The result depends on the simulator. With `<=` in both blocks, the right-hand sides are read before either variable changes, so the values are swapped whichever process runs first.

### Coding guidelines

| Rule | Reason |
|---|---|
| Sequential logic (`always_ff`): use `<=` | Models simultaneous capture; avoids races between flip-flops |
| Combinational logic (`always_comb`): use `=` | A later statement in the block must see the result of an earlier one |
| Never mix `=` and `<=` to the same variable | Unpredictable results, rejected by synthesis |
| Never assign the same variable from two `always` blocks | Multiple drivers |
| Testbench stimulus to the DUT at a clock edge: use `<=`, or drive through a clocking block | Avoids a race between the testbench and the DUT (Module 8) |
| Testbench internal variables (counters, class properties, local variables): use `=` | They are ordinary program variables. Automatic variables may not be assigned with `<=` at all |

### Comparison table

| Property | Blocking `=` | Nonblocking `<=` |
|---|---|---|
| Update happens | Immediately | In the NBA region, after all active processes of the time step |
| Order of statements matters | Yes | No (for the values read) |
| Models | Combinational logic, software-style variables | Flip-flops, registered outputs |
| Legal in `assign` | The `=` there is a continuous assignment, a different construct | No |
| Legal on automatic variables and class properties | Yes | Automatic variables: no. Class properties: yes |
| Also means | — | "less than or equal" inside an expression |

`<=` is an assignment when it appears as a statement and a comparison when it appears inside an expression: in `a <= b <= c;` the first is the assignment and the second is the comparison.

> **Interview trap:** "`x = 1; x <= 2; $display(x);` What is printed, and what is `x` afterwards?" 1 is printed, because the nonblocking update has not yet been applied. At the end of the time step `x` becomes 2.

> **Interview trap:** "Does the nonblocking assignment evaluate its right-hand side later?" No. The right-hand side is evaluated immediately, when the statement executes. Only the update of the left-hand side is postponed.

### Interview questions

**Q1. What is the difference between blocking and nonblocking assignments?**
A blocking assignment evaluates the right-hand side and updates the left-hand side immediately, before the next statement executes. A nonblocking assignment evaluates the right-hand side immediately but updates the left-hand side at the end of the current time step, in the NBA region, so other statements in the time step see the old value.

**Q2. Why are nonblocking assignments used for sequential logic?**
All flip-flops on one clock edge must sample their inputs before any of them changes its output. Nonblocking assignment separates sampling from updating, so the result does not depend on the order in which the simulator runs the `always` blocks.

**Q3. Write code to swap two variables without a temporary.**
`a <= b; b <= a;` in the same block (or in two blocks triggered by the same event).

**Q4. What happens if blocking assignments are used in a clocked block that models a shift register?**
Within one block the value ripples through all the stages in one clock, so the stages collapse into one. Between separate blocks the result depends on execution order: a race.

**Q5. Can nonblocking assignments be used in an `initial` block?**
Yes. They are commonly used there to drive DUT inputs at a clock edge without racing with the DUT.

## 1.4 The Simulation Event Regions

### In plain English

Many things are scheduled to happen at the same simulation time: RTL blocks triggered by the clock, testbench code triggered by the same clock, nonblocking updates, assertions, `$monitor` printing. To give predictable results, the simulator divides each time step into ordered phases called **regions** and assigns every kind of activity to one of them.

You do not need to memorise the full algorithm. You do need to know the order of the main regions and what runs in each, because the answers to "why did my testbench sample the old value?" and "why does `$strobe` print something different from `$display`?" are found here, and because clocking blocks and program blocks (Module 8) are defined in terms of these regions.

### The regions of one time step

```text
   from the previous time step
              |
              v
   +---------------------+
   |      Preponed       |  values are SAMPLED for concurrent assertions and for clocking
   +---------------------+  block inputs (with the default #1step skew). Nothing changes here.
              |
              v
   +---------------------+ <------------------------------------------+
   |       Active        |  blocking assignments, RHS of nonblocking  |
   +---------------------+  assignments, continuous assignments,      |
              |             $display, all module (design) code        |
              v                                                       |
   +---------------------+                                            |
   |      Inactive       |  statements delayed by #0                  |  loop back while
   +---------------------+                                            |  any of these
              |                                                       |  regions has
              v                                                       |  events
   +---------------------+                                            |
   |        NBA          |  left-hand sides of nonblocking            |
   +---------------------+  assignments are updated                   |
              |                                                       |
              v                                                       |
   +---------------------+                                            |
   |      Observed       |  concurrent assertions are evaluated       |
   +---------------------+  (using the Preponed samples)              |
              |                                                       |
              v                                                       |
   +---------------------+                                            |
   |      Reactive       |  program-block code, assertion pass/fail   |
   | Re-Inactive, Re-NBA |  action blocks, clocking block drives -----+
   +---------------------+
              |
              v
   +---------------------+
   |      Postponed      |  $strobe and $monitor print; nothing may change any more
   +---------------------+
              |
              v
     advance to the next time step
```

### What runs where

| Region | Activity |
|---|---|
| Preponed | Sampling of signals for concurrent assertions and clocking-block inputs. The values seen are those from just before the time step |
| Active | Blocking assignments; evaluation of the right-hand side of nonblocking assignments; continuous assignments; evaluation of all module code; `$display` and `$write` |
| Inactive | Statements that were delayed with `#0` |
| NBA | Update of the left-hand side of nonblocking assignments |
| Observed | Evaluation of concurrent assertions |
| Reactive (with Re-Inactive, Re-NBA) | Code in `program` blocks; action blocks of assertions; drives from clocking blocks |
| Postponed | `$strobe`, `$monitor`; read-only |

Two consequences to remember:

1. An NBA update can wake up more Active processes (for example a flip-flop output feeding combinational logic), so the simulator loops Active → Inactive → NBA until nothing is left. These loops within one time step are called **delta cycles**.
2. Design code runs in the Active/NBA set of regions and program-block testbench code runs in the Reactive set, which comes later. This separation is what removes races between the DUT and the testbench (Module 8).

### Complete example

```systemverilog file=tb_regions.sv
module tb_regions;

  int x;

  initial begin
    x = 1;
    x <= 2;
    $strobe ("3. $strobe   (Postponed region)   : x=%0d", x);
    $display("1. $display  (Active region)      : x=%0d", x);
    #0;
    $display("2. after #0  (via Inactive region): x=%0d", x);
  end

endmodule
```

```output
1. $display  (Active region)      : x=1
2. after #0  (via Inactive region): x=1
3. $strobe   (Postponed region)   : x=2
```

**Line by line**

| Line | Explanation |
|---|---|
| `x = 1;` | Blocking: `x` is 1 immediately. |
| `x <= 2;` | The value 2 is saved; the update is scheduled for the NBA region. |
| `$strobe(...)` | Does not print now. It schedules the printing for the Postponed region, at the very end of the time step. |
| `$display(...)` | Prints immediately, in the Active region. The NBA update has not happened: 1. |
| `#0;` | Suspends the process and moves it to the Inactive region. It resumes after all currently active processes, but **before** the NBA region. |
| Second `$display` | Still 1. `#0` is not enough to see the result of a nonblocking assignment. |
| `$strobe` output | Printed last, although it appears first in the source. By then the NBA update has been applied: 2. |

### $display, $write, $strobe and $monitor

| Task | Prints when | Region | Notes |
|---|---|---|---|
| `$display` | Immediately when executed | Active (or Reactive, in a program) | Adds a newline |
| `$write` | Immediately when executed | Same | No newline |
| `$strobe` | Once, at the end of the current time step | Postponed | Shows final, settled values |
| `$monitor` | At the end of every time step in which an argument changed | Postponed | Only one `$monitor` is active at a time; `$monitoroff` / `$monitoron` control it |

> **Interview trap:** "`a <= 5; $display(a);` prints the old value. How do you print the new one?" Use `$strobe`, or wait for the next time step. `#0` does not work, because the Inactive region comes before the NBA region.

> **Common mistake:** Using `#0` to "fix" a race. It only moves one process later within the Active/Inactive loop. If another piece of code does the same, the race is back. Use nonblocking assignments, clocking blocks or proper synchronisation instead.

### Interview questions

**Q1. Name the main regions of a simulation time step in order.**
Preponed, Active, Inactive, NBA, Observed, Reactive (with Re-Inactive and Re-NBA), Postponed.

**Q2. In which region are nonblocking assignments updated?**
The right-hand side is evaluated in the Active region; the left-hand side is updated in the NBA region.

**Q3. What is the difference between `$display`, `$strobe` and `$monitor`?**
`$display` prints at once. `$strobe` prints once at the end of the current time step, after all assignments including nonblocking ones. `$monitor` is registered once and then prints at the end of any time step in which one of its arguments changed.

**Q4. What does `#0` do?**
It suspends the current process and reschedules it in the Inactive region of the same time step, so it resumes after the other currently active processes, but before nonblocking updates are applied.

**Q5. In which region are concurrent assertions sampled and evaluated?**
Their signals are sampled in the Preponed region and the assertion is evaluated in the Observed region. Their action blocks run in the Reactive region.

**Q6. What is a delta cycle?**
One pass through the Active–Inactive–NBA loop without simulation time advancing. Several delta cycles may be needed within one time step for all signals to settle.

## 1.5 Procedural Statements at a Glance

Functions and tasks are built from the following statements. Loops were covered with arrays in Module 2; this table is a reference.

| Statement | Form | Notes |
|---|---|---|
| Conditional | `if (c) ... else if (d) ... else ...` | An X or Z condition is treated as false (Module 1, Section 4.3) |
| `unique if`, `priority if` | `unique if (a) ... else if (b) ...` | `unique`: exactly one condition true, otherwise a violation report. `priority`: at least one true |
| Selection | `case`, `casez`, `casex`, `case (...) inside` | `unique case` and `priority case` add the same checks |
| Loops | `for`, `foreach`, `while`, `do`...`while`, `repeat (n)`, `forever` | `forever` needs a timing control or a `break` inside |
| Jumps | `break`, `continue`, `return` | Section 1.2 |
| Delay | `#10;` `#(period/2);` | Suspends the process for a time |
| Event control | `@(posedge clk);` `@(a or b);` `@(ev);` | Suspends until the event occurs **after** this statement is reached |
| Level-sensitive wait | `wait (ready == 1);` | Continues at once if the condition is already true; otherwise suspends until it becomes true |
| Assignment | `=`, `<=`, `+=`, `++` and the other operators | `++` and `+=` are blocking assignments |
| Subroutine call | `my_task(a, b);` `y = my_func(a);` | The rest of this module |
| Parallel block | `fork`...`join`, `join_any`, `join_none` | Module 7 |
| Immediate assertion | `assert (cond) else $error(...);` | Module 10 |

### @ versus wait

| | `@(posedge sig)` / `@(sig)` | `wait (sig)` |
|---|---|---|
| Sensitive to | A change (an edge) | A level (the condition being true) |
| If the condition already holds when reached | Still waits for the **next** change | Does not wait |
| Typical use | Synchronising to a clock | Waiting for a flag such as `done` or `!busy` |

This distinction returns in Module 7, where missing an event that was triggered just before `@` is reached is a standard cause of hung testbenches.

### Interview questions

**Q1. What is the difference between `@(posedge clk)` and `wait (clk)`?**
`@(posedge clk)` waits for the next rising edge, even if `clk` is already 1. `wait (clk)` continues immediately when `clk` is 1 and blocks only while it is 0.

**Q2. What is the difference between `while` and `do`...`while`?**
`while` tests the condition before each iteration, so the body may execute zero times. `do`...`while` tests it after each iteration, so the body executes at least once.

**Q3. What is wrong with `forever begin count++; end`?**
There is no timing control inside, so the loop never yields. Simulation hangs at the current time.
