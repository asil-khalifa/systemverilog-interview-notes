# Part 6: Timing and Synchronization

## 6.1 #delay versus @event versus wait

### In plain English

A thread can be told to pause in three different ways.

- `#10` : "sleep for 10 time units." The thread sets an alarm clock.
- `@(something)` : "sleep until `something` **changes**." The thread waits for a doorbell.
- `wait (condition)` : "if the condition is already true, carry on; otherwise sleep until it **is** true." The thread checks whether the door is open, and waits only if it is closed.

### Technical definition

| Timing control | Name | Resumes when |
|---|---|---|
| `#delay` | Delay control | The given amount of simulation time has elapsed |
| `@(event_expression)` | Event control (edge-sensitive) | The expression **changes** after the thread has started waiting: an edge of a signal, any change of a value, or the trigger of a named event |
| `wait (expression)` | Wait statement (level-sensitive) | The expression is **true**. If it is already true the thread does not suspend at all |

### Forms of each

```systemverilog
// ---- delay control ----
#10;                          // 10 time units
#(2 * period);                // an expression
#1ns;                         // a time literal with a unit
#0;                           // zero delay: reschedule in the Inactive region (avoid)

// ---- event control ----
@(posedge clk);               // rising edge
@(negedge rst_n);             // falling edge
@(data);                      // any change of data
@(a or b);   @(a, b);         // a change of a or of b
@(posedge clk iff valid);     // a rising edge at which valid is true
@(ev);                        // a named event
repeat (3) @(posedge clk);    // three rising edges
@(vif.mon_cb);                // a clocking-block event (Module 8)

// ---- wait ----
wait (ready);                 // until ready is non-zero
wait (count == 8);            // until an expression is true
wait (q.size() > 0);          // until a queue is not empty
wait (ev.triggered);          // until an event has triggered in this time step
wait fork;                    // until all child threads have finished (Section 3.7)
wait_order (a, b, c);         // until events have occurred in order (Section 2.6)
```

### Complete example

```systemverilog file=tb_timing_controls.sv
module tb_timing_controls;

  logic ready = 0;

  initial begin : stimulus
    #10 ready = 1;            // ready is 1 from time 10 ...
    #10 ready = 0;            // ... 0 from time 20 ...
    #10 ready = 1;            // ... and 1 again from time 30
  end

  initial begin : level_wait
    #15;
    wait (ready);
    $display("[%0t] wait (ready) passed", $time);
  end

  initial begin : edge_wait
    #15;
    @(posedge ready);
    $display("[%0t] @(posedge ready) passed", $time);
  end

  initial begin : delay_wait
    #18;
    $display("[%0t] #18 passed", $time);
  end

endmodule
```

```output
[15] wait (ready) passed
[18] #18 passed
[30] @(posedge ready) passed
```

```text
   time       0        10       15   18  20        30
              |---------|--------|----|---|---------|
   ready      ___________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_________|‾‾‾‾‾‾

   wait(ready)        starts at 15: ready is 1  -> passes at 15
   #18                                 -> passes at 18, whatever ready does
   @(posedge ready)   starts at 15: the edge at 10 is in the past
                                      -> waits for the NEXT rising edge, at 30
```

**Line by line**

| Thread | Explanation |
|---|---|
| `level_wait` | At time 15 `ready` is already 1. `wait` is level-sensitive, so it does not block. |
| `delay_wait` | A delay looks at nothing. It resumes at time 18. |
| `edge_wait` | At time 15 `ready` is 1, but `@(posedge ready)` needs a **transition** that happens after it starts waiting. The rising edge at 10 is over, so it waits for the one at 30. |

### Comparison table

| Property | `#delay` | `@(event)` | `wait (expr)` |
|---|---|---|---|
| Waits for | Time to pass | A change | A condition to be true |
| Sensitivity | None | Edge | Level |
| If the awaited thing has already happened | Not applicable | **Missed**; waits for the next occurrence | **Seen**; continues immediately |
| Can complete in zero time | Only `#0` | No: always suspends at least until the next change | Yes |
| Depends on design activity | No | Yes | Yes |
| Risk | Fragile if the DUT's timing changes | Missing an event that occurred earlier | An endless zero-time loop if used in a loop while the condition stays true |
| Typical use | Clock generation, reset width, timeouts, modelling delay | Synchronising to clock edges; repeated notifications | Waiting for a status or flag; one-shot notifications |
| Synthesizable | No | Only as the sensitivity list of an `always` block | No |

