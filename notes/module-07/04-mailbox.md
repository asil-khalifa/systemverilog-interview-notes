# Part 4: Mailbox

## 4.1 What a Mailbox Is and Why It Is Required

### Start with the problem

The generator creates transactions. The driver turns each transaction into pin activity. They are two objects of two classes, running as two threads, and they work at different speeds: the generator can create a transaction in zero simulation time, while the driver needs at least one clock cycle to drive it.

The generator therefore needs to **hand over** each transaction, and the hand-over must cope with the difference in speed:

- If the driver is busy, the transaction must be **kept** until the driver is ready. Nothing may be lost or overwritten (remember `tb_no_ipc` in Section 1.2).
- If the driver is ready and no transaction exists yet, the driver must **wait** without wasting simulation effort.
- Transactions must arrive **in the order** they were sent.
- Optionally, the generator must be **slowed down** so that it does not create thousands of transactions the driver cannot keep up with.

A mailbox provides exactly this.

### In plain English

A mailbox is a letterbox between two people. One person drops letters in. The other takes letters out, oldest first. If the box is empty, the person collecting waits beside it until a letter arrives. If the box has a limited size and is full, the person posting waits until there is room.

### Technical definition

A **mailbox** is a built-in SystemVerilog class that implements a thread-safe **FIFO (first-in, first-out) queue of messages** with built-in blocking:

- `put()` adds a message at the tail. On a full bounded mailbox it blocks.
- `get()` removes the message at the head. On an empty mailbox it blocks.
- A message can be a value of any type: an `int`, a struct, or, most commonly, a **class handle** such as an `alu_txn`.

Because it is a class, a mailbox variable is a **handle**. It is `null` until the mailbox is constructed with `new()`, and several components can hold handles to the same mailbox object, which is how they are connected.

### How it works internally

```text
                          mailbox object
                 +---------------------------------+
     put(msg) -> | tail                       head | -> get(msg)
                 |   [ m4 ] [ m3 ] [ m2 ] [ m1 ]   |
                 +---------------------------------+
                 |  bound      : 0 (unbounded) or N                        |
                 |  put waiters: threads blocked because the box is full   |
                 |  get waiters: threads blocked because the box is empty  |
                 +---------------------------------+

     generator object                                   driver object
     +------------------+                               +------------------+
     | gen2drv_mbx  ----+------> [ same mailbox ] <-----+---- gen2drv_mbx  |
     +------------------+                               +------------------+
```

When a `get()` finds the mailbox empty, the calling thread is suspended and added to the list of get waiters. A later `put()` stores the message and makes the first waiter ready. The same happens in the other direction for a full bounded mailbox.

### Mailbox versus a shared queue

| Property | Queue (`alu_txn q[$]`) | Mailbox (`mailbox #(alu_txn)`) |
|---|---|---|
| Stores many items in FIFO order | Yes | Yes |
| Reader blocks when empty | No. You must write `wait (q.size() > 0);` yourself | Yes, built into `get()` and `peek()` |
| Writer blocks when full | No. No size limit | Yes, for a bounded mailbox |
| Safe with several readers and writers | You must add your own protection | Yes |
| Access to the middle, sorting, searching | Yes | No, only head and tail |
| Passed between components as | A `ref` argument or a shared object | A handle |
| Typical use | Storage inside one component (scoreboard expected list) | Connection **between** components |

### Interview questions

**Q1. What is a mailbox?**
A built-in class that provides a FIFO message queue for passing data between threads. `put()` adds a message and `get()` removes one; `get()` blocks while the mailbox is empty and `put()` blocks while a bounded mailbox is full.

**Q2. Why is a mailbox needed between the generator and the driver?**
They are separate threads that run at different rates. The mailbox stores transactions in order until the driver takes them, makes the driver wait when none is available, and, if bounded, makes the generator wait when the driver is behind. A shared variable would lose data and a plain queue has no blocking.

**Q3. Is a mailbox a data type or a class?**
A class. A mailbox variable is a handle that is `null` until `new()` is called.

**Q4. What is the difference between a mailbox and a queue?**
Both hold items in order. A mailbox adds blocking `get`/`put` and is designed for communication between threads; it gives access only to the head and tail. A queue is an ordinary data structure with full access and methods for inserting, deleting and searching, but with no synchronization.

## 4.2 Declaring and Creating a Mailbox: Bounded and Unbounded

### Syntax

