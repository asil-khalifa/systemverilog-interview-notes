# Part 7: Module 7 Revision and Practice

## 7.1 Revision Summary

### The whole module on one page

| Construct | Purpose | Create | Produce | Consume | Blocks when |
|---|---|---|---|---|---|
| `event` | Notification | `event ev;` | `-> ev;` `->> ev;` | `@(ev);` `wait (ev.triggered);` | Waiting for a trigger |
| `mailbox` | Data transfer | `mbx = new();` or `new(N)` | `put` / `try_put` | `get` / `peek` / `try_get` / `try_peek` | `get`, `peek`: empty. `put`: bounded and full |
| `semaphore` | Resource sharing | `sem = new(N);` | `put(n)` | `get(n)` / `try_get(n)` | `get`: not enough keys |
| `fork` ... `join` | Parallel threads, wait for all | | | | Until all children finish |
| `fork` ... `join_any` | Wait for the first | | | | Until one child finishes |
| `fork` ... `join_none` | Do not wait | | | | Never |

### Rules to remember

**Processes**

- The simulator runs one thread at a time; a thread runs until it blocks.
- The order of threads that are ready at the same time is undefined. Code that depends on it has a race.
- A loop with no blocking statement hangs the simulation at the current time.

**Events**

- `-> ev` wakes only the threads already waiting. It is not remembered.
- `@(ev)` is edge-sensitive; `wait (ev.triggered)` is level-sensitive until the end of the time step.
- `->> ev` fires in the NBA region; neither `->` nor `->>` suspends the caller.
- The unsafe pair is `->` with `@` in the same time step.
- `wait (ev.triggered)` in a zero-time loop spins forever.
- Events are handles: `b = a` merges them; a thread already waiting on the old `b` never wakes; triggering `null` does nothing.
- `wait_order (a, b, c) else ...;` checks the order of events.

**Fork and join**

- Each statement in a `fork` is one thread; `begin` ... `end` groups statements into one thread.
- `join`: all. `join_any`: first. `join_none`: no wait, and the children start only when the parent blocks.
- Unfinished threads are never killed automatically.
- `disable fork` kills **all descendants of the calling process**. Guard it: `fork begin ... disable fork; end join`.
- `wait fork` waits for all immediate children of the calling process.
- Loop plus `join_none`: copy the loop variable into an `automatic` variable declared outside the child's `begin` ... `end`.
- Only `join_none` is legal in a function.

**Mailbox**

- A class: needs `new()`. `new()` or `new(0)` is unbounded; `new(N)` is bounded.
- `put`, `get`, `peek` are blocking tasks. `try_put`, `try_get`, `try_peek` are nonblocking functions returning positive, 0, or (typeless mailbox only) negative.
- `get` removes; `peek` copies.
- Use `mailbox #(T)`: type errors at compile time instead of run time.
- A mailbox of objects stores handles. Create a new object for every `put`.
- One mailbox, constructed once, shared by handle.

**Semaphore**

- A class: needs `new(keys)`; the default is 0 keys.
- `get(n)` blocks (task); `put(n)` never blocks (function); `try_get(n)` returns positive or 0.
- No ownership, no key query, no upper limit: a stray `put` adds a key.
- One `put` for every `get`, on every path.

**Timing, races, deadlocks**

- `#` waits for time, `@` for a change, `wait` for a level.
- Races: cured by nonblocking assignments, clocking blocks, `wait (ev.triggered)`, `->>`, mailboxes, semaphores. Not by `#0`.
- Deadlocks: cured by a fixed acquisition order, releasing on all paths, timeouts and a global watchdog.
- End a test on a positive condition, not when the generator finishes.

### The key comparisons

| Comparison | One-line answer |
|---|---|
| `join` / `join_any` / `join_none` | Parent waits for all / the first / none |
| `@(ev)` / `wait (ev.triggered)` | Edge / level within the time step |
| `->` / `->>` | Trigger now / trigger in the NBA region |
| `get` / `peek` | Remove / copy |
| `get` / `try_get` | Blocking task / nonblocking function |
| Bounded / unbounded | `put` can block / `put` never blocks |
| Typeless / parameterized mailbox | Run-time / compile-time type check |
| `disable fork` / `disable label` | Descendants of the caller / a named block wherever it runs |
| `wait fork` / `join` | All children of the process / the threads of one block |
| Mailbox / semaphore | Data / keys |
| Event / mailbox / semaphore | Notify / transfer / protect |
| Race / deadlock | Wrong order / no progress |

