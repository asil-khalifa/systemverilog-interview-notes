# Module 7 Overview

This module covers **inter-process communication (IPC) and synchronization**: how the parallel threads of a testbench signal each other, pass data to each other, and share resources without corrupting them. Interviewers treat this module as a test of whether you have really built a class-based testbench, because every such testbench is a set of threads (generator, driver, monitor, scoreboard) that must cooperate.

**What this module covers**

| Part | Topic | Mechanism | Purpose |
|---|---|---|---|
| 1 | Why IPC is needed | Processes, scheduling, blocking | The problem that the other parts solve |
| 2 | Events | `event`, `->`, `->>`, `@`, `wait(ev.triggered)`, `wait_order` | "Something happened" |
| 3 | Fork and join | `fork`...`join` / `join_any` / `join_none`, `disable fork`, `wait fork` | Creating and controlling parallel threads |
| 4 | Mailbox | `mailbox`, `put`, `get`, `peek`, `try_*`, `num` | Passing data between threads |
| 5 | Semaphore | `semaphore`, `get`, `put`, `try_get` | Sharing a resource safely |
| 6 | Timing and synchronization | `#`, `@`, `wait`, races, deadlocks | Using all of the above correctly |
| 7 | Revision and practice | | Questions, traps, exercises |

**What you need from earlier modules**

| From | You should already know |
|---|---|
| M1 | Data types, `logic` versus `bit`, enums, the ALU DUT and `alu_pkg` |
| M2 | Queues (a mailbox is compared with a queue in Part 4) |
| M3 | Tasks versus functions, `automatic` versus `static` lifetime, `ref` arguments. A task may block; a function may not. This rule decides which IPC methods can be called where |
| M4 | Classes, handles, `new()`, `null`. Mailboxes and semaphores are built-in classes, and a mailbox of transactions stores **handles** |
| M6 | The `alu_txn` transaction class |

**Naming used in this module.** The examples use the names of the course testbench: transaction `alu_txn`, components `alu_generator` and `alu_driver`, mailboxes `gen2drv_mbx` and `mon2scb_mbx`, events `gen_done` and `drv_done`. So that every example compiles by itself, a cut-down `alu_txn` with the same field names is declared inside the example module, and field values are set by hand instead of being randomized. That keeps the printed output fixed.

> **Note:** The "Expected output" blocks were derived by hand from the IEEE 1800 rules, not captured from a simulator. The standard does **not** define the order in which threads that are ready at the same simulation time are executed. The examples are therefore written so that the output does not depend on that order: threads use different delays, or one line can only be printed after another because of a cause-and-effect chain. Where an example deliberately shows a race, the text says that the result depends on the simulator.

# Part 1: Why Inter-Process Communication Is Needed

## 1.1 Processes and Threads in SystemVerilog

### In plain English

Real hardware does everything at once: every flip-flop and every gate is active all the time. A testbench must imitate this. While the driver is wiggling the input pins, the monitor must be watching the output pins, the scoreboard must be checking results, and the clock must keep ticking. Each of these activities is written as a separate piece of code that runs "at the same time" as the others. Such a piece of code is called a **process** or a **thread**.

### Technical definition

A **process** (also called a **thread** of execution) is an independently scheduled sequence of statements. A SystemVerilog simulation contains many processes. They are created by:

| Construct | Creates |
|---|---|
| `initial` block | One process that starts at time 0 and runs once |
| `always`, `always_ff`, `always_comb`, `always_latch` block | One process that repeats forever |
| `final` block | One process that runs at the end of simulation (cannot block) |
| Continuous assignment (`assign`) | One process that re-evaluates when an input changes |
| Each statement inside `fork` ... `join` / `join_any` / `join_none` | One **dynamic** process per statement (Part 3) |
| Concurrent assertion | One process per attempt (M10) |

Processes created by `initial`, `always` and `assign` exist for the whole simulation and are called **static processes**. Processes created by `fork` are created while the simulation runs and are called **dynamic processes**. A class-based testbench is built almost entirely from dynamic processes: the `run()` task of every component is started inside a `fork`.

### How it works internally: there is only one CPU

The simulator is an ordinary program. It does not actually run the processes at the same time. It runs **one process at a time**, and switches to another process only when the running one **blocks**.

A process blocks when it executes a statement that must wait for something:

| Blocking statement | Waits for |
|---|---|
| `#10;` | Simulation time to advance by 10 units |
| `@(posedge clk);`, `@(ev);` | A change on a signal, or an event trigger |
| `wait (expr);` | The expression to become true |
| `mbx.get(x);` on an empty mailbox | A message |
| `mbx.put(x);` on a full bounded mailbox | Free space |
| `sem.get();` with no key available | A key |
| `fork` ... `join` | All the child threads to finish |
| `wait fork;` | All the child threads to finish |

```text
   What the testbench describes            What the simulator actually does
   ----------------------------            --------------------------------

   generator  ========>                    time 0 :  run generator until it blocks
   driver     ========>                              run driver    until it blocks
   monitor    ========>                              run monitor   until it blocks
   scoreboard ========>                              run scoreboard until it blocks
                                                     nothing left to run at time 0
   (four threads "in parallel")            time 5 :  wake the threads waiting for time 5,
                                                     run each until it blocks ...
```

Three consequences follow, and all of IPC rests on them.

1. **Within one simulation time, threads run one after another, in an order the standard does not define.** If two threads are both ready at time 10, the simulator may run either first. Code whose result depends on that order has a **race condition**.
2. **A thread that never blocks never lets any other thread run.** A `forever` loop with no delay, event or blocking call inside it hangs the simulation at the current time.
3. **Simulation time advances only when every thread is blocked.** Then the simulator moves to the next time at which something is scheduled.

### Complete example

```systemverilog file=tb_processes.sv
module tb_processes;

  initial begin : thread_a
    $display("[%0t] A: step 1", $time);
    #10;
    $display("[%0t] A: step 2", $time);
    #20;
    $display("[%0t] A: step 3", $time);
  end

  initial begin : thread_b
    #5;
    $display("[%0t] B: step 1", $time);
    #10;
    $display("[%0t] B: step 2", $time);
  end

endmodule
```

```output
[0] A: step 1
[5] B: step 1
[10] A: step 2
[15] B: step 2
[30] A: step 3
```

**Line by line**

| Time | What happens |
|---|---|
| 0 | Both `initial` blocks become ready. `thread_a` prints and blocks at `#10`. `thread_b` blocks at `#5` without printing. Whichever the simulator runs first, the output is the same, because only one of them prints at time 0. |
| 5 | Every thread is blocked, so time advances to the earliest wake-up, 5. `thread_b` prints and blocks until 15. |
| 10 | `thread_a` wakes, prints, and blocks until 30. |
| 15 | `thread_b` wakes, prints, and ends. |
| 30 | `thread_a` wakes, prints, and ends. No process is left, so the simulation stops. |

The two threads interleave. Neither knows anything about the other. That is fine here because they do not share anything. The rest of this module is about what happens when they do.

### Interview questions

**Q1. What is a process (thread) in SystemVerilog?**
An independently scheduled sequence of statements. `initial` and `always` blocks and continuous assignments create static processes; each statement of a `fork` block creates a dynamic process.

**Q2. Do SystemVerilog threads really run in parallel?**
No. The simulator executes one thread at a time. A thread runs until it reaches a blocking statement (a delay, an event control, a `wait`, or a blocking method call), and then another ready thread runs. The parallelism is in simulation time, not in real time.

**Q3. Two `initial` blocks both start at time 0. Which one runs first?**
The standard does not say. Code must not depend on the order.

**Q4. What happens if a `forever` loop contains no blocking statement?**
The thread never gives up control. Simulation time cannot advance and the simulation hangs (a "zero-delay loop").

## 1.2 Why Parallel Threads Must Communicate

### In plain English

Consider the two most basic testbench components.

- The **generator** creates transactions (what to send to the DUT).
- The **driver** takes a transaction and turns it into pin wiggles on the DUT inputs, which takes one or more clock cycles.

They are separate classes and run as separate threads, for a good reason: the generator knows nothing about pins and clocks, and the driver knows nothing about what makes a good test. But they cannot work independently:

1. The generator must **hand each transaction** to the driver. → data transfer
2. The generator must **not produce faster** than the driver can drive, or transactions are lost or pile up without limit. → flow control
3. The generator may need to know **when the driver has finished** an item, and the test must know **when everything is done** so that it can end. → notification
4. If two drivers use the **same bus**, only one may drive at a time. → mutual exclusion

SystemVerilog provides one construct for each need.

