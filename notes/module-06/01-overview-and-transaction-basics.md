# Module 6 Overview

This module has two halves that belong together.

The first half is about the **transaction class**: the object that carries one unit of stimulus or response through a class-based testbench. You already know every language feature it uses. Module 4 taught classes, handles and copying; Module 5 taught `rand`, constraints and `randomize()`. Here those features are assembled, step by step, into `alu_txn`, the transaction used by every component of the layered testbench in Module 9.

The second half is about **verification planning**: what verification is, how a specification is turned into a list of things to check, how tests and coverage are planned, how a testbench checks itself, and how a project decides that verification is finished. Interviewers for Design Verification roles ask about this at least as much as they ask about syntax, because it shows whether a candidate understands the job.

**What you will be able to do after this module**

- Explain what a transaction is and why testbenches work with transactions instead of pin values.
- Write a complete transaction class with properties, a constructor, constraints, and `print`, `copy`, `compare` and `convert2string` methods.
- Reuse a transaction through inheritance to create test-specific stimulus without editing the testbench.
- Explain verification, the verification plan, the test plan, directed and constrained-random testing, code and functional coverage, and the self-checking testbench.
- Take a specification (the 8-bit ALU) and produce a feature list, a verification plan, a test plan, a coverage plan and sign-off criteria.

**What you need from earlier modules**

| From | You must already know |
|---|---|
| Module 1 | Two-state and four-state types, `enum`, `==` versus `===`, the ALU design (`alu_pkg`, `alu`) |
| Module 2 | Queues and `foreach` (used to hold lists of transactions) |
| Module 3 | Functions, tasks, default arguments, `automatic` lifetime |
| Module 4 | Classes, `new()`, handles, `null`, shallow and deep copy, inheritance, `virtual` methods |
| Module 5 | `rand`, constraint blocks, `dist`, `randomize()`, `randomize() with`, `constraint_mode()` |

**What comes later**

| Topic touched here | Covered fully in |
|---|---|
| Passing transactions between components with a mailbox | Module 7 |
| Driving and sampling DUT pins through `alu_if` and `vif` | Module 8 |
| Generator, driver, monitor, scoreboard, environment, test | Module 9 |
| Covergroups and assertions | Module 10 |

**About the examples.** The examples use the ALU package from Module 1. A copy of `alu_pkg.sv` (and of `alu.sv`, needed by one example) is in `examples/module-06/` so that the folder is complete by itself. Every `tb_*.sv` file in this module needs `alu_pkg.sv` compiled before it.

> **Note:** As in the other modules, the "Expected output" blocks were derived by hand from the IEEE 1800 rules and were not captured from a simulator. Where an example uses randomization, the exact values cannot be predicted; such output is labelled as a sample, and the example prints at least one line that is the same on every run.

```systemverilog file=alu_pkg.sv
package alu_pkg;

  typedef enum logic [2:0] {
    ALU_ADD = 3'b000,
    ALU_SUB = 3'b001,
    ALU_AND = 3'b010,
    ALU_OR  = 3'b011,
    ALU_XOR = 3'b100,
    ALU_NOT = 3'b101,
    ALU_SHL = 3'b110,
    ALU_SHR = 3'b111
  } alu_op_e;

endpackage
```

# Part 1: Transactions and Transaction Classes

## 1.1 What Is a Transaction?

### In plain English

Look at the ALU from the outside. To make it do one addition, the testbench must put a value on `a`, a value on `b`, the code for "add" on `op`, raise `valid_in`, wait for a clock edge, lower `valid_in`, and one cycle later read `result` while `valid_out` is high. That is seven signal-level actions spread over two clock cycles.

But in your head the whole thing is one idea: **"add 200 and 100, expect 300"**.

A **transaction** is that one idea, written down as data. It records *what* is to be done (operation, operands) and *what came back* (result). It does not record *how* the pins must wiggle or *when*. The "how" and "when" belong to the driver and the monitor.

### Technical definition

A transaction is an abstract, pin-independent and time-independent description of one complete, meaningful unit of activity on an interface. In a SystemVerilog testbench it is an object of a **transaction class**, whose properties are the fields of that activity and whose methods operate on those fields.

