# Module 4 Overview

Module 4 teaches classes and object-oriented programming (OOP) in SystemVerilog from the very beginning. Every modern testbench, and the whole of UVM, is built from classes, so this module is the foundation for Modules 5 to 11.

**What this module covers**

| Part | Topics |
|---|---|
| Part 1 | What a class is, objects, handles, `null`, properties and methods, constructors, `new()`, `this` |
| Part 2 | The scope resolution operator `::`, static properties and methods, `extern` methods, `const` properties, `local` / `protected` / public access, forward `typedef class`, object lifetime and garbage collection |
| Part 3 | Handle assignment, shallow copy, deep copy, copy methods ("copy constructors"), comparing objects, the complete `alu_txn` class |
| Part 4 | The four OOP pillars, encapsulation, inheritance (single and multilevel), `super`, method overriding, why method overloading does not exist |
| Part 5 | Upcasting, virtual methods and dynamic binding, polymorphism, downcasting with `$cast`, abstract (virtual) classes, pure virtual methods, abstraction |
| Part 6 | Revision summary, interview questions, output-prediction, find-the-error, debugging, coding exercises with solutions |

**What you need from earlier modules**

| From | You should already know |
|---|---|
| Module 1 | `bit`, `logic`, `int`, `string`, `enum`, `struct`, `typedef`, the difference between static and dynamic casting, `===` versus `==` |
| Module 2 | Fixed arrays, dynamic arrays, queues (`push_back`, `foreach`) |
| Module 3 | Functions and tasks, arguments and default values, `automatic` versus `static` lifetime, `void` functions |

**Conventions.** The naming rules of Module 1 continue: types end in `_t`, enums in `_e`, small demonstration modules are called `tb_<topic>`. The running example is still the 8-bit ALU; in this module we build its transaction class, `alu_txn`, step by step. Classes are simulation-only: nothing in this module is synthesizable.

> **Note:** No simulator was available when these notes were written. Every "Expected output" block was derived by hand from the IEEE 1800-2017 rules. Run each example yourself (the files are in `examples/module-04/`) and investigate any difference.

# Part 1: Classes, Objects and Handles

## 1.1 Introduction to Classes

### In plain English

In Module 1 a `struct` let us group related data under one name: an address, some data and a read/write flag became one "request". But a struct is only data. The code that prints a request, copies it, compares it or checks it lives somewhere else, in loose functions that must be handed the struct every time.

A **class** groups the data *and* the code that works on that data into one unit. A class called `packet` contains the fields of a packet and also the functions `print()`, `copy()` and `compare()` that know how to handle a packet.

A class by itself is only a description, like the architectural drawing of a house. Nobody can live in a drawing. From one drawing you can build many houses, each with its own address and its own furniture. Each house is an **object**. To find a particular house you need its address written on a piece of paper; that piece of paper is a **handle**.

| Everyday idea | OOP term | In SystemVerilog |
|---|---|---|
| Drawing of a house | Class | `class packet; ... endclass` |
| A house that was built | Object (instance) | Created by `new()` |
| Paper with the address of one house | Handle | A variable of the class type: `packet p;` |
| Blank paper, no address on it | Null handle | `p == null` |
| Rooms and furniture | Properties (data members) | Variables declared inside the class |
| Things you can do in the house | Methods | Functions and tasks declared inside the class |

### Technical definition

- A **class** is a user-defined data type that encapsulates **properties** (variables) and **methods** (functions and tasks that operate on those variables).
- An **object** is an instance of a class. It is created dynamically, at run time, by calling the constructor `new()`. Memory for it is allocated at that moment.
- A **handle** is a variable whose type is a class. It holds a reference to an object, or the special value `null` when it refers to no object. A handle is like a safe pointer: you cannot do arithmetic on it and it can only refer to objects of a compatible class.

### Why classes are needed in verification