## 7.2 Interview Questions and Answers

The questions inside Parts 1 to 6 cover each topic directly. These are additional.

### Basic level

**Q1. Name the IPC mechanisms of SystemVerilog.**
Events, mailboxes and semaphores, together with `fork` ... `join`/`join_any`/`join_none`, `wait fork` and `disable fork` for creating and controlling threads.

**Q2. What is the difference between a thread created by `initial` and one created by `fork`?**
An `initial` block creates one static process per block at time 0, at module level. A `fork` creates dynamic processes at run time, anywhere procedural code can appear, including inside class methods.

**Q3. How many threads does `fork begin a(); b(); end c(); join` create?**
Two.

**Q4. Which form of fork does not block the parent?**
`join_none`.

**Q5. How do you declare and trigger an event?**
`event done;` and `-> done;`.

**Q6. What does `mbx.num()` return?**
The number of messages currently in the mailbox.

**Q7. How do you create a mailbox that can hold at most five transactions?**
`mailbox #(alu_txn) mbx = new(5);`

**Q8. What does `sem = new(2);` create?**
A semaphore with two keys.

**Q9. What happens when `get()` is called on an empty mailbox?**
The calling thread blocks until another thread puts a message.

**Q10. What is the return value of `try_get()` on an empty mailbox?**
0.

**Q11. Does an event carry data?**
No.

**Q12. Which IPC constructs must be constructed with `new()`?**
Mailbox and semaphore.

**Q13. What does `wait fork` do?**
It blocks until all child threads of the calling process have finished.

**Q14. What is mutual exclusion?**
A guarantee that only one thread at a time uses a shared resource.

### Intermediate level

**Q15. When do the threads of a `fork` ... `join_none` start executing?**
When the parent thread reaches a blocking statement or terminates, not at the `join_none` itself.

**Q16. Why is `automatic` needed for a variable used by threads forked in a loop?**
So that each iteration, and therefore each thread, gets its own variable. A static variable, or the loop variable itself, exists only once, and all threads would see its final value.

**Q17. What is the difference between `wait (ev.triggered)` and testing `if (ev.triggered)`?**
`wait` blocks until the event has been triggered in the current time step. `if` only tests whether it has been triggered so far in this time step and never blocks.

**Q18. A generator and a driver are connected by an unbounded mailbox, with no handshake. The generator creates 1000 transactions. When does the generator finish?**
At the simulation time it started, because `put` on an unbounded mailbox never blocks. All 1000 transactions sit in the mailbox while the driver works through them.

**Q19. What is wrong with ending the test when the generator has finished?**
The transactions may still be in the mailbox or in the DUT. The driver, monitor and scoreboard need time to process them. The test should wait until the scoreboard has checked the expected number, or for a drain time.

**Q20. How do you pass a mailbox to a class?**
As a handle: declare a mailbox property in the class and assign it from outside, or pass it as a constructor argument. The mailbox object itself is constructed once, by the owner of both ends.

**Q21. What is the difference between `peek()` followed by `get()`, and `get()` alone?**
The result for the consumer is the same message. The difference is in what the producer sees: between `peek` and `get` the message is still in the mailbox, so a bounded mailbox stays full and the producer stays blocked. This is used to hold the generator back until the driver has finished an item.

**Q22. Can two threads wait on the same event? On the same mailbox? On the same semaphore?**
Yes to all. One event trigger wakes all waiters. One mailbox message goes to one waiter. Returned semaphore keys go to as many waiters as they satisfy.

**Q23. What is the effect of `disable fork` in a thread that has no children?**
Nothing.

**Q24. How do you implement "wait for either event A or event B"?**
`@(a or b);`, or `fork @(a); @(b); join_any  disable fork;` inside a guard when the two branches do more than wait.

**Q25. Why is a parameterized mailbox preferred to `mailbox`?**
The element type is checked at compile time and documents what the connection carries. A typeless mailbox fails at run time when a message is retrieved into a variable of the wrong type.

**Q26. Is `sem.put()` allowed before any `get()`?**
Yes. It increases the key count. For a mutex this is a bug, since it creates a second key.

### Advanced and scenario-based

**Q27. A test passes on one simulator and hangs on another. Where do you look first?**
For races, especially an event that is triggered with `->` and waited for with `@` in the same time step. One simulator happens to run the waiter first; the other runs the trigger first and the waiter then waits forever. Also check for threads forked in a loop without an automatic copy, and for `initial` blocks that depend on each other's order at time 0.