> **Interview trap:** `forever begin wait (clk); count++; end` is not a clock-edge counter. Once `clk` is 1 the `wait` passes immediately in every iteration, time never advances, and the simulation hangs. To count edges, use `@(posedge clk)`.

> **Common mistake:** Using delays to synchronise with the DUT: `#50; check_result();`. If the DUT's latency changes by one cycle the check samples the wrong value. Synchronise to what you are actually waiting for: `@(posedge clk iff valid_out);` or `wait (vif.valid_out);`.

> **Key point:** `@(posedge sig)` detects any transition toward 1: 0→1, but also 0→X, 0→Z, X→1 and Z→1. The first clock edge after an X at time 0 can therefore be an unexpected "posedge".

### Interview questions

**Q1. What is the difference between `#`, `@` and `wait`?**
`#` suspends the process for a fixed amount of simulation time. `@` suspends it until a specified change occurs, and is edge-sensitive: the change must happen after the process started waiting. `wait` suspends it until an expression is true, and is level-sensitive: if the expression is already true, the process continues without suspending.

**Q2. `a` is already 1. What do `@(posedge a)` and `wait (a)` do?**
`@(posedge a)` blocks until `a` goes low and then high again. `wait (a)` continues immediately.

**Q3. What does `@(posedge clk iff valid)` mean?**
Wait for a rising edge of `clk` at which `valid` is true. Edges at which `valid` is false are ignored.

**Q4. Which of the three can be synthesised?**
None as a procedural statement. An event control is synthesizable only as the sensitivity of an `always` block (`always @(posedge clk)`). Delays are ignored by synthesis and `wait` is not supported.

## 6.2 @event versus wait(event.triggered), and -> versus ->>

These two comparisons were developed in Sections 2.2 and 2.3. Here they are combined, because the choices on the triggering side and on the waiting side interact.

### The situation

A trigger and a wait occur **in the same time step**, in different threads, and the trigger is executed first.

| Trigger used | Wait used | Does the waiter continue in this time step? | Why |
|---|---|---|---|
| `-> ev` | `@(ev)` | **No** (race lost; it would have continued if it had run first) | The trigger was over before the wait began |
| `-> ev` | `wait (ev.triggered)` | Yes | `triggered` stays true to the end of the time step |
| `->> ev` | `@(ev)` | Yes | The trigger is postponed to the NBA region; the waiter is waiting by then |
| `->> ev` | `wait (ev.triggered)` | Yes | Either mechanism is sufficient |

Only the first row is unsafe, and it is the one people write by default.

### Side-by-side summary

| | `@(ev)` | `wait (ev.triggered)` |
|---|---|---|
| Kind | Edge-sensitive event control | Level-sensitive wait on a property |
| Catches a trigger made earlier in the same time step | No | Yes |
| Catches a trigger made in an earlier time step | No | No |
| Safe in a loop without a time delay | Yes | No |

| | `-> ev` | `->> ev` |
|---|---|---|
| Kind | Immediate (blocking) trigger | Nonblocking trigger |
| Takes effect | Now, in the Active region | In the NBA region, or after the stated delay |
| Suspends the triggering thread | No | No |
| Accepts a delay: `->> #5 ev` | No | Yes |

### Choosing

| Situation | Recommended |
|---|---|
| One-shot notification ("reset done", "generator done") | `-> ev` with `wait (ev.triggered)` |
| Repeated notification consumed in a loop | `@(ev)`, with a protocol that guarantees the waiter is waiting first; or `->> ev` |
| The notification must not be lost even if the waiter arrives much later | Not an event: a flag, a semaphore with zero keys, or a mailbox |

### Interview questions

**Q1. Give two ways to avoid losing an event when the trigger and the wait happen at the same simulation time.**
Use `wait (ev.triggered)` instead of `@(ev)` on the waiting side, or use the nonblocking trigger `->> ev` instead of `-> ev` on the triggering side.

**Q2. Which combination of trigger and wait is exposed to a race?**
`-> ev` together with `@(ev)`.

## 6.3 Blocking versus Nonblocking Synchronization

### Definition

