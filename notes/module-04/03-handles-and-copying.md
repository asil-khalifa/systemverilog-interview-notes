# Part 3: Handle Assignment and Object Copying

There are three different things people mean when they say "copy an object". Interviewers ask about them constantly, because confusing them produces bugs that are hard to see.

| What you write | What is duplicated | Name |
|---|---|---|
| `p2 = p1;` | Only the handle. Still one object | Handle assignment |
| `p2 = new p1;` | The object, one level deep. Nested objects are shared | Shallow copy |
| `p2 = p1.copy();` (a method you write) | The object and every object nested inside it | Deep copy |

## 3.1 Handle Assignment

### In plain English

Assigning one handle to another does not copy the object. It copies the address. Afterwards two pieces of paper have the same address written on them, and there is still one house.

### Technical definition

The assignment `h2 = h1;` between class handles copies the **reference**. Both handles then refer to the same object. Nothing is allocated and no property is copied. Any change made through one handle is visible through the other. This is completely different from assigning structs or arrays, where the data is copied.

### How it works internally

```text
   packet p1, p2;
   p1 = new();  p1.addr = 8'h10;         p2 = p1;                  p2.addr = 8'h99;

   p1 --> [ addr = 10 ]                  p1 --+                    p1 --+
   p2 --> null                                +--> [ addr = 10 ]        +--> [ addr = 99 ]
                                         p2 --+                    p2 --+

                                         one object, two handles   p1.addr is now 99 as well
```

### Where handle assignment happens without an `=` sign

Handles are copied in all of these situations, and in every one of them the object is **not** duplicated:

| Situation | Example |
|---|---|
| Passing an object as a task or function argument | `drv.send(txn);` The method receives a copy of the handle and works on the caller's object |
| Returning an object from a function | `return txn;` |
| Putting an object into a mailbox, queue or array | `gen2drv_mbx.put(txn);` `q.push_back(txn);` |
| Getting an object out of a mailbox | `mon2scb_mbx.get(txn);` |
| Storing an object in a property of another object | `this.cfg = cfg;` |

This is exactly why classes are efficient for passing transactions around a testbench: only a reference moves. It is also why the following bug is so common.

### The classic bug: one object, put many times

```systemverilog file=tb_new_in_loop.sv
module tb_new_in_loop;

  class packet;
    bit [7:0] addr;
  endclass

  packet p;
  packet q_bad  [$];        // queues of handles (Module 2)
  packet q_good [$];

  initial begin
    // WRONG: the object is created once, outside the loop
    p = new();
    for (int i = 0; i < 3; i++) begin
      p.addr = i;
      q_bad.push_back(p);            // the same handle is stored three times
    end

    // RIGHT: a new object is created in every iteration
    for (int i = 0; i < 3; i++) begin
      p = new();
      p.addr = i;
      q_good.push_back(p);
    end

    foreach (q_bad[i])  $display("q_bad[%0d].addr  = %0d", i, q_bad[i].addr);
    foreach (q_good[i]) $display("q_good[%0d].addr = %0d", i, q_good[i].addr);
  end

endmodule
```

```output
q_bad[0].addr  = 2
q_bad[1].addr  = 2
q_bad[2].addr  = 2
q_good[0].addr = 0
q_good[1].addr = 1
q_good[2].addr = 2
```

**Explanation**

```text
   q_bad                                   q_good

   [0] --+                                 [0] --> [ addr = 0 ]
   [1] --+--> [ addr = 2 ]                 [1] --> [ addr = 1 ]
   [2] --+                                 [2] --> [ addr = 2 ]

   three handles, ONE object               three handles, three objects
   (it holds the last value written)
```

In the first loop only one object ever exists. The queue receives the same reference three times, and each iteration overwrites the single `addr`. When the queue is read afterwards, all three entries show the final value, 2.

> **Verification application:** This is the most frequent beginner bug in a generator. If the generator creates the transaction once and then, in a loop, randomizes it and puts it into the mailbox, a driver that is slower than the generator sees the same (last) transaction repeated, and a scoreboard that stored "expected" handles finds they have all changed. The fix is `txn = new();` inside the loop, or putting a copy into the mailbox: `gen2drv_mbx.put(txn.copy());`.