**Q28. After a timeout was added to one test, the scoreboard stopped reporting anything from that point on. Why?**
The timeout uses `fork` ... `join_any` followed by `disable fork` without a guard. `disable fork` killed every descendant of the calling thread, including the monitor and scoreboard threads that had been started earlier from the same thread. Wrap the timeout in `fork begin ... end join`.

**Q29. A driver receives ten transactions that are all identical to the last one generated. Why?**
The generator constructs one transaction object outside its loop and puts the same handle ten times. All ten mailbox entries refer to one object, which holds the values of the last randomization. A new object must be created, or a copy put, for each transaction.

**Q30. A simulation ends at a small simulation time with no error message, but the test did not complete. What happened?**
All threads were blocked and no further events were scheduled, so the simulator stopped: a deadlock or a dead thread. Typical causes are a missed event trigger, a `get` on a mailbox that nobody writes (for example two separately constructed mailboxes), or a semaphore key never returned.

**Q31. Two sequences drive the same interface and occasionally the bus shows a mixture of the two transfers. The code uses a semaphore. What could still be wrong?**
The two users may each have constructed their own semaphore; one path may use the bus without taking the key; a stray `put()` may have added a second key; or the critical section may be too short (the key is returned before the transfer has really finished on the pins).

**Q32. How would you make a generator wait for the driver without using an event?**
Create the mailbox with a bound of 1 and have the driver `peek`, drive, and only then `get`. The generator's next `put` blocks until the `get`.

**Q33. What does this do: `fork forever @(posedge clk) count++; join_none` followed later by `wait fork;`?**
`wait fork` never returns, because the `forever` thread is a child of the same process and never ends.

**Q34. How can a thread stop one particular other thread without affecting anything else?**
Through a `process` handle: the target thread stores `process::self()` in a variable, and the controlling thread calls `kill()` on it. This is covered in Module 11.

**Q35. Why are mailboxes preferred over events plus shared variables for passing transactions?**
An event plus a variable holds one item and loses any item produced while the consumer is busy; it also exposes the event race. A mailbox queues every item in order and has blocking built in on both sides.

**Q36. In which scheduling region does a thread woken by `->>` run?**
The event fires in the NBA region; the woken thread is then executed in the next Active region of the same time slot.

**Q37. How does UVM relate to these constructs?**
UVM is written in SystemVerilog and builds on them. TLM ports and FIFOs (`uvm_tlm_fifo`, analysis ports) replace hand-connected mailboxes; the sequencer-driver handshake replaces the mailbox plus `drv_done` event; `uvm_event` and `uvm_barrier` extend events; objections replace the hand-written end-of-test condition; sequencer `lock`/`grab` replaces a semaphore. Phases are started with `fork` internally.

## 7.3 Output-Prediction Questions

Work out the output on paper before reading the answer. Each example is a complete module.

**P1.**

```systemverilog
module p1;
  initial begin
    fork
      #5  $display("A");
      #15 $display("B");
    join_any
    $display("C at %0t", $time);
    #20 $display("D at %0t", $time);
  end
endmodule
```

Answer: `A`, `C at 5`, `B`, `D at 25`. `join_any` releases the parent at 5. Thread B is not killed and prints at 15. The parent prints again at 5 + 20 = 25.

**P2.**

```systemverilog
module p2;
  initial begin
    $display("1");
    fork
      $display("2");
    join_none
    $display("3");
    #0 $display("4");
  end
endmodule
```

Answer: `1`, `3`, `2`, `4`. The child cannot start until the parent blocks, so `3` comes before `2`. At `#0` the parent moves to the Inactive region; the child, in the Active region, runs first.

**P3.**

```systemverilog
module p3;
  initial begin
    for (int i = 0; i < 3; i++)
      fork
        #(i) $display("i=%0d t=%0t", i, $time);
      join_none
  end
endmodule
```

Answer: `i=3 t=3` three times. The threads start after the loop has ended, when `i` is 3. Each waits 3 time units and prints 3.

**P4.**

```systemverilog
module p4;
  event e;
  initial begin
    -> e;
    @(e);
    $display("got it");
  end
  initial #10 $display("end");
endmodule
```

Answer: only `end`. The trigger is over before `@(e)` starts waiting, so the first block waits forever. With `wait (e.triggered);` in place of `@(e);` the output would be `got it` and then `end`.

