# Part 3: Tasks

## 3.1 Tasks in SystemVerilog

### In plain English

A task is a named sequence of actions that is allowed to take time. "Apply reset for two clock cycles", "send one byte on the bus", "wait until the DUT says it is ready": each of these lasts for a while in simulation time, and each is something you want to write once and call many times. That is what a task is for.

A task does not hand back a value the way a function does. If it has results, it delivers them through `output`, `inout` or `ref` arguments.

### Technical definition

A task is a subroutine that

- **may** contain timing controls (`#`, `@`, `wait`) and other blocking statements, and may therefore consume simulation time (it does not have to),
- has **no return value**; it is called as a statement and cannot be used in an expression,
- may have any number of `input`, `output`, `inout` and `ref` arguments, including none,
- may call other tasks and functions.

### Syntax

```systemverilog
task [lifetime] task_name ([arguments]);
  [local declarations]
  statements
endtask [: task_name]
```

```systemverilog
// SystemVerilog (ANSI) style
task automatic wait_cycles(input int n);
  repeat (n) @(posedge clk);
endtask

// Verilog-1995 style: arguments declared in the body
task wait_cycles_v;
  input integer n;
  begin
    repeat (n) @(posedge clk);
  end
endtask
```

A task with no arguments may be called with or without parentheses: `reset_dut();` or `reset_dut;`.

### How it works internally

```text
   initial begin
     stmt_A;
     send_byte(8'hA5);     <-- call
     stmt_B;
   end

   1. Actual arguments are evaluated; input and inout values are copied into the formals.
   2. The CALLING PROCESS itself starts executing the task body. No new process is
      created: a task call is not a fork.
   3. When the body reaches @(posedge clk) or #10, the calling process suspends there.
      Other processes run; simulation time advances.
   4. When the wait is over, the process resumes inside the task.
   5. At endtask (or "return;"), output and inout formals are copied back to the
      caller's variables.
   6. The calling process continues with stmt_B.

   Consequence: stmt_B does not execute until the whole task has finished.
   A task call BLOCKS its caller for as long as the task takes.
```

Two properties of this mechanism cause most task-related bugs, and both are examined later:

- Output arguments are copied back **only when the task returns** (Section 4.1).
- In a `static` task, the formals and local variables are a single shared copy, so two processes inside the same task at the same time overwrite each other (Section 5.2).

### Complete example

```systemverilog file=tb_task_basic.sv
module tb_task_basic;

  logic       clk = 0;
  logic       valid = 0;
  logic [7:0] data;

  always #5 clk = ~clk;

  // A task with an input argument and timing control
  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  // A task that drives module-level signals over two clock cycles
  task automatic send_byte(input logic [7:0] value);
    @(posedge clk);
    valid <= 1'b1;
    data  <= value;
    @(posedge clk);
    valid <= 1'b0;
  endtask

  // A task with no timing control: legal, but it should have been a void function
  task automatic show(input string msg);
    $display("[%0t] %s", $time, msg);
  endtask

  // A simple monitor
  always @(posedge clk)
    if (valid) $display("[%0t] monitor saw data = %h", $time, data);

  initial begin
    show("start");
    wait_cycles(2);
    show("after wait_cycles(2)");
    send_byte(8'hA5);
    #1;
    show("after send_byte");
    $finish;
  end

endmodule
```

```output
[0] start
[15] after wait_cycles(2)
[35] monitor saw data = a5
[36] after send_byte
```

**Line by line**

| Line | Explanation |
|---|---|
| `task automatic wait_cycles(input int n);` | One input. The body waits for `n` rising edges, so the task consumes `n` clock cycles. |
| `wait_cycles(2);` | Called at time 0. Rising edges occur at 5 and 15, so the call returns at 15. The caller was blocked for 15 time units. |
| `send_byte(8'hA5);` | Called at 15, just after that edge. The first `@(posedge clk)` waits for the **next** edge, at 25. |
| `valid <= 1'b1; data <= value;` | Nonblocking drives at 25. The monitor block, which runs at the same edge, still sees `valid` = 0. This is how a real registered output behaves, and it is why testbench drives use `<=`. |
| Second `@(posedge clk)` | At 35 the monitor samples `valid` = 1 and `data` = `A5` and prints. The task then schedules `valid <= 0` and returns. |
| `#1;` | Moves the final message away from the clock edge, so that its order relative to the monitor's message is not left to the simulator. |
| `show(...)` | A task without any timing control. It works, but nothing can call it from a function. A void function is the better choice. |