- A **blocking** operation may suspend the calling thread until it can be completed. The thread makes no progress in the meantime. Blocking operations are **tasks** or timing statements.
- A **nonblocking** operation always returns immediately. If the operation could not be done, it says so (through a return value) or schedules the action for later. Nonblocking operations are **functions** or scheduling statements.

### The complete picture

| Mechanism | Blocking form | Nonblocking form |
|---|---|---|
| Mailbox: add | `put()` (blocks when a bounded mailbox is full) | `try_put()` returns 0 when full |
| Mailbox: remove | `get()` (blocks when empty) | `try_get()` returns 0 when empty |
| Mailbox: look | `peek()` (blocks when empty) | `try_peek()` returns 0 when empty |
| Semaphore: acquire | `get()` (blocks when keys are not available) | `try_get()` returns 0 when not available |
| Semaphore: release | None | `put()` never blocks |
| Event: wait | `@(ev)`, `wait (ev.triggered)` | Test `ev.triggered` in an `if` |
| Event: trigger | None (`->` and `->>` never suspend the caller) | `-> ev` acts now, `->> ev` acts in the NBA region |
| Threads | `fork` ... `join`, `fork` ... `join_any`, `wait fork` | `fork` ... `join_none` |
| Time | `#delay`, `@`, `wait` | None |
| Assignment (for comparison) | `a = b;` takes effect immediately | `a <= b;` takes effect in the NBA region |

### When each is appropriate

| Use blocking when | Use nonblocking when |
|---|---|
| The thread has nothing useful to do until the operation completes (a driver waiting for the next transaction) | The thread must not stall (a monitor that must sample every clock edge) |
| You want automatic flow control | The code is in a function, which cannot block |
| You want the simplest code | You need to do something else if the resource is not available, or to poll several sources |
| | You are emptying a mailbox at the end of the test |

### The danger on each side

| Style | Danger | Protection |
|---|---|---|
| Blocking | The thread may wait forever (deadlock) | Timeouts built with `fork` ... `join_any` and `disable fork`; a global watchdog |
| Nonblocking | The return value is ignored, or the call is repeated in a loop that consumes no time | Always test the return value; always include a time-consuming statement in a polling loop |

```systemverilog
// A monitor-style loop that must never stall: nonblocking put with a check
forever begin
  @(posedge clk);
  if (sample_valid) begin
    txn = new();
    capture(txn);
    if (!mon2scb_mbx.try_put(txn))
      $error("mon2scb_mbx full: scoreboard is not keeping up");
  end
end
```

### Interview questions

**Q1. What is the difference between blocking and nonblocking mailbox methods?**
The blocking methods `put`, `get` and `peek` are tasks that suspend the caller until the operation can complete. The nonblocking methods `try_put`, `try_get` and `try_peek` are functions that return immediately with a status: positive for success and 0 when the operation could not be performed.

**Q2. Why can a function call `try_get()` but not `get()`?**
A function must execute in zero simulation time and cannot contain anything that might suspend it. `get()` is a task that may block; `try_get()` is a function that never does.

**Q3. Is `-> ev` a blocking statement?**
No. Despite sometimes being called the "blocking trigger", it does not suspend the process. The name distinguishes it from `->>`, whose effect is deferred in the same way as a nonblocking assignment.

## 6.4 Race Conditions

### Definition

A **race condition** exists when the result of a simulation depends on the order in which the simulator executes threads that are ready at the same simulation time. The standard leaves that order undefined, so:

- two simulators may give different results for the same code;
- the same simulator may give different results after a change of options, optimisation level or version, or after an unrelated edit that reorders the source;
- the testbench may behave differently in RTL and in gate-level simulation.

A race is a bug even if the code "works" today.

### The kinds of race and their cures

| Kind | Example | Cure |
|---|---|---|
| Read/write of a shared variable in the same time step | One thread assigns `data` at time 10; another reads `data` at time 10 | Separate them in time or region: nonblocking assignment, a clocking block, a mailbox |
| Write/write | Two threads assign the same variable at the same time; the last one wins | One owner per variable; a semaphore |
| Event trigger versus wait | `-> ev` and `@(ev)` at the same time | `wait (ev.triggered)` or `->>` |
| Testbench versus DUT at a clock edge | The testbench changes a DUT input at `posedge clk` with a blocking assignment, while the DUT samples it at the same edge | Drive through a clocking block or with nonblocking assignments; sample before the edge (Module 8) |
| Lost update (read-modify-write) | Two threads read a counter, both add one, both write back | A semaphore around the whole read-modify-write |
| Order of `initial` blocks | One `initial` block uses an object that another constructs at time 0 | One `initial` block controls the order; or wait for an explicit event |