| Need in a testbench | Why modules and structs are not enough | What a class provides |
|---|---|---|
| Thousands of stimulus items (transactions) created during the run | Module instances are fixed at elaboration; they cannot be created at run time | Objects are created with `new()` whenever needed and freed automatically |
| Data and its operations kept together | A struct has no methods | Properties and methods in one unit |
| Random stimulus with rules | A struct has no `randomize()` method and no constraint blocks | `rand` properties, `constraint` blocks, `randomize()` (Module 5) |
| Reuse: a new test that is "the old one, slightly changed" | Modules cannot be extended; you copy and edit | Inheritance: `class new_test extends old_test` |
| One driver that handles many kinds of transaction | Requires `case` statements everywhere | Polymorphism through virtual methods |
| Passing data between components cheaply | A struct is copied on every assignment | Only the handle is passed; the object is not copied |

### Class versus module versus struct

| Property | `module` | `struct` | `class` |
|---|---|---|---|
| Purpose | Hardware hierarchy, testbench top | Group data | Group data and behaviour |
| Created | At elaboration, before time 0; fixed for the whole run | When the variable is declared | At run time with `new()` |
| Destroyed | Never | With its variable | Automatically, when no handle refers to it |
| Contains methods | Tasks and functions, yes | No | Yes |
| Contains `always`, `assign`, `initial` | Yes | No | No |
| A variable of this type holds | n/a (modules are instantiated, not stored) | The data itself | A handle (reference) |
| Assignment `a = b` | n/a | Copies all members | Copies the handle only |
| Inheritance and polymorphism | No | No | Yes |
| Randomization with constraints | No | No | Yes |
| Synthesizable | Yes | Yes | No |
| Typical use | DUT, `tb_top`, interfaces' containers | Signal bundles, bit fields | Transactions and every testbench component |

### Where classes may be declared

A class can be declared inside a `package` (the normal place in a real project, see Module 11), inside a `module`, `program` or `interface`, inside another class, or at file level outside everything (the "compilation unit" scope). To keep each example in one self-contained file, the examples in this module declare classes inside the demonstration module.

### Interview questions

**Q1. What is a class?**
A user-defined data type that encapsulates properties (data) and methods (tasks and functions) that operate on that data. It is a template from which objects are created at run time.

**Q2. What is the difference between a class and an object?**
A class is the type definition; it occupies no memory for data. An object is an instance of the class, created by `new()`, with its own copy of every non-static property.

**Q3. What is the difference between a class and a struct?**
A struct holds only data, is allocated statically, and a struct variable contains the data itself, so assignment copies everything. A class has data and methods, is created dynamically with `new()`, is accessed through a handle, and supports randomization, inheritance and polymorphism. Structs are synthesizable; classes are not.

**Q4. What is the difference between a class and a module?**
A module is a static hardware-style container that exists for the entire simulation and can hold `always` blocks, continuous assignments and instances. A class is a dynamic software-style type whose objects are created and destroyed during simulation. A class cannot contain `always` or `assign`, and a module cannot be extended or created at run time.

**Q5. Are classes synthesizable?**
No. Classes are a verification construct.

## 1.2 Class Declaration and Object Creation

### Syntax

```systemverilog
class class_name;
  // properties
  data_type property_name;

  // methods
  function return_type method_name(arguments);
    ...
  endfunction

  task task_name(arguments);
    ...
  endtask
endclass
```

Creating and using an object always takes three steps:

```systemverilog
packet p;        // 1. declare a handle        (p is null)
p = new();       // 2. construct an object     (memory is allocated, p refers to it)
p.addr = 8'h10;  // 3. use the object through the handle
```

Steps 1 and 2 may be combined: `packet p = new();`. The parentheses after `new` are optional when no arguments are passed, so `p = new;` is the same as `p = new();`.

### How it works internally

