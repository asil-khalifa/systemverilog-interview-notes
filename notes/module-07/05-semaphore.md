# Part 5: Semaphore

## 5.1 What a Semaphore Is and Why It Is Required

### Start with the problem

Two drivers in a testbench are connected to the same bus. Each one, when it has a transfer to send, puts its data on the bus and holds it there for a while. Nothing stops both from doing so at the same time.

```systemverilog file=tb_bus_no_semaphore.sv
module tb_bus_no_semaphore;

  logic [7:0] bus;

  task automatic send(string name, logic [7:0] data, int unsigned hold);
    bus = data;
    $display("[%0t] %s drives %h", $time, name, data);
    #hold;
    $display("[%0t] %s finished: bus = %h, expected %h", $time, name, bus, data);
  endtask

  initial begin
    fork
      send("DRV_A", 8'hAA, 20);
      begin
        #5;
        send("DRV_B", 8'hBB, 20);
      end
    join
  end

endmodule
```

```output
[0] DRV_A drives aa
[5] DRV_B drives bb
[20] DRV_A finished: bus = bb, expected aa
[25] DRV_B finished: bus = bb, expected bb
```

Driver A's transfer was destroyed at time 5, when driver B overwrote the bus in the middle of it. Neither driver knows about the other. The bus is a **shared resource**, and access to it must be **mutually exclusive**: one user at a time. The piece of code that uses the resource (from "start driving" to "finished") is called a **critical section**.

Other shared resources in a testbench:

- one physical interface used by several sequences or agents;
- a register bus used both by the test and by an interrupt-handling thread;
- a shared memory model or a shared counter updated by several threads;
- a log file written by several threads;
- a limited pool of something (for example at most two outstanding requests).

### In plain English

A semaphore is a box of keys beside a locked room. To enter the room you must take a key from the box. If the box is empty you wait beside it. When you leave the room you put the key back, and the next person waiting takes it. With one key in the box, only one person can be in the room at a time. With three keys, up to three.

### Technical definition

A **semaphore** is a built-in SystemVerilog class that holds a count of **keys**.

- `get(n)` takes `n` keys. If fewer than `n` are available, the calling thread **blocks** until they are.
- `put(n)` returns `n` keys to the semaphore and may unblock waiting threads.
- A thread holding the key(s) has the right to use the resource the semaphore protects.

A semaphore created with one key is a **mutex** (mutual exclusion lock, also called a binary semaphore). A semaphore with several keys is a **counting semaphore**.

A semaphore is a class, so a semaphore variable is a handle that is `null` until `new()` is called, and several components share a semaphore by sharing its handle.

### How it works internally

```text
                 semaphore object
            +---------------------------+
            |  key count : 1            |   get(1): if count >= 1 -> count - 1, continue
            |  waiters   : (FIFO list)  |           else           -> wait in the queue
            +---------------------------+   put(1): count = count + 1, wake waiters that can
                                                    now be satisfied

   time   DRV_A                 key count        DRV_B
   ----   -----                 ---------        -----
    0     get()  -> granted        1 -> 0
    5                                            get()  -> no key: blocked
    20    put()                    0 -> 1
                                   1 -> 0        (woken) granted
    40                             0 -> 1        put()
```

The important design fact: **a semaphore contains only a number**. It does not know which thread holds a key, and the keys have no identity. This has consequences that are covered in Section 5.4.

### Interview questions

**Q1. What is a semaphore?**
A built-in class that holds a number of keys and is used to control access to a shared resource. A thread must obtain a key with `get()` before using the resource and return it with `put()` afterwards. If no key is available, `get()` blocks.

**Q2. Why is a semaphore required?**
When several threads use the same resource (a bus, an interface, a shared variable), their operations can overlap and corrupt each other. A semaphore makes access mutually exclusive, or limits it to a fixed number of simultaneous users.

**Q3. What is a critical section?**
The portion of code that accesses the shared resource and must therefore be executed by only one thread at a time. It lies between the `get()` and the `put()`.

**Q4. What is the difference between a binary and a counting semaphore?**
A binary semaphore (mutex) has one key, so only one thread can hold it. A counting semaphore has several keys and allows that many threads, or one thread taking several keys, to proceed at once.