### Example 1: read/write at the same time (simulator-dependent)

```systemverilog
logic [7:0] data = 8'h00;

initial #10 data = 8'hAA;                               // thread 1 writes at time 10
initial #10 $display("[%0t] data = %h", $time, data);   // thread 2 reads at time 10
```

The printed value is `aa` if the simulator runs thread 1 first and `00` if it runs thread 2 first. Both are correct according to the standard, so no single "expected output" exists.

Ways to make the result defined:

| Change | Result | Why |
|---|---|---|
| Write with `data <= 8'hAA;` | Always `00` | The update happens in the NBA region, after all Active-region reads |
| Read with `$strobe` instead of `$display` | Always `aa` | `$strobe` prints in the Postponed region, after all updates |
| Read at `#11`, or on the opposite clock edge | Always `aa` | The two actions are at different times |

### Example 2: the testbench-DUT race at a clock edge

```systemverilog
// DUT
always_ff @(posedge clk) q <= d;

// Testbench: RACE
initial begin
  @(posedge clk);
  d = 1;              // blocking assignment at the same edge at which the DUT samples d
end
```

Both the `always_ff` and the `initial` block wake at the same clock edge. If the testbench runs first, the DUT samples the new `d` (1) at this edge. If the DUT runs first, it samples the old `d` and sees the 1 one cycle later. The DUT's behaviour changes by a whole clock cycle depending on the simulator.

Cures: drive with a nonblocking assignment (`d <= 1;`), so that `d` changes after the DUT has sampled it; or drive on the inactive clock edge; or, the proper method, drive and sample through a **clocking block**, which defines exactly when inputs are sampled and outputs are driven relative to the clock. Clocking blocks are the subject of Module 8.

### Example 3: lost update (deterministic) and its cure

This race does not depend on the simulator at all. It comes from a thread being suspended in the middle of a read-modify-write sequence.

```systemverilog file=tb_race_lost_update.sv
module tb_race_lost_update;

  int       shared_count = 0;
  semaphore key          = new(1);

  task automatic add_unsafe();
    int tmp;
    tmp = shared_count;             // read
    #1;                             // suspended in the middle (models work that takes time)
    shared_count = tmp + 1;         // write back
  endtask

  task automatic add_safe();
    int tmp;
    key.get();                      // only one thread at a time from here ...
    tmp = shared_count;
    #1;
    shared_count = tmp + 1;
    key.put();                      // ... to here
  endtask

  initial begin
    fork
      add_unsafe();
      add_unsafe();
    join
    $display("[%0t] unsafe: shared_count = %0d (expected 2)", $time, shared_count);

    shared_count = 0;
    fork
      add_safe();
      add_safe();
    join
    $display("[%0t] safe  : shared_count = %0d (expected 2)", $time, shared_count);
  end

endmodule
```

```output
[1] unsafe: shared_count = 1 (expected 2)
[3] safe  : shared_count = 2 (expected 2)
```

**Execution flow**

| Time | Unsafe version | |
|---|---|---|
| 0 | Thread 1 reads 0 into its `tmp`, suspends | Thread 2 reads 0 into its `tmp`, suspends |
| 1 | Thread 1 writes 0 + 1 = 1 | Thread 2 writes 0 + 1 = 1. One increment is lost |

| Time | Safe version | |
|---|---|---|
| 1 | Thread 1 takes the key, reads 0, suspends | Thread 2 blocks in `key.get()` |
| 2 | Thread 1 writes 1, returns the key | Thread 2 takes the key, reads 1, suspends |
| 3 | | Thread 2 writes 2, returns the key |

(Which of the two threads is "thread 1" is up to the simulator. The result is the same either way.)

The tasks are declared `automatic` so that each call has its own `tmp`. With a static task both threads would share one `tmp`, which is a second bug of the same family (Module 3).

### Why #0 is not a cure

