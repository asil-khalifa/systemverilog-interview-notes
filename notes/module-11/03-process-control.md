# Part 3: Process Control

## 3.1 Process Control

### In plain English

A testbench is many activities running at the same time: the generator creates transactions, the driver wiggles pins, the monitor watches, a watchdog counts down. Each of these activities is a **process** (also called a thread). Module 7 showed how to start processes with `fork` and how to make them cooperate with events, mailboxes and semaphores.

Process control is about the other half of the job: **stopping, waiting for, pausing and inspecting** processes. Typical needs are:

- "Wait for the response, but give up after 1000 clock cycles."
- "Start three checkers; when the first one finishes, stop the other two."
- "Reset was asserted in the middle of a transfer: abandon whatever the driver was doing."
- "Is that background thread still running?"

### Technical definition

A **process** is an independent thread of execution with its own point of execution and its own state. Processes are created by:

| Source of a process | Example |
|---|---|
| Each `initial` block | `initial begin ... end` |
| Each `always`, `always_ff`, `always_comb`, `always_latch` block | `always @(posedge clk) ...` |
| Each `final` block | `final $display(...)` |
| Each statement inside a `fork` | `fork a(); b(); join` creates two processes |
| Each continuous assignment | `assign y = a & b;` |
| A dynamic process | A `fork`...`join_none` or `join_any` branch that outlives the statement which created it |

A task or function call does **not** create a process. A called task runs in the process of its caller. This fact matters several times in this part.

### The process-control toolbox

| Tool | What it does | Granularity | Introduced in |
|---|---|---|---|
| `fork`...`join` / `join_any` / `join_none` | Starts processes and decides how long the parent waits | | M7 |
| `wait fork;` | Blocks until all child processes of the calling process have finished | All children of the caller | M7 |
| `disable fork;` | Kills all child processes of the calling process, and their descendants | All children of the caller | M7 |
| `disable <block_or_task_name>;` | Terminates a named block or task, wherever it is executing | A named piece of code | Section 3.2 |
| `process` class | A handle on one specific process: query its state, wait for it, kill, suspend or resume it | One process | Section 3.4 |
| `return`, `break`, `continue` | Leave a task/function or a loop from inside | The current process only | M3 |

```text
   Coarse  <--------------------------------------------------------------->  Fine

   $finish        disable fork         disable <name>         process handle
   (everything)   (all my children)    (that named code,      (exactly this one
                                        every activation)      thread)
```

### Process family relationships

```text
   initial begin                      // process P  (the parent)
     fork
       driver();                      // process C1 (child of P)
       begin                          // process C2 (child of P)
         fork
           checker_a();               // process G1 (child of C2, descendant of P)
           checker_b();               // process G2 (child of C2, descendant of P)
         join
       end
     join_none
     ...
   end

   From inside P:
     wait fork;       waits for C1 and C2 (its immediate children)
     disable fork;    kills C1 and C2 AND their descendants G1, G2
```

The rest of this part explains each tool in the toolbox that was not fully covered in M7, and the patterns built from them.

### Interview questions

**Q1. What is a process in SystemVerilog?**
An independent thread of execution. Every `initial` and `always` block, every branch of a `fork`, and every continuous assignment is a process.

**Q2. Does calling a task create a new process?**
No. The task executes in the calling process. A new process is created only by `fork` (or by a procedural block).

**Q3. Name the ways to terminate a process from outside.**
`disable fork` (all children of the caller), `disable` of a named block or task, and the `kill()` method of a `process` handle.

## 3.2 Named Blocks and the disable Statement

### In plain English

Any `begin`...`end` block or `fork`...`join` block can be given a name. A name is useful for three things: the reader sees what the block is for, variables declared in it get a hierarchical name, and the block can be terminated from anywhere with `disable <name>`.

### Technical definition

A **named block** is a sequential (`begin`...`end`) or parallel (`fork`...`join`) block with an identifier after the opening keyword:

```systemverilog
begin : <name>
  ...
end : <name>          // the closing name is optional; if present it must match
```

The statement `disable <name>;` terminates the execution of the named block or task: every statement still executing inside it stops, and execution continues at the statement that follows the block. The same statement can be executed from inside the block (to leave it early) or from another process (to stop it from outside).

