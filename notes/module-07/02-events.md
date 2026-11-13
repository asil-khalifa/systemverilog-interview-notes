# Part 2: Events

## 2.1 What an Event Is: Declaration, Triggering and Waiting

### In plain English

An event is a doorbell. One thread presses it; every thread that is standing at the door listening at that moment hears it and continues. The bell carries no message: it only says "now". And it does not keep ringing: a thread that arrives after the bell was pressed hears nothing and waits for the next press.

### Technical definition

An **event** (also called a **named event**) is a synchronization object declared with the keyword `event`. It has no value and no duration. Two operations are defined on it:

- **Triggering** it with `->` (or `->>`), which unblocks every process that is waiting for it at that instant.
- **Waiting** for it with the event control `@`, or with `wait (ev.triggered)`.

In SystemVerilog an event variable is a **handle** to the underlying synchronization object. It can be assigned, compared, passed as an argument and set to `null` (Section 2.4).

### Why it is needed

Threads often need to know that something has happened, without any data being exchanged:

- reset has finished, so the driver may start;
- the driver has finished one transaction, so the generator may create the next;
- the generator has produced its last transaction, so the test may start its end-of-test checks;
- the monitor has seen a complete packet, so the coverage collector should sample.

Polling a flag variable in a loop would work but wastes simulation effort and is easy to get wrong. An event lets a thread sleep until exactly the moment it is needed.

### Syntax

```systemverilog
event ev;                 // declaration: creates an event object, ready to use (no new())

-> ev;                    // trigger: wake every thread waiting on ev right now
->> ev;                   // nonblocking trigger: happens in the NBA region (Section 2.3)

@(ev);                    // wait for the next trigger of ev      (also written  @ev; )
@(ev1 or ev2);            // wait for whichever triggers first
wait (ev.triggered);      // wait unless ev has already triggered in this time step
```

### How it works internally

```text
   Thread A                      event ev                     Thread B
   --------                    ------------                   --------
   @(ev);  ------------------> [ waiting list: A ]
   (A is suspended)
                               [ waiting list: A ] <--------  -> ev;
                               every waiter is made ready     (B continues immediately;
                               waiting list is emptied         the trigger does not block)
   A resumes after B blocks

   Later:
                               [ waiting list: empty ] <----  -> ev;     nobody is waiting:
                                                                         the trigger is lost
   @(ev);  ------------------> [ waiting list: A ]         A now waits for the NEXT trigger
```

Three rules follow from this picture.

1. A trigger is an instant. It affects only the threads that are **already waiting**.
2. `-> ev` does not block the triggering thread. The woken threads run after the triggering thread itself blocks or ends.
3. One trigger wakes **all** waiting threads. The order in which they then run is not defined.

### Complete example

```systemverilog file=tb_event_basic.sv
module tb_event_basic;

  event ev;

  initial begin : waiter
    $display("[%0t] waiter : waiting for ev", $time);
    @(ev);
    $display("[%0t] waiter : ev received", $time);
    @(ev);
    $display("[%0t] waiter : ev received again", $time);
  end

  initial begin : trigger
    #10;
    $display("[%0t] trigger: -> ev", $time);
    -> ev;
    #10;
    $display("[%0t] trigger: -> ev", $time);
    -> ev;
  end

endmodule
```

```output
[0] waiter : waiting for ev
[10] trigger: -> ev
[10] waiter : ev received
[20] trigger: -> ev
[20] waiter : ev received again
```

**Line by line**

| Line | Explanation |
|---|---|
| `event ev;` | Declares the event. Unlike a mailbox or semaphore, no `new()` is needed. |
| `@(ev);` (first) | The waiter is suspended and placed on the waiting list of `ev`. This happens at time 0, long before the first trigger. |
| `#10; ... -> ev;` | At time 10 the trigger thread prints and then triggers. The waiter becomes ready. The trigger thread is not suspended by `->`; it continues to its own `#10`. |
| `ev received` | The waiter runs once the trigger thread has blocked. The time is still 10. |
| `@(ev);` (second) | The waiter waits again. The trigger at time 10 is over; this `@` waits for the **next** one, at time 20. |

The waiter's line at time 10 always comes after the trigger's line, because the trigger thread prints *before* it executes `->`, and the waiter cannot run before the trigger.