Adding `#0` before the read in Example 1 moves that thread to the Inactive region, so the write (in the Active region) happens first. It appears to work. But if the writer is later changed to use `#0` as well, or is woken by a nonblocking update, the race is back, and the code now contains unexplained `#0`s. `#0` documents nothing and guarantees little. Use a mechanism that states the intended order.

> **How to say it in an interview:** "A race condition is when the result depends on the execution order of processes scheduled at the same simulation time, which the LRM leaves undefined. Typical cases are a blocking write and a read of the same variable at the same clock edge, and triggering an event in the same time step in which another process starts to wait for it. I avoid them by using nonblocking assignments and clocking blocks between the testbench and the DUT, `wait (ev.triggered)` or `->>` for events, mailboxes for passing data, and semaphores for shared resources."

### Interview questions

**Q1. What is a race condition? Give an example.**
A situation in which the simulation result depends on the order in which processes that are active at the same simulation time are executed. Example: one process assigns `a = 1` at a clock edge with a blocking assignment while another process reads `a` at the same edge.

**Q2. How do nonblocking assignments avoid races in RTL?**
All right-hand sides are evaluated in the Active region using the old values, and all left-hand sides are updated afterwards in the NBA region. Every flip-flop therefore sees the pre-edge values, whatever the order of the `always` blocks.

**Q3. How do you avoid a race between the testbench and the DUT?**
Drive DUT inputs and sample DUT outputs through a clocking block (with input and output skews), or drive with nonblocking assignments and sample before the clock edge, or use the opposite clock edge. Historically, placing the testbench in a `program` block, which executes in the Reactive region, served the same purpose.

**Q4. Two threads each execute `count = count + 1;` at the same simulation time, with no delay in between. Is an increment lost?**
No. A thread runs until it blocks, and this statement contains no blocking point, so each increment is completed before the other thread runs. The final value is correct, although the order is undefined. An update is lost only when a thread can be suspended between its read and its write.

**Q5. Is `#0` a good way to fix a race?**
No. It reorders execution within the time step by moving a process to the Inactive region, but it does not express the dependency, it fails as soon as another process also uses `#0`, and it makes the code hard to reason about.

## 6.5 Deadlocks

### Definition

A **deadlock** is a state in which two or more threads are each blocked waiting for something that can only be provided by another of the blocked threads. None of them can ever continue. More loosely, any thread that is blocked forever on a condition that will never occur is called deadlocked (or "hung").

### The classic case: two semaphores taken in opposite orders

```systemverilog file=tb_deadlock.sv
module tb_deadlock;

  semaphore key_a = new(1);
  semaphore key_b = new(1);

  initial begin : thread_1
    key_a.get();
    $display("[%0t] T1 holds A", $time);
    #5;
    $display("[%0t] T1 waits for B", $time);
    key_b.get();                                   // blocked: T2 holds B
    $display("[%0t] T1 holds A and B", $time);     // never reached
    key_b.put();
    key_a.put();
  end

  initial begin : thread_2
    #1;
    key_b.get();
    $display("[%0t] T2 holds B", $time);
    #5;
    $display("[%0t] T2 waits for A", $time);
    key_a.get();                                   // blocked: T1 holds A
    $display("[%0t] T2 holds A and B", $time);     // never reached
    key_a.put();
    key_b.put();
  end

  initial begin : watchdog
    #100;
    $display("[%0t] WATCHDOG: no progress, the threads are deadlocked", $time);
    $finish;
  end

endmodule
```

```output
[0] T1 holds A
[1] T2 holds B
[5] T1 waits for B
[6] T2 waits for A
[100] WATCHDOG: no progress, the threads are deadlocked
```

```text
            holds                      waits for
     T1  ---------->  key A   <----------------------  T2
      |                                                ^
      |   waits for                         holds      |
      +------------------>  key B  --------------------+

     A cycle: T1 waits for what T2 holds, and T2 waits for what T1 holds.
```

**The cure:** every thread acquires the semaphores **in the same order**. If thread 2 also takes A first and then B, it simply blocks on A at time 1 until thread 1 has finished with both, and no cycle can form.

```systemverilog
initial begin : thread_2_fixed
  #1;
  key_a.get();        // same order as thread 1: A first ...
  key_b.get();        // ... then B
  // ... use both resources ...
  key_b.put();
  key_a.put();
end
```

