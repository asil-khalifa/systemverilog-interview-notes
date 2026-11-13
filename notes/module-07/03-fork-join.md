# Part 3: Fork and Join

## 3.1 Sequential and Parallel Blocks

### In plain English

A `begin` ... `end` block is a to-do list for one worker: the statements are done one after another. A `fork` ... `join` block hires one worker **per statement**: all the statements start together and each proceeds at its own pace. The word after the block (`join`, `join_any` or `join_none`) only decides how long the person who hired the workers waits for them.

### Technical definition

| Block | Name | Behaviour |
|---|---|---|
| `begin` ... `end` | Sequential block | Statements execute in order, as part of the current process |
| `fork` ... `join` / `join_any` / `join_none` | Parallel block | **Each statement** inside becomes a separate child process. All children are created at the same simulation time |

The process that executes the `fork` is the **parent**. The processes it creates are its **children** (also called sub-processes or spawned threads). A child that itself executes a `fork` creates grandchildren, and so on: processes form a tree.

### What counts as one thread

Each *statement* directly inside the `fork` is one thread. To put several statements into one thread, group them with `begin` ... `end`.

```text
   fork
     statement_1;              -> thread 1
     begin                     -> thread 2 (the whole begin...end block, executed in order)
       statement_2a;
       statement_2b;
     end
     task_call();              -> thread 3 (everything the task does)
   join
```

### Why it is needed

- A testbench must run its components at the same time: `fork gen.run(); drv.run(); mon.run(); scb.run(); join_none`.
- A test must apply stimulus on several interfaces at once.
- Checks need time limits: "wait for the response, but give up after 1000 clock cycles".
- A design with several independent interfaces needs traffic on all of them concurrently to find the bugs that occur only when things overlap.

`initial` and `always` blocks also create threads, but only fixed ones, at the module level. Classes cannot contain `initial` or `always` blocks. `fork` is the only way for class-based code to start a thread, and it can create any number of threads at run time.

### Complete example

```systemverilog file=tb_fork_threads.sv
module tb_fork_threads;

  initial begin
    fork
      #10 $display("[%0t] thread 1 (a single statement)", $time);

      begin
        #5  $display("[%0t] thread 2: first statement", $time);
        #20 $display("[%0t] thread 2: second statement", $time);
      end

      #15 $display("[%0t] thread 3 (a single statement)", $time);
    join
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
```

```output
[5] thread 2: first statement
[10] thread 1 (a single statement)
[15] thread 3 (a single statement)
[25] thread 2: second statement
[25] parent: all threads finished
```

**Line by line**

| Line | Explanation |
|---|---|
| `fork` | Three child threads are created at time 0. |
| `#10 $display(...)` | Thread 1 is one statement: wait 10, print. |
| `begin ... end` | Thread 2 is the whole block. Its two statements run **sequentially** inside the thread: the second delay starts when the first statement is done, so it prints at 5 and at 5 + 20 = 25. |
| `#15 $display(...)` | Thread 3 prints at 15. All three delays are counted from time 0, because the threads started together. |
| `join` | The parent waits until the last thread (thread 2) finishes at 25. |

> **Common mistake:** Forgetting `begin` ... `end`. In
> `fork  drive_header();  drive_payload();  join`
> the header and the payload are driven **at the same time** on the same pins. If they must follow each other they belong in one thread: `fork begin drive_header(); drive_payload(); end ... join`.

### Interview questions

**Q1. What is the difference between `begin`...`end` and `fork`...`join`?**
Statements in `begin`...`end` execute sequentially in one process. Each statement in `fork`...`join` executes as its own process, and all of them start at the same simulation time.

**Q2. How many threads does this create: `fork a(); begin b(); c(); end d(); join`?**
Three: `a()`, the block containing `b()` then `c()`, and `d()`.

**Q3. Is `fork`...`join` synthesizable?**
No. It is a simulation construct used in testbenches and behavioural models.

## 3.2 fork ... join

### Definition

`fork` ... `join` creates the child threads and **blocks the parent until every child has finished**. It is the only form that existed in Verilog.

### Syntax