> **Common mistake:** Expecting an event to "remember" that it was triggered. It does not. `-> ev;` followed later by `@(ev);` waits for a second trigger. If you need a memory, use `wait (ev.triggered)` within the same time step, or a flag variable, or a mailbox or semaphore, which do store their state.

> **Verification application:** Events are used for phase-like notifications in a testbench: `reset_done`, `gen_done`, `drv_done`, `end_of_test`. In UVM the same idea appears as `uvm_event`, which adds a persistent "on" state and the ability to carry data.

### Interview questions

**Q1. What is an event in SystemVerilog?**
A synchronization object, declared with `event`, that one process triggers and other processes wait for. It carries no data and has no duration.

**Q2. How do you trigger an event and how do you wait for it?**
Trigger with `-> ev;` (or `->> ev;` for a nonblocking trigger). Wait with `@(ev);` or `wait (ev.triggered);`.

**Q3. Does `-> ev` block the process that executes it?**
No. The triggering process continues with its next statement. The waiting processes become ready and run when the triggering process blocks.

**Q4. If three processes are waiting on the same event and it is triggered once, how many wake up?**
All three. The order in which they execute is not defined.

**Q5. Does an event need to be constructed with `new()`?**
No. Declaring an event variable creates the event object. (Mailboxes and semaphores are classes and do need `new()`.)

## 2.2 wait(event.triggered) and the Trigger-versus-Wait Race

### The problem

`@(ev)` only sees triggers that occur **after** it has started waiting. If the trigger and the `@` are executed at the same simulation time by two different threads, the simulator may run either thread first:

```systemverilog
event ev;

initial begin : trigger
  #10 -> ev;
end

initial begin : waiter
  #10 @(ev);
  $display("[%0t] waiter: ev received", $time);     // printed, or not?
end
```

```text
   Possibility 1: the simulator runs "waiter" first at time 10

      time 10, Active region :  waiter  executes @(ev)   -> starts waiting
                                trigger executes -> ev   -> waiter is woken
                                waiter  prints                               OK

   Possibility 2: the simulator runs "trigger" first at time 10

      time 10, Active region :  trigger executes -> ev   -> nobody is waiting: lost
                                waiter  executes @(ev)   -> starts waiting ... forever
                                                                             HANGS
```

Both possibilities are legal. Which one you get depends on the simulator, its version, its options, and even on the order of the `initial` blocks in the file. This is a **race condition**, and it is one of the most common causes of "the test hangs on one simulator and passes on another".

### The solution: the triggered property

Every event has a built-in property `triggered`.

- `ev.triggered` is **true from the moment the event is triggered until the end of the current time step**, and false otherwise.
- `wait (ev.triggered);` is therefore a **level-sensitive** wait: if the event has already been triggered in this time step, it does not block; otherwise it blocks until the trigger.

```text
   time 10                                              time 11
   |<------------------ one time step ---------------->|
          -> ev
           |
   ev.triggered :  0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 | 0 0 0 0 ...
                         ^                    ^
                         |                    |
                 trigger happens      a wait (ev.triggered) executed anywhere
                                      in here passes immediately

   @(ev) passes only if it was already waiting at the instant marked "trigger happens".
```

With `wait (ev.triggered)` the race above disappears: whichever thread runs first, the waiter continues at time 10.

### Complete example

To make the output independent of the simulator, the example puts the trigger and the two kinds of wait in a known order inside one parent thread.

```systemverilog file=tb_event_triggered.sv
module tb_event_triggered;

  event ev;

  initial begin
    -> ev;                                      // the trigger happens FIRST, at time 0

    fork                                        // both waits start AFTER the trigger
      begin
        @(ev);
        $display("[%0t] thread 1: @(ev) passed", $time);
      end
      begin
        wait (ev.triggered);
        $display("[%0t] thread 2: wait (ev.triggered) passed", $time);
      end
    join_none

    #20;
    $display("[%0t] parent  : -> ev again", $time);
    -> ev;
  end

endmodule
```

```output
[0] thread 2: wait (ev.triggered) passed
[20] parent  : -> ev again
[20] thread 1: @(ev) passed
```

**Line by line**