Other names for the same thing: *sequence item* (UVM), *packet*, *data item*, *transfer*, *bus item*.

| Design | One transaction is | Typical fields |
|---|---|---|
| 8-bit ALU (this course) | One operation | `op`, `a`, `b`, `result` |
| Synchronous FIFO | One write or one read | `kind` (write/read), `data` |
| Memory or register bus (APB, AXI-Lite) | One read or write transfer | `addr`, `data`, `write`, `strobe`, `response` |
| AXI | One burst | `addr`, `len`, `size`, `burst`, a queue of data beats, `id` |
| Ethernet | One frame | `dst`, `src`, `type`, payload bytes, `crc` |
| UART | One character | `data`, `parity_error`, `framing_error` |
| Processor | One instruction | `opcode`, register numbers, immediate |

### Levels of abstraction

```text
Transaction level  (what)        alu_txn { op = ALU_ADD, a = 200, b = 100, result = 300 }
                                            |                              ^
                           driver converts  |                              | monitor turns
                           transaction to   v                              |  pins back to a
                           pin activity                                    |  transaction
Signal level  (how and when)
                      ___     ___     ___     ___
        clk       ___|   |___|   |___|   |___|   |___
                          _______
        valid_in  _______|       |___________________
                          _______
        a, b, op  -------<_______>-------------------
                                  _______
        valid_out _______________|       |___________
                                  _______
        result    ---------------<__300__>-----------
```

Everything above the line is easy to generate, print, copy, compare and reason about. Everything below the line is detail that only two components (driver and monitor) need to know.

### Where transactions travel in a testbench

```text
+-----------+  alu_txn   +--------+   pins    +-------+   pins    +---------+
| generator | ---------> | driver | --------> |  DUT  | --------> | monitor |
+-----------+  mailbox   +--------+  alu_if   +-------+  alu_if   +---------+
 creates and                converts                                 rebuilds an
 randomizes                 txn -> pins                              alu_txn from pins
                                                                          |
                                                                          | alu_txn
                                                                          v
                                                                   +------------+
                                                                   | scoreboard |
                                                                   +------------+
                                                                    predicts the expected
                                                                    result and compares
```

Notice that the transaction class is the only type that **every** component uses. That is why it is designed first and designed carefully.

### Interview questions

**Q1. What is a transaction?**
A high-level, pin-independent description of one complete operation on an interface: for example one ALU operation, one bus read or write, or one packet. In a class-based testbench it is an object whose properties are the fields of that operation.

**Q2. What is the difference between transaction-level and signal-level?**
Signal level describes individual pin values at individual clock edges. Transaction level describes the operation as a whole (operands, command, result) without timing. The driver converts from transaction level to signal level, and the monitor converts back.

**Q3. Give an example of a transaction for a memory.**
One write or read: `rand bit write; rand bit [15:0] addr; rand bit [31:0] wdata; logic [31:0] rdata;`.

**Q4. Does a transaction contain clock and reset?**
No. Clock, reset and handshake timing are signal-level concepts that live in the interface and are handled by the driver and monitor. A transaction may contain *timing intent* as data, for example `rand int unsigned delay;` meaning "wait this many idle cycles before driving me", but not the clock itself.

## 1.2 Why Do We Need Transaction Classes?

### The testbench without transactions

In a Verilog-style testbench, stimulus is written directly on the pins:

```systemverilog
@(negedge clk); a = 8'd200; b = 8'd100; op = ALU_ADD; valid_in = 1;
@(negedge clk); valid_in = 0;
if (result !== 9'd300) $error("add failed");

@(negedge clk); a = 8'd5;   b = 8'd10;  op = ALU_SUB; valid_in = 1;
@(negedge clk); valid_in = 0;
if (result !== 9'h1FB) $error("sub failed");
// ... and so on, three lines per operation, for every operation you can think of
```

Problems with this style:

| Problem | Consequence |
|---|---|
| What to send and how to send it are mixed in the same lines | A change in the protocol (say, `valid_in` must be held for two cycles) means editing every test |
| Every value is typed by hand | Only the cases the engineer thought of are tested |
| Nothing can be randomized as a unit | There is no object on which to call `randomize()` or write constraints |
| The expected value is typed by hand | Slow, error-prone, impossible for thousands of operations |
| There is no object to pass around | Generation, driving, monitoring and checking cannot be split into separate, reusable components |
| Nothing can be printed or counted as an operation | Debugging means reading waveforms |

### What the transaction class gives you

| Need | How a transaction class provides it |
|---|---|
| Separate "what" from "how" | The class holds only the fields. Pin-level protocol lives in one place, the driver |
| Random stimulus | Fields are declared `rand`; one call to `randomize()` produces a complete legal operation |
| Legal stimulus | Constraint blocks inside the class define what is legal and what is interesting |
| Communication | A handle to the object is passed through a mailbox from one component to the next |
| Automatic checking | The scoreboard receives an object containing inputs and actual result, computes the expected result from the inputs, and compares |
| Debug | A `print()` method shows the whole operation in one line of the log |
| Reuse | A test extends the class and adds constraints; the generator, driver, monitor and scoreboard are untouched |
| Coverage | A covergroup samples the fields of the object |

### Why a class and not a struct?

Module 1 showed that a `struct` can also group fields. The comparison explains why testbenches use a class:

| Requirement of a transaction | `struct` | `class` |
|---|---|---|
| Group the fields under one name | Yes | Yes |
| `rand` fields with a `randomize()` method | No method of its own | Yes |
| Constraint blocks | No | Yes |
| Methods (`print`, `copy`, `compare`) kept with the data | No | Yes |
| Extend with new fields or constraints without editing the original | No | Yes, by inheritance |
| Replace by a specialised version at run time | No | Yes, by polymorphism |
| Created on demand, any number, during simulation | Fixed at declaration | Yes, with `new()` |
| Passed between components cheaply | The whole struct is copied | Only the handle is copied |
| Synthesizable | Yes | No (not needed in a testbench) |

Structs remain the right choice for the DUT side (packed bit fields on ports). The testbench side uses classes.

> **How to say it in an interview:** "A transaction class raises the testbench from signal level to transaction level. It bundles the fields of one operation, lets me randomize them under constraints, gives me one object to pass from generator to driver and from monitor to scoreboard, and keeps the print, copy and compare routines with the data. Because it is a class, a test can extend it to change the stimulus without touching the rest of the environment."

### Interview questions

**Q1. Why do we need a transaction class?**
To separate what is being tested from how it is driven on the pins; to allow constrained-random generation of whole operations; to give the testbench components a common object to exchange; and to make stimulus and results easy to print, copy, compare, cover and reuse.

**Q2. Why is a transaction a class and not a struct?**
A class supports `randomize()` with constraint blocks, methods, inheritance and polymorphism, and dynamic creation. A struct supports none of these, so stimulus could not be constrained, extended per test, or overridden.

**Q3. Which testbench components use the transaction?**
All of them. The generator creates and randomizes it, the driver converts it to pin activity, the monitor rebuilds it from pin activity, the scoreboard compares it, and the coverage collector samples it.

**Q4. If the pin-level protocol of the DUT changes but its function does not, which parts of the testbench change?**
Only the driver and the monitor (and the interface). The transaction class, generator, scoreboard and tests are unaffected. This is the practical benefit of the separation.

## 1.3 Building a Transaction Class: Properties

### How to decide which fields a transaction needs

Start from the DUT's port list and its specification, and sort every signal into one of four groups:

| Group | Question to ask | In the transaction? | ALU |
|---|---|---|---|
| Stimulus data | Does the testbench choose this value for each operation? | Yes, as a `rand` field | `a`, `b`, `op` |
| Response data | Does the DUT produce this value for each operation? | Yes, as a non-`rand` field | `result` |
| Protocol and timing | Is this a handshake, clock or reset signal? | No. The driver and monitor handle it | `clk`, `rst_n`, `valid_in`, `valid_out` |
| Bookkeeping | Does the testbench need it for tracking or debug? | Yes, as a non-`rand` field | `id` |

### Choosing the type of each field

This is a direct application of Module 1.