| Need | Question it answers | Construct | Part |
|---|---|---|---|
| Notification | "Has X happened yet?" | `event` | 2 |
| Creating and joining threads | "Start these in parallel; continue when all / one / none have finished" | `fork` ... `join` / `join_any` / `join_none` | 3 |
| Data transfer with flow control | "Give this item to the other thread; wait if it is not ready" | `mailbox` | 4 |
| Mutual exclusion | "May I use the shared resource now?" | `semaphore` | 5 |

Together these are called the **inter-process communication (IPC)** and **synchronization** constructs.

- **Communication** means passing information from one thread to another.
- **Synchronization** means making threads wait for each other so that things happen in the right order.

### What goes wrong without IPC: a shared variable

The obvious first idea is a shared variable: the producer writes it, and the consumer reads it. The example below shows why that is not enough.

```systemverilog file=tb_no_ipc.sv
module tb_no_ipc;

  int shared_data;
  bit new_data;

  initial begin : producer
    for (int i = 1; i <= 4; i++) begin
      $display("[%0t] producer writes %0d", $time, i * 11);
      shared_data = i * 11;
      new_data    = 1;
      #5;                              // produces one item every 5 time units
    end
  end

  initial begin : consumer
    forever begin
      wait (new_data);                 // wait until something has been written
      new_data = 0;
      $display("[%0t] consumer reads  %0d", $time, shared_data);
      #12;                             // needs 12 time units to process one item
    end
  end

endmodule
```

```output
[0] producer writes 11
[0] consumer reads  11
[5] producer writes 22
[10] producer writes 33
[12] consumer reads  33
[15] producer writes 44
[24] consumer reads  44
```

**Execution flow**

| Time | Producer | Consumer | `shared_data` |
|---|---|---|---|
| 0 | Writes 11, sets `new_data` | `wait (new_data)` passes, reads 11, starts processing until 12 | 11 |
| 5 | Writes 22 | Busy | 22 |
| 10 | Writes 33. **22 is overwritten before anybody read it** | Busy | 33 |
| 12 | | Finishes, `new_data` is still 1, reads 33, busy until 24 | 33 |
| 15 | Writes 44, then ends | Busy | 44 |
| 24 | | Reads 44, busy until 36 | 44 |
| 36 | | `wait (new_data)` blocks forever. Nothing else is scheduled, so the simulation ends | |

Four items were produced and only three were consumed. Item 22 was silently lost. The shared variable has three defects:

| Defect | Why |
|---|---|
| No storage | One variable holds one value. A second write destroys the first. |
| No flow control | The producer has no way to know that the consumer is still busy. |
| Hand-written handshake | The `new_data` flag is a home-made protocol. With more than two threads it becomes very easy to get wrong. |

A mailbox (Part 4) removes all three: it stores any number of items in order, it can make the producer wait when it is full, and the handshake is built in.

> **Key point:** IPC constructs exist because threads run independently and at different speeds. A plain shared variable gives no storage, no waiting and no protection. Events add waiting, mailboxes add storage and waiting, semaphores add protection.

### Where IPC appears in a layered testbench

```text
                    gen2drv_mbx                                  mon2scb_mbx
  +-----------+    (mailbox)     +----------+      +---------+   (mailbox)    +------------+
  | generator | ---------------> |  driver  |      | monitor | -------------> | scoreboard |
  +-----------+                  +----------+      +---------+                +------------+
        ^                             |  |              ^
        |        drv_done (event)     |  |  vif         |  vif
        +-----------------------------+  v              |
                                      +---------------------+
        gen_done (event)              |         DUT         |
        ----------------> test        +---------------------+

  All four run() tasks are started with fork ... join_none (or join_any) by the environment.
  A semaphore is added when two components must share one interface.
```

Every arrow in this picture is one of the constructs of this module. Module 9 builds exactly this structure for the ALU.

### Interview questions

**Q1. What is inter-process communication and why is it needed in a testbench?**
IPC is the set of mechanisms by which parallel threads exchange information and coordinate their execution. A testbench consists of components that run as separate threads (generator, driver, monitor, scoreboard). They must pass transactions to each other, wait for each other, and share resources such as an interface. Events, mailboxes and semaphores provide this; `fork`...`join` creates the threads.

**Q2. Why not use a shared variable or a queue between the generator and the driver?**
A shared variable holds only one value, so a fast producer overwrites data, and it gives the consumer no way to wait for data except polling. A queue stores many items but has no blocking: the consumer must be written with its own `wait (q.size() > 0)` and the producer has no flow control. A mailbox has storage, blocking `get` and optional blocking `put` built in.