### Other ways a testbench hangs

| Situation | Why nothing proceeds | Cure |
|---|---|---|
| `@(ev)` after the event has already been triggered | The waiter missed the only trigger | `wait (ev.triggered)`, `->>`, or a persistent flag |
| Waiting on an event that was never connected between two classes | Each object has its own private event | Share the handle before forking |
| `get()` on a mailbox whose producer has finished or died | No message will ever arrive | End-of-test logic; `try_get`; a timeout |
| `put()` on a full bounded mailbox whose consumer has stopped | No space will ever be freed | Same |
| Two threads connected by two bounded mailboxes, each blocked in `put` towards the other | A cycle of full mailboxes | Unbounded mailbox in one direction; redesign the protocol |
| A semaphore key not returned on an error path, or its holder killed | No key will ever be put | Release on every path; do not kill threads in critical sections |
| `fork` ... `join` containing a `forever` thread | `join` waits for a thread that never ends | `join_any` / `join_none` |
| `wait fork` with a never-ending background child | Same | Guard thread |
| Generator waits for `drv_done`; driver waits for a second transaction before triggering it | Each waits for the other (a protocol deadlock) | Review the handshake |
| Waiting for a DUT signal that never comes because of a DUT bug | The testbench waits forever | A timeout that reports an error |

### How a deadlock appears in practice

| What you see | What it means |
|---|---|
| The simulation ends early, quietly, with no error and with the test incomplete | Every thread is blocked and nothing is scheduled, so the simulator has no events left and stops. This happens when the clock is not free-running, or is generated by a thread that has ended |
| The simulation runs until the maximum time or the wall-clock limit of the regression | The clock generator keeps the simulation alive while all the useful threads are blocked |
| Simulation time stops advancing and the simulator uses 100% CPU | Not a deadlock but a zero-delay loop (for example `wait (ev.triggered)` or `try_get` in a loop without a delay) |

The first symptom is the dangerous one: a test that stops early without printing an error can be reported as "passed" by a careless script. A test should print an explicit end-of-test message that the regression script requires, and should count the transactions it expected to check.

### Prevention

| Technique | How |
|---|---|
| Global watchdog | `initial begin #(MAX_TIME); $fatal(1, "watchdog timeout"); end` in the testbench top. Every testbench should have one |
| Timeout on each important wait | `fork begin fork wait_for_x(); #limit $error("timeout"); join_any  disable fork; end join` |
| Fixed acquisition order | Always take semaphores in the same order |
| Release on all paths | One `put()` for every `get()`, including error paths |
| Nonblocking alternatives | `try_get()` where waiting forever is not acceptable |
| Simple ownership | One mailbox per direction, constructed once; one owner per resource |
| End-of-test condition | The test ends on a positive condition ("all N transactions checked"), not on "nothing seems to be happening" |

> **Interview trap:** "The simulation finished at time 350 with no errors, but only two of the ten transactions were checked. What happened?" The testbench deadlocked, or a thread died, and with nothing left to schedule the simulator ended normally. "No errors" is not "passed". Look for the last message of each component to find which thread is blocked and on what.

### Interview questions

**Q1. What is a deadlock?**
A situation in which two or more threads are blocked, each waiting for a resource or an action that only another blocked thread can provide, so that none of them can ever resume.

**Q2. Give an example of a deadlock with semaphores and its solution.**
Thread 1 takes semaphore A and then requests B; thread 2 takes B and then requests A. Each holds what the other needs. The solution is for all threads to acquire the semaphores in the same order.

**Q3. How do you debug a hanging simulation?**
First decide whether time is advancing. If time is frozen, a zero-delay loop exists: look for loops without a blocking statement. If time advances or the simulation ends early, a thread is blocked: use the last messages printed by each component, or the simulator's thread/process view, to find the blocking statement (`get`, `@`, `wait`), and then ask who was supposed to provide the message, trigger or key.

**Q4. How do you protect a testbench against hangs?**
A global watchdog that ends the simulation with a fatal error after a maximum time, timeouts on individual waits built with `fork` ... `join_any` and `disable fork`, and an explicit end-of-test condition.

**Q5. What is the difference between a deadlock and a race condition?**
A race is a result that depends on undefined execution order: the simulation completes but may be wrong. A deadlock is a state from which threads can never continue: the simulation hangs or ends prematurely. An event race (a missed trigger) frequently causes a hang, so the two often appear together.