```systemverilog
fork
  thread_1;
  thread_2;
  thread_3;
join
// reached only when thread_1, thread_2 and thread_3 have all completed
```

### Complete example

```systemverilog file=tb_fork_join.sv
module tb_fork_join;

  initial begin
    $display("[%0t] parent: before fork", $time);
    fork
      begin #30 $display("[%0t] thread A done", $time); end
      begin #10 $display("[%0t] thread B done", $time); end
      begin #20 $display("[%0t] thread C done", $time); end
    join
    $display("[%0t] parent: after join", $time);
  end

endmodule
```

```output
[0] parent: before fork
[10] thread B done
[20] thread C done
[30] thread A done
[30] parent: after join
```

The children finish in order of their delays, not in the order they are written. The parent resumes at time 30, when the slowest child (A) has finished.

### When to use it

| Use | Example |
|---|---|
| Do several things in parallel and continue only when all are complete | Drive a write on port 0 and on port 1 at the same time; then check both |
| Start reset and clock-stabilisation activities together | `fork apply_reset(); wait_pll_lock(); join` |
| Run several directed sequences concurrently | `fork seq_a.run(); seq_b.run(); join` |

> **Interview trap:** If any child of a `fork` ... `join` never finishes (for example it contains a `forever` loop, as most `run()` tasks of drivers and monitors do), the `join` never completes and the code after it is never reached. This is why the components of an environment are started with `join_none` or `join_any`, not `join`.

## 3.3 fork ... join_any

### Definition

`fork` ... `join_any` creates the child threads and **blocks the parent until any one child has finished**. The remaining children are **not** stopped: they keep running in the background.

### Complete example

```systemverilog file=tb_fork_join_any.sv
module tb_fork_join_any;

  initial begin
    $display("[%0t] parent: before fork", $time);
    fork
      begin #30 $display("[%0t] thread A done", $time); end
      begin #10 $display("[%0t] thread B done", $time); end
      begin #20 $display("[%0t] thread C done", $time); end
    join_any
    $display("[%0t] parent: after join_any", $time);
  end

endmodule
```

```output
[0] parent: before fork
[10] thread B done
[10] parent: after join_any
[20] thread C done
[30] thread A done
```

The parent resumes at time 10, as soon as the fastest child (B) finishes. Threads C and A continue and print at 20 and 30, even though the parent's `initial` block has already ended.

### When to use it

| Use | Example |
|---|---|
| Timeout: wait for an operation, but only up to a limit | One thread waits for the response, another waits for the time limit; whichever finishes first ends the wait |
| First of several: continue when any one of several conditions occurs | Wait for `done` **or** `error` |
| End a test when the stimulus generator is finished while the driver and monitor loop forever | `fork gen.run(); drv.run(); mon.run(); join_any` |

> **Common mistake:** Forgetting that the other threads are still alive after `join_any`. In a timeout structure the losing thread must be stopped with `disable fork` (Section 3.8). Otherwise the "timeout" thread fires later and reports a timeout for an operation that completed long ago.

## 3.4 fork ... join_none

### Definition

`fork` ... `join_none` creates the child threads and **does not block the parent at all**. The parent continues with the statement after `join_none` immediately.

There is one more rule, and it is asked in interviews: **the child threads do not start executing until the parent thread blocks or terminates.** At the `join_none` the children are only *scheduled*. The parent keeps the processor until it reaches a blocking statement.

### Complete example

```systemverilog file=tb_fork_join_none.sv
module tb_fork_join_none;

  initial begin
    $display("[%0t] parent: before fork", $time);
    fork
      $display("[%0t] thread D (no delay) runs", $time);
      begin #30 $display("[%0t] thread A done", $time); end
      begin #10 $display("[%0t] thread B done", $time); end
      begin #20 $display("[%0t] thread C done", $time); end
    join_none
    $display("[%0t] parent: after join_none", $time);
    #5;
    $display("[%0t] parent: continues its own work", $time);
  end

endmodule
```

```output
[0] parent: before fork
[0] parent: after join_none
[0] thread D (no delay) runs
[5] parent: continues its own work
[10] thread B done
[20] thread C done
[30] thread A done
```