A task can read and write any variable that is visible where the task is declared (`clk`, `valid`, `data` here). This is convenient in a small module-level testbench. In a class-based testbench the same signals are reached through a virtual interface (Module 8).

### Where tasks are used

| Use | Example |
|---|---|
| Pin-level protocol sequences | `drive(txn)`, `write_reg(addr, data)`, `read_reg(addr, data)` |
| Reset and initialisation sequences | `reset_dut()` |
| Waiting for conditions | `wait_for_ready()`, `wait_cycles(n)` |
| The main loop of every testbench component | `task run(); forever begin ... end endtask` in the driver, monitor, scoreboard |
| Bus functional models (BFMs) | A module or interface containing tasks that perform bus transfers |

### Synthesis

A task is synthesizable only if it contains no timing control, which makes it equivalent to a void function. In practice tasks are a verification construct; RTL uses functions.

> **Common mistake:** Trying to use a task in an expression: `x = my_task(a);` is a compile error. A task has no return value. Use an `output` argument, or make it a function if it does not consume time.

> **Common mistake:** Thinking that calling a task starts it "in the background". The caller waits until the task returns. To run a task in the background, call it inside `fork`...`join_none` (Module 7).

> **Verification application:** The driver's job in the ALU testbench is a task: wait for a clock edge, put `a`, `b`, `op` on the interface with `valid_in` = 1, wait one cycle, remove `valid_in`. It must be a task because it spans clock cycles. The transaction's `print()` is a function because it finishes instantly.

### Interview questions

**Q1. What is a task?**
A subroutine that can contain timing controls and so can consume simulation time. It has no return value, is called as a statement, and passes results back through `output`, `inout` or `ref` arguments.

**Q2. Must a task contain a delay?**
No. A task *may* consume time; it is not required to. But a subroutine that never needs to wait should be written as a function.

**Q3. Does calling a task create a new thread?**
No. The task body is executed by the calling process, which is blocked until the task returns. A new thread is created only by `fork`.

**Q4. Can a task return a value?**
Not with `return value;`. A task can use `return;` (with no expression) to exit early, and delivers values through its `output`, `inout` or `ref` arguments.

**Q5. Is a task synthesizable?**
Only when it contains no timing controls. Tasks are normally used in testbenches.

## 3.2 Timing Control Inside Tasks

### The three timing controls

| Control | Syntax | The task resumes when |
|---|---|---|
| Delay | `#10;` `#(period);` `#1ns;` | The given amount of simulation time has passed |
| Event control | `@(posedge clk);` `@(negedge rst_n);` `@(sig);` `@(ev);` | The next occurrence of the edge, change or named event |
| Level-sensitive wait | `wait (ready);` `wait (count == 0);` | The condition is true (immediately, if it already is) |

A task may also block in other ways: calling another task that blocks, `mailbox.get()`, `semaphore.get()`, `fork`...`join`, `wait fork` (Module 7).

### Which one to use

| Situation | Use | Why |
|---|---|---|
| Synchronous DUT interface | `@(posedge clk)` or a clocking block event `@(vif.drv_cb)` | The testbench stays aligned with the clock whatever the period is |
| Clock and reset generation, asynchronous stimulus | `#delay` | These define time itself |
| Waiting for a status flag | `wait (flag)`, or a loop of `@(posedge clk)` that tests the flag | `wait` alone is sensitive to glitches; sampling on the clock is safer for DUT signals |
| Protection against hanging | A timeout in parallel with the wait | Module 7 (`fork`...`join_any` with `disable fork`) |

> **Key point:** In a testbench for a clocked design, tasks should advance time with clock edges, not with `#` delays. A task written as `#10; valid = 1; #10; valid = 0;` breaks as soon as the clock period changes and can place stimulus exactly on the clock edge, creating a race.

### Execution trace of a task with timing