## 5.2 Declaration and Methods: new, get, put, try_get

### Syntax

```systemverilog
semaphore sem;              // a handle, null until constructed

sem = new(1);               // create with 1 key   (a mutex)
sem = new(3);               // create with 3 keys
sem = new();                // create with 0 keys  (the default)

sem.get();                  // take 1 key; block if none is available
sem.get(2);                 // take 2 keys; block until 2 are available
sem.put();                  // return 1 key
sem.put(2);                 // return 2 keys

if (sem.try_get())  ...     // take 1 key if available; never blocks
if (sem.try_get(2)) ...     // take 2 keys if 2 are available; never blocks
```

### The methods

| Method | Kind | Blocks | What it does | Return value |
|---|---|---|---|---|
| `new(int keyCount = 0)` | Constructor | No | Creates the semaphore with `keyCount` keys | The handle |
| `get(int keyCount = 1)` | Task | Yes, until that many keys are available | Removes `keyCount` keys | None |
| `put(int keyCount = 1)` | Function | No | Adds `keyCount` keys; waiting threads may be released | None |
| `try_get(int keyCount = 1)` | Function | No | Removes `keyCount` keys if that many are available | Positive if the keys were taken, 0 otherwise |

Points to note:

- The default number of keys in `new()` is **0**. A semaphore created with `new()` and no argument blocks the first `get()`. For a mutex write `new(1)`.
- `put()` is a function: it never blocks and can be called from a function. (A mailbox's `put()` is a task, because it can block.)
- There is **no `try_put`**, because `put` cannot fail, and **no method to read the number of keys**.
- `get(n)` is all-or-nothing: it never takes some of the keys and waits for the rest.

### Complete example

```systemverilog file=tb_semaphore_keys.sv
module tb_semaphore_keys;

  semaphore sem;

  initial begin
    sem = new(3);                                             // 3 keys

    if (sem.try_get(2))  $display("1. got 2 keys              : 1 left");
    if (!sem.try_get(2)) $display("2. cannot get 2 keys       : only 1 left, none taken");
    if (sem.try_get(1))  $display("3. got the last key        : 0 left");
    if (!sem.try_get())  $display("4. cannot get a key        : 0 left");

    sem.put(3);
    $display("5. returned 3 keys         : 3 available");

    sem.put(2);
    $display("6. put 2 keys never taken  : 5 available (created with 3)");

    if (sem.try_get(5))  $display("7. got 5 keys at once      : 0 left");
  end

endmodule
```

```output
1. got 2 keys              : 1 left
2. cannot get 2 keys       : only 1 left, none taken
3. got the last key        : 0 left
4. cannot get a key        : 0 left
5. returned 3 keys         : 3 available
6. put 2 keys never taken  : 5 available (created with 3)
7. got 5 keys at once      : 0 left
```

**Line by line**

| Line | Explanation |
|---|---|
| `sem = new(3);` | The semaphore starts with three keys. |
| 1 | `try_get(2)` finds three keys, takes two, returns a positive value. |
| 2 | Only one key remains. `try_get(2)` takes nothing and returns 0. A blocking `get(2)` here would suspend the thread forever, because no other thread exists to return keys. |
| 3, 4 | The last key is taken; a further request fails. `try_get()` with no argument asks for one key. |
| 5 | Three keys are returned. |
| 6 | Two **more** keys are put, although this thread holds none. The semaphore accepts them: it now has five keys, more than it was created with. |
| 7 | Proof that five keys exist: a request for five succeeds. |

`try_get` is used throughout this example because the example has a single thread: a blocking `get` that could not be satisfied would never be released.

### Key-based synchronization: the standard pattern

```systemverilog
sem.get(1);          // acquire the key        : entering the critical section
// ... use the shared resource; this may take simulation time ...
sem.put(1);          // release the key        : leaving the critical section
```

Every thread that uses the resource must follow this pattern, with the same semaphore. The protection is a convention: nothing in the language stops a thread from using the resource without taking the key.

### Interview questions

**Q1. What are the semaphore methods?**
`new()`, `get()`, `put()` and `try_get()`.

**Q2. What is the default number of keys?**
Zero for `new()` without an argument. The default number of keys requested or returned by `get()`, `put()` and `try_get()` is one.

**Q3. What is the difference between `get()` and `try_get()`?**
`get()` is a blocking task: it waits until the requested keys are available. `try_get()` is a function that never blocks: it takes the keys and returns a positive value if they are available, and returns 0 otherwise.

**Q4. Can `put()` block?**
No. It is a function and always completes immediately.

**Q5. A semaphore has one key and a thread calls `get(2)`. What happens?**
The thread blocks until two keys are available. It does not take the single key in the meantime. If nobody ever puts another key, it blocks forever.

**Q6. Is there a way to ask a semaphore how many keys it has?**
No. The only way to test availability is `try_get()`, which also takes the keys if they are there.

## 5.3 Resource Sharing: Two Drivers on One Bus

### The design

The two drivers of Section 5.1 now share a semaphore with one key. A driver must hold the key for the whole time it is using the bus.

```text
        bus_driver "DRV_A"                         bus_driver "DRV_B"
        +----------------+                         +----------------+
        | bus_key -------+----> [ semaphore ] <----+------- bus_key |
        +----------------+       1 key             +----------------+
                |                                          |
                +---------------> [  bus  ] <--------------+
                      only the holder of the key drives
```

### Complete example

```systemverilog file=tb_semaphore_bus.sv
module tb_semaphore_bus;

  logic [7:0] bus;

  class bus_driver;
    string    name;
    semaphore bus_key;                           // handle to the shared semaphore

    function new(string name, semaphore bus_key);
      this.name    = name;
      this.bus_key = bus_key;
    endfunction

    task send(logic [7:0] data, int unsigned hold);
      $display("[%0t] %s requests the bus", $time, name);
      bus_key.get(1);                            // blocks while the other driver has it
      $display("[%0t] %s granted", $time, name);
      bus = data;                                // ---- critical section starts ----
      #hold;
      $display("[%0t] %s releasing, bus = %h", $time, name, bus);
      bus_key.put(1);                            // ---- critical section ends ------
    endtask
  endclass

  semaphore  bus_key;
  bus_driver drv_a, drv_b;

  initial begin
    bus_key = new(1);                            // ONE semaphore with ONE key
    drv_a   = new("DRV_A", bus_key);
    drv_b   = new("DRV_B", bus_key);

    fork
      begin
        drv_a.send(8'hAA, 20);
        #3;
        drv_a.send(8'hAA, 20);
      end
      begin
        #5;
        drv_b.send(8'hBB, 20);
        #7;
        drv_b.send(8'hBB, 20);
      end
    join
    $display("[%0t] TOP: all transfers complete", $time);
  end

endmodule
```

```output
[0] DRV_A requests the bus
[0] DRV_A granted
[5] DRV_B requests the bus
[20] DRV_A releasing, bus = aa
[20] DRV_B granted
[23] DRV_A requests the bus
[40] DRV_B releasing, bus = bb
[40] DRV_A granted
[47] DRV_B requests the bus
[60] DRV_A releasing, bus = aa
[60] DRV_B granted
[80] DRV_B releasing, bus = bb
[80] TOP: all transfers complete
```

### Execution flow

| Time | DRV_A | DRV_B | Keys | Bus owner |
|---|---|---|---|---|
| 0 | Requests, key available: granted | | 1 → 0 | A |
| 5 | Driving | Requests, no key: **blocked** | 0 | A |
| 20 | Prints "releasing", `put` | Woken by the `put`: granted | 0 → 1 → 0 | B |
| 23 | Requests, no key: **blocked** | Driving | 0 | B |
| 40 | Woken: granted | Prints "releasing", `put` | 0 → 1 → 0 | A |
| 47 | Driving | Requests, no key: **blocked** | 0 | A |
| 60 | Prints "releasing", `put` | Woken: granted | 0 → 1 → 0 | B |
| 80 | | Prints "releasing", `put` | 0 → 1 | none |

Each "releasing" line shows the bus still holding the value its owner wrote: no transfer was disturbed. Compare with Section 5.1, where driver A found `bb` on the bus.

### Line by line

| Code | Explanation |
|---|---|
| `semaphore bus_key;` in the class | A handle. The class does not create a semaphore. |
| `function new(string name, semaphore bus_key);` | The shared semaphore is passed in at construction. |
| `bus_key = new(1);` at the top | The one semaphore, with one key. If each driver constructed its own, each would have its own key and there would be no exclusion. |
| `bus_key.get(1);` | Blocks until the key is available. At time 5 this is where DRV_B stops. |
| `bus = data; #hold;` | The critical section. It consumes time, which is exactly why protection is needed. |
| `$display(... "releasing" ...)` before `bus_key.put(1);` | The message is printed before the key is returned, so it always appears before the other driver's "granted" message. |
| `bus_key.put(1);` | Returns the key. The waiting driver becomes ready and runs when the current thread blocks or ends. |
| `fork ... join` | Each driver's sequence of two transfers is one thread. `join` waits for both. |

> **Verification application:** In a real testbench the `get`/`put` pair is placed inside the driver's or the bus-functional model's transfer task, so that every user of the interface is protected automatically: `task write(...); bus_key.get(); ...drive...; bus_key.put(); endtask`. UVM offers the same service for sequences through `lock()`/`unlock()` and `grab()`/`ungrab()` on a sequencer.

### Interview questions

**Q1. Two drivers share one interface. How do you prevent them from driving at the same time?**
Create one semaphore with one key and give both drivers its handle. Each driver calls `get()` before driving and `put()` when its transfer is complete. While one holds the key the other blocks in `get()`.

**Q2. Where should the semaphore be constructed?**
Once, in the component that owns both users (the environment or agent), and its handle passed to each user. Constructing one per driver gives each its own key and provides no protection.

**Q3. In what order are threads that are waiting for a key served?**
In the order in which they started waiting: the semaphore's waiting queue is first-in, first-out.

## 5.4 Semaphore Pitfalls

### 1. Keys can be put that were never taken

`put()` simply adds to the count. Example 5.2 ended with five keys in a semaphore created with three. For a mutex this is serious:

```systemverilog
bus_key = new(1);
...
bus_key.put();        // a stray put (for example an error path "releasing" without a get)
// The semaphore now has 2 keys. Two drivers can hold the "mutex" at the same time.
```

No error or warning is given. The symptom is intermittent corruption of the shared resource long after the stray `put`.

### 2. A key that is never returned

If a thread takes the key and leaves the critical section without `put()`, every other user blocks forever.

```systemverilog
task send(alu_txn txn);
  bus_key.get();
  if (txn == null) return;          // BUG: returns while holding the key
  drive(txn);
  bus_key.put();
endtask
```

The same happens if the thread holding the key is killed by `disable fork` in the middle of the critical section. Every path out of the critical section must return the key.

### 3. No ownership

The semaphore does not record who holds a key. Any thread can call `put()`, including one that never called `get()`. A thread that calls `get()` twice on a mutex blocks on itself forever (the semaphore is not "re-entrant").

### 4. Asking for more keys than can ever exist

`sem = new(2); sem.get(3);` blocks forever unless some thread puts an extra key.

### 5. Several keys and waiting order

When threads request different numbers of keys, the order in which they are served is delicate. Suppose thread X is waiting for two keys, thread Y arrives later and waits for one key, and then one key is put. A strict first-in, first-out queue keeps Y waiting behind X; an implementation that serves any request it can satisfy lets Y through. The standard states that the waiting queue is FIFO, but simulators have differed in this corner. Do not write code whose correctness depends on it. If all users request one key, the question does not arise.

### 6. A semaphore with zero keys used as a signal

```systemverilog
semaphore done = new(0);      // no keys

// notifier                         // waiter
done.put();                         done.get();     // passes if the put has happened
                                                    // at ANY earlier time
```

Unlike an event, the key is **remembered**: the waiter does not miss the notification if it arrives late, and several notifications are counted. This is a legitimate use when a persistent "it has happened" signal is needed.

### Summary of pitfalls

| Pitfall | Symptom | Prevention |
|---|---|---|
| `new()` instead of `new(1)` | First `get()` blocks forever | Always give the key count |
| Extra `put()` | Mutual exclusion silently lost | Exactly one `put` for every `get` |
| Missing `put()` on some path | Other threads hang | Release on every exit path |
| `get()` twice by the same thread | That thread deadlocks | Do not nest acquisitions of the same mutex |
| Thread killed while holding a key | Other threads hang | Do not `disable` threads inside critical sections |
| One semaphore per user | No protection | One shared semaphore |
| Polling with `try_get()` in a zero-time loop | Simulation hangs | Blocking `get()`, or a delay in the loop |

### Interview questions

**Q1. A semaphore is created with one key. A thread calls `put()` without calling `get()`. What happens?**
The semaphore now has two keys. No error is reported. Two threads can then acquire the "mutex" simultaneously, so mutual exclusion is broken.

**Q2. Does a semaphore know which process holds its key?**
No. It only keeps a count. Any process may put keys, whether or not it took any.

**Q3. What happens if a thread forgets to call `put()`?**
The key is never returned, and every thread that subsequently calls `get()` blocks forever: a deadlock.

**Q4. How can a semaphore be used instead of an event?**
Create it with zero keys. The notifying thread calls `put()`, and the waiting thread calls `get()`. Because the key persists, the waiter is released even if it starts waiting after the notification, which an event cannot do.

## 5.5 Semaphore versus Mailbox, and Summary

### Difference between semaphore and mailbox

| Property | Semaphore | Mailbox |
|---|---|---|
| Purpose | Control access to a shared resource | Transfer data between threads |
| What it holds | A count of identical keys | A FIFO queue of messages |
| Carries data | No | Yes |
| `get` | Takes keys; blocks if not enough | Takes the oldest message; blocks if empty |
| `put` | Returns keys; **never blocks** (function) | Adds a message; blocks if a bounded mailbox is full (task) |
| `peek` | Not available | Available |
| Nonblocking methods | `try_get` only | `try_get`, `try_put`, `try_peek` |
| Query | None | `num()` |
| Upper limit | None: keys can always be added | Optional bound |
| Typical relationship between users | The same thread does `get` then `put` | One thread does `put`, another does `get` |
| Type parameter | None | `mailbox #(T)` |
| Typical use | Two sequences sharing one driver or interface | Generator → driver, monitor → scoreboard |

Both are built-in classes, both must be constructed with `new()`, both are shared by sharing the handle, and both keep waiting threads in arrival order.

> **Key point:** A semaphore behaves like a mailbox whose messages have no content. Indeed, a mutex can be imitated with a bounded mailbox of size 1 (`put` to lock, `get` to unlock), but a semaphore states the intention directly.

### Common mistakes

| Mistake | Fix |
|---|---|
| Using a semaphore to pass data | Use a mailbox |
| Using a mailbox or an event to protect a resource | Use a semaphore |
| Holding the key longer than necessary (for example across a wait for a response that needs the other user) | Keep the critical section minimal |
| Acquiring two semaphores in different orders in different threads | Always acquire in the same order (Section 6.5) |

### Further interview questions

**Q1. What is the difference between a semaphore and a mailbox?**
A semaphore holds a count of keys and is used for mutual exclusion or for limiting the number of simultaneous users; it carries no data, and its `put` never blocks. A mailbox is a FIFO of messages used to pass data from one thread to another; its `get` blocks when empty and its `put` blocks when a bounded mailbox is full.

**Q2. How would you allow at most two of five threads to be active at once?**
Create a semaphore with two keys. Each thread calls `get()` before the activity and `put()` afterwards. At most two can hold a key at any time.

**Q3. Can a semaphore be used inside a function?**
`put()` and `try_get()` can, because they are functions. `get()` is a task and cannot be called from a function.

**Q4. A thread needs two resources, each protected by its own semaphore. What must you be careful about?**
Deadlock. If one thread takes semaphore A then B, and another takes B then A, each can end up holding one and waiting for the other. All threads must acquire the semaphores in the same order.

**Q5. Is a SystemVerilog semaphore a mutex?**
With one key and disciplined use it serves as a mutex, but it is weaker than a true mutex: it has no owner, so it cannot detect a release by a thread that does not hold the key, and it can be given extra keys.