**Line by line**

| Line | Explanation |
|---|---|
| `join_none` | Four children are scheduled. None of them has run yet. |
| `parent: after join_none` | Printed **before** thread D's message although thread D has no delay. The parent has not blocked yet, so no child can run. |
| `#5;` | The parent blocks. Now the children start, at time 0. Thread D prints immediately; A, B and C begin their delays. |
| `parent: continues its own work` | The parent and the children now run independently. |

### When to use it

| Use | Example |
|---|---|
| Start background activity that runs for the whole test | Clock generators in classes, monitors, scoreboards, protocol checkers |
| Start all components of an environment and return control to the test | `fork gen.run(); drv.run(); mon.run(); scb.run(); join_none` |
| Launch a variable number of threads from a loop, then collect them with `wait fork` | One thread per port, per channel, per agent |

> **Interview trap:** "When do the threads of a `fork` ... `join_none` begin to execute?" Not at the `fork`, and not at the `join_none`. They begin when the parent executes a blocking statement (or ends). Any statements between `join_none` and that blocking statement are executed first.

## 3.5 Differences Between join, join_any and join_none

### Timeline

All three examples above used the same three children: B takes 10 time units, C takes 20, A takes 30.

```text
   time         0          10          20          30
                |-----------|-----------|-----------|
   thread B     ===========>|
   thread C     =======================>|
   thread A     ===================================>|

   join         parent blocked ......................  resumes at 30   (all children done)
   join_any     parent blocked .....  resumes at 10                    (first child done)
   join_none    resumes at 0                                           (no waiting)

   In all three cases every child runs to completion unless it is explicitly disabled.
```

### Comparison table

| Property | `join` | `join_any` | `join_none` |
|---|---|---|---|
| Parent resumes when | **All** children have finished | **Any one** child has finished | **Immediately** |
| Parent blocked at the join | Yes | Yes | No |
| Children still running when the parent resumes | None | All except the one that finished | All |
| When children start executing | When the parent blocks at `join` | When the parent blocks at `join_any` | When the parent next blocks or terminates |
| Remaining children are killed automatically | Not applicable | **No** | **No** |
| Available in Verilog | Yes | No | No |
| Allowed inside a function | No | No | Yes |
| Typical use | Parallel actions that must all complete | Timeouts, "first of" | Background threads, starting components |
| Usually followed by | Nothing | `disable fork` | `wait fork` (when the results are needed) |

### The same structure with each join

```systemverilog
// 1. Both operations must finish before the check
fork
  write_port(0);
  write_port(1);
join
check_both();

// 2. Wait for the response, with a time limit
fork
  wait_for_response();
  #1000;
join_any
disable fork;

// 3. Start the components; the test continues at once
fork
  drv.run();
  mon.run();
join_none
```

### Interview questions

**Q1. What is the difference between `join`, `join_any` and `join_none`?**
All three start every thread of the block in parallel. `join` blocks the parent until all threads finish. `join_any` blocks the parent until the first thread finishes; the others keep running. `join_none` does not block the parent; the threads start when the parent next blocks.

**Q2. After `join_any`, what happens to the threads that have not finished?**
They continue to run. They must be terminated explicitly with `disable fork` (or by disabling a named block, or through a `process` handle) if they are no longer wanted.

**Q3. Three threads have delays of 5, 10 and 15. After which simulation time does the statement following the block execute for `join`, `join_any` and `join_none`?**
15, 5 and 0.

**Q4. Which form of fork can be used inside a function, and why?**
Only `fork` ... `join_none`. A function must not consume simulation time. `join` and `join_any` would block the function; `join_none` returns immediately and the spawned threads run independently.

**Q5. In an environment's `run()` task, why are the components started with `join_none` or `join_any` and not `join`?**
Because drivers, monitors and scoreboards normally contain `forever` loops and never finish. A `join` would wait for them forever and the test could never end.

## 3.6 Variables in Forked Threads and the Loop Trap

### How children see variables

A child thread can read and write the variables that are visible where the `fork` is written: module variables, class properties, and the local variables of the enclosing task or block. It does **not** get a private copy. All children, and the parent, share the same variable.