```text
  After   packet p;                         After   p = new();

  handle p                                  handle p                 object (on the heap)
  +----------+                              +----------+            +---------------------+
  |   null   |    no object exists          |    *-----|----------> | addr : 8'h00        |
  +----------+                              +----------+            | data : 8'h00        |
                                                                    +---------------------+
                                                                    methods print(), ...
                                                                    are stored once per
                                                                    CLASS, not per object
```

What `new()` does, in order:

1. Allocates memory for one object of the class.
2. Gives every property its initial value: the default of its type (Module 1, Section 4.2), or the initialiser written in its declaration.
3. Executes the body of the constructor function `new`, if the class defines one.
4. Returns a reference to the object, which is stored in the handle on the left of the assignment.

Methods are code, and code is not duplicated. One thousand `packet` objects contain one thousand copies of `addr` and `data` but share one copy of `print()`.

### Complete example

```systemverilog file=tb_class_basic.sv
module tb_class_basic;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    function void print(string tag = "");
      $display("[%s] addr=%h data=%h", tag, addr, data);
    endfunction
  endclass

  packet p1;                       // a handle; no object yet

  initial begin
    if (p1 == null) $display("p1 is null before new()");

    p1 = new();                    // the object is created here
    p1.print("after new");

    p1.addr = 8'h10;
    p1.data = 8'hAB;
    p1.print("after set");
  end

endmodule
```

```output
p1 is null before new()
[after new] addr=00 data=00
[after set] addr=10 data=ab
```

**Line by line**

| Line | Explanation |
|---|---|
| `class packet;` ... `endclass` | Declares a new data type called `packet`. No memory is allocated for `addr` or `data` yet. |
| `bit [7:0] addr;` `bit [7:0] data;` | Properties. Each object will have its own copy. |
| `function void print(string tag = "");` | A method. Inside it, `addr` and `data` mean "the `addr` and `data` of the object this method was called on". |
| `packet p1;` | Declares a handle of type `packet`. Its value is `null`. |
| `if (p1 == null)` | A handle can be compared with `null`. This is how you test whether an object exists. |
| `p1 = new();` | Allocates a `packet` object and stores its reference in `p1`. |
| `p1.print("after new");` | Calls the method on the object. The properties are 0 because `bit` defaults to 0. |
| `p1.addr = 8'h10;` | Writes a property through the handle, using the dot operator. |

> **Common mistake:** Forgetting step 2. Declaring `packet p1;` does **not** create an object. Using `p1.addr` before `p1 = new();` is a run-time fatal error: "null object access" (also reported as "null pointer dereference"). It compiles without any warning. This is the most common run-time error in class-based testbenches.

> **Common mistake:** Writing a declaration after a statement inside a `begin`...`end` block. All declarations (`packet p;`) must come before the first statement of the block.

### Interview questions

**Q1. How do you create an object?**
Declare a handle of the class type and assign it the result of the constructor: `packet p; p = new();` or in one line `packet p = new();`.

**Q2. What does `new()` do?**
It allocates memory for an object, initialises the properties (type default or declaration initialiser), runs the constructor body, and returns the object's reference.

**Q3. What happens if you use a handle without calling `new()`?**
The handle is `null`. Accessing a non-static property or calling a non-static method through it causes a fatal run-time error (null object access). The compiler does not detect it.

**Q4. When is the memory for a class allocated?**
When `new()` is called, at run time, not when the class or the handle is declared.

## 1.3 Class Properties and Methods

### Properties

A **property** is a variable declared inside a class. It can be of any data type: integral types, `real`, `string`, enums, structs, arrays of every kind, events, virtual interfaces, and handles of other classes (or of the same class, which is how linked lists are built).

```systemverilog
class example;
  bit [7:0]  addr;                 // integral
  int        delay = 5;            // with an initial value
  string     name  = "item";
  bit [7:0]  payload [];           // dynamic array (Module 2)
  int        history [$];          // queue
  example    next;                 // handle of the same class
endclass
```