### Comparison with value types

| Type of `a` and `b` | Effect of `b = a;` | Later change to `b` affects `a`? |
|---|---|---|
| `int`, `logic [7:0]`, `real`, `string`, enum | Value copied | No |
| `struct` (packed or unpacked) | All members copied | No |
| Fixed, dynamic, associative array, queue | All elements copied | No |
| Class handle | Reference copied | **Yes**, they share one object |

### Interview questions

**Q1. What happens when one handle is assigned to another?**
The reference is copied. Both handles point to the same object; no new object is created.

**Q2. An object is passed to a function and the function changes one of its properties. Does the caller see the change?**
Yes. The function received a copy of the handle, which refers to the caller's object. (This is true without `ref`. The `ref` keyword would only matter if the function assigned a *different object* to the handle and the caller needed to see that.)

**Q3. A generator creates one transaction before a loop, randomizes it ten times and puts it in a mailbox each time. What does the driver get?**
Ten handles to the same object. Depending on timing it may see the same values repeatedly, typically those of the last randomization. A new object must be constructed for each transaction.

## 3.2 Shallow Copy

### In plain English

A shallow copy makes a second object and copies every property of the first object into it. For ordinary data that gives an independent duplicate. But if one of the properties is a *handle* to another object, the handle is what gets copied. The two outer objects then share the same inner object.

### Technical definition

The expression `new source_handle` (the keyword `new` followed by a handle, with **no parentheses**) allocates a new object of the same class and copies the value of every property from the source object into it:

- integral, `real`, `string`, enum and struct properties: the value is copied;
- array properties (fixed, dynamic, associative, queue): the whole array is copied, element by element;
- **class handle properties (and handles stored inside arrays): only the handle is copied**; the object it refers to is not duplicated.

The class constructor `new()` is **not executed** for a shallow copy.

### Syntax

```systemverilog
packet p1, p2;
p1 = new();        // normal construction: parentheses, constructor runs
p2 = new p1;       // shallow copy: no parentheses, constructor does NOT run
```

### How it works internally

```text
   class header;  bit [7:0] id;                      endclass
   class packet;  bit [7:0] data;  header hdr;       endclass

   p1 = new();  p1.data = AA;  p1.hdr.id = 01;
   p3 = new p1;                                      // shallow copy

        p1 --> +-------------+                  +-----------+
               | data = AA   |                  |  id = 01  |   ONE header object,
               | hdr  = *----|----------------> |           |   shared by both packets
               +-------------+        +-------> +-----------+
                                      |
        p3 --> +-------------+        |
               | data = AA   |        |         data was duplicated:
               | hdr  = *----|--------+         p3.data = BB does not touch p1.data
               +-------------+                  hdr was only re-pointed:
                                                p3.hdr.id = 99 changes "p1.hdr.id" too
```

### Complete example

```systemverilog file=tb_shallow_copy.sv
module tb_shallow_copy;

  class header;
    bit [7:0] id;
  endclass

  class packet;
    bit [7:0] data;
    header    hdr;

    function new();
      hdr = new();
      $display("   packet::new() executed");
    endfunction
  endclass

  packet p1, p2, p3;

  initial begin
    p1 = new();
    p1.data   = 8'hAA;
    p1.hdr.id = 8'h01;

    p2 = p1;            // handle assignment: no new object
    p3 = new p1;        // shallow copy: a new packet object, constructor not called

    p3.data   = 8'hBB;  // changes only p3
    p3.hdr.id = 8'h99;  // changes the header shared by p1 and p3

    $display("p1: data=%h hdr.id=%h", p1.data, p1.hdr.id);
    $display("p2: data=%h hdr.id=%h", p2.data, p2.hdr.id);
    $display("p3: data=%h hdr.id=%h", p3.data, p3.hdr.id);
    $display("p1 == p2: %0d   p1 == p3: %0d   p1.hdr == p3.hdr: %0d",
             p1 == p2, p1 == p3, p1.hdr == p3.hdr);
  end

endmodule
```