### Why it is needed

| Use | Example |
|---|---|
| Leave nested loops in one step | `disable search;` from the inner loop, where `break` would leave only the inner loop |
| Skip the rest of one loop iteration (old-style `continue`) | Name the loop **body** and disable it |
| Stop the losing threads of a race | `fork : race ... join_any  disable race;` |
| Stop a specific background block | `disable tb_top.watchdog;` |
| Readable waveforms and messages | Variables and `%m` show the block name |

Since SystemVerilog added `break`, `continue` and `return`, those are preferred for leaving code from the inside. `disable` remains the tool for stopping named code **from the outside**.

### Complete example

```systemverilog file=tb_named_block.sv
module tb_named_block;

  int data [8] = '{3, 7, 0, 9, 4, 0, 1, 5};

  initial begin

    // ---- 1. leave a named sequential block early ----
    begin : search
      foreach (data[i]) begin
        if (data[i] == 0) begin
          $display("1. first zero found at index %0d", i);
          disable search;
        end
      end
      $display("   (not printed: the block was disabled before reaching this line)");
    end : search
    $display("2. execution continues after the named block");

    // ---- 2. name the loop BODY: disable acts like 'continue' ----
    for (int i = 0; i < 4; i++) begin : body
      if (i == 1) disable body;
      $display("3. i = %0d", i);
    end

    // ---- 3. a named fork block: stop the slower thread ----
    fork : race
      begin : thread_a
        #30 $display("[%0t] thread_a done", $time);
      end
      begin : thread_b
        #10 $display("[%0t] thread_b done", $time);
      end
    join_any
    disable race;
    $display("[%0t] 4. fork block 'race' disabled", $time);

    #50 $display("[%0t] 5. end of test", $time);
  end

endmodule
```

```output
1. first zero found at index 2
2. execution continues after the named block
3. i = 0
3. i = 2
3. i = 3
[10] thread_b done
[10] 4. fork block 'race' disabled
[60] 5. end of test
```

**Line by line**

| Code | Explanation |
|---|---|
| `begin : search ... end : search` | A named sequential block. |
| `disable search;` | Executed inside the block when the first zero is found (index 2). The whole block stops, including the `foreach`. The `$display` after the loop is never reached. |
| Line 2 | Execution resumes at the statement following the disabled block. |
| `for (...) begin : body` | Here the name is on the loop's body, not around the loop. |
| `if (i == 1) disable body;` | Disabling the body ends only the current iteration; the `for` statement then performs `i++` and continues. So 0, 2 and 3 are printed. This is how `continue` was written before SystemVerilog. |
| `fork : race ... join_any` | A named fork with two threads. `join_any` returns when the first finishes: `thread_b`, at time 10. |
| `disable race;` | Terminates everything still running inside the fork block: `thread_a`, which was waiting for time 30. Its message never appears. |
| `#50 ...` | Proof that `thread_a` is gone: nothing is printed at time 30. |

### disable and tasks

`disable <task_name>;` terminates the task. Two properties make this dangerous:

1. It terminates **every** currently executing call of that task, in all processes, not only one.
2. The state it leaves behind is not cleaned up: output arguments are not assigned, nonblocking assignments already scheduled still happen, and a semaphore key the task was holding is not returned.

```systemverilog
task automatic send_packet();
  sem.get(1);
  // ... many clock cycles ...
  sem.put(1);
endtask

// elsewhere
disable send_packet;    // every thread inside send_packet stops; the key is never put back
```

A function cannot be disabled, and a task cannot disable itself to return a value: use `return`.

### What exactly does disable <name> stop?

`disable` works on the **name in the hierarchy**, not on a thread. If the same named block is being executed by several threads at once, all of those executions stop. That happens when:

- the block is inside a task called from several processes;
- the block is inside a class method and several objects are running that method;
- the block is inside a module that is instantiated several times (here each instance has its own hierarchical name, so `disable inst1.blk` affects only that instance).

| Statement | Stops | Typical problem |
|---|---|---|
| `disable <block>;` | All activations of that named block | With class methods running in several objects, it stops all of them |
| `disable <task>;` | All active calls of that task | Same; also leaves resources locked |
| `disable fork;` | All child processes of the calling process, with descendants | Kills children started earlier by the same process that you wanted to keep (Section 3.3) |
| `p.kill();` | Exactly the process `p`, with its descendants | None of the above; you must have obtained the handle |