```systemverilog
mailbox            mbx_any;            // typeless mailbox handle (can hold any type)
mailbox #(int)     mbx_int;            // parameterized mailbox of int
mailbox #(alu_txn) gen2drv_mbx;        // parameterized mailbox of transaction handles

mbx_int     = new();                   // unbounded: can hold any number of messages
mbx_int     = new(0);                  // the same: a bound of 0 means unbounded
gen2drv_mbx = new(4);                  // bounded: holds at most 4 messages

mailbox #(int) m = new(2);             // declaration and construction together

typedef mailbox #(alu_txn) alu_txn_mbx_t;   // a short name for the type
alu_txn_mbx_t mon2scb_mbx = new();
```

### The constructor

`function new(int bound = 0);`

| Argument | Result |
|---|---|
| Omitted, or 0 | **Unbounded** mailbox. `put()` never blocks |
| A positive number N | **Bounded** mailbox with room for N messages. `put()` blocks while N messages are stored |
| A negative number | Not allowed |

### Bounded versus unbounded

| Property | Unbounded `new()` | Bounded `new(N)` |
|---|---|---|
| Capacity | Limited only by memory | N messages |
| `put()` | Never blocks | Blocks while full |
| `try_put()` | Always succeeds | Fails (returns 0) while full |
| `get()`, `peek()` | Block while empty | Block while empty |
| Flow control of the sender | None: the sender can run arbitrarily far ahead | Built in: the sender is throttled to the receiver's speed |
| Risk | A fast generator fills memory with thousands of pending transactions; stimulus is decided long before it is used | A deadlock if both sides wait on full/empty mailboxes in a cycle |
| Typical use | Monitor → scoreboard (the monitor must never be held up) | Generator → driver when the generator should stay close to the driver |

> **Common mistake:** Declaring a mailbox and using it without `new()`:
> `mailbox #(alu_txn) gen2drv_mbx;  gen2drv_mbx.put(txn);`
> The handle is `null`, and the simulation stops with a null-handle error. The second version of this mistake is constructing **two** mailboxes, one in the generator and one in the driver. Each component then talks to its own private mailbox and nothing ever arrives. One mailbox must be constructed (normally in the environment) and its handle given to both components.

### Interview questions

**Q1. How do you create a bounded mailbox and an unbounded mailbox?**
`mbx = new(n);` creates a bounded mailbox holding at most `n` messages. `mbx = new();` or `new(0)` creates an unbounded mailbox.

**Q2. What is the default size of a mailbox?**
Unbounded (bound 0).

**Q3. What happens when `put()` is called on a full bounded mailbox?**
The calling thread blocks until another thread removes a message with `get()` or `try_get()`.

**Q4. Can `put()` on an unbounded mailbox ever block?**
No.

## 4.3 Mailbox Methods

### The complete set

| Method | Kind | Blocks | What it does | Return value |
|---|---|---|---|---|
| `new(int bound = 0)` | Constructor | No | Creates the mailbox | The handle |
| `num()` | Function | No | Number of messages currently stored | `int` |
| `put(msg)` | Task | Yes, while full (bounded only) | Stores `msg` at the tail | None |
| `try_put(msg)` | Function | No | Stores `msg` if there is room | Positive if stored, 0 if full |
| `get(ref msg)` | Task | Yes, while empty | Removes the head message and copies it into `msg` | None |
| `try_get(ref msg)` | Function | No | Removes the head message if there is one | Positive if a message was taken, 0 if empty, negative on a type mismatch |
| `peek(ref msg)` | Task | Yes, while empty | **Copies** the head message into `msg` **without removing it** | None |
| `try_peek(ref msg)` | Function | No | Copies the head message if there is one, without removing it | Positive if copied, 0 if empty, negative on a type mismatch |

Three patterns organise this table:

1. **`put` adds, `get` removes, `peek` looks.**
2. **The plain methods are tasks and may block. The `try_` methods are functions, never block, and report what happened.**
3. Because the `try_` methods are functions, they are the only ones that can be called from a **function** (for example from a scoreboard's `check()` function or from a `final` block).

### get versus peek

```text
   mailbox before :   tail [ 30 ] [ 20 ] [ 10 ] head

   peek(v)  ->  v = 10      mailbox after :  tail [ 30 ] [ 20 ] [ 10 ] head     (unchanged)
   get(v)   ->  v = 10      mailbox after :  tail [ 30 ] [ 20 ]        head     (10 removed)
```

| Property | `get()` | `peek()` |
|---|---|---|
| Returns the head message | Yes | Yes |
| Removes it from the mailbox | Yes | No |
| Blocks while empty | Yes | Yes |
| `num()` afterwards | One less | Unchanged |
| A second call returns | The next message | The same message again |
| Typical use | Normal consumption | Look at an item before deciding to take it; keep a bounded mailbox full while the item is being processed (Section 4.8) |

### Complete example

```systemverilog file=tb_mailbox_methods.sv
module tb_mailbox_methods;

  mailbox #(int) mbx;
  int            v;

  initial begin
    mbx = new();                               // unbounded

    mbx.put(10);
    mbx.put(20);
    mbx.put(30);
    $display("1. after three puts : num = %0d", mbx.num());

    mbx.peek(v);
    $display("2. peek    -> %0d    : num = %0d  (message stays)", v, mbx.num());

    mbx.get(v);
    $display("3. get     -> %0d    : num = %0d  (message removed)", v, mbx.num());

    mbx.get(v);
    $display("4. get     -> %0d    : num = %0d", v, mbx.num());

    if (mbx.try_get(v))
      $display("5. try_get -> %0d    : num = %0d", v, mbx.num());

    if (!mbx.try_get(v))
      $display("6. try_get on an empty mailbox returned 0 and did not block");

    if (!mbx.try_peek(v))
      $display("7. try_peek on an empty mailbox returned 0 and did not block");
  end

endmodule
```

```output
1. after three puts : num = 3
2. peek    -> 10    : num = 3  (message stays)
3. get     -> 10    : num = 2  (message removed)
4. get     -> 20    : num = 1
5. try_get -> 30    : num = 0
6. try_get on an empty mailbox returned 0 and did not block
7. try_peek on an empty mailbox returned 0 and did not block
```

**Line by line**

| Line | Explanation |
|---|---|
| `mbx = new();` | Constructs an unbounded mailbox. Without this line the first `put` would be a null-handle error. |
| Three `put` calls | The messages are queued in order: 10 at the head, 30 at the tail. None of them blocks. |
| `mbx.peek(v);` | Copies the head message (10). The mailbox still holds three messages. |
| `mbx.get(v);` | Returns the same head message (10) and removes it. FIFO order: the first message put is the first one got. |
| `mbx.try_get(v)` | A message is available (30), so it is taken and the function returns a positive value, which the `if` treats as true. |
| Second `try_get` | The mailbox is empty. A blocking `get` here would suspend the thread forever, since nobody else puts anything. `try_get` returns 0 and the code continues. |

### Blocking versus nonblocking methods

| | Blocking: `put`, `get`, `peek` | Nonblocking: `try_put`, `try_get`, `try_peek` |
|---|---|---|
| Kind | Task | Function |
| If the operation cannot be done now | The thread waits until it can | Returns 0 immediately |
| Callable from a function | No | Yes |
| Callable from a task | Yes | Yes |
| Consumes simulation time | Possibly | Never |
| Result must be checked | No | **Yes**: ignoring the return value means not knowing whether anything happened |
| Typical use | Normal component loops: `forever begin mbx.get(t); ... end` | Polling, draining a mailbox at end of test, code that must not wait |

> **Interview trap:** `forever begin if (mbx.try_get(t)) process(t); end` hangs the simulation. When the mailbox is empty, `try_get` returns at once, the loop repeats without any blocking statement, and simulation time can never advance. A polling loop must contain a delay or an event control, for example `@(posedge clk);`. If there is no reason to poll, use the blocking `get`.

> **Common mistake:** Using `num()` to decide whether a following `get()` will block: `if (mbx.num() > 0) mbx.get(t);`. With more than one consumer, another thread can take the message between the test and the `get`. `try_get` performs the test and the removal as one indivisible operation.

### Interview questions

**Q1. List the mailbox methods.**
`new()`, `put()`, `try_put()`, `get()`, `try_get()`, `peek()`, `try_peek()`, `num()`.

**Q2. What is the difference between `get()` and `peek()`?**
Both return the message at the head and both block while the mailbox is empty. `get()` removes the message; `peek()` leaves it in the mailbox.

**Q3. What is the difference between `get()` and `try_get()`?**
`get()` is a task that blocks until a message is available. `try_get()` is a function that never blocks: it returns a positive value and the message if one is available, and 0 otherwise.

**Q4. What does `try_put()` return?**
A positive value if the message was stored, and 0 if the bounded mailbox was full.

**Q5. Which mailbox methods can be called from a function?**
`num()`, `try_put()`, `try_get()` and `try_peek()`. The blocking methods are tasks and cannot be called from a function.

**Q6. What does `num()` return?**
The number of messages currently in the mailbox.

## 4.4 Bounded Mailbox in Action

### A mailbox of integer values with flow control

The producer wants to send four values as fast as it can. The mailbox holds two. The consumer takes one value every 10 time units. Only the producer prints, so that the output shows exactly when each `put` was able to complete.

```systemverilog file=tb_mailbox_bounded.sv
module tb_mailbox_bounded;

  mailbox #(int) mbx = new(2);                 // bounded: at most 2 messages

  initial begin : producer
    for (int i = 1; i <= 4; i++) begin
      mbx.put(i);                              // blocks while the mailbox is full
      $display("[%0t] producer: put(%0d) completed", $time, i);
    end
  end

  initial begin : consumer
    int v;
    repeat (4) begin
      #10;
      mbx.get(v);                              // frees one place every 10 time units
    end
  end

endmodule
```

```output
[0] producer: put(1) completed
[0] producer: put(2) completed
[10] producer: put(3) completed
[20] producer: put(4) completed
```

**Execution flow**

| Time | Consumer | Producer | Mailbox contents (head first) |
|---|---|---|---|
| 0 | Waiting for time 10 | `put(1)` and `put(2)` complete. `put(3)` blocks: full | 1, 2 |
| 10 | `get` takes 1 | A place is free: `put(3)` completes. `put(4)` blocks: full again | 2, 3 |
| 20 | `get` takes 2 | `put(4)` completes. The producer has finished | 3, 4 |
| 30 | `get` takes 3 | | 4 |
| 40 | `get` takes 4 | | empty |

The producer was automatically slowed to the consumer's pace, without any extra code. With an unbounded mailbox all four `put` calls would have completed at time 0.

### try_put on a bounded mailbox

```systemverilog file=tb_mailbox_try_put.sv
module tb_mailbox_try_put;

  mailbox #(int) mbx = new(2);

  initial begin
    if (mbx.try_put(1))  $display("1. try_put(1) stored    : num = %0d", mbx.num());
    if (mbx.try_put(2))  $display("2. try_put(2) stored    : num = %0d", mbx.num());
    if (!mbx.try_put(3)) $display("3. try_put(3) refused   : mailbox full, num = %0d",
                                  mbx.num());
  end

endmodule
```

```output
1. try_put(1) stored    : num = 1
2. try_put(2) stored    : num = 2
3. try_put(3) refused   : mailbox full, num = 2
```

The third `try_put` does not block and does not store anything; the value 3 is simply not sent, and it is the caller's job to notice the return value of 0.

### Interview questions

**Q1. A bounded mailbox of size 1 connects a generator and a driver. The generator calls `put` three times in a row. When does each `put` return?**
The first returns immediately. The second returns when the driver has removed the first message. The third returns when the driver has removed the second.

**Q2. How can a sender avoid blocking on a full bounded mailbox?**
Use `try_put()` and check its return value.

**Q3. Why would you bound the generator-to-driver mailbox?**
So that the generator cannot run far ahead of the driver. This keeps memory use small, and, more importantly, keeps the generation of each transaction close in time to its use, so that the generator can react to the current state of the testbench (for example to responses or to configuration changes).

## 4.5 Parameterized and Typeless Mailboxes

### Two kinds of mailbox

| Declaration | Name | What it can hold | Type checking |
|---|---|---|---|
| `mailbox mbx;` | Typeless (generic, dynamic) mailbox | Messages of **any** type, even mixed in one mailbox | At **run time**, when a message is taken out |
| `mailbox #(T) mbx;` | Parameterized (typed) mailbox | Only messages of type `T` | At **compile time** |

### The problem with a typeless mailbox

The receiver must take each message into a variable of exactly the type that was sent. The compiler cannot check this, because any thread may have put anything.

```systemverilog file=tb_mailbox_typeless.sv
module tb_mailbox_typeless;

  mailbox mbx = new();                 // typeless
  int     i_val = 42;
  string  s_val = "hello";
  int     i_out;
  string  s_out;
  int     rc;

  initial begin
    mbx.put(i_val);                    // first message  : an int
    mbx.put(s_val);                    // second message : a string

    mbx.get(i_out);                    // int message into an int variable: fine
    $display("1. got int    : %0d", i_out);

    rc = mbx.try_get(i_out);           // string message into an int variable
    if (rc < 0)
      $display("2. try_get returned a negative value: type mismatch, nothing taken");

    mbx.get(s_out);                    // the string is still there
    $display("3. got string : %s", s_out);

    // mbx.put(s_val);
    // mbx.get(i_out);                 // blocking get with the wrong type: RUN-TIME ERROR
  end

endmodule
```

```output
1. got int    : 42
2. try_get returned a negative value: type mismatch, nothing taken
3. got string : hello
```

**Line by line**

| Line | Explanation |
|---|---|
| `mailbox mbx = new();` | No type parameter. The compiler accepts any `put` and any `get`. |
| `mbx.try_get(i_out)` on a string message | The types do not match. `try_get` reports this by returning a negative value and leaves the message in the mailbox. |
| The commented lines | A blocking `get()` or `peek()` into a variable of the wrong type is a **run-time error**. The simulation stops, possibly hours into a regression. |

### The parameterized mailbox

```systemverilog
mailbox #(int) mbx = new();
string s = "hello";

mbx.put(5);         // fine
// mbx.put(s);      // COMPILE-TIME error: a string is not an int
```

With the type fixed in the declaration, a wrong `put` or `get` is found by the compiler in seconds. A parameterized mailbox is used in practically all testbench code:

```systemverilog
typedef mailbox #(alu_txn) alu_txn_mbx_t;      // define the type once

alu_txn_mbx_t gen2drv_mbx;                     // generator -> driver
alu_txn_mbx_t mon2scb_mbx;                     // monitor   -> scoreboard
```

### Comparison

| Property | Typeless `mailbox` | Parameterized `mailbox #(T)` |
|---|---|---|
| Message types | Any, may be mixed | Exactly `T` |
| A wrong type is detected | At run time | At compile time |
| Blocking `get`/`peek` with a wrong type | Run-time error | Does not compile |
| `try_get`/`try_peek` with a wrong type | Returns a negative value | Does not compile |
| Readability | The reader cannot tell what travels through it | The type documents the connection |
| Recommended | No | Yes |

> **Key point:** A `mailbox #(alu_txn)` can also carry objects of any class **derived** from `alu_txn`, because a derived-class handle may be stored in a base-class handle (Module 4). The receiver gets a base-class handle and uses `$cast` if it needs the derived type. This is how one driver can accept several kinds of transaction.

### Interview questions

**Q1. What is a parameterized mailbox and why is it preferred?**
A mailbox declared with a type parameter, `mailbox #(T)`, which accepts only messages of type `T`. Type errors are found at compile time. A typeless mailbox accepts anything and reports a mismatch only at run time, when a message is retrieved into a variable of the wrong type.

**Q2. What happens if you `get()` from a typeless mailbox into a variable of the wrong type?**
A run-time error. With `try_get()` or `try_peek()` the function returns a negative value instead.

**Q3. What are the three possible results of `try_get()`?**
Positive: a message was retrieved. Zero: the mailbox was empty. Negative: a message is available but its type does not match the argument (possible only with a typeless mailbox).

## 4.6 Mailbox of Transaction Objects

### What is actually stored

When a class object is put into a mailbox, the mailbox stores the **handle**, not a copy of the object (Module 4: a class variable holds a reference). Sender and receiver end up with handles to the same object.

```text
   generator:  txn = new();  txn.id = 1;  gen2drv_mbx.put(txn);

        txn (generator) ------+
                              v
                        +-----------+
                        | alu_txn   |
                        | id = 1    |
                        +-----------+
                              ^
        mailbox slot ---------+

   driver:  gen2drv_mbx.get(txn);      the driver's txn now refers to the SAME object
```

This is efficient, since no data is copied. It also causes the most common mailbox bug.

### The bug: one object reused for every transaction

```systemverilog file=tb_mailbox_reuse_bug.sv
module tb_mailbox_reuse_bug;

  class alu_txn;
    bit [7:0]    a;
    int unsigned id;
  endclass

  mailbox #(alu_txn) gen2drv_mbx = new();
  alu_txn            txn, got;

  initial begin
    txn = new();                               // BUG: one object, created once

    for (int i = 1; i <= 3; i++) begin         // "generator"
      txn.id = i;
      txn.a  = 8'(i * 16);
      gen2drv_mbx.put(txn);                    // puts the same handle three times
    end

    repeat (3) begin                           // "driver"
      gen2drv_mbx.get(got);
      $display("driver got id=%0d a=%h", got.id, got.a);
    end
  end

endmodule
```

```output
driver got id=3 a=30
driver got id=3 a=30
driver got id=3 a=30
```

The generator intended to send three different transactions. The driver receives the last one three times.

```text
   After the loop:

        mailbox slot 1 ---+
        mailbox slot 2 ---+----> +-----------+
        mailbox slot 3 ---+      | alu_txn   |      there is only ONE object;
        txn (generator) --+      | id = 3    |      each iteration overwrote its fields
                                 | a  = 30   |
                                 +-----------+
```

### The fix: a new object for every transaction

```systemverilog
for (int i = 1; i <= 3; i++) begin
  txn    = new();                              // FIX: construct inside the loop
  txn.id = i;
  txn.a  = 8'(i * 16);
  gen2drv_mbx.put(txn);
end
```

```output
driver got id=1 a=10
driver got id=2 a=20
driver got id=3 a=30
```

Each iteration now creates a separate object, and each mailbox slot refers to a different one.

An alternative with the same effect is to keep one "template" object, randomize it in each iteration, and put a **copy** into the mailbox: `gen2drv_mbx.put(txn.copy());`. This is the form used when a test replaces the template with a derived transaction type (Module 9).

> **Interview trap:** "My generator sends ten different transactions but the driver drives the same one ten times. Why?" The generator constructs the transaction once, outside the loop, and puts the same handle each time. With an unbounded mailbox the generator finishes the loop before the driver takes anything, so every handle in the mailbox points to the single object holding the last values. Construct a new object (or put a copy) for every transaction.

The same rule applies to the monitor: it must create a **new** `alu_txn` for each sampled transfer before putting it into `mon2scb_mbx`. Otherwise the scoreboard, which may still be holding the previous handle, sees its data change underneath it.

### Interview questions

**Q1. When a class object is put into a mailbox, is the object copied?**
No. Only the handle is stored. The receiver's handle refers to the same object the sender created.

**Q2. After `gen2drv_mbx.put(txn);` the generator modifies `txn.a`. Does the driver see the change?**
Yes, if the driver has not yet finished using the object, because both hold handles to the same object. To prevent this, the generator creates a new object for the next transaction instead of modifying the one it has sent.

**Q3. Where should `new()` be called in a generator loop, and why?**
Inside the loop, once per transaction. If it is called once outside the loop, every `put` stores the same handle and all the messages refer to one object.

## 4.7 Communication Between Generator and Driver

This section combines a mailbox (for the data) and an event (for the handshake), using the component names of the course testbench. The classes are simplified: the generator sets field values by hand instead of randomizing (Module 5), and the driver consumes time with a delay instead of driving an interface (Module 8).

### The design

```text
   alu_generator                                              alu_driver
   +---------------------+        gen2drv_mbx                +----------------------+
   | create alu_txn      |        (mailbox #(alu_txn))       | forever:             |
   | fill in the fields  | --------- put ---> [ ] --- get --> |   get a transaction  |
   | put it in mailbox   |                                   |   drive it (takes    |
   | wait for drv_done   | <-------- drv_done (event) ------ |     time)            |
   | repeat N times      |                                   |   trigger drv_done   |
   | trigger gen_done    |                                   +----------------------+
   +---------------------+
            |
            | gen_done (event)
            v
        tb top: ends the test
```

- The **mailbox** carries the transactions from generator to driver.
- The event **`drv_done`** goes the other way: the driver tells the generator that it has finished the current transaction. The generator therefore creates one transaction at a time, in step with the driver.
- The event **`gen_done`** tells the top level that the generator has sent everything.

### Complete example

```systemverilog file=tb_gen_drv_mailbox.sv
module tb_gen_drv_mailbox;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  // ----------------------------------------------------------------- transaction
  class alu_txn;
    bit [7:0]    a, b;
    alu_op_e     op;
    int unsigned id;

    function void print(string tag = "");
      $display("[%0t] %s id=%0d a=%0d b=%0d op=%s", $time, tag, id, a, b, op.name());
    endfunction
  endclass

  // ------------------------------------------------------------------- generator
  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    event              drv_done;
    event              gen_done;
    int unsigned       num_txn = 3;

    function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done);
      this.gen2drv_mbx = gen2drv_mbx;
      this.drv_done    = drv_done;
    endfunction

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();                        // a new object for every transaction
        txn.id = i;
        txn.a  = 8'(10 * i);
        txn.b  = 8'(i);
        txn.op = (i % 2) ? ALU_ADD : ALU_SUB;
        txn.print("GEN: put");
        gen2drv_mbx.put(txn);
        @(drv_done);                           // wait until the driver has finished it
      end
      $display("[%0t] GEN: all %0d transactions sent", $time, num_txn);
      -> gen_done;
    endtask
  endclass

  // ---------------------------------------------------------------------- driver
  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    event              drv_done;

    function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done);
      this.gen2drv_mbx = gen2drv_mbx;
      this.drv_done    = drv_done;
    endfunction

    task run();
      alu_txn txn;
      forever begin
        gen2drv_mbx.get(txn);                  // blocks until a transaction arrives
        txn.print("DRV: got");
        #10;                                   // stands for driving the DUT pins
        $display("[%0t] DRV: done id=%0d", $time, txn.id);
        -> drv_done;
      end
    endtask
  endclass

  // ------------------------------------------------------------------- top level
  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  alu_generator      gen;
  alu_driver         drv;

  initial begin
    gen2drv_mbx = new();                       // ONE mailbox ...
    gen = new(gen2drv_mbx, drv_done);          // ... shared by both components
    drv = new(gen2drv_mbx, drv_done);

    fork
      gen.run();
      drv.run();
    join_none

    @(gen.gen_done);
    $display("[%0t] TOP: generator finished, %0d items left in the mailbox",
             $time, gen2drv_mbx.num());
    $finish;
  end

endmodule
```

```output
[0] GEN: put id=1 a=10 b=1 op=ALU_ADD
[0] DRV: got id=1 a=10 b=1 op=ALU_ADD
[10] DRV: done id=1
[10] GEN: put id=2 a=20 b=2 op=ALU_SUB
[10] DRV: got id=2 a=20 b=2 op=ALU_SUB
[20] DRV: done id=2
[20] GEN: put id=3 a=30 b=3 op=ALU_ADD
[20] DRV: got id=3 a=30 b=3 op=ALU_ADD
[30] DRV: done id=3
[30] GEN: all 3 transactions sent
[30] TOP: generator finished, 0 items left in the mailbox
```

### Execution flow

| Time | Generator | Driver | Top |
|---|---|---|---|
| 0 | Creates txn 1, prints, `put`. Blocks at `@(drv_done)` | `get` returns txn 1. Prints. Starts "driving" (`#10`) | Forked both, now blocked at `@(gen.gen_done)` |
| 10 | | Prints "done", triggers `drv_done`, loops to `get`: mailbox empty, blocks | |
| 10 | Wakes. Creates txn 2, prints, `put`. Blocks at `@(drv_done)` | `get` returns txn 2. Prints. Drives until 20 | |
| 20 | Same for txn 3 | Same for txn 3 | |
| 30 | Wakes, loop finished. Prints. Triggers `gen_done`, ends | Blocked in `get` | Wakes, prints, `$finish` |

Every line of the output follows from the previous one by cause and effect, so the order does not depend on the simulator: the driver cannot print "got" before the generator's `put`, and the generator cannot print the next "put" before the driver's `-> drv_done`.

### Line by line

| Code | Explanation |
|---|---|
| `mailbox #(alu_txn) gen2drv_mbx;` in both classes | Each class has a **handle**. Neither class constructs a mailbox. |
| `function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done);` | The handles are passed in when the object is built, so a component cannot exist unconnected. |
| `this.gen2drv_mbx = gen2drv_mbx;` | `this.` selects the class property; the plain name is the constructor argument (Module 4). |
| `txn = new();` inside the loop | Avoids the reuse bug of Section 4.6. |
| `txn.op = (i % 2) ? ALU_ADD : ALU_SUB;` | Odd identifiers get `ALU_ADD`, even ones `ALU_SUB`. Both branches are of the enum type, so no cast is needed. |
| `gen2drv_mbx.put(txn);` | The mailbox is unbounded, so this never blocks. |
| `@(drv_done);` in the generator | The generator sleeps until the driver has finished. This `@` is safe from the race of Section 2.2 because the driver triggers only after a `#10`: the generator is always waiting long before the trigger. |
| `forever begin gen2drv_mbx.get(txn); ...` | The standard driver loop. `get` is the only thing that paces it; when no transaction is available the driver sleeps. |
| `-> drv_done;` | Tells the generator that the item is complete. |
| `gen2drv_mbx = new();` at the top | The single mailbox object. Both components receive the same handle. |
| `fork gen.run(); drv.run(); join_none` | Two threads. `join` could not be used: the driver's `forever` loop never ends. |
| `@(gen.gen_done);` | The top level reaches the generator's event through the generator handle. It starts waiting at time 0, well before the trigger at time 30. |
| `$finish;` | Ends the simulation; the driver, blocked in `get`, is simply abandoned. |

### Other ways to keep generator and driver in step

| Technique | How | Comment |
|---|---|---|
| Event handshake (above) | Generator waits for `drv_done` after each `put` | Explicit and easy to follow |
| Bounded mailbox of size 1 | `gen2drv_mbx = new(1);` | The generator can still be one transaction ahead: its `put` succeeds as soon as the driver has done `get`, before the driver has finished driving |
| Bounded mailbox of size 1 with `peek` | Driver does `peek`, drives, then `get` | The message stays in the mailbox while it is being driven, so the generator's next `put` blocks until the driver has completely finished. True lock-step without an event |
| No synchronization | Unbounded mailbox, generator puts everything at once | Simplest; acceptable when the stimulus does not depend on what the DUT is doing |

```systemverilog
// Driver loop for the peek-then-get technique (mailbox created with new(1))
forever begin
  gen2drv_mbx.peek(txn);      // look at the transaction; the mailbox stays full
  drive(txn);                 // takes simulation time
  gen2drv_mbx.get(txn);       // remove it: only now can the generator put the next one
end
```

> **Verification application:** This generator → mailbox → driver structure is half of the layered testbench built in Module 9. The other half, monitor → `mon2scb_mbx` → scoreboard, is identical in form. In UVM the mailbox and the handshake are replaced by the sequencer-driver connection (`get_next_item()` and `item_done()`), which works on the same principle.

### Interview questions

**Q1. How do a generator and a driver communicate?**
Through a mailbox of transaction handles. The environment constructs one mailbox and passes its handle to both. The generator creates (and randomizes) a transaction and calls `put()`; the driver calls `get()` in a `forever` loop and drives each transaction onto the interface.

**Q2. How does the generator know when the driver has finished a transaction?**
Through a handshake: an event such as `drv_done` that the driver triggers after driving and the generator waits for after each `put`. Alternatives are a bounded mailbox of size 1 combined with `peek` then `get` in the driver.

**Q3. Who should construct the mailbox, and why?**
The environment (or whatever owns both components). There must be exactly one mailbox object, with its handle given to the generator and the driver. If each component constructs its own, they are not connected.

**Q4. Why is `fork` ... `join_none` (or `join_any`) used to start the generator and driver, and not `join`?**
The driver runs a `forever` loop and never returns, so `join` would never complete.

**Q5. With a bounded mailbox of size 1 and a driver that uses `get` first and then drives, is the generator in lock-step with the driver?**
Not quite. As soon as the driver has done `get`, the mailbox is empty and the generator's next `put` succeeds, so the generator is one transaction ahead. For true lock-step the driver uses `peek`, drives, and then `get`, or an event handshake is added.

## 4.8 Mailbox: Summary, Mistakes and Questions

### Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Mailbox never constructed | Null-handle run-time error at the first `put`/`get` | `mbx = new();` |
| Two mailboxes constructed, one in each component | Generator sends, driver waits forever | Construct once, share the handle |
| Same object put repeatedly | Receiver sees the last value every time | `new()` per transaction, or put a copy |
| Typeless mailbox | Run-time type error | `mailbox #(T)` |
| `try_get` in a loop with no delay | Simulation hangs at one time | Blocking `get`, or add a clock edge |
| Ignoring the return value of `try_put` / `try_get` | Messages silently not sent, or stale data processed | Test the return value |
| `get` called from a function | Compile error | `try_get`, or make it a task |
| Bounded mailbox where the consumer has stopped | Producer blocks forever (deadlock) | End-of-test logic, timeouts |
| Two consumers on one mailbox, each expecting to see every message | Each message is delivered to only one of them | One mailbox per consumer; the producer puts into each |

### Further interview questions

**Q1. Can several threads `get` from the same mailbox?**
Yes, but each message is delivered to exactly one of them. A mailbox does not broadcast. To give every consumer every message, use a separate mailbox for each consumer and have the producer put a handle into each.

**Q2. Can a mailbox be passed to a task or stored in an array?**
Yes. It is a class handle, so it can be an argument, a class property, an array element, or the value of an associative array.

**Q3. Is the mailbox FIFO guaranteed?**
Yes. Messages are retrieved in the order in which they were put.

**Q4. How do you empty a mailbox at the end of a test, from a function?**
`while (mbx.try_get(item)) begin ... end`. `try_get` is a function, never blocks, and returns 0 when the mailbox is empty.

**Q5. What is the difference between a mailbox and a semaphore?**
A mailbox transfers data: it is a queue of messages. A semaphore transfers no data: it holds a count of keys and is used to control access to a resource. Both block a thread when the request cannot be satisfied (Part 5).

**Q6. How would you implement a mailbox yourself?**
With a queue for the messages, a `put` task that does `wait (q.size() < bound);` (when bounded) and then `q.push_back(msg);`, and a `get` task that does `wait (q.size() > 0);` and then `msg = q.pop_front();`. The built-in mailbox additionally preserves the arrival order of blocked threads and is safe when several threads are woken at the same time.