```output
   packet::new() executed
p1: data=aa hdr.id=99
p2: data=aa hdr.id=99
p3: data=bb hdr.id=99
p1 == p2: 1   p1 == p3: 0   p1.hdr == p3.hdr: 1
```

**Line by line**

| Line | Explanation |
|---|---|
| `p1 = new();` | The constructor runs once (one message is printed) and creates the nested `header`. |
| `p2 = p1;` | Same object. `p1 == p2` is 1. |
| `p3 = new p1;` | A second `packet` object. The message is **not** printed again: the constructor does not run for a shallow copy. `p1 == p3` is 0. |
| `p3.data = 8'hBB;` | `data` is an ordinary property with its own storage in each object. `p1.data` stays `AA`. |
| `p3.hdr.id = 8'h99;` | `p3.hdr` and `p1.hdr` are the same reference. The single header object is changed, so `p1.hdr.id` also reads `99`. |
| `p1.hdr == p3.hdr` | 1: proof that the nested object is shared. |

### What a shallow copy does and does not duplicate

| Property kind | Duplicated by `new src`? |
|---|---|
| `int`, `bit [..]`, `logic [..]`, `real`, enum | Yes |
| `string` | Yes |
| Struct | Yes |
| Fixed array, dynamic array, queue, associative array of non-handle elements | Yes, all elements |
| Class handle | **No**: the handle is copied, the object is shared |
| Array or queue of class handles | The array is duplicated, but its elements are handles to the **same** objects |
| Static property | Not applicable: there is only one, belonging to the class |
| Per-object ID assigned in the constructor | Copied as-is, because the constructor does not run. The copy has the same ID as the original |

> **Interview trap:** "Does a shallow copy call the constructor?" No. `new p1` copies the property values directly. Anything the constructor normally does (incrementing a static counter, assigning a unique ID, printing a message, creating nested objects) does not happen for the copy.

> **Common mistake:** Writing `p2 = new(p1);` when a shallow copy was intended. With parentheses this is an ordinary constructor call with `p1` as an argument, which is an error unless the constructor happens to accept a `packet` argument.

> **Common mistake:** Assuming a shallow copy is "broken" for every class. If the class has no handle properties, a shallow copy is a complete, independent copy and is perfectly adequate.

### Interview questions

**Q1. What is a shallow copy?**
A copy made with `new handle;`. A new object is allocated and all properties are copied. Properties that are handles are copied as handles, so nested objects are shared between the original and the copy.

**Q2. What is the syntax, and how does it differ from construction?**
`p2 = new p1;` with no parentheses. `p2 = new();` constructs a fresh object by running the constructor.

**Q3. After a shallow copy, which changes to the copy affect the original?**
Changes to nested objects reached through handle properties. Changes to ordinary properties and to array properties do not.

**Q4. Is a dynamic array property shared after a shallow copy?**
No. Arrays are values, not references; the copy gets its own array. Only class handles are shared.

## 3.3 Deep Copy

### In plain English

A deep copy duplicates the object **and everything it refers to**, all the way down. The copy and the original have nothing in common afterwards. SystemVerilog has no built-in deep copy, because only the author of a class knows which nested objects should be duplicated. You write a `copy()` method yourself.

### Technical definition

A deep copy is a user-written operation that creates a new object, copies all non-handle properties, and for every handle property creates a **new nested object** that is itself a deep copy of the original's nested object. The usual implementation is a `copy()` function in each class; the outer class's `copy()` calls the inner class's `copy()`.

### How it works internally

```text
   p3 = p1.copy();                                   // deep copy

        p1 --> +-------------+                  +-----------+
               | data = AA   |                  |  id = 01  |
               | hdr  = *----|----------------> |           |
               +-------------+                  +-----------+

        p3 --> +-------------+                  +-----------+
               | data = AA   |                  |  id = 01  |   a second header object,
               | hdr  = *----|----------------> |           |   created by hdr.copy()
               +-------------+                  +-----------+

        Nothing is shared.  p3.hdr.id = 99 leaves p1.hdr.id at 01.
```