> **Interview trap:** "What is the difference between `disable fork` and `disable <label>`?" `disable fork` has no name: it kills the children of whichever process executes it. `disable <label>` kills the code with that name wherever it is running, regardless of who executes the statement. The first is relative to the caller, the second is absolute.

> **Common mistake:** Using `disable <label>` inside a class method that runs concurrently in several objects (for example every driver of a multi-port testbench). One object's `disable` terminates the block in all objects. In class-based code prefer `disable fork` with an isolating wrapper (Section 3.3) or process handles (Section 3.4).

> **Common mistake:** Expecting code after `disable` inside the block to run. `disable search;` is the last statement the block executes.

### Interview questions

**Q1. What is a named block and why would you name one?**
A `begin`...`end` or `fork`...`join` block with a label. Naming it lets it be terminated with `disable`, gives its local variables a hierarchical path, and documents its purpose.

**Q2. How did Verilog implement `break` and `continue`?**
With `disable`: naming a block that encloses the loop and disabling it acts as `break`; naming the loop body and disabling it acts as `continue`.

**Q3. What happens to a task that is disabled while it is running?**
It stops immediately. Its output and inout arguments are not updated, and anything it was holding (such as semaphore keys) is not released. All concurrent calls of the same task are terminated.

**Q4. What is the difference between `disable`, `break` and `return`?**
`break` leaves the innermost loop. `return` leaves the current task or function, optionally with a value. Both act only on the code that executes them. `disable` terminates a named block or task, can be issued from a different process, and affects every activation of that name.

## 3.3 Named Fork Blocks, disable fork and wait fork

### Recap from M7

| Statement | Parent continues when | Children after that |
|---|---|---|
| `fork ... join` | All children have finished | None left |
| `fork ... join_any` | The first child has finished | The others keep running |
| `fork ... join_none` | Immediately | All keep running; they start only when the parent next blocks |
| `wait fork;` | All children of the calling process have finished | |
| `disable fork;` | Immediately | All children of the calling process, and their descendants, are killed |

### The disable fork trap

`disable fork` kills **all** children of the calling process, not just those of the nearest `fork` statement. Because a task call does not create a process, a `disable fork` inside a task kills children that the *caller* started earlier.

```text
   initial begin                         // process P
     fork
       background_monitor();             // child C1 of P   <-- must survive
     join_none

     wait_with_timeout();                // runs in P (a task call is not a new process)
   end

   task wait_with_timeout();
     fork
       do_work();                        // child C2 of P
       #timeout;                         // child C3 of P
     join_any
     disable fork;                       // executed by P: kills C2, C3 ... and C1 !
   endtask
```

The cure is to make the `disable fork` execute in a process whose **only** children are the ones to be killed. Wrapping the code in `fork begin ... end join` creates such a process:

```text
   task wait_with_timeout();
     fork                                // creates process W (child of P); P waits for it
       begin
         fork
           do_work();                    // child of W
           #timeout;                     // child of W
         join_any
         disable fork;                   // executed by W: kills only W's children
       end
     join
   endtask
```

This wrapper is called an **isolating fork** (or guard fork). It appears in almost every production testbench, and "why is the extra `fork begin ... end join` there?" is a favourite interview question.

### Complete example

```systemverilog file=tb_disable_fork.sv
module tb_disable_fork;

  task automatic background(string name, int n);
    repeat (n) #20 $display("[%0t] %s tick", $time, name);
  endtask

  task automatic wait_with_timeout(int work_time, int timeout);
    fork                                 // isolating fork
      begin
        fork
          #work_time $display("[%0t] work done", $time);
          #timeout   $display("[%0t] TIMEOUT", $time);
        join_any
        disable fork;                    // kills only the loser of this race
      end
    join
  endtask

  initial begin
    fork
      background("monitor", 4);          // must keep running throughout
    join_none

    wait_with_timeout(30, 50);           // the work wins
    wait_with_timeout(70, 25);           // the timeout wins

    wait fork;                           // wait for the background thread
    $display("[%0t] all threads finished", $time);
  end

endmodule
```