### The classic bug

The task: start three threads, numbered 0, 1 and 2.

```systemverilog file=tb_fork_loop_bug.sv
module tb_fork_loop_bug;

  initial begin
    for (int i = 0; i < 3; i++) begin
      fork
        begin
          #(10 * (i + 1));
          $display("[%0t] thread %0d finished", $time, i);
        end
      join_none
    end
    wait fork;
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
```

```output
[40] thread 3 finished
[40] thread 3 finished
[40] thread 3 finished
[40] parent: all threads finished
```

Every thread reports number 3, a value the loop body was never supposed to see, and all of them finish at time 40.

**Why**

```text
   parent                                            children
   ------                                            --------
   i = 0 : fork ... join_none   -> child 1 scheduled   (not running yet)
   i = 1 : fork ... join_none   -> child 2 scheduled   (not running yet)
   i = 2 : fork ... join_none   -> child 3 scheduled   (not running yet)
   i = 3 : loop condition false, loop ends
   wait fork;  <-- the parent blocks here for the first time
                                                     child 1 starts: reads i  -> 3
                                                     child 2 starts: reads i  -> 3
                                                     child 3 starts: reads i  -> 3
```

1. With `join_none`, no child runs until the parent blocks (Section 3.4).
2. The parent does not block inside the loop, so the loop runs to completion first and `i` ends at 3.
3. All three children share the single variable `i`. When they finally start, each reads 3: the delay is `10 * (3 + 1)` = 40 and the printed number is 3.

### The fix

Give each thread its own copy of the loop value, in a variable that is created anew for every iteration: an **automatic** variable declared inside the loop body.

```systemverilog file=tb_fork_loop_fixed.sv
module tb_fork_loop_fixed;

  initial begin
    for (int i = 0; i < 3; i++) begin
      automatic int id = i;            // a new variable for each iteration, copied NOW
      fork
        begin
          #(10 * (id + 1));
          $display("[%0t] thread %0d finished", $time, id);
        end
      join_none
    end
    wait fork;
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
```

```output
[10] thread 0 finished
[20] thread 1 finished
[30] thread 2 finished
[30] parent: all threads finished
```

**Line by line**

| Line | Explanation |
|---|---|
| `automatic int id = i;` | Executed by the **parent** in each iteration, while `i` still has the value of that iteration. `automatic` means a fresh `id` is allocated every time the block is entered, so there are three separate variables holding 0, 1 and 2. |
| The child's use of `id` | Each child refers to the `id` of its own iteration. The variable stays alive as long as a thread still refers to it, even though the loop body has finished. |
| `wait fork;` | Blocks the parent until all three children have completed (Section 3.7). |

An equivalent form declares the variable inside the `fork` block. Declarations at the top of a `fork` block are initialised by the parent when the `fork` is executed, before any child starts:

```systemverilog
for (int i = 0; i < 3; i++)
  fork
    automatic int id = i;              // initialised at the fork, by the parent
    begin
      #(10 * (id + 1));
      $display("[%0t] thread %0d finished", $time, id);
    end
  join_none
```

### When the keyword automatic is required

| Where the loop is written | Lifetime of a local variable by default | What to write |
|---|---|---|
| `initial` / `always` block in a module or interface, static task | Static: one copy for the whole simulation | `automatic int id = i;` (the keyword is required) |
| Class method | Automatic | `int id = i;` is enough; `automatic` is harmless |
| Task or function declared `automatic`, or inside a `program` or module declared `automatic` | Automatic | `int id = i;` |

Without `automatic` in a module-level `initial` block, `int id = i;` declares a single static variable; it would be shared by all threads exactly like `i`. Writing `automatic` always is the safe habit.

> **Interview trap:** The wrong fix is to copy the value **inside** the child: `fork begin int id = i; ... end join_none`. The copy is then made when the child starts running, which is after the loop has ended, so it copies 3. The copy must be made by the parent, outside the child's `begin` ... `end`.

> **Verification application:** The same pattern starts one thread per array element: `foreach (drv[i]) begin automatic int k = i; fork drv[k].run(); join_none end`. It is used for multi-port DUTs, where the number of drivers and monitors is a parameter.