**P5.**

```systemverilog
module p5;
  mailbox #(int) m = new(2);
  int v;
  initial begin
    $display("%s", m.try_put(1) ? "ok" : "full");
    $display("%s", m.try_put(2) ? "ok" : "full");
    $display("%s", m.try_put(3) ? "ok" : "full");
    m.get(v);
    m.peek(v);
    $display("%0d %0d", v, m.num());
  end
endmodule
```

Answer: `ok`, `ok`, `full`, `2 1`. The mailbox holds two messages. `get` removes 1. `peek` copies 2 without removing it, so one message remains.

**P6.**

```systemverilog
module p6;
  semaphore s = new(1);
  initial begin
    fork
      begin
        s.get();
        $display("[%0t] T1 in", $time);
        #10;
        $display("[%0t] T1 out", $time);
        s.put();
      end
      begin
        #1 s.get();
        $display("[%0t] T2 in", $time);
        #10 s.put();
      end
      begin
        #2;
        if (s.try_get()) $display("[%0t] T3 in", $time);
        else             $display("[%0t] T3 gave up", $time);
      end
    join
    $display("[%0t] done", $time);
  end
endmodule
```

Answer: `[0] T1 in`, `[2] T3 gave up`, `[10] T1 out`, `[10] T2 in`, `[20] done`. T2 blocks at time 1 and is granted the key when T1 returns it at 10. T3 does not block: `try_get` fails at time 2 and it moves on.

**P7.**

```systemverilog
module p7;
  initial begin
    fork
      begin #10 $display("A"); end
      begin #20 $display("B"); end
      begin #30 $display("C"); end
    join_any
    $display("first done at %0t", $time);
    #15 disable fork;
    #20 $display("end at %0t", $time);
  end
endmodule
```

Answer: `A`, `first done at 10`, `B`, `end at 45`. `disable fork` is executed at time 25. By then B has finished (at 20); only C is still running and is killed, so `C` is never printed.

**P8.**

```systemverilog
module p8;
  event e;
  initial begin
    ->> e;
    $display("1");
    @(e);
    $display("2 at %0t", $time);
  end
endmodule
```

Answer: `1`, `2 at 0`. The nonblocking trigger fires in the NBA region of time 0, after the thread has started waiting. With `-> e` the thread would hang after printing `1`.

**P9.**

```systemverilog
module p9;
  bit ready;
  initial begin
    ready = 1;
    #10 ready = 0;
    #10 ready = 1;
  end
  initial begin
    #5 wait (ready);
    $display("W %0t", $time);
  end
  initial begin
    #5 @(posedge ready);
    $display("E %0t", $time);
  end
endmodule
```

Answer: `W 5`, `E 20`. At time 5 `ready` is already 1: the level-sensitive `wait` passes at once, while the edge-sensitive `@` waits for the next rising edge, at time 20.

**P10.**

```systemverilog
module p10;
  mailbox #(int) m = new(1);
  initial begin
    for (int i = 1; i <= 3; i++) begin
      m.put(i);
      $display("put %0d at %0t", i, $time);
    end
  end
  initial begin
    int v;
    repeat (3) begin
      #10 m.get(v);
    end
  end
endmodule
```

Answer: `put 1 at 0`, `put 2 at 10`, `put 3 at 20`. The mailbox holds one message, so each further `put` waits for the consumer's `get`, which occurs every 10 time units.

## 7.4 Find-the-Error and Debugging Questions

### Compile-time and run-time errors

**E1.**

```systemverilog
mailbox #(alu_txn) gen2drv_mbx;
initial begin
  alu_txn txn = new();
  gen2drv_mbx.put(txn);
end
```

The mailbox was never constructed: a null-handle run-time error at `put`. Add `gen2drv_mbx = new();`.

**E2.**

```systemverilog
function void collect(mailbox #(alu_txn) mbx);
  alu_txn txn;
  mbx.get(txn);
endfunction
```

`get` is a blocking task and cannot be called from a function. Use `try_get` and test its return value, or make `collect` a task.

**E3.**

```systemverilog
function void start_all();
  fork
    drv.run();
    mon.run();
  join_any
endfunction
```

Only `fork` ... `join_none` is allowed inside a function. Use `join_none` or change the function into a task.

**E4.**

```systemverilog
event done;
initial @(posedge done) $display("done");
```

An event has no value and therefore no edges. Write `@(done)`.