| Field | Declaration | Why this type |
|---|---|---|
| Operands | `rand bit [7:0] a, b;` | The testbench chooses them. The solver only produces 0 and 1, so two-state is correct and faster. Unsigned, exactly the port width |
| Operation | `rand alu_op_e op;` | Using the enum means the solver can only pick one of the eight legal names, logs print `ALU_ADD` instead of `0`, and coverage gets one bin per name |
| Result | `logic [8:0] result;` | It is sampled from the DUT. If the DUT drives X, the transaction must hold X so that the scoreboard can report it. Therefore four-state. Not `rand`: the testbench does not choose it |
| Identifier | `int unsigned id;` | A serial number so that a line in the log can be matched to a transaction. Not `rand` |

> **Interview trap:** "Why is `result` declared `logic` when `a` and `b` are `bit`?" Because of where the value comes from. `a` and `b` are generated by the testbench and can never be X. `result` is copied from a DUT pin by the monitor; a two-state field would silently turn an X output into 0 and the comparison could pass. Fields that hold DUT outputs are four-state.

### The first version of the class

```systemverilog file=tb_txn_basic.sv
module tb_txn_basic;
  import alu_pkg::*;

  class alu_txn;
    // ---- stimulus: chosen by the testbench, therefore rand ----
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;

    // ---- response: sampled from the DUT, therefore four-state, not rand ----
    logic [8:0]    result;

    // ---- bookkeeping ----
    int unsigned   id;
  endclass

  alu_txn t1, t2;

  initial begin
    t1 = new();
    t2 = new();

    t1.id = 1;
    t1.a  = 8'd200;
    t1.b  = 8'd100;
    t1.op = ALU_ADD;

    $display("t1: id=%0d a=%0d b=%0d op='%s' result=%h",
             t1.id, t1.a, t1.b, t1.op.name(), t1.result);
    $display("t2: id=%0d a=%0d b=%0d op='%s' result=%h",
             t2.id, t2.a, t2.b, t2.op.name(), t2.result);
  end

endmodule
```

```output
t1: id=1 a=200 b=100 op='ALU_ADD' result=xxx
t2: id=0 a=0 b=0 op='' result=xxx
```

**Line by line**

| Line | Explanation |
|---|---|
| `import alu_pkg::*;` | Makes `alu_op_e` and the opcode names visible. The transaction uses the same type as the DUT port, so the two can never disagree about encodings. |
| `class alu_txn;` | For teaching, the class is declared inside the demo module. In the real testbench it lives in the package `alu_tb_pkg` (Section 3.5). |
| `rand bit [7:0] a;` | `rand` marks the field as one that `randomize()` may change. Until `randomize()` is called, a `rand` field is an ordinary variable with its default value. |
| `logic [8:0] result;` | Nine bits, like the DUT output. Four-state. |
| `t1 = new();` | Creates an object. No constructor was written, so the built-in default constructor is used: it allocates the object and gives every property its default value. |
| `t1.a = 8'd200;` | A `rand` field can also be assigned by hand. This is how directed tests build transactions. |
| Output line 1 | `result` was never assigned, so all nine bits are X; `%h` prints three hex digits `xxx`. |
| Output line 2 | An untouched object. `a`, `b` and `id` are two-state and start at 0. `op` is an enum whose base type is `logic [2:0]`, so it starts at X, which is not one of the eight members; `name()` returns an empty string. |

> **Common mistake:** Assuming a freshly constructed transaction contains a valid opcode. Because `alu_op_e` has a four-state base type, `op` is X until it is assigned or randomized. A driver that puts such a transaction on the pins drives X into the DUT. Always randomize or assign every stimulus field before use, or initialise `op` in the constructor.

### What should not be in a transaction

| Do not put this in the transaction | Reason |
|---|---|
| The virtual interface handle | The transaction would then depend on the pins, which is exactly what it exists to avoid |
| Clock or reset values | They are not per-operation data |
| Tasks that consume time (`@`, `#`) | A transaction is data. Timing belongs to the driver and monitor |
| Mailboxes, events, handles to components | A transaction is passed between components; it should not know about them |
| Large data that is never used | Thousands of transaction objects may be alive at once |