```output
[20] monitor tick
[30] work done
[40] monitor tick
[55] TIMEOUT
[60] monitor tick
[80] monitor tick
[80] all threads finished
```

**Execution flow**

| Time | What happens |
|---|---|
| 0 | The `initial` process forks the background thread with `join_none` and calls `wait_with_timeout(30, 50)`. The task forks the isolating process, which forks the two racing threads. |
| 20 | Background thread: first tick. |
| 30 | The work thread finishes first. `join_any` returns, `disable fork` kills the timeout thread (it would have fired at 50). The isolating process ends, `join` returns, the task returns. The second call starts: work due at 100, timeout due at 55. |
| 40 | Background tick. It was not affected by the `disable fork` at 30. |
| 55 | The timeout thread finishes first and prints `TIMEOUT`. `disable fork` kills the work thread. The task returns. |
| 55 | `wait fork` blocks: the background thread, a child of the `initial` process, is still running. |
| 60, 80 | Remaining ticks. After the fourth tick the background task ends. |
| 80 | `wait fork` returns. |

If the isolating `fork begin ... end join` were removed, the `disable fork` at time 30 would be executed by the `initial` process itself and would kill the background thread as well. The output would then contain a single tick at 20.

### Named fork blocks

A fork block may be named like any other block, and its threads may be named individually:

```systemverilog
fork : checks
  begin : check_valid   ...  end
  begin : check_result  ...  end
join_any
disable checks;                 // stop everything left in this fork block
// disable check_result;        // or stop one particular thread
```

| Property | `disable fork;` | `disable <fork_name>;` |
|---|---|---|
| Identifies its targets by | Parenthood: children of the calling process | Name: the code inside the named fork block |
| Kills threads from earlier forks of the same process | Yes (the trap above) | No |
| Kills grandchildren | Yes | Yes, everything executing inside the named block |
| Safe in class methods that run in several objects | Yes (with an isolating fork) | No: all activations of that name are affected |
| Needs a label | No | Yes |

Named forks are the simple solution in module-level testbench code. In class-based code the isolating fork with `disable fork`, or process handles, are the safe choices.

### wait fork

`wait fork;` blocks the calling process until all of its **immediate** child processes have terminated. It is used at the end of a test or a task to make sure nothing started with `join_none` is still running:

```systemverilog
for (int i = 0; i < 4; i++) begin
  fork
    automatic int ch = i;          // each thread gets its own copy (M7)
    send_on_channel(ch);
  join_none
end
wait fork;                         // all four sends have completed
```