### Interview questions

**Q1. What does this print, and why?**
`for (int i = 0; i < 3; i++) fork $display(i); join_none`
It prints 3 three times. The threads of a `join_none` do not start until the parent blocks, which is after the loop has finished, and they all share the one loop variable, whose final value is 3.

**Q2. How do you fix it?**
Declare an automatic variable inside the loop (or in the declaration part of the `fork` block), initialised from the loop variable, and use that in the thread: `automatic int j = i;`.

**Q3. Would the bug occur with `fork` ... `join` instead of `join_none`?**
No. With `join` the parent blocks in every iteration until the child has finished, so the child reads `i` while it still has the right value. But then the threads run one after another, not in parallel, which defeats the purpose.

**Q4. Why does an automatic variable solve the problem when a static one does not?**
A static variable exists once; every iteration overwrites it and every thread sees the last value. An automatic variable is created each time its block is entered, so each iteration, and therefore each thread, has its own copy.

## 3.7 wait fork

### Definition

`wait fork;` blocks the calling process until **all of its immediate child processes** have finished. "Immediate children" means the threads this process itself created with `fork`; the grandchildren that those threads may have created are not waited for.

### Why it is needed

`join_none` lets the parent continue, and a loop of `join_none` blocks creates a number of threads that is not known when the code is written. There is no `join` to wait at. `wait fork` is the way to say "now wait for everything I have started".

### Syntax and use

```systemverilog
for (int i = 0; i < n; i++) begin
  automatic int id = i;
  fork
    send_packet(id);
  join_none
end
wait fork;                    // all n send_packet() threads have completed
```

The example in Section 3.6 (`tb_fork_loop_fixed`) shows it in a complete program: the parent's last message is printed at time 30, when the slowest thread finishes.

### Rules

| Rule | Consequence |
|---|---|
| It waits for **all** children of the calling process, not only those of the most recent `fork` | A background thread started earlier with `join_none` in the same process is included. If that thread contains a `forever` loop, `wait fork` never returns |
| It waits only for immediate children | Threads created by the children may still be running afterwards |
| If the process has no active children it does not block | It is safe to call when nothing was forked |

### wait fork versus join

| Property | `join` | `wait fork` |
|---|---|---|
| Waits for | The threads of that one `fork` block | Every child thread of the current process |
| Where it is written | At the end of the `fork` block | Anywhere later in the parent |
| Works with threads created in a loop | Only one iteration at a time (sequentially) | Yes: start all with `join_none`, then wait once |

> **Common mistake:** Calling `wait fork` in a `run()` task that has earlier started a monitor or clock thread with `join_none`. The call never returns. The cure is the guard described in the next section: do the forking and the `wait fork` inside a dedicated thread, so that "all my children" means only the intended ones.

### Interview questions

**Q1. What does `wait fork` do?**
It suspends the calling process until all the child processes it has spawned have terminated.

**Q2. What is the difference between `wait fork` and `fork` ... `join`?**
`join` waits for the threads of one specific `fork` block. `wait fork` waits for all children of the calling process, whichever `fork` created them. It is used after `join_none` or `join_any`, typically when threads are created in a loop.

**Q3. Does `wait fork` wait for the threads spawned by its children?**
No, only for the immediate children.

## 3.8 disable fork and disable label

### In plain English

After `join_any` the parent has what it wanted from one thread, and the others are still running. `disable fork` stops them. More precisely, it stops **every thread the current process has spawned, and everything those threads have spawned**. That reach is larger than most people expect, and is the source of a well-known bug.

### Technical definition

| Statement | What it terminates |
|---|---|
| `disable fork;` | All active **descendants** (children, grandchildren, ...) of the **calling process**. It is not limited to the nearest `fork` block |
| `disable block_name;` | The named `begin`...`end` or `fork`...`join` block, and everything started inside it. Execution continues after the block |
| `disable task_name;` | The named task. All currently active executions of it are terminated |

### Complete example: a timeout