### Common additional fields in real projects

| Field | Purpose |
|---|---|
| `rand int unsigned delay;` | Number of idle cycles the driver inserts before this transaction. Randomizing it finds timing-dependent bugs |
| `time start_time, end_time;` | Filled in by the monitor; used for latency checks and debug |
| `rand kind_e kind;` | Type of operation, when one class models several kinds of transfer |
| `bit error;` or a response enum | Status returned by the DUT |
| `rand bit inject_error;` | Tells the driver to corrupt this transaction on purpose (bad parity, bad CRC) to test error handling |

### Interview questions

**Q1. How do you decide which signals become fields of the transaction?**
Data that the testbench chooses per operation becomes a `rand` field. Data that the DUT returns per operation becomes a non-`rand` field. Clock, reset and handshake signals are protocol and stay in the interface, driver and monitor. Tracking information such as an ID is added as non-`rand` bookkeeping.

**Q2. Which fields are `rand` and which are not?**
Stimulus fields are `rand`. Response fields, IDs, timestamps and anything computed are not.

**Q3. Why use an enum for the opcode instead of `bit [2:0]`?**
Readable logs and waveforms; the solver generates only declared members, which matters when not all encodings are legal; coverage bins are created per name automatically; and the compiler rejects an assignment of an arbitrary number.

**Q4. What does a newly constructed `alu_txn` contain?**
The default value of each property: 0 for the two-state fields `a`, `b`, `id`; X for the four-state `result`; and X for `op`, because the enum's base type is four-state.

**Q5. Should a transaction contain a virtual interface?**
No. The transaction must stay independent of pins and timing. Only the driver and monitor hold the virtual interface.

## 1.4 Transaction Methods and the Constructor

### The standard set of methods

A transaction is more than a record. Each testbench component needs a particular service from it, and that service is provided as a method of the class so that it is written once and kept next to the fields it handles.

| Method | Purpose | Called by | Section |
|---|---|---|---|
| `new()` | Create the object and set initial values | Generator, monitor | 1.4 |
| `randomize()` (built in) | Give the `rand` fields legal random values | Generator | 2.1 |
| `pre_randomize()`, `post_randomize()` (built-in hooks) | Prepare before, or compute derived fields after, randomization | Called automatically by `randomize()` | 2.2 |
| `convert2string()` | Return the contents as one formatted string | `print()`, error messages | 3.1 |
| `print(tag)` | Display the contents in the log | Every component | 3.1 |
| `copy()` | Return a new, independent object with the same field values | Generator, monitor, scoreboard | 3.2 |
| `compare(rhs)` | Return 1 if two transactions have the same contents | Scoreboard | 3.3 |
| `pack()` / `unpack()` (optional) | Convert to and from a flat bit vector | Driver and monitor of serial or bus protocols | Revision exercises |

The names `copy`, `compare`, `print` and `convert2string` are a deliberate choice. UVM's base class for transactions provides methods with exactly these names, so a hand-written class that uses them is immediately familiar to anyone who knows UVM, and learning UVM later is easier.

All of these are **functions**, not tasks: none of them consumes simulation time. Recall from Module 3 that a function must return in zero time; a method that only manipulates fields has no reason to wait.

### The constructor

**Definition.** The constructor is the special function `new()`. It runs automatically when an object is created, has no return type, and is used to put the object into a defined initial state (Module 4).

For a transaction the constructor is usually very small, because the stimulus fields will be set by `randomize()` anyway. Three styles are found in practice:

**Style 1: no constructor.** The built-in default constructor is used. Acceptable when every field's default value is acceptable.

**Style 2: a constructor with no arguments** that sets safe initial values.

```systemverilog
function new();
  op     = ALU_ADD;     // a legal opcode instead of the default X
  result = 'x;          // "no result captured yet"
endfunction
```

**Style 3: a constructor with default arguments**, convenient for directed tests.