### Complete example

```systemverilog file=tb_deep_copy.sv
module tb_deep_copy;

  class header;
    bit [7:0] id;

    function header copy();
      header h = new();
      h.id = this.id;
      return h;
    endfunction
  endclass

  class packet;
    bit [7:0] data;
    header    hdr;

    function new();
      hdr = new();
    endfunction

    function packet copy();
      packet p = new();              // 1. a new packet (its constructor creates a header)
      p.data = this.data;            // 2. copy the ordinary properties
      p.hdr  = this.hdr.copy();      // 3. deep-copy the nested object
      return p;
    endfunction
  endclass

  packet p1, p3;

  initial begin
    p1 = new();
    p1.data   = 8'hAA;
    p1.hdr.id = 8'h01;

    p3 = p1.copy();                  // deep copy

    p3.data   = 8'hBB;
    p3.hdr.id = 8'h99;

    $display("p1: data=%h hdr.id=%h", p1.data, p1.hdr.id);
    $display("p3: data=%h hdr.id=%h", p3.data, p3.hdr.id);
    $display("p1 == p3: %0d   p1.hdr == p3.hdr: %0d", p1 == p3, p1.hdr == p3.hdr);
  end

endmodule
```

```output
p1: data=aa hdr.id=01
p3: data=bb hdr.id=99
p1 == p3: 0   p1.hdr == p3.hdr: 0
```

**Line by line**

| Line | Explanation |
|---|---|
| `function header copy();` | The inner class knows how to copy itself. |
| `header h = new();` | A local handle with an initialiser. Class methods are automatic, so this runs on every call. |
| `function packet copy();` | Return type is the class itself. |
| `packet p = new();` | Creates the new outer object. Its constructor has already created a fresh `header`, which step 3 replaces. |
| `p.hdr = this.hdr.copy();` | The key line: instead of copying the handle, ask the nested object for a copy of itself. |
| Output | `p1` is untouched by the changes to `p3`. `p1.hdr == p3.hdr` is 0: two separate header objects. |

If `hdr` could legitimately be `null`, the method must guard the call: `if (this.hdr != null) p.hdr = this.hdr.copy();`.

### The three kinds of copy compared

| Property | Handle assignment | Shallow copy | Deep copy |
|---|---|---|---|
| Syntax | `p2 = p1;` | `p2 = new p1;` | `p2 = p1.copy();` (user-written) |
| New outer object created | No | Yes | Yes |
| Ordinary properties | Shared (same object) | Duplicated | Duplicated |
| Nested objects (handle properties) | Shared | Shared | Duplicated |
| Constructor executed | No | No | Yes, as written in `copy()` |
| Built into the language | Yes | Yes | No |
| Number of objects after copying a packet with one header | 2 (1 packet, 1 header) | 3 (2 packets, 1 header) | 4 (2 packets, 2 headers) |
| Cost | Lowest | Low | Highest |
| Use when | You want another name for the same object, or to pass it on | The class has no handle properties, or sharing the nested objects is intended | The copy must be fully independent |

> **Interview trap:** "If a class contains only `int` and `bit` fields, is there a difference between a shallow and a deep copy?" No. The difference appears only when the class contains handles to other objects.

> **Common mistake:** Writing a `copy()` method that does `p.hdr = this.hdr;`. That is a hand-written shallow copy. It looks like a deep copy from outside and behaves like a shallow one.

> **Common mistake:** Adding a new property to a class and forgetting to add it to `copy()` (and to `compare()` and `print()`). The copy then silently has the default value for that field. UVM's field macros and `do_copy` convention exist to reduce this risk.

> **Verification application:** A monitor that reuses one transaction object for every bus transfer must send a **copy** to the scoreboard; otherwise the scoreboard's stored handles all end up pointing at the object the monitor keeps overwriting. Equally, when one transaction is broadcast to a scoreboard and a coverage collector and either might modify it, each should receive its own copy.

### Interview questions

**Q1. What is a deep copy?**
A copy in which the object and all objects nested inside it are duplicated, so that the copy shares nothing with the original. It is implemented by a user-written method.