```systemverilog
fork
  begin
    wait_for_response();                 // thread 1: the operation
    $display("response received");
  end
  begin
    #1000;                               // thread 2: the time limit
    $display("TIMEOUT");
  end
join_any                                 // continue when either finishes
disable fork;                            // stop the one that has not finished
```

### The bug: disable fork kills too much

```systemverilog file=tb_disable_fork_bug.sv
module tb_disable_fork_bug;

  initial begin
    fork                                             // a background thread
      forever #10 $display("[%0t] heartbeat", $time);
    join_none

    fork                                             // a timeout structure
      begin #25 $display("[%0t] response received", $time); end
      begin #15 $display("[%0t] timeout", $time); end
    join_any
    disable fork;                                    // intended: stop the slower of the two
    $display("[%0t] disable fork executed", $time);

    #30;
    $display("[%0t] end of test", $time);
    $finish;
  end

endmodule
```

```output
[10] heartbeat
[15] timeout
[15] disable fork executed
[45] end of test
```

The heartbeat stops after time 10. `disable fork` terminated the response thread, as intended, **and the heartbeat thread**, because the heartbeat is also a child of the same `initial` process. In a real testbench the "heartbeat" is a monitor, a scoreboard or a clock generator, and the symptom is that checking silently stops halfway through the test.

### The fix: a guard thread

Put the timeout structure inside its own thread. Inside that thread, "all my descendants" means only the two threads of the timeout structure.

```systemverilog file=tb_disable_fork_guard.sv
module tb_disable_fork_guard;

  initial begin
    fork                                             // a background thread
      forever #10 $display("[%0t] heartbeat", $time);
    join_none

    fork                                             // guard: fork begin ... end join
      begin
        fork
          begin #25 $display("[%0t] response received", $time); end
          begin #15 $display("[%0t] timeout", $time); end
        join_any
        disable fork;                                // kills only the guard's children
      end
    join
    $display("[%0t] disable fork executed", $time);

    #30;
    $display("[%0t] end of test", $time);
    $finish;
  end

endmodule
```

```output
[10] heartbeat
[15] timeout
[15] disable fork executed
[20] heartbeat
[30] heartbeat
[40] heartbeat
[45] end of test
```

```text
   Process tree in the buggy version            Process tree in the guarded version

   initial                                      initial
     |-- heartbeat        <- killed               |-- heartbeat            <- survives
     |-- response thread  <- killed               |-- guard thread
     |-- timeout thread   (already finished)            |-- response thread  <- killed
                                                        |-- timeout thread
   disable fork is executed by "initial":
   everything below it dies.                    disable fork is executed by "guard thread":
                                                only what is below the guard dies.
```

The outer `fork begin ... end join` creates exactly one child and waits for it, so it adds no parallelism. Its only purpose is to create a new process to act as the owner of the inner threads.

> **Key point:** The idiom `fork begin ... fork ... join_any  disable fork; end join` is the standard, safe way to write a timeout or a "first of" construct. Use it whenever the surrounding code may have other threads running, which in a class-based testbench is always.

### disable with a block name

```systemverilog
fork : watch
  begin #25 $display("response received"); end
  begin #15 $display("timeout");           end
join_any
disable watch;                // terminates the threads of the block named "watch" only
```

A named `disable` does not touch unrelated threads, so it avoids the bug above without a guard. It has its own trap:

> **Interview trap:** `disable block_name` (and `disable task_name`) acts on the block or task **by name**, not on one particular execution of it. If the same task is running concurrently in several threads, or the named block is inside a class method that is running in several objects, the `disable` terminates the block in **all** of them. `disable fork` affects only the descendants of the calling process, which is why it is preferred in class-based code.

### Comparison

| Property | `disable fork` | `disable name` | `process.kill()` |
|---|---|---|---|
| What is terminated | All descendants of the calling process | The named block or task, all active executions | The one process the handle refers to, and its descendants |
| Selective | No (everything below the caller) | By name | Yes, exactly one thread |
| Needs a name or handle | No | A block or task name | A `process` handle |
| Main risk | Kills unrelated background threads | Kills other executions of the same named code | None, but more code to write |
| Covered in | This section | This section | Module 11 |

### Interview questions