A property may have an initialiser in its declaration. The initialiser is applied every time an object is created, before the constructor body runs.

### Methods

A **method** is a function or a task declared inside a class.

| | Function in a class | Task in a class |
|---|---|---|
| Can consume simulation time (`#`, `@`, `wait`) | No | Yes |
| Returns a value | Yes (or `void`) | No (uses `output` / `ref` arguments) |
| Typical use | `print`, `copy`, `compare`, `get_*`, calculations, `new` | `run`, `drive`, `wait_for_reset`: anything that follows the clock |

Two rules are specific to class methods:

1. **Class methods always have automatic lifetime.** Each call has its own copies of the arguments and local variables, so methods are re-entrant and can be called from several threads at once. Declaring a class method with static lifetime (`function static ...`) is illegal. (In a module, tasks and functions are static by default; see Module 3.)
2. **A method can use every property and every other method of its own class directly**, without a handle. The compiler knows they belong to the object on which the method was called.

### Accessing class members

Members are accessed with the dot operator through a handle:

```systemverilog
handle.property            // read or write a property
handle.method(args)        // call a method
handle.sub_handle.property // chain through a nested object
```

### Complete example

```systemverilog file=tb_class_methods.sv
module tb_class_methods;

  class counter;
    int    count;
    string name = "cnt";

    function void incr(int step = 1);
      count += step;
    endfunction

    function int get();
      return count;
    endfunction

    task wait_then_incr(int delay);
      #delay;
      count++;
      $display("[%0t] %s: count=%0d", $time, name, count);
    endtask
  endclass

  counter c;

  initial begin
    c = new();
    c.incr();                    // step defaults to 1
    c.incr(5);
    $display("[%0t] %s: count=%0d", $time, c.name, c.get());

    c.wait_then_incr(10);        // a task: simulation time advances
    c.wait_then_incr(5);
  end

endmodule
```

```output
[0] cnt: count=6
[10] cnt: count=7
[15] cnt: count=8
```

**Line by line**

| Line | Explanation |
|---|---|
| `int count;` | Starts at 0 in every new object. |
| `string name = "cnt";` | A declaration initialiser: every new object starts with this name. |
| `function void incr(int step = 1);` | A method with a default argument. It changes the object's own `count`. |
| `function int get();` | Returns a value. Called a "getter". |
| `task wait_then_incr(int delay);` | A task may contain `#delay`. A function may not. |
| `c.incr(); c.incr(5);` | 0 + 1 + 5 = 6. |
| `c.wait_then_incr(10);` | The calling `initial` block is suspended for 10 time units inside the task. |

> **Verification application:** In the layered testbench of Module 9, every component is a class with a `task run()`. The driver's `run()` contains a `forever` loop that waits for a clock edge and drives pins; the transaction class has only functions (`print`, `copy`, `compare`) because a transaction is passive data.

### Interview questions

**Q1. Can a class contain tasks as well as functions?**
Yes. Functions are used for operations that take no simulation time; tasks for operations that wait on clocks, delays or events.

**Q2. What is the default lifetime of a class method?**
Automatic. It cannot be changed to static.

**Q3. Can a class contain an `always` block or an `initial` block?**
No. A class contains only declarations: properties, methods, constraints, covergroups, typedefs and parameters. Activity is started by calling a task of the object from an `initial` block (or from `fork`), typically a `run()` task with a `forever` loop.

**Q4. Can a property of a class be a handle to the same class?**
Yes. `class node; node next; endclass` is legal and is used to build linked data structures.

## 1.4 Object Handles and Null Handles

### In plain English

A handle is not the object. It is the address of the object. Several handles can hold the same address, and a handle can be changed to hold a different address. Understanding this one fact prevents most OOP bugs in testbenches.

### Technical definition