**Q3. Name the SystemVerilog IPC constructs and the purpose of each.**
`event` for notification that something happened; `mailbox` for passing data between threads; `semaphore` for controlling access to a shared resource; and `fork`...`join`, `join_any`, `join_none` with `wait fork` and `disable fork` for creating and controlling the threads.

**Q4. What is the difference between communication and synchronization?**
Communication transfers data between threads (a mailbox). Synchronization controls the relative timing of threads so that actions occur in the required order (events, semaphores, joining threads). A mailbox does both: `get` blocks until data arrives.

## 1.3 The Simulation Time Slot: Why Order Within a Time Step Matters

To understand races, `->` versus `->>`, and `@` versus `wait(triggered)`, you need a simplified picture of how the simulator processes one moment of simulation time. Everything that happens at one simulation time is called a **time slot**. A time slot is divided into ordered **regions**.

```text
   One time slot (all activity at a single simulation time)

        Preponed   : sample values for assertions and clocking blocks (nothing changes here)
   +--> Active     : run ready processes: blocking assignments, -> ev, $display,
   |                 evaluate the right-hand side of <=
   |    Inactive   : processes that executed #0
   |    NBA        : update the left-hand side of <= ; perform ->> ev triggers
   |    Observed   : evaluate concurrent assertions
   |    Reactive   : program-block code, assertion action blocks, clocking-block drives
   +--- loop back while any of these regions still has something to do
        Postponed  : $strobe and $monitor print; nothing may change any more

   Then simulation time advances to the next time at which something is scheduled.
```

The points to remember for this module:

| Fact | Consequence |
|---|---|
| All ready threads run in the **Active** region, in an undefined order | Two threads that touch the same variable or event at the same time can race |
| A plain trigger `-> ev` takes effect immediately, in the Active region | A thread that starts waiting later in the same time slot has missed it |
| A nonblocking trigger `->> ev` takes effect in the **NBA** region | Every thread that ran in the Active region is already waiting when the trigger arrives |
| `ev.triggered` stays true from the trigger until the **end of the time slot** | `wait (ev.triggered)` cannot miss a trigger made earlier in the same time slot |
| `#0` moves a thread to the **Inactive** region | The thread runs again after all other Active threads have run. It is a crude way of saying "let the others go first" and is discouraged |
| The regions repeat (loop back) | A thread woken by an NBA update runs in a new Active region of the same time slot |

The full scheduling model, including the Reactive region and `program` blocks, belongs to Module 8 (clocking blocks) and Module 11. This simplified picture is enough for IPC.

### The words used in this module

| Term | Meaning |
|---|---|
| Thread / process | An independent sequence of statements |
| Parent / child | The thread that executes a `fork`, and the threads that the `fork` creates |
| Blocking statement | A statement that may suspend the thread until something happens |
| Nonblocking call | A call that never suspends the thread; it reports success or failure immediately (`try_get`, `try_put`) |
| Time step / time slot | All activity at one value of simulation time |
| Race condition | The result depends on the order in which threads run within one time step |
| Deadlock | Two or more threads each wait for something only another waiting thread can provide, so none can ever continue |
| Mutual exclusion | Only one thread at a time may use a resource |
| Critical section | The code that uses the shared resource, between acquiring and releasing it |
| Handshake | Two threads signalling each other so that each knows the other has completed a step |

### Interview questions

**Q1. What is a time slot?**
All the simulation activity that occurs at one simulation time. It is processed in ordered regions (Active, Inactive, NBA, Observed, Reactive, Postponed), looping until no events remain, before time advances.

**Q2. In which region is a blocking assignment executed, and in which region is the left-hand side of a nonblocking assignment updated?**
A blocking assignment is executed in the Active region. For a nonblocking assignment, the right-hand side is evaluated in the Active region and the left-hand side is updated in the NBA region.

**Q3. What does `#0` do?**
It suspends the thread and reschedules it in the Inactive region of the same time slot, so it resumes after the other Active threads have run. It is sometimes used to "fix" a race, but it only hides the ordering problem; if another thread also uses `#0` the race returns. Proper synchronization (events, nonblocking triggers, mailboxes, clocking blocks) is preferred.

**Q4. What is a race condition?**
A situation in which the outcome of the simulation depends on the order in which the simulator executes threads that are ready at the same simulation time. Because that order is not defined by the standard, the same code may give different results on different simulators, with different options, or after an unrelated code change.