**Q1. What does `disable fork` do?**
It terminates all active threads that were spawned by the calling process, including their own child threads.

**Q2. Does `disable fork` kill only the threads of the nearest `fork` block?**
No. It kills every descendant of the process that executes it. Threads started earlier by the same process, for example with `join_none`, are killed as well.

**Q3. How do you make `disable fork` affect only one `fork` block?**
Enclose the block and the `disable fork` in a guard thread: `fork begin fork ... join_any  disable fork; end join`. The `disable fork` is then executed by the guard thread, whose only descendants are the threads of the inner block.

**Q4. What is the difference between `disable fork` and `disable <label>`?**
`disable fork` terminates the descendants of the current process and needs no name. `disable <label>` terminates a specific named block or task wherever it is executing, which can include other threads or objects running the same code.

**Q5. Write code that waits for an event `done` but gives up after 500 time units.**
```systemverilog
fork
  begin
    fork
      @(done);
      #500 $error("timeout waiting for done");
    join_any
    disable fork;
  end
join
```

## 3.9 Nested fork-join

### Definition

A thread created by a `fork` may itself contain a `fork`. The inner block's join keyword controls when **that thread** continues; the outer block's join keyword controls when the **parent** continues. Each join only looks at the threads of its own block.

### Complete example

```systemverilog file=tb_fork_nested.sv
module tb_fork_nested;

  initial begin
    fork
      begin : branch_1
        fork
          #10 $display("[%0t] 1a done", $time);
          #20 $display("[%0t] 1b done", $time);
        join
        $display("[%0t] branch 1 complete (waited for 1a and 1b)", $time);
      end

      begin : branch_2
        #5;
        fork
          #10 $display("[%0t] 2a done", $time);
          #30 $display("[%0t] 2b done", $time);
        join_any
        $display("[%0t] branch 2 complete (waited for 2a only)", $time);
      end
    join
    $display("[%0t] parent: outer join complete", $time);
  end

endmodule
```

```output
[10] 1a done
[15] 2a done
[15] branch 2 complete (waited for 2a only)
[20] 1b done
[20] branch 1 complete (waited for 1a and 1b)
[20] parent: outer join complete
[35] 2b done
```

```text
   Process tree                                Timeline

   initial (parent)                            time   0    5   10   15   20        35
     |-- branch_1                                     |----|----|----|----|---------|
     |     |-- 1a                              1a     =========>
     |     |-- 1b                              1b     ===================>
     |-- branch_2                              branch_1 ends ............^ (join: 1a and 1b)
           |-- 2a                              2a          ==========>
           |-- 2b                              2b          ==============================>
                                               branch_2 ends ........^ (join_any: 2a)
                                               outer join ...............^ (both branches)
```

**Line by line**

| Time | Explanation |
|---|---|
| 0 | The outer `fork` creates `branch_1` and `branch_2`. `branch_1` immediately forks `1a` and `1b` and blocks at its inner `join`. `branch_2` waits 5. |
| 5 | `branch_2` forks `2a` (finishes at 15) and `2b` (finishes at 35) and blocks at its inner `join_any`. |
| 10 | `1a` finishes. |
| 15 | `2a` finishes. The inner `join_any` is satisfied, so `branch_2` prints and ends. `2b` is still running. |
| 20 | `1b` finishes. The inner `join` is satisfied, so `branch_1` prints and ends. Both children of the outer `fork` have now ended, so the outer `join` completes. |
| 35 | `2b` finishes. It is a grandchild; the outer `join` did not wait for it. |

> **Key point:** A `join` waits for the threads of its own block, which are its immediate children. It does not wait for threads that those children left running with `join_any` or `join_none`.

### Interview questions

**Q1. In a nested fork, does the outer `join` wait for threads created by an inner `join_none`?**
No. The outer `join` waits until each of its own threads has finished executing its statements. A thread that executes an inner `fork` ... `join_none` finishes without waiting for the inner threads, which carry on independently.

**Q2. An inner thread is still running when its parent thread ends. What happens to it?**
It continues to run. A child is not terminated when its parent finishes; it stops only when it completes, when it is disabled, or when the simulation ends.