| Line | Explanation |
|---|---|
| `-> ev;` | Triggered at time 0. Nobody is waiting yet. `ev.triggered` is now true for the rest of time 0. |
| `fork ... join_none` | Creates two child threads. With `join_none` they start running only when the parent blocks, which is at `#20`. The time is still 0. |
| Thread 1: `@(ev);` | The trigger is already in the past. Thread 1 waits for the next one. |
| Thread 2: `wait (ev.triggered);` | `ev.triggered` is still true at time 0, so thread 2 does not block and prints immediately. |
| `#20; ... -> ev;` | At time 20 the event is triggered again. Thread 1 has been waiting since time 0, so it wakes now. |

### @(ev) versus wait(ev.triggered)

| Property | `@(ev)` | `wait (ev.triggered)` |
|---|---|---|
| Sensitivity | Edge: the instant of the trigger | Level: true for the rest of the time step |
| Trigger happened earlier in the same time step | **Missed**; waits for the next trigger | **Seen**; does not block |
| Trigger happened in an earlier time step | Missed | Missed (the property was cleared when time advanced) |
| Race with a trigger in the same time step | Yes | No |
| Safe inside a loop that consumes no time | Yes, each `@` needs a new trigger | **No**: passes again and again in the same time step (infinite loop) |
| Typical use | Repeated notifications in a loop | One-shot notifications such as "reset done", "generator done" |

> **Interview trap:** "Is `wait (ev.triggered)` always better than `@(ev)`?" No. In a loop that does not advance time it is dangerous:
>
> `forever begin wait (ev.triggered); count++; end`
>
> After the first trigger, `ev.triggered` stays true for the whole time step, so the loop spins forever at that time and the simulation hangs. Inside loops use `@(ev)`, or make sure time advances in every iteration.

> **Common mistake:** Writing `@(ev.triggered)`. That waits for the *value* of the property to change, which is not what is wanted and reintroduces the race. The correct form is `wait (ev.triggered)`.

> **Key point:** `ev.triggered` does not make an event permanent. It only covers the remainder of the time step in which the trigger occurred. A waiter that arrives one time unit later has still missed it.

### Interview questions

**Q1. What is the difference between `@(ev)` and `wait (ev.triggered)`?**
`@(ev)` is edge-sensitive: it unblocks only if it was already waiting when the event was triggered. `wait (ev.triggered)` is level-sensitive within the time step: it unblocks immediately if the event has been triggered at any earlier point in the current time step, and otherwise waits for the trigger. The second form removes the race between a trigger and a wait that occur at the same simulation time.

**Q2. An event is triggered at time 10 and a process executes `@(ev)` at time 10. Does the process continue?**
It depends on which executes first, and that order is not defined. If the `@` executes first, the process continues at time 10. If the trigger executes first, the process waits for the next trigger. Using `wait (ev.triggered)` makes the result deterministic.

**Q3. An event is triggered at time 10 and a process executes `wait (ev.triggered)` at time 15. Does the process continue?**
No. The `triggered` property is cleared when simulation time advances beyond the time step of the trigger. The process waits for the next trigger.

**Q4. Why can `wait (ev.triggered)` cause a simulation to hang?**
If it is used in a loop that contains no other time-consuming statement, the condition remains true for the whole time step after the first trigger, so the loop iterates endlessly without letting time advance.

## 2.3 Nonblocking Event Trigger: ->>

### In plain English

`-> ev` rings the bell right now. `->> ev` says "ring the bell a moment later, after everybody who is running at this time has had the chance to reach the door". The thread that executes `->>` does not wait; it only schedules the ringing.

### Technical definition

The **nonblocking event trigger** `->> ev;` schedules the event to be triggered in the **NBA (nonblocking assignment) region** of the current time step, in the same way that `a <= b;` schedules an update of `a`. The statement itself completes immediately. An optional delay or event control may be given: `->> #5 ev;` triggers the event five time units later, again without blocking the thread that executed it.

### Why it is needed

It is the second way of removing the trigger-versus-wait race, applied on the triggering side. All threads that are ready at a given time run in the Active region. A thread that executes `@(ev)` in the Active region is waiting by the time the NBA region is reached, so a trigger scheduled there cannot be missed.

```text
   time 10
   Active region :   trigger thread :  ->> ev        (only scheduled, nothing happens yet)
                     waiter thread  :  @(ev)         (starts waiting)
                     -- the order of these two no longer matters --
   NBA region    :   ev is triggered  ->  waiter is woken
   Active region :   waiter runs (still time 10)
```