- A **handle** is a variable of a class type that stores a reference to an object of that class (or of a class derived from it), or `null`.
- `null` is the default value of every handle. It means "refers to no object".
- Operations allowed on handles: assignment (`h1 = h2`, `h = null`), equality comparison (`==`, `!=`, `===`, `!==`, all of which compare the *references*), use as a condition after comparison with `null`, and member access with the dot operator.
- Operations not allowed: arithmetic, casting to or from integers, taking the address of a variable.

### Handle versus C pointer

| Property | C pointer | SystemVerilog handle |
|---|---|---|
| Arithmetic (`p + 1`) | Allowed | Not allowed |
| Can point to any memory | Yes | Only to an object of a compatible class |
| Cast from an integer | Allowed | Not allowed |
| Dangling reference (pointing to freed memory) | Possible | Impossible: an object lives as long as any handle refers to it |
| Memory must be freed by the programmer | Yes (`free`) | No, garbage collection is automatic |
| Null access | Undefined behaviour | Clean run-time fatal error |

### Complete example

```systemverilog file=tb_handles.sv
module tb_handles;

  class packet;
    bit [7:0] addr;
  endclass

  packet p1, p2, p3;

  initial begin
    p1 = new();  p1.addr = 8'h01;        // object A
    p2 = new();  p2.addr = 8'h02;        // object B

    p3 = p1;                             // p3 refers to object A too
    p3.addr = 8'h33;
    $display("1. p1.addr=%h p2.addr=%h p3.addr=%h", p1.addr, p2.addr, p3.addr);

    if (p1 == p3) $display("2. p1 and p3 refer to the same object");
    if (p1 != p2) $display("3. p1 and p2 refer to different objects");

    p1 = null;                           // object A is still reachable through p3
    $display("4. p3.addr=%h (object A is alive)", p3.addr);

    p3 = p2;                             // nothing refers to object A now
    $display("5. p3.addr=%h (p3 now refers to object B)", p3.addr);

    if (p1 == null) $display("6. p1 is null: p1.addr would be a fatal error");
    // p1.addr = 8'h55;                  // run-time error: null object access
  end

endmodule
```

```output
1. p1.addr=33 p2.addr=02 p3.addr=33
2. p1 and p3 refer to the same object
3. p1 and p2 refer to different objects
4. p3.addr=33 (object A is alive)
5. p3.addr=02 (p3 now refers to object B)
6. p1 is null: p1.addr would be a fatal error
```

**Execution, step by step**

```text
  after p1 = new(); p2 = new(); p3 = p1;     after p1 = null;         after p3 = p2;

  p1 ----+                                   p1 --> null              p1 --> null
         +--> [ object A : addr = 33 ]
  p3 ----+                                   p3 --> [ object A ]      [ object A ] garbage,
                                                                      memory reclaimed
  p2 -------> [ object B : addr = 02 ]       p2 --> [ object B ]      p2 --+
                                                                           +--> [ object B ]
                                                                      p3 --+
```

| Line | Explanation |
|---|---|
| `p3 = p1;` | Copies the reference, not the object. There are still only two objects. |
| `p3.addr = 8'h33;` | Changes object A. `p1.addr` shows 33 because `p1` refers to the same object. |
| `p1 == p3` | Handle comparison: true when both refer to the same object. It does not compare contents. |
| `p1 = null;` | `p1` lets go of object A. The object survives because `p3` still refers to it. |
| `p3 = p2;` | Now no handle refers to object A. It can never be reached again, so the simulator reclaims its memory (Section 2.8). |
| Commented line | Accessing a property through a null handle stops the simulation with a fatal error. |

### Protecting against null handles

```systemverilog
if (txn == null) $fatal(1, "driver received a null transaction");

if (txn != null && txn.addr == 8'h10) ...   // txn.addr is read only if txn exists
```

> **Interview trap:** "What does `p1 == p2` compare when `p1` and `p2` are class handles?" It compares the handles: the result is 1 only if both refer to the *same* object (or both are `null`). Two different objects with identical contents are not equal under `==`. To compare contents you write a `compare()` method (Section 3.5).