```systemverilog file=tb_task_timing.sv
module tb_task_timing;

  logic clk = 0;
  logic rst_n;
  logic ready = 0;

  always #5 clk = ~clk;

  initial #42 ready = 1;             // "DUT" raises ready at time 42

  task automatic reset_dut(input int cycles);
    rst_n = 1'b0;
    repeat (cycles) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("[%0t] reset released", $time);
  endtask

  task automatic wait_ready();
    $display("[%0t] waiting for ready", $time);
    wait (ready);
    $display("[%0t] ready is high", $time);
    @(posedge clk);
    $display("[%0t] aligned to the clock", $time);
  endtask

  initial begin
    reset_dut(2);
    wait_ready();
    wait_ready();
    #3;
    $display("[%0t] end", $time);
    $finish;
  end

endmodule
```

```output
[20] reset released
[20] waiting for ready
[42] ready is high
[45] aligned to the clock
[45] waiting for ready
[45] ready is high
[55] aligned to the clock
[58] end
```

**Execution flow**

| Time | What happens |
|---|---|
| 0 | `reset_dut(2)` drives `rst_n` low and waits. |
| 5, 15 | The two rising edges counted by `repeat (2)`. |
| 20 | `@(negedge clk)`: reset is released on a falling edge, away from the active edge. The task returns. |
| 20 | First `wait_ready()`: `ready` is 0, so `wait (ready)` suspends. |
| 42 | `ready` becomes 1. The `wait` ends at once, in the middle of a clock cycle. |
| 45 | `@(posedge clk)` brings the task back in step with the clock. It returns. |
| 45 | Second `wait_ready()`: `ready` is already 1, so `wait (ready)` does not block at all. |
| 55 | `@(posedge clk)` waits for the next edge, even though the task was called exactly at an edge. The edge at 45 has already happened. |
| 58 | `#3` after the return. |

This example shows the difference between a level-sensitive `wait` (passes straight through when the condition is true) and an edge-sensitive `@` (always waits for a future event).

### Tasks and the clock edge

```text
   clk      __|‾‾|__|‾‾|__|‾‾|__|‾‾|__
   time       5    15    25    35

   task automatic drive_op(...);
     @(posedge clk);          <- the caller is suspended until the edge
     valid_in <= 1'b1;        <- nonblocking: the DUT at THIS edge still sees the old value,
     a        <= a_i;            and sees the new values at the NEXT edge. No race.
     @(posedge clk);
     valid_in <= 1'b0;
   endtask
```

Driving with blocking assignments exactly at the active edge creates a race: whether the DUT samples the old or the new value depends on which process the simulator runs first. The three standard cures are nonblocking assignments (above), driving on the opposite edge (as the Module 1 testbench did), or a clocking block (Module 8).

### Leaving a task early

```systemverilog
task automatic wait_for_done(input int max_cycles);
  repeat (max_cycles) begin
    @(posedge clk);
    if (done) return;                 // leave the task as soon as done is seen
  end
  $error("done was not seen within %0d cycles", max_cycles);
endtask
```

`return;` ends the task at that point; output arguments are copied back as usual. `disable task_name;` also ends a task, but it kills **every** process currently executing that task, and output values are not guaranteed to be copied; it is a blunt Verilog-era tool and `return` is preferred.

> **Common mistake:** Calling a task that waits for an event that has already happened. `@(posedge start)` reached after `start` has already risen waits for the next rising edge, possibly for ever. Use `wait (start)` when "already true" should count.

> **Verification application:** Every component of the layered testbench has a `task run()` built from these controls. The driver's `run` is `forever begin gen2drv_mbx.get(txn); drive(txn); end`: it blocks on the mailbox until a transaction arrives, then blocks for the clock cycles needed to drive it. The whole behaviour of the testbench in time is the sum of the blocking points in its tasks.

### Interview questions

**Q1. Which timing controls can a task contain?**
Delays (`#`), event controls (`@`) and level-sensitive waits (`wait`), as well as any other blocking statement such as a blocking task call, `mailbox.get()` or `fork`...`join`.

**Q2. What is the difference between `#10` and `@(posedge clk)` inside a driver task?**
`#10` waits a fixed time regardless of the clock, so the stimulus drifts or races if the clock period or phase differs. `@(posedge clk)` waits for the actual clock edge, so the task stays synchronous with the DUT.

**Q3. A task is called at the exact time of a rising clock edge and begins with `@(posedge clk)`. When does it continue?**
At the next rising edge, one full period later. The edge at the time of the call has already occurred.

**Q4. How do you exit a task before its end?**
With `return;`. The older alternative is `disable` on the task or on a named block inside it.

## 3.3 Differences Between Functions and Tasks

### Comparison table