**E5.**

```systemverilog
mailbox mbx = new();
string  s = "abc";
int     i;
initial begin
  mbx.put(s);
  mbx.get(i);
end
```

A string was put and an `int` is requested: a run-time type error from the typeless mailbox. Declare `mailbox #(string)` so that the mistake is found at compile time.

**E6.**

```systemverilog
semaphore sem = new();
initial begin
  sem.get();
  $display("in critical section");
  sem.put();
end
```

Not a compile error, but the thread hangs: `new()` creates zero keys. Write `new(1)`.

### Run-time bugs (the code compiles and runs)

**D1.**

```systemverilog
forever begin
  if (mbx.try_get(txn)) drive(txn);
end
```

When the mailbox is empty the loop repeats without blocking, and simulation time cannot advance. Use the blocking `mbx.get(txn);`, or add `@(posedge clk);` to the loop.

**D2.**

```systemverilog
forever begin
  wait (start.triggered);
  num_starts++;
end
```

After the first trigger, `start.triggered` stays true for the rest of the time step, so the loop spins forever. Use `@(start);`.

**D3.**

```systemverilog
foreach (drv[i])
  fork
    drv[i].run();
  join_none
```

All threads start after the loop, when `i` is past the last index: an out-of-range access (a null handle) instead of one thread per driver. Fix: `foreach (drv[i]) begin automatic int k = i; fork drv[k].run(); join_none end`.

**D4.**

```systemverilog
task send(alu_txn txn);
  bus_key.get();
  if (txn == null) begin
    $error("null transaction");
    return;
  end
  drive(txn);
  bus_key.put();
endtask
```

The error path returns while holding the key. Every later `get` blocks forever. Put the key back before `return`, or do the check before `get`.

**D5.**

```systemverilog
class alu_generator;
  mailbox #(alu_txn) gen2drv_mbx = new();
endclass
class alu_driver;
  mailbox #(alu_txn) gen2drv_mbx = new();
endclass
```

Each class constructs its own mailbox. The generator fills one, the driver waits on the other. Construct one mailbox in the environment and pass its handle to both.

**D6.**

```systemverilog
task run();
  fork
    mon.run();
  join_none
  fork
    wait_for_done();
    #5000 $error("timeout");
  join_any
  disable fork;
endtask
```

`disable fork` also kills `mon.run()`. Guard the timeout: `fork begin fork ... join_any  disable fork; end join`.

**D7.**

```systemverilog
// thread 1                          // thread 2
@(posedge clk);                      @(posedge clk);
-> sample_now;                       @(sample_now);
                                     sample();
```

Both threads wake at the same clock edge. If thread 1 runs first, thread 2 misses the trigger and samples one cycle late (at the next trigger). Use `wait (sample_now.triggered)` in thread 2 or `->> sample_now` in thread 1.

**D8.**

```systemverilog
task run();
  alu_txn txn = new();
  forever begin
    @(vif.mon_cb);
    if (vif.mon_cb.valid_out) begin
      txn.result = vif.mon_cb.result;
      mon2scb_mbx.put(txn);
    end
  end
endtask
```

The monitor reuses one object. Every message in `mon2scb_mbx` refers to it, so the scoreboard sees later samples overwrite earlier ones. Move `txn = new();` inside the `if`.

**D9.**

```systemverilog
fork
  gen.run();
  drv.run();      // forever loop
  mon.run();      // forever loop
join
$display("test finished");
```

`join` waits for threads that never end, so the message is never printed. Use `join_any` (the generator ends) followed by an end-of-test condition.

**D10.**

```systemverilog
initial begin
  fork
    @(rst_done);
  join_none
  rst_done = other_done;
  -> rst_done;
end
```

The child may already be waiting on the original event object when the handle is reassigned (and in any case the two orders give different behaviour). A thread attached to the old object never wakes. Connect event handles before forking the threads that wait on them.

## 7.5 Coding Exercises with Solutions

Try each exercise before reading the solution.

### Exercise 1: producer and consumer with a bounded mailbox

A producer sends the squares of 1 to 4 as fast as the mailbox allows. The mailbox holds one message. A consumer takes one value every 5 time units and prints it.

```systemverilog file=ex01_producer_consumer.sv
module ex01_producer_consumer;

  mailbox #(int) mbx = new(1);

  initial begin : producer
    for (int i = 1; i <= 4; i++)
      mbx.put(i * i);                       // blocks while the mailbox is full
  end

  initial begin : consumer
    int v;
    repeat (4) begin
      #5;
      mbx.get(v);
      $display("[%0t] consumer got %0d", $time, v);
    end
  end

endmodule
```