> **Common mistake:** Assuming that a handle that is a class property is constructed automatically. A property `header hdr;` inside a class is `null` after the outer object is created, unless the constructor (or a declaration initialiser) calls `hdr = new();`.

### Interview questions

**Q1. What is a handle?**
A variable of a class type that holds a reference to an object, or `null`.

**Q2. What is the default value of a handle?**
`null`.

**Q3. What is the difference between a handle and an object?**
The object is the block of memory holding the property values, created by `new()`. The handle is a named variable that refers to it. One object can have many handles; one handle refers to at most one object at a time.

**Q4. How is a handle different from a C pointer?**
A handle is type-safe: no arithmetic, no casting from integers, it can refer only to objects of a compatible class, it can never dangle, and the memory it refers to is reclaimed automatically.

**Q5. What happens after `h2 = h1;`?**
Both handles refer to the same object. No new object is created. A change made through one handle is visible through the other.

**Q6. How do you check that a handle is valid before using it?**
Compare it with `null`: `if (h != null) ...`.

## 1.5 Constructors and the new() Method

### In plain English

When a house is built, somebody must do the initial setup: fit the doors, connect the electricity. The **constructor** is the function that does the initial setup of an object. It runs automatically, once, at the moment the object is created.

### Technical definition

- The constructor is a special function named `new`. It is called when an object is created with `handle = new(arguments);`.
- It has **no return type** (not even `void`). It implicitly returns the reference to the newly created object.
- It may take arguments, including arguments with default values.
- A class can have **only one** constructor, because SystemVerilog has no method overloading (Section 4.6).
- It is a function, so it cannot contain timing controls.
- It cannot be declared `static` or `virtual`.

### Default constructor and custom constructor

| | Default (implicit) constructor | Custom (user-defined) constructor |
|---|---|---|
| Who writes it | The compiler provides it when the class does not define `new` | You write `function new(...); ... endfunction` |
| Arguments | None | Any, with or without defaults |
| What it does | Allocates the object; sets each property to its type default or declaration initialiser; in a derived class also calls the base-class constructor | The same, and then runs your statements |
| Typical use | Simple data classes | Setting initial values, creating nested objects, receiving a name, a virtual interface or mailbox handles |

### Syntax

```systemverilog
class packet;
  bit [7:0] addr;
  bit [7:0] data;

  function new(bit [7:0] a = 8'h00, bit [7:0] d = 8'hFF);   // custom constructor
    addr = a;
    data = d;
  endfunction
endclass

packet p1 = new();              // both defaults
packet p2 = new(8'h10);         // a = 10, d = default
packet p3 = new(8'h20, 8'h55);  // positional arguments
packet p4 = new(.d(8'h77));     // argument passed by name
```

### Order of events inside new()

```text
   p = new(8'h10, 8'h55);

   1. memory for the object is allocated
   2. (derived classes only) the base-class constructor runs first      -> Section 4.4
   3. every property gets its initial value:
          - the initialiser from its declaration, if there is one
          - otherwise the default of its data type (0, X, "", null ...)
   4. the statements in the body of function new() execute
   5. the reference to the object is returned and stored in p
```

Because step 3 comes before step 4, the constructor body can read the declaration initialisers and may overwrite them.

### Complete example

```systemverilog file=tb_constructor.sv
module tb_constructor;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;
    int       len = 4;                     // declaration initialiser

    function new(bit [7:0] a = 8'h00, bit [7:0] d = 8'hFF);
      $display("   new() starts with len=%0d", len);
      addr = a;
      data = d;
      len  = len * 2;
    endfunction

    function void print(string tag = "");
      $display("[%s] addr=%h data=%h len=%0d", tag, addr, data, len);
    endfunction
  endclass

  packet p1, p2, p3, p4;

  initial begin
    p1 = new();              p1.print("p1");
    p2 = new(8'h10);         p2.print("p2");
    p3 = new(8'h20, 8'h55);  p3.print("p3");
    p4 = new(.d(8'h77));     p4.print("p4");
  end

endmodule
```