| Property | Function | Task |
|---|---|---|
| Simulation time | Always zero | Zero or more |
| Timing controls (`#`, `@`, `wait`) | Not allowed | Allowed |
| Return value | One value, or `void` | None |
| Use in an expression | Yes (non-void) | No |
| Called as a statement | Void functions; others with `void'()` | Yes |
| Arguments | `input`, `output`, `inout`, `ref`; zero or more | `input`, `output`, `inout`, `ref`; zero or more |
| Can call functions | Yes | Yes |
| Can call tasks | No (only inside `fork`...`join_none`) | Yes |
| `fork`...`join`, `join_any` | Not allowed | Allowed |
| `fork`...`join_none` | Allowed | Allowed |
| `return` statement | `return value;` (`return;` if void) | `return;` only |
| Usable in `assign`, `always_comb`, constraints | Yes | No |
| Synthesizable | Yes | Only without timing controls |
| Default lifetime in a module | Static | Static |
| Default lifetime in a class | Automatic | Automatic |
| Typical testbench use | `print`, `copy`, `compare`, reference model, `new` | `run`, `drive`, `monitor`, `reset`, anything that waits |

In old Verilog two more differences existed: a function needed at least one input and could not have outputs. SystemVerilog removed both restrictions, so do not quote them as SystemVerilog rules.

### The same job written both ways

```systemverilog file=tb_func_vs_task.sv
module tb_func_vs_task;

  logic clk = 0;
  always #5 clk = ~clk;

  // Function: answer available immediately, usable inside an expression
  function automatic logic [8:0] add9(logic [7:0] x, logic [7:0] y);
    return {1'b0, x} + {1'b0, y};
  endfunction

  // Task: same calculation, but the answer is delivered one clock cycle later,
  // the way the real ALU delivers it
  task automatic add9_clocked(input  logic [7:0] x,
                              input  logic [7:0] y,
                              output logic [8:0] sum);
    @(posedge clk);
    sum = {1'b0, x} + {1'b0, y};
  endtask

  logic [8:0] r;

  initial begin
    r = add9(8'd200, 8'd100);
    $display("[%0t] function result = %0d", $time, r);

    if (add9(8'd255, 8'd1) == 9'd256)
      $display("[%0t] a function call can sit inside a condition", $time);

    add9_clocked(8'd200, 8'd100, r);
    $display("[%0t] task result     = %0d", $time, r);
    $finish;
  end

endmodule
```

```output
[0] function result = 300
[0] a function call can sit inside a condition
[5] task result     = 300
```

The function gives its answer at the time of the call and can be embedded in an `if`. The task must be called as a separate statement, blocks the caller until the clock edge at time 5, and passes its answer back through the `output` argument.

### How to choose

```text
   Does the subroutine need to wait for anything
   (a clock edge, a delay, a mailbox, another task)?
            |
     +------+------+
     | yes         | no
     v             v
    TASK        Does it produce a single result?
                     |
              +------+------+
              | yes         | no
              v             v
          FUNCTION      VOID FUNCTION
        with return type
```

> **Interview trap:** "A task can do everything a function can and more, so why have functions?" Because a function carries a guarantee: it returns in zero time. That guarantee is what allows it to be used in expressions, continuous assignments, `always_comb`, constraints, constructors and `final` blocks. A task gives no such guarantee and is excluded from all of them.

> **Common mistake:** Saying "a function returns a value and a task does not" as the only difference. The primary difference is **time**. Return value comes second.

### Interview questions

**Q1. What are the differences between a function and a task?**
(1) A function executes in zero time and cannot contain timing controls; a task can consume time. (2) A function returns a value (unless void) and can be used in an expression; a task returns nothing and is called as a statement. (3) A function cannot call a task; a task can call both. (4) A function is synthesizable; a task only if it has no timing. Both accept `input`, `output`, `inout` and `ref` arguments.

**Q2. Can a function have output arguments like a task?**
Yes, in SystemVerilog.

**Q3. When would you choose a void function over a task?**
When the subroutine returns nothing but also never waits. It can then be called from functions and other zero-time contexts, and readers know it does not block.

**Q4. Which is used for the driver's main loop and which for a transaction's compare method? Why?**
The driver's loop is a task because it waits for clock edges and for mailbox items. `compare` is a function because it only inspects data and returns a pass/fail bit.