### Complete example 1: the race removed

```systemverilog file=tb_event_nonblocking.sv
module tb_event_nonblocking;

  event ev;

  initial begin : trigger
    #10;
    ->> ev;                 // takes effect in the NBA region of time 10
  end

  initial begin : waiter
    #10;
    @(ev);                  // starts waiting in the Active region of time 10
    $display("[%0t] waiter: ev received", $time);
  end

endmodule
```

```output
[10] waiter: ev received
```

This is the racy example of Section 2.2 with one character added. Whichever `initial` block the simulator runs first at time 10, the `@(ev)` has been executed before the NBA region, so the waiter always continues.

### Complete example 2: -> versus ->> in a single thread

```systemverilog file=tb_event_nb_single.sv
module tb_event_nb_single;

  event ev;

  initial begin
    ->> ev;
    $display("[%0t] 1. after ->> ev   : statement did not block", $time);
    @(ev);
    $display("[%0t] 2. @(ev) passed   : the trigger arrived in the NBA region", $time);

    ->> #15 ev;
    $display("[%0t] 3. after ->> #15 ev : statement did not block", $time);
    @(ev);
    $display("[%0t] 4. @(ev) passed", $time);
  end

endmodule
```

```output
[0] 1. after ->> ev   : statement did not block
[0] 2. @(ev) passed   : the trigger arrived in the NBA region
[0] 3. after ->> #15 ev : statement did not block
[15] 4. @(ev) passed
```

**Line by line**

| Line | Explanation |
|---|---|
| `->> ev;` | Schedules a trigger for the NBA region of time 0. The thread continues at once. |
| `@(ev);` (first) | The thread starts waiting. When the NBA region is reached the event fires and the thread resumes, still at time 0. If the first statement had been `-> ev;`, this `@` would have waited forever: a thread cannot catch its own blocking trigger. |
| `->> #15 ev;` | Schedules a trigger for time 15. The thread is **not** delayed: line 3 is printed at time 0. |
| `@(ev);` (second) | Waits until the scheduled trigger at time 15. |

### -> versus ->>

| Property | `-> ev` | `->> ev` |
|---|---|---|
| Name | Blocking trigger (immediate trigger) | Nonblocking trigger |
| When the event fires | Immediately, in the Active region | In the NBA region of the same time step (or after the given delay) |
| Does the statement suspend the thread | No | No |
| A thread that executes `@(ev)` later in the same Active region | Misses it | Catches it |
| Optional delay or event control | Not allowed | Allowed: `->> #5 ev;`, `->> @(posedge clk) ev;` |
| Analogy | Blocking assignment `=` | Nonblocking assignment `<=` |

The names are confusing: neither form blocks the thread that executes it. "Blocking" and "nonblocking" here follow the naming of the two assignment operators and describe *when the effect takes place*.

### Three ways to avoid the trigger-versus-wait race

| Method | Change made on | How it works |
|---|---|---|
| `wait (ev.triggered)` | The waiting side | The trigger is remembered until the end of the time step |
| `->> ev` | The triggering side | The trigger is postponed to the NBA region |
| Design the protocol so that the waiter is always waiting first | Both | For example the waiter starts at time 0 and the trigger can only occur after a clock edge |

> **Common mistake:** Using both `->>` and a waiter that is itself woken in the NBA region. If the waiter only reaches its `@(ev)` *after* an NBA update (for example it was waiting on a signal assigned with `<=`), it executes `@` after the trigger and still misses it. `->>` protects only waiters that run in the Active region.

### Interview questions

**Q1. What is the difference between `->` and `->>`?**
`->` triggers the event immediately. `->>` schedules the trigger for the nonblocking-assignment region of the current time step (or for a later time if a delay is given). With `->>`, a process that starts waiting with `@` in the same time step, even after the `->>` statement was executed, still receives the trigger.

**Q2. Does `->>` block the calling process?**
No. Neither `->` nor `->>` suspends the process that executes it.

**Q3. What does `->> #10 ev;` do?**
It schedules `ev` to be triggered ten time units from now and continues immediately. `#10 -> ev;` would instead suspend the process for ten time units and then trigger.