```output
   new() starts with len=4
[p1] addr=00 data=ff len=8
   new() starts with len=4
[p2] addr=10 data=ff len=8
   new() starts with len=4
[p3] addr=20 data=55 len=8
   new() starts with len=4
[p4] addr=00 data=77 len=8
```

**Line by line**

| Line | Explanation |
|---|---|
| `int len = 4;` | Applied to every new object before the constructor body runs. |
| `function new(bit [7:0] a = 8'h00, bit [7:0] d = 8'hFF);` | No return type is written. Both arguments are optional because they have defaults. |
| `$display("   new() starts with len=%0d", len);` | Prints 4, proving that the declaration initialiser has already been applied. |
| `len = len * 2;` | The constructor may modify the initial value: 8. |
| `p1 = new();` | Uses both defaults. |
| `p2 = new(8'h10);` | First argument given, second defaulted. |
| `p4 = new(.d(8'h77));` | Named argument binding skips `a`, which takes its default. |

### Constructors that build nested objects and receive connections

In a real testbench the constructor has two typical jobs: create the objects this object owns, and store the connections it was given.

```systemverilog
class alu_driver;
  virtual alu_if      vif;            // connection to the DUT pins        (Module 8)
  mailbox #(alu_txn)  gen2drv_mbx;    // connection to the generator       (Module 7)

  function new(virtual alu_if vif, mailbox #(alu_txn) gen2drv_mbx);
    this.vif         = vif;           // "this" is explained in the next section
    this.gen2drv_mbx = gen2drv_mbx;
  endfunction
endclass
```

> **Interview trap:** "What is the return type of `new`?" It has none; writing `function void new()` is a syntax error. The constructor implicitly returns the handle of the created object.

> **Interview trap:** "Can a class have several constructors with different argument lists?" No. SystemVerilog does not support overloading. One `new` with default arguments covers the common cases.

> **Common mistake:** Declaring a constructor with required arguments and then calling `new()` without them. This is a compile error. Give the arguments default values if the object should also be constructible without them.

> **Common mistake:** Putting a delay or `@(posedge clk)` in `new`. The constructor is a function and cannot consume time. Put time-consuming setup in a task such as `run()` or `reset()`.

### new() versus new[]

| | `new()` | `new[]` |
|---|---|---|
| Purpose | Constructs a class object | Allocates a dynamic array (Module 2) |
| Brackets | Parentheses, arguments of the constructor | Square brackets, the number of elements |
| Example | `p = new(8'h10);` | `arr = new[20];` |

A dynamic array of handles needs both: `arr = new[4];` creates four null handles, and then `foreach (arr[i]) arr[i] = new();` creates the four objects.

### Interview questions

**Q1. What is a constructor?**
A special function named `new` that is called automatically when an object is created. It allocates the object and initialises it.

**Q2. What is the default constructor?**
The implicit constructor supplied by the compiler when the class does not define `new`. It takes no arguments and sets every property to its declaration initialiser or type default.

**Q3. Can a constructor have arguments? Can it return a value?**
It can have arguments, with or without default values. It has no declared return type and cannot return a user value; it implicitly returns the object handle.

**Q4. Can the constructor be a task?**
No. It is always a function, so it cannot contain delays or event controls.

**Q5. In which order are declaration initialisers and the constructor body executed?**
Declaration initialisers first, then the constructor body. In a derived class the base-class constructor runs before both (Section 4.4).

**Q6. What is the difference between `new()` and `new[]`?**
`new()` constructs a class object. `new[n]` sets the size of a dynamic array.

**Q7. Can `new` be virtual or static?**
No.

## 1.6 The this Keyword

### In plain English