```output
[5] consumer got 1
[10] consumer got 4
[15] consumer got 9
[20] consumer got 16
```

The values arrive in the order they were sent. The producer needs no delay of its own: the bounded mailbox paces it.

### Exercise 2: a reusable wait-with-timeout task

Write a task that waits for an event for at most a given time and reports whether the event occurred. It must not disturb any other thread of the caller.

```systemverilog file=ex02_timeout.sv
module ex02_timeout;

  event resp;

  task automatic wait_resp(input time limit, output bit ok);
    ok = 0;
    fork                                    // guard thread
      begin
        fork
          begin
            @(resp);
            ok = 1;
          end
          #limit;
        join_any
        disable fork;                       // stops only the two threads above
      end
    join
  endtask

  initial begin
    bit ok;

    fork
      #30 -> resp;                          // the response arrives at time 30
    join_none

    wait_resp(50, ok);
    $display("[%0t] first wait : ok = %b", $time, ok);

    wait_resp(50, ok);
    $display("[%0t] second wait: ok = %b", $time, ok);
  end

endmodule
```

```output
[30] first wait : ok = 1
[80] second wait: ok = 0
```

The first call ends at time 30 when the event arrives. The second call starts at time 30, after that trigger, sees no further trigger, and gives up after 50 time units, at time 80.

### Exercise 3: ping-pong with two events

Two threads print `ping` and `pong` alternately, three times each, five time units apart. Stop both when the ping thread has finished.

```systemverilog file=ex03_ping_pong.sv
module ex03_ping_pong;

  event ping_e, pong_e;

  initial begin
    fork
      begin : ping_thread
        repeat (3) begin
          #5;
          $display("[%0t] ping", $time);
          -> ping_e;
          @(pong_e);
        end
      end

      begin : pong_thread
        forever begin
          @(ping_e);
          #5;
          $display("[%0t] pong", $time);
          -> pong_e;
        end
      end
    join_any
    disable fork;
    $display("[%0t] game over", $time);
  end

endmodule
```

```output
[5] ping
[10] pong
[15] ping
[20] pong
[25] ping
[30] pong
[30] game over
```

Each `@` is safe from the trigger race because the other thread always consumes time (`#5`) before triggering: the waiter is already waiting. `join_any` returns when the ping thread ends; `disable fork` stops the endless pong thread. No guard is needed here because this `initial` block has no other children.

### Exercise 4: empty a mailbox from a function

Write a function that removes and prints everything in a mailbox and returns the number of messages removed.

```systemverilog file=ex04_drain.sv
module ex04_drain;

  mailbox #(int) mbx = new();

  function automatic int drain();
    int v;
    int n = 0;
    while (mbx.try_get(v)) begin            // a function may only use the try_ methods
      $display("  drained %0d", v);
      n++;
    end
    return n;
  endfunction

  initial begin
    int n;
    for (int i = 1; i <= 3; i++) mbx.put(i * 100);
    n = drain();
    $display("drained %0d messages, %0d left", n, mbx.num());
  end

endmodule
```

```output
  drained 100
  drained 200
  drained 300
drained 3 messages, 0 left
```

### Exercise 5: limit the number of simultaneous jobs

Four jobs each need 10 time units. At most two may run at the same time. Job `k` asks to start at time `k + 1`.

```systemverilog file=ex05_job_pool.sv
module ex05_job_pool;

  semaphore pool = new(2);                  // two keys: two jobs at a time

  initial begin
    for (int i = 0; i < 4; i++) begin
      automatic int id = i;
      fork
        begin
          #(id + 1);
          pool.get();
          $display("[%0t] job %0d starts", $time, id);
          #10;
          $display("[%0t] job %0d ends", $time, id);
          pool.put();
        end
      join_none
    end
    wait fork;
    $display("[%0t] all jobs done", $time);
  end

endmodule
```

```output
[1] job 0 starts
[2] job 1 starts
[11] job 0 ends
[11] job 2 starts
[12] job 1 ends
[12] job 3 starts
[21] job 2 ends
[22] job 3 ends
[22] all jobs done
```

Jobs 2 and 3 ask for a key at times 3 and 4, find none, and wait in that order. Job 2 receives the key job 0 returns at 11; job 3 receives the key job 1 returns at 12.