## 3.10 Parallel Process Execution and Synchronization Patterns

### The common patterns

| Requirement | Pattern |
|---|---|
| Run A and B together; continue when **both** are done | `fork A; B; join` |
| Continue when **either** is done, stop the other | `fork begin fork A; B; join_any  disable fork; end join` |
| Run A with a time limit | `fork begin fork A; #limit; join_any  disable fork; end join` |
| Start background threads and carry on | `fork A; B; join_none` |
| Start N threads from a loop and wait for all | loop of `fork ... join_none` with an automatic copy of the index, then `wait fork` |
| Start N threads and continue when the first finishes | loop of `fork ... join_none`, then wait for an event or flag set by the finishing thread |
| Start the components of an environment | `fork gen.run(); drv.run(); mon.run(); scb.run(); join_none` and then wait for an end-of-test condition |

### How an environment uses them

```systemverilog
task run();
  fork
    gen.run();              // ends after the last transaction
    drv.run();              // forever loop
    mon.run();              // forever loop
    scb.run();              // forever loop
  join_any                  // continue when the generator has finished
  wait (scb.num_checked == gen.num_txn);    // let the last transactions drain
endtask
```

`join_any` returns when the generator, the only thread that ever finishes, is done. The other three keep running so that the transactions still in flight are driven, monitored and checked. Module 9 develops this into the complete environment.

### Other rules worth knowing

| Rule | Detail |
|---|---|
| A child outlives the task that created it | If a task executes `fork ... join_none` and returns, the threads keep running |
| Automatic variables stay alive | Local variables of the parent that a child refers to exist as long as the child does |
| `return` inside a fork block | Illegal. A thread cannot return from the enclosing task or function |
| `fork` in a function | Only `join_none` is permitted |
| End of simulation | `$finish` ends everything. In a `program` block, the simulation also ends when the program's `initial` blocks have all finished, even if threads they forked are still running, so background threads are cut off. Waiting with `wait fork` or an end-of-test event avoids this |
| Fine-grained control | The built-in `process` class gives a handle to a thread: `process::self()`, `status()`, `kill()`, `await()`, `suspend()`, `resume()`. Covered in Module 11 |

### Common mistakes with fork

| Mistake | Effect | Fix |
|---|---|---|
| `fork` ... `join` around `forever` threads | Code after `join` never runs | `join_any` or `join_none` |
| No `disable fork` after `join_any` in a timeout | A stale timeout fires later | `disable fork` inside a guard |
| `disable fork` without a guard | Background threads die | `fork begin ... end join` guard |
| Loop variable used directly in a `join_none` thread | Every thread sees the final value | `automatic` copy per iteration |
| Statements that must be sequential written as separate fork statements | They run at the same time | Group with `begin` ... `end` |
| Expecting `join_none` threads to start at once | Parent code runs first | Remember that children start when the parent blocks |
| `wait fork` with a never-ending background child | Hangs | Guard thread, or do not use `wait fork` there |

### Interview questions

**Q1. How do you start an unknown number of threads and wait for all of them?**
In a loop, make an automatic copy of the loop index and start each thread with `fork` ... `join_none`. After the loop call `wait fork`.

**Q2. How do you implement a timeout in SystemVerilog?**
Start the operation and a delay as two threads of a `fork` ... `join_any`, and after it execute `disable fork` to stop whichever is still running. Wrap the whole construct in `fork begin ... end join` so that the `disable fork` cannot kill unrelated threads.

**Q3. What happens to forked threads when the parent task returns?**
They continue running. Threads are terminated only by finishing, by being disabled or killed, or by the end of simulation.

**Q4. How do you kill one specific thread among several?**
Obtain its `process` handle inside the thread with `process::self()` and call `kill()` on that handle, or give the thread's block a name and use `disable name` (keeping in mind that this disables every active execution of that block).

**Q5. A test ends before the scoreboard has checked the last transactions. What is the likely cause?**
The test finished (called `$finish` or returned) as soon as the generator was done, typically right after a `join_any`, while the driver, monitor and scoreboard still had transactions in flight. The test must wait for an end-of-test condition such as "number checked equals number generated", or for a drain time.