Inside a method, `this` means "the object I was called on". Most of the time you do not need to write it, because a plain property name already means "my own property". You need it in two situations: when a local name hides a property name, and when the object must hand its own handle to somebody else.

### Technical definition

`this` is a predefined handle, available inside every non-static method of a class, that refers to the object on which the method was invoked. `this.x` always means the class property `x` of the current object, whatever local variables or arguments are in scope.

### Why it is needed: name shadowing

SystemVerilog resolves a name by searching from the innermost scope outward: first the local variables and arguments of the method, then the class properties. If an argument has the same name as a property, the plain name refers to the **argument**, and the property is hidden ("shadowed").

```text
   function new(bit [7:0] addr);
     addr = addr;          // argument = argument    -> the property is never written
     this.addr = addr;     // property = argument    -> correct
   endfunction

   name lookup for the plain name "addr":
      1. method scope (arguments, local variables)   <- found here: the argument
      2. class scope (properties)                     <- never reached
```

Using the same name for the argument and the property is the normal coding style, because it avoids inventing names such as `a`, `addr_i` or `new_addr`. That style depends on `this`.

### Uses of this

| Use | Example |
|---|---|
| Distinguish a property from an argument or local variable of the same name | `this.addr = addr;` |
| Pass the current object to another object or function | `scoreboard.register(this);` |
| Return the current object, for example to allow call chaining | `return this;` |
| Make it explicit that a name is a class member (readability) | `this.count++;` |

`this` cannot be used in a static method, because a static method is not called on any object (Section 2.3).

### Complete example

```systemverilog file=tb_this.sv
module tb_this;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    function new(bit [7:0] addr, bit [7:0] data);
      this.addr = addr;          // property = argument
      this.data = data;
    endfunction

    function void bad_set(bit [7:0] addr);
      addr = addr;               // BUG: assigns the argument to itself
    endfunction

    function void good_set(bit [7:0] addr);
      this.addr = addr;
    endfunction

    function packet get_self();
      return this;               // returns a handle to the current object
    endfunction
  endclass

  packet p, q;

  initial begin
    p = new(8'h11, 8'h22);
    $display("1. after new      : addr=%h data=%h", p.addr, p.data);

    p.bad_set(8'h99);
    $display("2. after bad_set  : addr=%h", p.addr);

    p.good_set(8'h99);
    $display("3. after good_set : addr=%h", p.addr);

    q = p.get_self();
    if (q == p) $display("4. get_self() returned the same object");
  end

endmodule
```

```output
1. after new      : addr=11 data=22
2. after bad_set  : addr=11
3. after good_set : addr=99
4. get_self() returned the same object
```

**Line by line**

| Line | Explanation |
|---|---|
| `this.addr = addr;` | Left side: the property of the current object. Right side: the constructor argument. |
| `addr = addr;` in `bad_set` | Both names resolve to the argument. The property keeps its old value, and there is no compiler error. Some tools give a warning. |
| Output line 2 | `addr` is still 11: the bug is silent. |
| `return this;` | The method hands back the handle of the object it was called on. |
| `q == p` | Both handles refer to one object. |

> **Interview trap:** "What does `addr = addr;` do in a constructor whose argument is called `addr`?" Nothing useful: it assigns the argument to itself. The class property is not changed. The fix is `this.addr = addr;`.

> **Verification application:** `this` is used when a component registers itself with another, for example a monitor that passes `this` to a callback object, and in UVM where a child component is created with `new(name, this)` so that the child knows its parent.

### Interview questions

**Q1. What is `this`?**
A predefined handle that refers to the current object, that is, the object on which the method was called.

**Q2. When must `this` be used?**
When a method argument or local variable has the same name as a class property and you need to refer to the property; and when the object needs to pass or return its own handle.

**Q3. Can `this` be used in a static method?**
No. A static method has no current object.

**Q4. Can `this` be used outside a class?**
No. It is only meaningful inside non-static class methods (and in constraints and property initialisers of the class).