**Q4. A process executes `-> ev; @(ev);`. What happens? What if the first statement is `->> ev;`?**
With `->`, the process waits forever (unless another process triggers `ev`), because the trigger is already over when `@` starts waiting. With `->>`, the trigger occurs in the NBA region after the process has started waiting, so the process continues in the same time step.

## 2.4 Event Handles: Assignment, Merging, null and Comparison

### In plain English

In Verilog a named event was a fixed object. In SystemVerilog the name you declare is a **handle**: a reference to an event object. Handles can be copied. After `b = a;` the two names refer to the same bell, so pressing either name rings it and listening on either name hears it. This is what makes it possible to share one event between objects of different classes.

### Technical definition

- `event a;` creates a new event object and makes `a` refer to it.
- `event b = a;` or `b = a;` makes `b` refer to the object of `a`. The two events are said to be **merged** (aliased). Triggering either one unblocks processes waiting on either one.
- `a = null;` breaks the association. `a` then refers to no object.
- Event handles can be compared with `==`, `!=`, `===`, `!==`, and with `null`. Two handles are equal if they refer to the same object.
- An event can be an argument of a task or function, a class property, an element of an array, and the value returned by a function.

### Memory picture

```text
   event a, b, c;                 a ---> [ event object 1 ]
                                  b ---> [ event object 2 ]
                                  c ---> [ event object 3 ]

   b = a;                         a ---> [ event object 1 ] <--- b
                                         [ event object 2 ]   (unreachable through b;
                                                               threads already waiting on it
                                                               stay there forever)
   c = null;                      c ---> (nothing)
```

### Rules

| Operation | Behaviour |
|---|---|
| `b = a;` then `-> a;` | Wakes processes waiting on `a` **and** processes that started waiting on `b` after the assignment |
| A process is already blocked in `@(b)` when `b = a;` is executed | That process stays attached to the **old** object of `b`. It never unblocks, because nothing can trigger the old object through `b` any more |
| `-> c;` when `c` is `null` | No effect |
| `@(c);` or `wait (c.triggered);` when `c` is `null` | Undefined by the standard: it may block forever or not block at all. Never do this |
| `a == b` | 1 if both refer to the same event object |
| `if (c == null)` | Test for an unassigned event handle |

### Complete example

```systemverilog file=tb_event_handles.sv
module tb_event_handles;

  event a, b, c;

  initial begin
    $display("1. a == b : %b   (two separate event objects)", a == b);

    b = a;                                    // merge: b now refers to the object of a
    $display("2. a == b : %b   (after b = a)", a == b);

    fork
      begin
        @(b);
        $display("[%0t] 3. the waiter on b was woken by -> a", $time);
      end
    join_none

    #10 -> a;

    #10;
    c = null;
    $display("[%0t] 4. c == null : %b", $time, c == null);
    -> c;                                     // triggering a null event does nothing
    $display("[%0t] 5. -> c on a null event had no effect", $time);
  end

endmodule
```

```output
1. a == b : 0   (two separate event objects)
2. a == b : 1   (after b = a)
[10] 3. the waiter on b was woken by -> a
[20] 4. c == null : 1
[20] 5. -> c on a null event had no effect
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Each declared event has its own object, so the handles differ. |
| `b = a;` | Handle copy. No new object is created. |
| 2 | Both handles now refer to the same object. |
| `@(b);` | The child starts waiting when the parent blocks at `#10`. It waits on the object that `b` refers to **now**, which is the object of `a`. |
| `#10 -> a;` | Triggering through `a` wakes the waiter that used the name `b`. |
| `c = null;` and `-> c;` | A null event can be triggered without error, with no effect. |

### The merging hazard

```systemverilog
event a, b;

initial begin
  fork
    begin
      @(b);                          // (1) starts waiting on the ORIGINAL object of b
      $display("never printed");
    end
  join_none
  #1;
  b = a;                             // (2) b now refers to the object of a
  -> b;                              // (3) triggers the object of a, not the one in (1)
end
```

The child thread is attached to the object that `b` referred to at step (1). After step (2) no handle refers to that object, so it can never be triggered and the thread is stuck. **Assign shared event handles before starting the threads that wait on them.** In a testbench this means: connect the events in the environment's constructor or build step, and only then `fork` the `run()` tasks.