## 6.6 Synchronization Between Multiple Processes: a Complete Example

The example connects three components with two mailboxes and ends the test on a positive condition, protected by a timeout. It is a miniature of the environment built in Module 9. To stay self-contained it has no DUT: the driver computes the result itself and forwards the transaction, standing in for the DUT and the monitor.

```text
   alu_generator --> gen2drv_mbx --> alu_driver --> mon2scb_mbx --> alu_scoreboard
        |                             (drives, 10 time units each)        |
        | num_txn                                                         | num_checked
        +--------------------------> test: wait (num_checked == num_txn) <+
                                           or timeout
```

```systemverilog file=tb_multi_process_sync.sv
module tb_multi_process_sync;

  class alu_txn;
    bit [7:0]    a, b;
    logic [8:0]  result;
    int unsigned id;
  endclass

  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    int unsigned       num_txn = 3;

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();
        txn.id = i;
        txn.a  = 8'(i);
        txn.b  = 8'(2 * i);
        $display("[%0t] GEN: put id=%0d", $time, txn.id);
        gen2drv_mbx.put(txn);
      end
    endtask
  endclass

  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    mailbox #(alu_txn) mon2scb_mbx;

    task run();
      alu_txn txn;
      forever begin
        gen2drv_mbx.get(txn);
        #10;                                         // one transfer takes 10 time units
        txn.result = txn.a + txn.b;                  // stands in for the DUT
        $display("[%0t] DRV: drove id=%0d, result=%0d", $time, txn.id, txn.result);
        mon2scb_mbx.put(txn);                        // stands in for the monitor
      end
    endtask
  endclass

  class alu_scoreboard;
    mailbox #(alu_txn) mon2scb_mbx;
    int unsigned       num_checked;

    task run();
      alu_txn txn;
      forever begin
        mon2scb_mbx.get(txn);
        if (txn.result !== txn.a + txn.b)
          $display("[%0t] SCB: id=%0d FAIL", $time, txn.id);
        else
          $display("[%0t] SCB: id=%0d PASS", $time, txn.id);
        num_checked++;
      end
    endtask
  endclass

  mailbox #(alu_txn) gen2drv_mbx, mon2scb_mbx;
  alu_generator      gen;
  alu_driver         drv;
  alu_scoreboard     scb;

  initial begin
    // build
    gen2drv_mbx = new();
    mon2scb_mbx = new();
    gen = new();
    drv = new();
    scb = new();

    // connect
    gen.gen2drv_mbx = gen2drv_mbx;
    drv.gen2drv_mbx = gen2drv_mbx;
    drv.mon2scb_mbx = mon2scb_mbx;
    scb.mon2scb_mbx = mon2scb_mbx;

    // run
    fork
      gen.run();
      drv.run();
      scb.run();
    join_none

    // end of test: all transactions checked, or timeout
    fork
      begin
        fork
          wait (scb.num_checked == gen.num_txn);
          begin
            #1000;
            $display("[%0t] TEST: TIMEOUT", $time);
          end
        join_any
        disable fork;
      end
    join

    $display("[%0t] TEST: %0d of %0d transactions checked",
             $time, scb.num_checked, gen.num_txn);
    $finish;
  end

endmodule
```

```output
[0] GEN: put id=1
[0] GEN: put id=2
[0] GEN: put id=3
[10] DRV: drove id=1, result=3
[10] SCB: id=1 PASS
[20] DRV: drove id=2, result=6
[20] SCB: id=2 PASS
[30] DRV: drove id=3, result=9
[30] SCB: id=3 PASS
[30] TEST: 3 of 3 transactions checked
```

### What synchronizes what

| Mechanism in the example | Threads involved | Purpose |
|---|---|---|
| `gen2drv_mbx` (unbounded) | Generator → driver | The generator runs ahead and finishes at time 0; the mailbox holds the three transactions until the driver takes them |
| `mon2scb_mbx` | Driver → scoreboard | Each completed transaction is checked as soon as it arrives |
| `fork` ... `join_none` | Top → three components | Starts the components; the driver and scoreboard loop forever |
| `wait (scb.num_checked == gen.num_txn)` | Scoreboard → test | A positive end-of-test condition. The test does not end when the generator finishes (time 0); it ends when the last transaction has been checked (time 30) |
| `fork` ... `join_any` with `disable fork` in a guard | Test | Timeout. Without the guard, `disable fork` would also kill the three components |