**Q5. Can a task be called from a continuous assignment or `always_comb`?**
No from a continuous assignment. `always_comb` does not allow blocking statements, so a task that consumes time is illegal there; use functions.

## 3.4 Tasks Calling Other Tasks and Functions

### The calling rules

| Caller ↓ / Callee → | Function | Task |
|---|---|---|
| **Function** | Allowed | **Not allowed** (only inside a `fork`...`join_none`) |
| **Task** | Allowed | Allowed |
| `initial`, `always`, `always_ff` body | Allowed | Allowed (`always_ff` and `always_comb` only if it does not block) |
| `always_comb`, `assign`, constraint | Allowed | Not allowed |
| `final` block | Allowed | Not allowed if it could consume time |

### Why layering subroutines matters

Real testbench code is layered. A test calls a high-level task; that task calls protocol-level tasks; those call signal-level tasks and helper functions. Each layer hides detail from the one above.

```text
   test:        run_smoke_test()                           (task)
                     |
                     +--> reset_dut()                      (task)   uses wait_cycles()
                     |
                     +--> do_op(a, b, op)                  (task)
                              |
                              +--> drive_op(...)           (task)   clock-level pin activity
                              +--> alu_model(a, b, op)     (function) expected value
                              +--> check(actual, expected) (function) compare and count
```

### Complete example: a task-based ALU testbench

This testbench uses the `alu_pkg` package and `alu` module from Module 1 (compile `alu_pkg.sv` and `alu.sv` first). It is the Module 1 directed test rewritten with tasks and functions, and it is the last step before the class-based testbench: in Module 9 each of these subroutines becomes a method of a class.

```systemverilog file=tb_alu_tasks.sv
module tb_alu_tasks;
  import alu_pkg::*;

  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  int unsigned pass_cnt, fail_cnt;

  alu dut (.*);

  always #5 clk = ~clk;

  // ---------- low-level tasks ----------
  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task automatic reset_dut();
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    wait_cycles(2);                  // a task calling a task
    @(negedge clk);
    rst_n = 1'b1;
  endtask

  task automatic drive_op(input  logic [7:0] a_i,
                          input  logic [7:0] b_i,
                          input  alu_op_e    op_i,
                          output logic [8:0] res);
    @(negedge clk);
    a        = a_i;
    b        = b_i;
    op       = op_i;
    valid_in = 1'b1;
    @(negedge clk);
    valid_in = 1'b0;
    res      = result;
  endtask

  // ---------- functions ----------
  function automatic logic [8:0] alu_model(logic [7:0] a_i,
                                           logic [7:0] b_i,
                                           alu_op_e    op_i);
    case (op_i)
      ALU_ADD: return {1'b0, a_i} + {1'b0, b_i};
      ALU_SUB: return {1'b0, a_i} - {1'b0, b_i};
      ALU_AND: return {1'b0, a_i & b_i};
      ALU_OR : return {1'b0, a_i | b_i};
      ALU_XOR: return {1'b0, a_i ^ b_i};
      ALU_NOT: return {1'b0, ~a_i};
      ALU_SHL: return {a_i, 1'b0};
      ALU_SHR: return {2'b00, a_i[7:1]};
      default: return 'x;
    endcase
  endfunction

  function automatic void check(alu_op_e op_i, logic [8:0] actual, logic [8:0] expected);
    if (actual !== expected) begin
      fail_cnt++;
      $display("[%0t] FAIL %s: actual=%0d expected=%0d",
               $time, op_i.name(), actual, expected);
    end
    else begin
      pass_cnt++;
      $display("[%0t] PASS %s: result=%0d", $time, op_i.name(), actual);
    end
  endfunction

  // ---------- high-level task ----------
  task automatic do_op(input logic [7:0] a_i, input logic [7:0] b_i, input alu_op_e op_i);
    logic [8:0] actual;
    drive_op(a_i, b_i, op_i, actual);                  // task calling a task
    check(op_i, actual, alu_model(a_i, b_i, op_i));    // task calling functions
  endtask

  // ---------- the test ----------
  initial begin
    reset_dut();
    do_op(8'd200, 8'd100, ALU_ADD);
    do_op(8'd5,   8'd10,  ALU_SUB);
    do_op(8'hF0,  8'h3C,  ALU_AND);
    do_op(8'h81,  8'h00,  ALU_SHL);
    do_op(8'hAA,  8'h00,  ALU_NOT);
    $display("[%0t] %0d passed, %0d failed", $time, pass_cnt, fail_cnt);
    $finish;
  end

endmodule
```