```systemverilog
function new(alu_op_e op = ALU_ADD, bit [7:0] a = 0, bit [7:0] b = 0);
  this.op = op;         // this.op is the property; op is the argument
  this.a  = a;
  this.b  = b;
endfunction

// usage
t = new();                        // ALU_ADD, 0, 0
t = new(ALU_SUB, 8'd5, 8'd10);    // a directed transaction in one line
```

`this` is needed because the arguments have the same names as the properties (Module 4).

> **Key point:** Give every constructor argument a default value. A class that can be constructed as `new()` with no arguments can be created by generic code, such as a parameterized generator or a factory, that knows nothing about its fields. UVM requires this.

### Assigning the identifier

There are two common ways to give each transaction its `id`.

| Method | Code | Remarks |
|---|---|---|
| The creator assigns it | `t.id = count++;` in the generator | Simple and explicit. Used in this course |
| A static counter in the class | `static int unsigned next_id; function new(); id = next_id++; endfunction` | Automatic, but every `new()` consumes a number, including the `new()` inside `copy()` and the objects built by the monitor, so the numbers no longer mean "the n-th generated transaction" unless the code compensates |

### Complete example

```systemverilog file=tb_txn_constructor.sv
module tb_txn_constructor;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    function new(alu_op_e op = ALU_ADD, bit [7:0] a = 0, bit [7:0] b = 0);
      this.op = op;
      this.a  = a;
      this.b  = b;
    endfunction

    function bit is_unary();
      return op inside {ALU_NOT, ALU_SHL, ALU_SHR};
    endfunction
  endclass

  alu_txn t;

  initial begin
    t = new();
    $display("1. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());

    t = new(ALU_SUB, 8'd5, 8'd10);
    $display("2. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());

    t = new(ALU_NOT, 8'h0F);
    $display("3. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());
  end

endmodule
```

```output
1. op=ALU_ADD a=0 b=0 unary=0
2. op=ALU_SUB a=5 b=10 unary=0
3. op=ALU_NOT a=15 b=0 unary=1
```

**Line by line**

| Line | Explanation |
|---|---|
| `function new(alu_op_e op = ALU_ADD, ...)` | A custom constructor. Every argument has a default, so `new()` is still legal. |
| `this.op = op;` | Left side: the property of the object. Right side: the argument. Without `this`, the statement would assign the argument to itself and the property would stay X. |
| `function bit is_unary();` | A small helper method. It answers a question about the transaction ("does this operation ignore `b`?") so that the driver, scoreboard and coverage do not each repeat the list of unary opcodes. |
| `t = new();` | All defaults: a legal opcode and zero operands. |
| `t = new(ALU_SUB, 8'd5, 8'd10);` | A directed transaction. The handle `t` now refers to a new object; the previous object has no handle left and its memory is reclaimed automatically. |
| `t = new(ALU_NOT, 8'h0F);` | Trailing arguments may be omitted; `b` takes its default of 0. |

> **Common mistake:** Writing `function void new()` or `function alu_txn new()`. A constructor has no return type at all; either form is a compile error.

> **Common mistake:** Doing real work in the constructor, such as calling `randomize()` inside `new()`. It hides the randomization from the code that creates the object, makes it impossible to check the return value of `randomize()` properly, and prevents a test from adding inline constraints. Construct first, then randomize.

### Interview questions

**Q1. Which methods does a typical transaction class contain?**
A constructor, `print` (often built on `convert2string`), `copy`, `compare`, and sometimes `pack`/`unpack`, plus the built-in `randomize()`, `pre_randomize()` and `post_randomize()`.

**Q2. Why are transaction methods functions and not tasks?**
They only read and write fields and return immediately. Declaring them as functions guarantees that they cannot block, and lets them be called from other functions, from constraints' helper code and from `$display` argument lists.

**Q3. What is the role of the constructor in a transaction class?**
To leave the new object in a known, safe state: for example a legal opcode instead of X. It should not randomize or perform time-consuming actions.

**Q4. Why should constructor arguments have default values?**
So that the object can be created by code that does not know the argument list, such as a generic generator, and so that a derived class does not have to pass arguments through `super.new()`.

**Q5. Why does the course call the methods `copy`, `compare` and `print`?**
These are the conventional names, and the same names are used by UVM's transaction base class, so the habit transfers directly.