> **Interview trap:** "What happens to a process waiting on an event when that event variable is assigned another event?" It never unblocks. The assignment only affects event controls and waits that are executed *after* it.

### Interview questions

**Q1. Is an event variable a handle?**
Yes. In SystemVerilog an event variable refers to an underlying synchronization object. It can be assigned to another event variable, compared, passed as an argument and assigned `null`.

**Q2. What does `event b = a;` do?**
It makes `b` an alias of `a`: both refer to the same event object. Triggering either wakes the processes waiting on either.

**Q3. What happens if you trigger a null event? Wait on a null event?**
Triggering has no effect. Waiting on a null event is undefined by the standard and must be avoided.

**Q4. How can you tell whether two event variables refer to the same event?**
Compare them: `if (a == b)`.

**Q5. What is the difference between a Verilog named event and a SystemVerilog event?**
A Verilog named event is a static object that can only be triggered with `->` and waited for with `@`. A SystemVerilog event is a handle: it adds assignment and merging, `null`, comparison, passing to tasks and classes, the `triggered` property, the nonblocking trigger `->>` and `wait_order`.

## 2.5 Sharing Events Between Classes: Event-Based Communication

### The problem

A driver object must not start driving until reset has finished. The reset is generated by a different object. The two objects are instances of different classes, created separately; neither can see the local variables of the other. How does the driver wait for something that happens inside the reset agent?

### The solution

Because an event variable is a handle, two objects can each hold a handle to **the same** event object. There are three common ways to arrange this.

| Method | Code | Notes |
|---|---|---|
| Assign the handle after construction | `drv.reset_done = rst.reset_done;` | Simple. Must be done before `run()` starts |
| Pass the event to the constructor | `drv = new(reset_done);` with `function new(event reset_done);` | Cannot be forgotten: the object cannot be built without it |
| Reach through an object handle | `@(env.gen.gen_done);` | Convenient in the test or environment, which already hold handles to the components |

```text
   reset_agent object                         alu_driver object
   +--------------------+                     +--------------------+
   | event reset_done --+----+           +----+-- event reset_done |
   +--------------------+    |           |    +--------------------+
                             v           v
                        [ one shared event object ]
                             ^
   alu_monitor object        |
   +--------------------+    |
   | event reset_done --+----+
   +--------------------+
```

### Complete example

```systemverilog file=tb_event_classes.sv
module tb_event_classes;

  class reset_agent;
    event reset_done;

    task run();
      $display("[%0t] RST: asserting reset", $time);
      #25;
      $display("[%0t] RST: reset released", $time);
      -> reset_done;
    endtask
  endclass

  class alu_driver;
    event reset_done;                     // will refer to the reset agent's event

    task run();
      wait (reset_done.triggered);
      $display("[%0t] DRV: reset finished, start driving", $time);
    endtask
  endclass

  class alu_monitor;
    event reset_done;

    function new(event reset_done);       // alternative: receive the event at construction
      this.reset_done = reset_done;
    endfunction

    task run();
      wait (reset_done.triggered);
      $display("[%0t] MON: reset finished, start sampling", $time);
    endtask
  endclass

  reset_agent rst;
  alu_driver  drv;
  alu_monitor mon;

  initial begin
    rst = new();
    drv = new();
    drv.reset_done = rst.reset_done;      // method 1: assign the handle
    mon = new(rst.reset_done);            // method 2: pass it to the constructor

    fork                                  // only now start the threads
      rst.run();
      drv.run();
      mon.run();
    join
    $display("[%0t] TOP: all components finished", $time);
  end

endmodule
```

```output
[0] RST: asserting reset
[25] RST: reset released
[25] DRV: reset finished, start driving
[25] MON: reset finished, start sampling
[25] TOP: all components finished
```

One trigger wakes both waiters. The standard does not define which of the two runs first, so the `DRV` and `MON` lines may appear in the opposite order on your simulator. The `TOP` line is always last, because `join` waits for all three tasks.

**Line by line**