**Q2. What is the difference between shallow and deep copy?**
A shallow copy (`new h`) duplicates only the top-level object; handle properties are copied as references, so nested objects are shared. A deep copy also duplicates the nested objects.

**Q3. How do you implement a deep copy?**
Write a `copy()` function in each class. It constructs a new object, assigns all value properties, and for each handle property calls that object's own `copy()`.

**Q4. Does SystemVerilog provide a built-in deep copy?**
No. Only handle assignment and shallow copy are built in.

## 3.4 Copy Constructors and Copy Methods

### What "copy constructor" means in SystemVerilog

In C++ a *copy constructor* is a constructor that takes another object of the same class and initialises the new object from it; the language calls it automatically in many places. SystemVerilog has **no automatic copy constructor**. The term is used loosely in interviews for "the code that makes a copy of an object". There are two idioms.

### Idiom 1: a constructor that accepts a source object

```systemverilog
class packet;
  bit [7:0] addr;
  bit [7:0] data;

  function new(packet src = null);
    if (src != null) begin
      this.addr = src.addr;
      this.data = src.data;
    end
  endfunction
endclass

packet p1 = new();        // src defaults to null: a fresh object
packet p2 = new(p1);      // "copy constructor": initialised from p1
```

Note the parentheses: `new(p1)` calls the constructor with an argument, while `new p1` is the built-in shallow copy.

Limitations: the single constructor now has to serve two purposes, its argument list is occupied by `src`, and it does not work well with inheritance, because the constructor cannot be virtual.

### Idiom 2: a copy() method (the standard practice)

```systemverilog
function packet copy();
  packet p = new();
  p.addr = this.addr;
  p.data = this.data;
  return p;
endfunction
```

This is the form used throughout these notes and in industry. A variation splits it in two, which becomes important with inheritance:

| Method | Job |
|---|---|
| `copy()` or `clone()` | Creates a new object of the right class and returns it |
| `copy_from(src)` / `do_copy(src)` | Copies the fields of `src` into an *existing* object (`this`) |

Section 5.6 shows why the split is needed when classes are extended.

### Comparison

| | `new(src)` constructor idiom | `copy()` method |
|---|---|---|
| Call | `p2 = new(p1);` | `p2 = p1.copy();` |
| Can be `virtual` (works through a base-class handle) | No | Yes |
| Leaves the constructor free for other arguments | No | Yes |
| Used by UVM | No | Yes (`copy`, `clone`, `do_copy`) |

### Interview questions

**Q1. Does SystemVerilog have copy constructors?**
Not as a language feature. A constructor can be written to take a source object and copy its fields, but the usual solution is a user-defined `copy()` method.

**Q2. What is the difference between `p2 = new p1;` and `p2 = new(p1);`?**
`new p1` is the built-in shallow copy; the constructor is not called. `new(p1)` calls the class constructor and passes `p1` as its argument; what happens depends entirely on how the constructor is written.

## 3.5 Comparing Objects

### Handle comparison versus content comparison

| Expression | Compares | True when |
|---|---|---|
| `p1 == p2` | The two handles | Both refer to the same object, or both are `null` |
| `p1.compare(p2)` (user-written) | The contents | The properties you chose to compare are equal |

Two separately created objects with identical field values are **not** equal under `==`. A scoreboard that checks `if (actual == expected)` on transaction handles will report a mismatch for every transaction, or, worse, a match when both handles happen to refer to the same object.

### Writing compare()

```systemverilog
function bit compare(packet rhs);
  if (rhs == null) return 0;                      // nothing to compare with
  return (this.addr == rhs.addr) &&
         (this.data == rhs.data) &&
         this.hdr.compare(rhs.hdr);               // deep compare of the nested object
endfunction
```

Guidelines:

- Check `rhs` for `null` first.
- Compare four-state properties that carry DUT values with `===`, so that X or Z is a mismatch and not an "unknown" (Module 1, Section 4.5).
- Compare nested objects by calling their `compare()`, not by comparing the handles.
- Leave out fields that are not part of the functional content (IDs, timestamps), or the comparison will always fail.