### Points to notice

- The driver prints **before** it puts the transaction into `mon2scb_mbx`, and the scoreboard prints **before** it increments `num_checked`. Each line of output is therefore caused by the previous one, and the order does not depend on the simulator.
- The generator finishes at time 0. A test that ended on "generator done" would stop before anything had been driven. This is the most common end-of-test bug.
- The driver passes the *same* object on to the scoreboard. In a real environment the monitor creates a **new** transaction from what it observes on the interface, so that the checked data comes from the DUT pins and not from the stimulus.

## 6.7 Event versus Mailbox versus Semaphore

### Comparison table

| Property | Event | Mailbox | Semaphore |
|---|---|---|---|
| Purpose | Notify that something happened | Transfer data | Control access to a shared resource |
| What it holds | Nothing | A FIFO of messages | A count of keys |
| Carries data | No | Yes | No |
| Kind of object | Built-in synchronization object, handle semantics | Built-in class | Built-in class |
| Needs `new()` | No | Yes | Yes |
| Producing operation | `-> ev`, `->> ev` | `put()`, `try_put()` | `put()` |
| Consuming operation | `@(ev)`, `wait (ev.triggered)` | `get()`, `peek()`, `try_get()`, `try_peek()` | `get()`, `try_get()` |
| Is the state remembered | No (only to the end of the time step, through `triggered`) | Yes, until a `get` removes the message | Yes, until a `get` takes the key |
| Counts occurrences | No | Yes, one message each | Yes, one key each |
| Number of threads woken by one action | **All** waiters | One (the message goes to a single getter) | As many as the returned keys satisfy |
| Can the producer block | No | Yes, if bounded and full | No |
| Can the consumer block | Yes | Yes, if empty | Yes, if keys are not available |
| Nonblocking consumer call | Test `ev.triggered` | `try_get()`, `try_peek()` | `try_get()` |
| Query | `ev.triggered` | `num()` | None |
| Typical use | `reset_done`, `drv_done`, `gen_done` | generator → driver, monitor → scoreboard | Two sequences sharing one driver or interface |

### Choosing

```text
   Do the threads need to pass data?
        yes ----------------------------------------------> MAILBOX
        no
         |
   Do they compete for something only one (or N) may use at a time?
        yes ----------------------------------------------> SEMAPHORE
        no
         |
   Does one thread just need to tell others "it has happened"?
        yes, and all waiters are already waiting ---------> EVENT
        yes, but a waiter may arrive later ---------------> flag variable,
                                                            semaphore with 0 keys,
                                                            or mailbox
```

### They are used together

A real testbench uses all three at once. In the ALU environment: mailboxes carry `alu_txn` handles between generator, driver, monitor and scoreboard; the `drv_done` and `gen_done` events pace the generator and end the test; and a semaphore protects the interface whenever more than one source of stimulus (for example a main sequence and an error-injection sequence) shares the driver.

### Interview questions

**Q1. Compare event, mailbox and semaphore.**
An event signals that something has occurred; it carries no data, is not remembered, and wakes all waiting threads. A mailbox passes data between threads as a FIFO of messages, with blocking `get` and optionally blocking `put`. A semaphore holds keys and controls access to a shared resource; a thread blocks in `get` until a key is available.

**Q2. Which would you use for each of these: sending transactions from monitor to scoreboard; telling the test that the generator has finished; letting two sequences use one driver?**
A mailbox; an event; a semaphore.

**Q3. Which of the three can lose information, and how?**
An event. A trigger that occurs when nobody is waiting is lost, and two triggers before the waiter runs are seen as one. A mailbox stores every message and a semaphore counts every key.

**Q4. Which of the three need `new()`?**
Mailbox and semaphore, because they are classes. An event does not.

**Q5. Can a mailbox be used in place of an event or a semaphore?**
Yes. A message with no meaningful content acts as a remembered notification, and a bounded mailbox of size 1 acts as a lock. It is rarely done, because the dedicated constructs state the intention clearly, but it shows that the mailbox is the most general of the three.