| Line | Explanation |
|---|---|
| `event reset_done;` in each class | Each object initially gets its own event object. |
| `drv.reset_done = rst.reset_done;` | The driver's handle now refers to the reset agent's event object. The driver's original event object is discarded. |
| `mon = new(rst.reset_done);` | The same result through a constructor argument. |
| `fork ... join` | The three `run()` tasks become three threads. They are started only after the handles are connected (see the merging hazard in Section 2.4). |
| `wait (reset_done.triggered);` | Level-sensitive wait. It is the safe choice for a one-shot notification: it works even if a component happens to reach this line in the same time step in which reset was released. |
| `-> reset_done;` | Executed by the reset agent at time 25; wakes the driver and the monitor. |

### What events cannot do

| Limitation | Use instead |
|---|---|
| An event carries no data | Mailbox |
| An event is not remembered across time steps | A flag variable, a semaphore key, or a mailbox message |
| An event does not count: two triggers before the waiter runs look like one | Mailbox, or a counter |
| An event gives no mutual exclusion | Semaphore |

> **Verification application:** The standard generator/driver handshake uses an event in the reverse direction to the data: the generator puts a transaction in the mailbox and then waits for `drv_done`; the driver triggers `drv_done` when it has finished driving the transaction. Part 4 shows the complete code.

### Interview questions

**Q1. How do you share an event between two classes?**
Declare an event property in both classes and make both handles refer to the same event object, either by assigning one to the other (`drv.done = gen.done;`), or by passing the event as a constructor or task argument. Then one object triggers it and the other waits on it.

**Q2. Why must the event handles be connected before the `run()` tasks are forked?**
A thread that is already waiting on an event stays attached to the object the handle referred to at that time. If the handle is reassigned afterwards, the thread waits on an object that nobody can trigger any more.

**Q3. Can an event pass data from one thread to another?**
No. It only signals that something occurred. Data is passed through a mailbox, or through a shared object whose handle both threads hold.

## 2.6 wait_order

### In plain English

`wait_order` waits for several events and checks that they occur in a given sequence. It is a small built-in protocol checker: "first a request, then a grant, then done; anything else is an error".

### Technical definition

`wait_order (ev1, ev2, ..., evN)` suspends the calling process until all the listed events have been triggered **in the listed order**. If an event is triggered out of order (a later event in the list fires while an earlier one is still awaited), the construct **fails**.

| Form | On success | On failure |
|---|---|---|
| `wait_order (a, b, c);` | The process continues | A run-time error is reported |
| `wait_order (a, b, c) else stmt;` | The process continues | `stmt` is executed, no error |
| `wait_order (a, b, c) pass_stmt; else fail_stmt;` | `pass_stmt` is executed | `fail_stmt` is executed |

### Rules

- The events must be triggered in order, from left to right, for the construct to succeed.
- An event that has already been matched may trigger again without causing a failure. What is not allowed is a *later* event of the list triggering before its turn.
- The failure is detected at the moment the out-of-order event is triggered. The process does not wait for the rest of the sequence.

### Complete example

```systemverilog file=tb_wait_order.sv
module tb_wait_order;

  event req, gnt, done;

  initial begin : stimulus
    #10 -> req;        // time 10
    #10 -> gnt;        // time 20
    #10 -> done;       // time 30 : req, gnt, done  -> correct order

    #10 -> gnt;        // time 40 : gnt before req  -> wrong order
    #10 -> req;        // time 50
    #10 -> done;       // time 60
  end

  initial begin : order_check
    wait_order (req, gnt, done)
      $display("[%0t] PASS: req -> gnt -> done", $time);
    else
      $display("[%0t] FAIL: events out of order", $time);

    #5;                // start the second check at time 35

    wait_order (req, gnt, done)
      $display("[%0t] PASS: req -> gnt -> done", $time);
    else
      $display("[%0t] FAIL: events out of order", $time);
  end

endmodule
```

```output
[30] PASS: req -> gnt -> done
[40] FAIL: events out of order
```

**Line by line**

| Line | Explanation |
|---|---|
| First `wait_order` | Starts at time 0. `req` at 10, `gnt` at 20 and `done` at 30 arrive in order. The pass statement runs at time 30. |
| `#5;` | The second check starts at time 35, clear of the triggers at time 30. |
| Second `wait_order` | It expects `req` first. At time 40 `gnt` is triggered instead. The sequence can no longer be satisfied, so the `else` statement runs at time 40. The later triggers at 50 and 60 are not examined. |