## 3.6 The Complete alu_txn Class

Everything in Parts 1 to 3 comes together in the transaction class of the ALU testbench. This is the class used in all later modules. The fields are `rand` so that Module 5 can randomize them; in this module `rand` has no effect and can be ignored.

```systemverilog file=tb_alu_txn.sv
module tb_alu_txn;

  // In the real testbench this type comes from alu_pkg (Module 1).
  // It is repeated here so that the file runs on its own.
  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;       // filled in by the monitor from the DUT
    int unsigned   id;

    function void print(string tag = "");
      $display("[%s] id=%0d a=%0d b=%0d op=%s result=%0d",
               tag, id, a, b, op.name(), result);
    endfunction

    function alu_txn copy();
      alu_txn t = new();
      t.a      = this.a;
      t.b      = this.b;
      t.op     = this.op;
      t.result = this.result;
      t.id     = this.id;
      return t;
    endfunction

    function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction
  endclass

  alu_txn t1, t2;

  initial begin
    t1 = new();
    t1.id     = 1;
    t1.a      = 8'd200;
    t1.b      = 8'd100;
    t1.op     = ALU_ADD;
    t1.result = 9'd300;
    t1.print("t1");

    t2 = t1.copy();
    t2.print("t2");
    $display("same object? %0d   same contents? %0d", t1 == t2, t1.compare(t2));

    t2.b = 8'd101;
    $display("after t2.b = 101: same contents? %0d", t1.compare(t2));
    t1.print("t1");
  end

endmodule
```

```output
[t1] id=1 a=200 b=100 op=ALU_ADD result=300
[t2] id=1 a=200 b=100 op=ALU_ADD result=300
same object? 0   same contents? 1
after t2.b = 101: same contents? 0
[t1] id=1 a=200 b=100 op=ALU_ADD result=300
```

**Line by line**

| Line | Explanation |
|---|---|
| `rand bit [7:0] a;` | A two-state random stimulus field (Module 1: `bit` for random data). |
| `logic [8:0] result;` | Four-state, because it will hold a value sampled from the DUT and must be able to show X. It is not `rand`: the testbench does not choose the result. |
| `int unsigned id;` | A serial number for tracing a transaction through the log. |
| `print(string tag = "")` | The tag lets each component label its own messages, for example `txn.print("DRV")`. |
| `copy()` | All fields are values, so there is nothing nested to deep-copy; a shallow copy `new t1` would give the same result. Writing `copy()` anyway keeps the interface uniform and ready for derived classes. |
| `compare(alu_txn rhs)` | `result` is compared with `===` so that an X from the DUT is a mismatch. `id` is deliberately not compared. |
| `t1 == t2` | 0: two different objects. |
| `t1.compare(t2)` | 1: the same contents. |
| `t2.b = 8'd101;` | Changes only the copy. The final `t1.print` proves the original is intact. |

> **Key point:** Every transaction class should offer at least `print()`, `copy()` and `compare()`. They are what the driver, monitor and scoreboard need, and UVM standardises exactly these operations (`print`, `copy`/`clone`, `compare`).

### Interview questions

**Q1. How do you compare two objects?**
With a user-written `compare()` method that compares the relevant properties (and calls `compare()` on nested objects). The `==` operator on handles only tells you whether they refer to the same object.

**Q2. Why is `result` declared `logic` and not `rand bit` in `alu_txn`?**
It is an output observed from the DUT, not a stimulus, so it is not randomized; and it must be four-state so that an X or Z driven by the DUT is preserved and detected in the comparison.

**Q3. Why does `compare()` use `===` for `result`?**
With `==`, an X in the DUT result would make the comparison X, which is treated as false in one place and silently ignored in another, depending on how the code is written. `===` always returns 0 or 1 and treats X as a mismatch.

**Q4. Why should a scoreboard store a copy of a transaction and not the handle it received?**
The sender may reuse and modify the same object later. If the scoreboard kept only the handle, its stored "expected" data would change underneath it.