```output
[40] PASS ALU_ADD: result=300
[60] PASS ALU_SUB: result=507
[80] PASS ALU_AND: result=48
[100] PASS ALU_SHL: result=258
[120] PASS ALU_NOT: result=85
[120] 5 passed, 0 failed
```

**Execution flow**

| Time | What happens |
|---|---|
| 0 | `reset_dut` drives reset and idle inputs, then calls `wait_cycles(2)`. |
| 5, 15 | The two rising edges. `wait_cycles` returns into `reset_dut`. |
| 20 | Falling edge: reset released. `reset_dut` returns. |
| 20 | `do_op` calls `drive_op`, which waits for the next falling edge. |
| 30 | `drive_op` applies `a`=200, `b`=100, `op`=`ALU_ADD`, `valid_in`=1. |
| 35 | Rising edge: the ALU registers the result 300. |
| 40 | Falling edge: `drive_op` removes `valid_in`, copies `result` into `res` and returns; the output argument is copied to `actual`. `do_op` calls `alu_model` and `check`, both in zero time. |
| 50, 60 | The same sequence for the subtraction: drive at 50, check at 60. Each operation takes 20 time units. |
| 120 | Last check, then the summary. |

**Points to notice**

| Code | Explanation |
|---|---|
| `wait_cycles(2);` inside `reset_dut` | A task may call a task. The caller of `reset_dut` is blocked for the total time. |
| `output logic [8:0] res` | The only way for the task to give the sampled result back. |
| `alu_model` | A function: the expected value is pure calculation. `{1'b0, a_i} - {1'b0, b_i}` is evaluated in 9 bits, so 5 − 10 gives `1FB` = 507, the same wrapped value as the DUT (Module 1, Section 4.4). |
| `check` | A void function that updates the module-level counters. It uses `!==` so that an X result fails. |
| `check(op_i, actual, alu_model(a_i, b_i, op_i));` | A function call used as an argument of another function call. |
| `a_i`, `b_i`, `op_i` | The formal arguments have different names from the module signals `a`, `b`, `op`. If they had the same names, the argument would hide the signal inside the task, and `a = a;` would do nothing useful. |
| `do_op` | The test is now five readable lines. Adding a test case is one line. |

### Calls between parallel processes

If two processes call the same task at the same time (for example two `fork` branches both calling `drive_op`), both are executing the same code. Whether they interfere depends on the task's lifetime: with `automatic` each call has its own arguments and locals; with `static` they share them. They would still both be driving the same module signals, which needs a semaphore to arbitrate (Module 7). Section 5.2 demonstrates the lifetime problem.

### A function "calling" a task through fork...join_none

```systemverilog
function automatic void kick_off();
  fork
    reset_dut();          // legal here: executed by the spawned process, not by the function
  join_none
endfunction
```

As explained in Section 2.4, this is the only form in which a task call may appear inside a function body.

> **Common mistake:** Naming a formal argument the same as a module-level signal that the task is meant to drive. Inside the task the name refers to the argument. Use a suffix such as `_i`, or reach the signal through an interface handle (`vif.a`).

> **Verification application:** Compare the structure above with the layered testbench of Module 9. `drive_op` becomes `alu_driver::drive()`. Sampling `result` becomes `alu_monitor::run()`. `alu_model` and `check` become methods of `alu_scoreboard`. The five `do_op` lines become a generator producing random `alu_txn` objects. The functions-versus-tasks decision is the same in both.

### Interview questions

**Q1. Can a task call another task? Can it call a function?**
Yes to both. The calling task is blocked until the called task returns.

**Q2. Can a function call a task?**
No, because the task might consume time. The only exception is a call placed inside a `fork`...`join_none` in the function, where a separate spawned process executes the task.

**Q3. If task A calls task B and B waits for 3 clock cycles, how long is A's caller blocked?**
For the whole of A, including the 3 cycles of B. Blocking time adds up through the call chain.

**Q4. What happens when a task argument has the same name as a module signal?**
Inside the task the name refers to the argument; the module signal is hidden. Assignments intended for the signal go to the argument instead.

**Q5. Why is the reference model a function and the driver a task?**
The reference model computes the expected value from the inputs with no dependence on time. The driver must synchronise with the clock and hold values for a number of cycles.