> **Common mistake:** Using `wait_order` without an `else` clause in a testbench that is supposed to keep running after a protocol error. Without `else`, a failure is a run-time error issued by the simulator, in the simulator's own format, which regression scripts may not recognise. Provide an `else` with your own `$error` message.

> **Verification application:** `wait_order` is occasionally used in a monitor or checker to confirm that the phases of a simple protocol occur in sequence. For anything involving clocks and signal values, concurrent assertions (Module 10) are the normal tool; `wait_order` only works on named events.

### Interview questions

**Q1. What does `wait_order` do?**
It blocks the process until a list of events has been triggered in the specified order. If the events occur out of order it fails: it reports a run-time error, or executes the `else` statement if one is given.

**Q2. Write the statement that waits for events `a`, `b`, `c` in order and prints a message if they occur out of order.**
`wait_order (a, b, c) else $display("out of order");`

**Q3. What is the difference between `wait_order (a, b, c);` and `@(a); @(b); @(c);`?**
The sequence of three `@` statements also waits for the events one after another, but it cannot detect a violation: if `b` triggers before `a`, it is simply missed, and the code then waits for another `b`. `wait_order` treats the early `b` as a failure and reports it immediately.

## 2.7 Events: Summary, Mistakes and Questions

### Summary table

| Item | Syntax | Remember |
|---|---|---|
| Declare | `event ev;` | No `new()`. It is a handle |
| Trigger now | `-> ev;` | Wakes current waiters only; does not block |
| Trigger in the NBA region | `->> ev;` | Removes the same-time-step race; a delay may be added |
| Wait, edge-sensitive | `@(ev);` | Must already be waiting when the trigger occurs |
| Wait, level-sensitive | `wait (ev.triggered);` | True until the end of the trigger's time step |
| Wait for one of several | `@(ev1 or ev2);` | Either event unblocks |
| Check order | `wait_order (a, b, c) else ...;` | Fails on an out-of-order trigger |
| Alias | `b = a;` | Both names refer to one event |
| Disconnect | `ev = null;` | Trigger has no effect; waiting is undefined |
| Compare | `a == b`, `ev == null` | Same object? |

### Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Trigger and `@` in the same time step from different threads | Hang on some simulators | `wait (ev.triggered)` or `->>` |
| `wait (ev.triggered)` in a zero-time loop | Simulation hangs at one time | Use `@(ev)` in loops |
| `@(ev.triggered)` | Waits for a change of the property, races | `wait (ev.triggered)` |
| Assuming an event is remembered | Waiter that arrives late hangs | Use a flag, mailbox or semaphore when state must persist |
| Reassigning an event handle while a thread waits on it | That thread never wakes | Connect handles before forking threads |
| Declaring separate events in two classes and never connecting them | The waiter waits on its own private event forever | Share the handle |
| Trying to pass data with an event | Not possible | Mailbox |

### Further interview questions

**Q1. Two processes trigger the same event at the same simulation time, and one process is waiting. How many times does the waiter wake up?**
Normally once. The first trigger makes the waiter ready, and when the second trigger occurs it is no longer on the waiting list, so the second trigger is lost. Only if the waiter is in a loop and the simulator happens to run it between the two triggers can it wake twice. The count therefore cannot be relied on: events do not count triggers. Use a mailbox or a counter when every occurrence matters.

**Q2. How would you wait for either of two events, and how for both?**
Either: `@(ev1 or ev2);`. Both, in any order: start two threads with `fork @(ev1); @(ev2); join`. Both, in a fixed order: `wait_order (ev1, ev2);`.

**Q3. Can an event be used in a sensitivity list such as `always @(ev)`?**
Yes. An `always @(ev)` block executes each time the event is triggered.

**Q4. Is `@(posedge ev)` legal?**
No. An event has no value, so it has no edges. Only `@(ev)` is allowed.

**Q5. What is the lifetime of the `triggered` state?**
From the instant of the trigger to the end of the current time step. It is cleared when simulation time advances.

**Q6. How would you give an event a "memory" so that a waiter arriving later still sees it?**
Pair it with a flag: the triggering thread sets `done = 1;` and triggers the event; the waiting thread executes `wait (done);`. Alternatively use a semaphore created with zero keys (the notifier puts a key, the waiter gets it) or a mailbox message. In UVM, `uvm_event` provides this with `wait_on()`.