### Exercise 6: lock-step generator and driver without an event

Using only a mailbox, make the generator's `put` of item N+1 complete exactly when the driver has finished item N. The driver needs 10 time units per item.

```systemverilog file=ex06_lock_step.sv
module ex06_lock_step;

  mailbox #(int) gen2drv_mbx = new(1);      // bound of 1

  initial begin : generator
    for (int i = 1; i <= 3; i++) begin
      gen2drv_mbx.put(i);
      $display("[%0t] GEN: put %0d accepted", $time, i);
    end
  end

  initial begin : driver
    int item;
    forever begin
      gen2drv_mbx.peek(item);               // look: the mailbox stays full
      #10;                                  // drive the item
      gen2drv_mbx.get(item);                // remove: the generator may continue
    end
  end

endmodule
```

```output
[0] GEN: put 1 accepted
[10] GEN: put 2 accepted
[20] GEN: put 3 accepted
```

If the driver used `get` first and then the delay, the mailbox would be empty while item 1 was being driven, and the output would be `put 1` at 0, `put 2` at 0 and `put 3` at 10: the generator would be one item ahead.

### Further practice (no solutions given)

1. Rewrite `tb_no_ipc` (Section 1.2) with a mailbox so that all four values are consumed. At what time is the last one read?
2. Write a task `wait_any(event a, event b, output int which)` that returns 1 or 2 according to the event that occurred first.
3. Build a module in which three threads each need the bus twice, protected by one semaphore, with request times chosen so that the output order is fully determined. Predict the output, then run it.
4. Implement your own mailbox class for `int` using a queue and `wait`, with `put`, `get`, `try_get` and `num`.
5. Create a deadlock with two bounded mailboxes and two threads, then remove it by changing one mailbox to unbounded.
6. Modify `tb_gen_drv_mailbox` so that the generator uses `wait (drv_done.triggered)` instead of `@(drv_done)`. Does it still work? What happens if the driver's `#10` is removed, and why?
7. Add a second driver to `tb_multi_process_sync` that takes transactions from the same `gen2drv_mbx`. Which driver gets which transaction, and what determines it?

## 7.6 Concepts You Must Understand Before Moving Forward

**Processes**

- [ ] I can explain how the simulator runs "parallel" threads one at a time, and what makes a thread block.
- [ ] I can explain why the order of threads at one simulation time is undefined and what a race is.

**Events**

- [ ] I can explain `->`, `->>`, `@(ev)` and `wait (ev.triggered)`, and draw the same-time-step race on a timeline.
- [ ] I know why `wait (ev.triggered)` must not be used in a zero-time loop.
- [ ] I can share an event between two classes and explain why the handles are connected before the threads are forked.
- [ ] I can write a `wait_order` with an `else` clause.

**Fork and join**

- [ ] I can state when the parent resumes for `join`, `join_any` and `join_none`, and when the children start.
- [ ] I can explain and fix the loop-variable bug.
- [ ] I can write a timeout with `join_any`, `disable fork` and the guard, and explain what the guard prevents.
- [ ] I know what `wait fork` waits for.

**Mailbox**

- [ ] I can list all eight methods and say which block and which are functions.
- [ ] I can explain bounded versus unbounded and typeless versus parameterized.
- [ ] I can explain why a new transaction object is needed for every `put`.
- [ ] I can write a generator and a driver connected by a mailbox, with a handshake.

**Semaphore**

- [ ] I can protect a shared resource with `get` and `put`.
- [ ] I know that `put` can add keys that were never taken, and why that matters.
- [ ] I can compare a semaphore with a mailbox and with an event.

**Timing, races, deadlocks**

- [ ] I can explain `#` versus `@` versus `wait` with an example.
- [ ] I can give three kinds of race and the cure for each.
- [ ] I can describe a deadlock, how it appears in a simulation, and how a watchdog protects against it.
- [ ] I can explain why a test should not end when the generator finishes.

## 7.7 What Comes Next

Module 8 covers interfaces, modports, virtual interfaces and clocking blocks. So far the driver has only pretended to drive (`#10`). With a virtual interface the driver class reaches the real DUT pins, and with a clocking block it does so without the testbench-versus-DUT race described in Section 6.4. Module 9 then assembles everything from Modules 4 to 8 into the complete layered testbench for the ALU, using exactly the mailbox, event and fork structures of this module.