Like `disable fork`, it refers to *all* children of the calling process. If a never-ending child (a monitor's `forever` loop) was started by the same process, `wait fork` never returns. The same isolating-fork idea fixes it.

> **Interview trap:** "`fork ... join_any` followed by `disable fork`: which threads die?" All children of the process executing `disable fork`, including children created by earlier `fork` statements of that process and their descendants, not merely the remaining threads of the fork just above.

> **Common mistake:** A `wait fork` at the end of `alu_env::run()` after the monitor and scoreboard were started with `join_none` and contain `forever` loops. The wait never ends and the test hangs. End-of-test must be based on something that actually completes (the generator finishing, a transaction count, a watchdog).

### Interview questions

**Q1. What does `disable fork` do?**
It terminates all active child processes of the process that executes it, together with all of their descendants.

**Q2. Why is `fork begin ... end join` wrapped around a `join_any` and `disable fork`?**
To isolate the `disable fork`. The wrapper creates a new process whose only children are the threads forked inside it, so `disable fork` cannot kill unrelated threads that the outer process had started earlier.

**Q3. What is the difference between `wait fork` and `join`?**
`join` belongs to one `fork` statement and waits for that statement's threads. `wait fork` is a separate statement that waits for all child processes of the calling process, whichever `fork` statements created them, including those started with `join_none` or left running after `join_any`.

**Q4. How do you stop only one thread of a fork?**
Name that thread's block and `disable` the name, or capture the thread's `process` handle and call `kill()` on it.

## 3.4 The Process Class and Process Handles

### In plain English

`disable fork` and `disable <name>` are blunt. Sometimes you want a handle on **one particular thread**, like a job number, so that you can ask "are you still running?", say "wait until that one has finished", or "stop that one and nothing else". The built-in `process` class provides that handle.

### Technical definition

`process` is a built-in class declared in the `std` package. Each process in the simulation has an associated `process` object. A process obtains the handle to **itself** with the static method `process::self()`, and may store that handle in a variable so that other processes can control it.

```systemverilog
// Prototype of the built-in class (you never write this; it is part of the language)
class process;
  typedef enum { FINISHED, RUNNING, WAITING, SUSPENDED, KILLED } state;

  static function process self();     // handle of the calling process
  function state status();            // current state of this process
  function void  kill();              // terminate this process and its sub-processes
  task           await();             // block until this process terminates
  function void  suspend();           // pause this process
  function void  resume();            // let a suspended process continue
  // also: srandom(), get_randstate(), set_randstate() for random stability (M5)
endclass
```

Special rules:

- You cannot create a process object with `new`. `process p = new();` is an error. The only source of handles is `process::self()`.
- The class cannot be extended.
- A handle remains valid after its process has ended; `status()` then reports `FINISHED` or `KILLED`.

### The process states

| State | Value | Meaning |
|---|---|---|
| `FINISHED` | 0 | The process terminated normally (ran to its end) |
| `RUNNING` | 1 | The process is currently executing (it is not blocked) |
| `WAITING` | 2 | The process is blocked in a blocking statement: a delay, `@`, `wait`, a mailbox `get`, and so on |
| `SUSPENDED` | 3 | The process was stopped by `suspend()` and is waiting for `resume()` |
| `KILLED` | 4 | The process was terminated by `kill()` or by a `disable` |

```text
                          suspend()
              +------------------------------+
              |                              v
          RUNNING  <----------------->  SUSPENDED
           |   ^        resume()             |
   blocks  |   |  unblocks                   |
           v   |                             |
          WAITING  ---- suspend() -----------+
           |   |
           |   +---- kill() / disable ----->  KILLED
           |
   runs to the end
           v
        FINISHED
```

Since only one process executes at any instant, a process that asks for the status of *another* process normally sees `WAITING`, `SUSPENDED`, `FINISHED` or `KILLED`. `RUNNING` is what a process sees when it asks about itself.

### The methods

| Method | Called on | Effect | Notes |
|---|---|---|---|
| `process::self()` | The class (static) | Returns the handle of the process that executes the call | A task called from process P returns P's handle |
| `p.status()` | Any handle | Returns the state enum | Use `process::FINISHED` etc. to compare |
| `p.kill()` | Any handle | Terminates `p` and all its descendants | A process may kill itself |
| `p.await()` | Another process's handle | Blocks the caller until `p` has terminated (finished or killed) | A process must not `await` itself: error |
| `p.suspend()` | Any handle | Stops `p` from executing until resumed | A process may suspend itself; another process must then resume it |
| `p.resume()` | A suspended process's handle | Lets `p` continue | If `p` was suspended while waiting for a delay or event that has meanwhile occurred, it continues straight away |

> **Note:** `self()`, `status()`, `kill()` and `await()` are supported by all major simulators and are used widely (UVM uses them internally). `suspend()` and `resume()` are less commonly used, and the exact time at which a resumed process continues has differed between tools. Avoid building testbench logic that depends on them.

### How to obtain a handle to a forked thread

The thread itself must call `process::self()` and store the result. There is one subtlety: after `fork ... join_none`, the child has **not started yet** (it starts when the parent blocks), so the variable is still `null`. The parent must wait for the handle to appear.

```text
   parent                                  child
   ------                                  -----
   fork
     begin
       p = process::self();    ....... (not executed yet)
       ...
     end
   join_none
   p.kill();        <-- WRONG: p is still null here -> null handle error

   wait (p != null);           parent blocks -> child starts, sets p, blocks on a delay
   p.kill();        <-- correct
```

### Complete example: status, await and kill

```systemverilog file=tb_process_class.sv
module tb_process_class;

  process p_main, p_fast, p_slow;

  function automatic string st(process p);
    process::state s = p.status();
    return s.name();
  endfunction

  initial begin
    p_main = process::self();

    fork
      begin
        p_fast = process::self();
        #10 $display("[%0t] fast thread finished", $time);
      end
      begin
        p_slow = process::self();
        #100 $display("[%0t] slow thread finished", $time);
      end
    join_none

    wait (p_fast != null && p_slow != null);
    $display("[%0t] main=%s fast=%s slow=%s", $time, st(p_main), st(p_fast), st(p_slow));

    p_fast.await();
    $display("[%0t] after await : fast=%s slow=%s", $time, st(p_fast), st(p_slow));

    #5 p_slow.kill();
    $display("[%0t] after kill  : slow=%s", $time, st(p_slow));

    #200 $display("[%0t] end (the slow thread never printed)", $time);
  end

endmodule
```

```output
[0] main=RUNNING fast=WAITING slow=WAITING
[10] fast thread finished
[10] after await : fast=FINISHED slow=WAITING
[15] after kill  : slow=KILLED
[215] end (the slow thread never printed)
```

**Line by line**

| Code | Explanation |
|---|---|
| `process p_main, p_fast, p_slow;` | Three handle variables. Like all class handles they start as `null`. |
| `function automatic string st(process p);` | A helper that returns the name of the state. `process::state` is the enum type declared inside the class, reached with `::`. |
| `p_main = process::self();` | The `initial` process stores its own handle. |
| `p_fast = process::self();` inside the fork | Executed by the first child, so it returns that child's handle. |
| `join_none` | The parent continues immediately. The children have not started. |
| `wait (p_fast != null && p_slow != null);` | The parent blocks. Both children now start, store their handles and block on their delays. The condition becomes true and the parent continues, still at time 0. |
| First `$display` | `p_main` is the process doing the printing: `RUNNING`. Both children are blocked on a delay: `WAITING`. |
| `p_fast.await();` | The parent blocks until the fast thread ends at time 10. |
| Second `$display` | The fast thread ran to completion: `FINISHED`. The slow one is still waiting for time 100. |
| `#5 p_slow.kill();` | At time 15 the slow thread is terminated. Its `$display` at time 100 never executes. |
| Third `$display` | A killed process reports `KILLED`, which is distinct from `FINISHED`. |

### Complete example: a pool of worker threads

Handles can be stored in a queue, which gives full control over a group of threads created in a loop.

```systemverilog file=tb_process_array.sv
module tb_process_array;

  process jobs [$];
  int     killed;

  initial begin
    for (int i = 0; i < 3; i++) begin
      fork
        automatic int id = i;
        begin
          jobs.push_back(process::self());
          #(10 * (id + 1));
          $display("[%0t] worker %0d done", $time, id);
        end
      join_none
    end

    wait (jobs.size() == 3);        // all three threads have started and registered

    #25;
    foreach (jobs[k]) begin
      if (jobs[k].status() != process::FINISHED) begin
        jobs[k].kill();
        killed++;
      end
    end
    $display("[%0t] killed %0d unfinished worker(s)", $time, killed);
  end

endmodule
```

```output
[10] worker 0 done
[20] worker 1 done
[25] killed 1 unfinished worker(s)
```

**Line by line**

| Code | Explanation |
|---|---|
| `process jobs [$];` | A queue of process handles. |
| `automatic int id = i;` | Each forked thread gets its own copy of the loop variable (M7). Without it, every thread would see `i` = 3. |
| `jobs.push_back(process::self());` | Each worker registers itself. The order of registration within time 0 is not defined, and the example does not depend on it. |
| `#(10 * (id + 1));` | Workers 0, 1 and 2 need 10, 20 and 30 time units. |
| `wait (jobs.size() == 3);` | The parent waits until all three have registered. |
| `#25;` then the `foreach` | At time 25, workers 0 and 1 are `FINISHED`. Worker 2 is still `WAITING`; it is killed and counted. Nothing is printed at time 30. |

### Complete example: suspend and resume

```systemverilog file=tb_process_suspend.sv
module tb_process_suspend;

  process p_worker;

  initial begin
    fork
      begin
        p_worker = process::self();
        for (int i = 1; i <= 4; i++)
          #10 $display("[%0t] worker step %0d", $time, i);
      end
    join_none

    wait (p_worker != null);

    #15 p_worker.suspend();
    $display("[%0t] worker suspended", $time);

    #30 p_worker.resume();
    $display("[%0t] worker resumed", $time);

    p_worker.await();
    $display("[%0t] worker finished", $time);
  end

endmodule
```

```output
[10] worker step 1
[15] worker suspended
[45] worker resumed
[45] worker step 2
[55] worker step 3
[65] worker step 4
[65] worker finished
```

**Explanation**

- Step 1 is printed at time 10. The worker then waits for its next delay, which would expire at time 20.
- At time 15 the worker is suspended while it is blocked in that delay.
- Time 20 passes; the worker does not continue, because it is suspended.
- At time 45 it is resumed. The standard says that if the delay a process was waiting for has already elapsed, the resumed process is scheduled to continue immediately. So step 2 is printed at time 45, and the remaining steps follow at 10-unit intervals from there.
- The parent prints "worker resumed" before the worker prints "step 2", because `resume()` only schedules the worker; the parent keeps executing until it blocks on `await()`.

This is the behaviour defined by IEEE 1800. As noted above, it is the least uniformly implemented part of the class, so run this example on your simulator before relying on it.

### Comparison of the ways to stop a thread

| Property | `disable fork` | `disable <label>` | `process.kill()` |
|---|---|---|---|
| Targets | All children of the caller | All activations of a named block or task | One specific process (with its descendants) |
| Needs preparation | No | A label | The thread must store `process::self()` |
| Can query whether the thread is still alive | No | No | Yes, `status()` |
| Can wait for one specific thread | No (`wait fork` waits for all) | No | Yes, `await()` |
| Safe with many objects running the same method | Yes, with an isolating fork | No | Yes |
| Can pause and continue | No | No | Yes, `suspend()` / `resume()` |

> **Interview trap:** "What does `process::self()` return when it is called inside a task?" The handle of the process that **called** the task, because a task call does not create a process. To get a handle to a new thread, `self()` must be called inside a `fork` branch.

> **Interview trap:** "The code does `fork begin p = process::self(); ... end join_none` and then immediately `p.kill();`. What goes wrong?" `p` is still `null`: a `join_none` child does not begin executing until the parent blocks. The result is a null-handle run-time error. Insert `wait (p != null);`.

> **Common mistake:** `process p = new();`. Process objects cannot be constructed by the user.

> **Common mistake:** Checking `p.status() == process::RUNNING` from another process to mean "still alive". A blocked process reports `WAITING`. Test for "not finished and not killed" instead.

> **Verification application:** UVM is built on process handles: it uses them to kill sequences, to terminate phase tasks when a phase ends, and to keep each component's random stream stable. In hand-written testbenches they are used for per-transaction timeouts, for aborting a driver's current transfer on reset while leaving the rest of the testbench running, and for reporting which threads were still active when a test hung.

### Interview questions

**Q1. What is the `process` class?**
A built-in class in the `std` package that gives a handle on a process. Through the handle the process's status can be read and the process can be killed, awaited, suspended or resumed.

**Q2. How do you get a process handle?**
The process itself calls the static method `process::self()` and assigns the result to a variable visible to whoever needs it. A process object cannot be created with `new`.

**Q3. What are the process states?**
`FINISHED`, `RUNNING`, `WAITING`, `SUSPENDED` and `KILLED`.

**Q4. What is the difference between `await()` and `wait fork`?**
`p.await()` waits for one specific process to terminate. `wait fork` waits for all child processes of the calling process.

**Q5. What is the difference between `kill()` and `disable fork`?**
`kill()` terminates exactly the process referred to by the handle (and its descendants). `disable fork` terminates every child of the calling process. `kill()` is precise and works on any process you hold a handle to, not only on your own children.

**Q6. What is the difference between `FINISHED` and `KILLED`?**
`FINISHED` means the process ran to its natural end. `KILLED` means it was terminated from outside by `kill()` or `disable`.

**Q7. Can a process `await()` itself? Can it `kill()` or `suspend()` itself?**
It cannot await itself: that is an error (it would never return). It can kill itself and it can suspend itself; a suspended process needs another process to resume it.

## 3.5 Watchdog and Timeout Patterns

Every pattern below combines the tools of this part. They are the practical reason process control is taught, and they are frequent "write the code" interview questions.

### Pattern 1: global test watchdog

The simplest protection against a hung simulation: a separate `initial` block in the top module that ends the test with an error after a maximum time.

```systemverilog
module tb_top;
  ...
  initial begin : watchdog
    #1ms;
    $fatal(1, "[%0t] WATCHDOG: test did not finish in time", $time);
  end
endmodule
```

When the test finishes normally it calls `$finish`, which ends everything, including the watchdog. The limit is usually made configurable with `$value$plusargs` (Section 4.4).

### Pattern 2: an operation with a timeout

"Wait for X, but not longer than N." A race between the operation and a timer, in an isolating fork:

```systemverilog
task automatic wait_for_valid_out(virtual alu_if vif, int max_cycles, output bit ok);
  fork
    begin
      fork
        begin                                    // the awaited condition
          @(vif.mon_cb iff vif.mon_cb.valid_out === 1'b1);
          ok = 1;
        end
        begin                                    // the timer
          repeat (max_cycles) @(vif.mon_cb);
          ok = 0;
        end
      join_any
      disable fork;
    end
  join
endtask
```

Exactly one of the two branches completes; `disable fork` removes the other. The caller checks `ok` and reports an error on a timeout.

### Pattern 3: first of N wins

Start several alternatives and continue with whichever completes first:

```systemverilog
fork
  begin
    fork
      wait_for_response();
      wait_for_error();
      wait_for_reset();
    join_any
    disable fork;
  end
join
```

### Pattern 4: abort the driver on reset

A driver must drop the transaction it is driving when reset is asserted, then start again. The driving loop is forked, a reset detector races with it, and the loop is restarted for ever.

```systemverilog
task alu_driver::run();
  forever begin
    wait (vif.rst_n === 1'b1);                 // stay idle while in reset
    fork
      begin
        fork
          drive_loop();                        // forever: get from gen2drv_mbx, drive
          @(negedge vif.rst_n);                // reset asserted
        join_any
        disable fork;                          // abandon the transfer in progress
      end
    join
    vif.drv_cb.valid_in <= 1'b0;               // return the pins to their idle values
  end
endtask
```

`drive_loop()` never returns, so `join_any` can only be satisfied by the reset branch.

### Pattern 5: timeout using a process handle

The same idea as pattern 2 with explicit handles, which makes it possible to report what was killed:

```systemverilog
task automatic run_with_timeout(int limit, output bit timed_out);
  process p_work;
  fork
    begin
      p_work = process::self();
      do_work();
    end
  join_none
  wait (p_work != null);

  fork
    begin
      fork
        p_work.await();
        #limit;
      join_any
      disable fork;
    end
  join

  timed_out = (p_work.status() != process::FINISHED);
  if (timed_out) p_work.kill();
endtask
```

A complete, runnable version of this pattern is Exercise 3 in Section 6.5.

### Which pattern to use

| Situation | Pattern |
|---|---|
| Whole simulation must not hang | 1, global watchdog |
| One wait must not hang | 2, race in an isolating fork |
| Several possible outcomes | 3, first of N |
| Restartable activity (reset, link down) | 4, loop around a race |
| Need to know or report what was still running | 5, process handles |

> **Common mistake:** Writing the timer as a second `initial` block that sets a flag, and polling the flag in a loop with no delay in it. A loop without any blocking statement never lets simulation time advance: the simulator hangs at one time step. Every waiting loop must contain a delay, an event control or a `wait`.

> **Common mistake:** A timeout measured in raw time units (`#1000`) inside reusable class code. The meaning depends on the time scale of the file. Count clock cycles through the clocking block, or use explicit units (`#1us`).

### Interview questions

**Q1. How do you implement a timeout for a blocking operation?**
Fork the operation and a timer in parallel with `join_any`, then `disable fork` to kill whichever did not finish, all inside an isolating `fork begin ... end join`. A flag or a process status tells the caller which branch won.

**Q2. How does a testbench avoid hanging for ever when the DUT never responds?**
With a watchdog: a thread that waits for a maximum time (or cycle count) and then ends the simulation with `$fatal`. Local timeouts on individual waits give a more precise error message than the global watchdog.

**Q3. How would you make a driver stop its current transaction when reset occurs?**
Run the driving code and a reset detector as a race in a `fork`...`join_any`, `disable fork` when reset wins, put the interface signals back to idle, wait for reset to be released, and start again, all inside a `forever` loop.
