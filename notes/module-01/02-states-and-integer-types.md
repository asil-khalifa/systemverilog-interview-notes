# Part 2: States, Nets, Variables and Built-in Types

## 2.1 Two-State and Four-State Data Types

### In plain English

A real wire in a digital circuit is normally at a low voltage (0) or a high voltage (1). But while designing and simulating hardware, two more situations must be represented:

- "I do not know whether this is 0 or 1." For example a flip-flop that has not been reset yet, or two gates driving opposite values onto the same wire.
- "Nothing is driving this wire at all." For example a bus where every tri-state driver is switched off.

A **four-state** data type can hold all four situations in each bit. A **two-state** data type can hold only 0 and 1 in each bit.

### Technical definition

| Value | Name | Meaning |
|---|---|---|
| `0` | Logic zero | Low, false |
| `1` | Logic one | High, true |
| `X` | Unknown | The simulator cannot determine whether the value is 0 or 1 |
| `Z` | High impedance | The bit is not driven by anything (floating, tri-stated) |

- **Four-state types** store 0, 1, X or Z per bit: `logic`, `reg`, `integer`, `time`, and all net types such as `wire`.
- **Two-state types** store 0 or 1 per bit: `bit`, `byte`, `shortint`, `int`, `longint`.

X and Z exist only in simulation. Real silicon has no "X" voltage; X is the simulator's way of saying "I cannot tell". Z is real: it is an undriven wire.

### Why both kinds are needed

| Need | Type to use | Reason |
|---|---|---|
| Model hardware signals accurately | Four-state | Uninitialised flip-flops, bus contention and floating buses must be visible, otherwise real bugs are hidden |
| Fast, compact testbench code | Two-state | A loop counter or packet count can never be "floating", so storing X and Z for it wastes memory and time |

### How it works internally

One bit that can take four values needs two bits of storage. Simulators use a pair of bits, traditionally called `aval` and `bval` (this is also the encoding exposed to C code through DPI and VPI):

```text
   value    aval  bval
   -----    ----  ----
     0        0     0
     1        1     0
     Z        0     1
     X        1     1

   logic [7:0] sig = 8'b10xz_01xx;          bit [7:0] cnt = 8'b1011_0110;

   aval : 1 0 1 0 0 1 1 1                   bits : 1 0 1 1 0 1 1 0
   bval : 0 0 1 1 0 0 1 1                   (one storage bit per bit)
   (two storage bits per bit)
```

Consequences:

- A four-state variable uses twice the memory of a two-state variable of the same width.
- Every operation on four-state values must also compute the X/Z part, so it is slower.
- When a four-state value is copied into a two-state variable, `bval` is simply dropped: **every X and every Z becomes 0**. No warning is given.

### Where X comes from in a simulation

| Source of X | Example |
|---|---|
| Uninitialised four-state variable | A flip-flop that has no reset, before its first clocked assignment |
| Multiple drivers in conflict | Two `assign` statements drive 0 and 1 onto the same `wire` |
| Reading an array out of range | `mem[300]` when `mem` has 256 entries (four-state element type) |
| Unknown select or condition | `sel ? a : b` when `sel` is X and `a` differs from `b` |
| Arithmetic with an unknown operand | `a + b` where any bit of `a` is X gives a result that is entirely X |
| Division by zero | `a / 0` and `a % 0` return X |
| Undriven input | An undriven `wire` is Z; when it passes through a gate it becomes X |
| Timing violation in gate-level simulation | A setup or hold violation makes the flip-flop model output X |

### Complete example

```systemverilog file=tb_states.sv
module tb_states;

  logic [3:0] l4;   // four-state
  bit   [3:0] b2;   // two-state

  initial begin
    $display("default : l4=%b  b2=%b", l4, b2);

    l4 = 4'b1x0z;
    b2 = l4;        // X and Z are silently converted to 0
    $display("assigned: l4=%b  b2=%b", l4, b2);

    if ($isunknown(l4)) $display("l4 contains X or Z");
    if (!$isunknown(b2)) $display("b2 can never contain X or Z");

    l4 = 4'b1010;
    l4 = l4 + 4'b000x;   // one unknown bit poisons the whole sum
    $display("sum     : l4=%b", l4);
  end

endmodule
```

```output
default : l4=xxxx  b2=0000
assigned: l4=1x0z  b2=1000
l4 contains X or Z
b2 can never contain X or Z
sum     : l4=xxxx
```

**Line by line**

| Line | Explanation |
|---|---|
| `logic [3:0] l4;` | Four-state. It has never been assigned, so each bit starts as X. |
| `bit [3:0] b2;` | Two-state. It starts as 0. |
| `l4 = 4'b1x0z;` | A literal may contain `x` and `z` digits. |
| `b2 = l4;` | `1`→1, `x`→0, `0`→0, `z`→0. The result is `1000`. Information has been lost. |
| `$isunknown(l4)` | System function that returns 1 if any bit of its argument is X or Z. |
| `l4 + 4'b000x` | For arithmetic operators, if any bit of any operand is X or Z, the entire result is X. |

### Which to use in a real verification environment

| Location | Recommended | Why |
|---|---|---|
| RTL signals | `logic` | X must be visible so that reset and initialisation bugs are caught |
| Signals inside an `interface` | `logic` | They connect directly to DUT pins and must show X and Z |
| Fields sampled from the DUT by the monitor | `logic` | If the DUT drives X, the monitor must capture X so that the scoreboard can flag it |
| `rand` fields of a transaction class | `bit` / `int` | The constraint solver only generates 0 and 1, and two-state is faster |
| Loop variables, counters, array indices, flags | `int`, `bit` | They never need X or Z |

> **Interview trap:** "Why not use two-state types everywhere? They are faster." If a testbench samples a DUT output into a `bit` variable, an X on that output is converted to 0. The comparison against the expected value may then pass even though the DUT is broken. Signals that touch the DUT must be four-state, or must be checked with `$isunknown()` before conversion.

> **Common mistake:** Believing X means "either 0 or 1, and the simulator tries both". It does not. X is a distinct third value with its own propagation rules, and those rules are sometimes optimistic (see Section 4.3).

### Interview questions

**Q1. What are two-state and four-state data types?**
Two-state types hold only 0 and 1 per bit (`bit`, `byte`, `shortint`, `int`, `longint`). Four-state types hold 0, 1, X and Z per bit (`logic`, `reg`, `integer`, `time`, and nets such as `wire`).

**Q2. Why were two-state types added?**
For simulation performance and lower memory use in testbench code, where X and Z have no meaning. They also make it easier to exchange data with C code through DPI.

**Q3. What happens when a four-state value is assigned to a two-state variable?**
X and Z bits are converted to 0, with no error or warning.

**Q4. How do you check whether a signal has X or Z?**
`$isunknown(sig)` returns 1 if any bit is X or Z. An alternative idiom is `(^sig) === 1'bx`, because the reduction XOR of a vector containing X or Z is X.

**Q5. Does X exist in real hardware?**
No. Every node in silicon settles to some voltage. X is a simulation concept that represents lack of knowledge. Z does exist: it is a node with no active driver.

## 2.2 Difference Between bit and logic

### Definition

Both `bit` and `logic` are **data types** for a single bit, and both can be turned into vectors by adding a packed dimension such as `[7:0]`. Both are unsigned by default. The only difference is the number of states.

| Property | `bit` | `logic` |
|---|---|---|
| States | 2 (0, 1) | 4 (0, 1, X, Z) |
| Default value | 0 | X |
| Storage per bit | 1 bit | 2 bits |
| Simulation speed | Faster | Slower |
| Signed by default | No | No |
| Shows uninitialised state | No, appears as 0 | Yes, appears as X |
| Can model tri-state (Z) | No | Yes |
| Synthesizable | Yes | Yes |
| Typical use | Testbench variables, `rand` fields | RTL signals, interface signals, sampled DUT values |

### Syntax

```systemverilog
bit          flag;        // 1 bit, two-state
bit   [7:0]  data_b;      // 8-bit two-state vector
logic        ready;       // 1 bit, four-state
logic [31:0] addr;        // 32-bit four-state vector
bit signed [7:0] offset;  // signed two-state vector
```

### Why the default value matters: a reset bug

The following counter has a bug: the designer forgot the reset. Look at how each type shows the problem.

```systemverilog file=tb_bit_vs_logic.sv
module tb_bit_vs_logic;

  logic       clk = 0;
  logic [3:0] count_logic;   // four-state counter, no reset
  bit   [3:0] count_bit;     // two-state counter, no reset

  always #5 clk = ~clk;

  always_ff @(posedge clk) count_logic <= count_logic + 1'b1;
  always_ff @(posedge clk) count_bit   <= count_bit   + 1'b1;

  initial begin
    repeat (3) @(negedge clk);
    $display("count_logic = %b   count_bit = %b", count_logic, count_bit);
    $finish;
  end

endmodule
```

```output
count_logic = xxxx   count_bit = 0011
```

`count_logic` starts as X. X + 1 is X, so it stays X forever, and anybody looking at the waveform sees the missing reset immediately. `count_bit` starts at 0 and counts happily, so the simulation looks correct. The real chip, however, powers up with a random value in those flip-flops. The two-state type has hidden a real bug. This is the reason RTL is written with `logic`.

### Interview questions

**Q1. What is the difference between `bit` and `logic`?**
`bit` is two-state with a default of 0. `logic` is four-state with a default of X. Everything else (width, unsigned by default, usable as a vector) is the same.

**Q2. Which would you use in a testbench and which in RTL? Why?**
`logic` in RTL and for anything connected to the DUT, so that uninitialised or undriven signals appear as X or Z. `bit` (and `int`) for internal testbench data such as transaction fields, counters and indices, for speed and because random values are always two-state.

**Q3. Is `bit` synthesizable?**
Yes. But a simulation with `bit` starts flip-flops at 0 while the synthesised hardware starts at an unknown value, so simulation may not match hardware. `logic` is therefore preferred for RTL.

## 2.3 Difference Between reg, wire and logic

### The Verilog problem

In Verilog every signal had to be declared as either a `wire` or a `reg`, and the choice depended on how the signal was assigned:

- assigned by an `assign` statement or driven by a module output → `wire`
- assigned inside an `always` or `initial` block → `reg`

Two things were wrong with this. First, the name `reg` suggests "register", but a `reg` assigned in a combinational `always @*` block becomes plain gates, not a flip-flop. Second, changing how a signal was assigned forced you to change its declaration.

### The SystemVerilog solution

SystemVerilog introduced `logic`. A `logic` variable can be

- assigned in procedural blocks (`always_ff`, `always_comb`, `initial`, tasks, functions), **or**
- driven by **one** continuous `assign` statement, **or**
- driven by **one** output port of a module instance.

So in almost all cases you declare everything as `logic` and stop thinking about it. The single exception is a signal with **more than one driver** (a tri-state bus, an `inout` port). That still needs a net type such as `wire`, because only nets have the mechanism to resolve several drivers into one value.

### Comparison table

| Property | `wire` | `reg` | `logic` |
|---|---|---|---|
| What it is | A net type | A variable data type | A variable data type (the same type as `reg`) |
| States | 4 | 4 | 4 |
| Default value | Z (when undriven) | X | X |
| Stores a value | No, it shows what its drivers drive | Yes | Yes |
| Procedural assignment (`always`, `initial`) | Not allowed | Allowed | Allowed |
| Continuous assignment (`assign`) | Allowed, any number | Not allowed in Verilog; one allowed in SystemVerilog | One allowed |
| Multiple drivers | Allowed and resolved | Not allowed | Not allowed |
| Tri-state bus, `inout` port | Yes | No | No |
| Infers a flip-flop automatically | No | No, depends on how it is coded | No, depends on how it is coded |
| Introduced in | Verilog | Verilog | SystemVerilog |

> **Key point:** In SystemVerilog, `reg` and `logic` are exactly the same data type. `logic` is simply the better name. New code uses `logic`; `reg` remains for backward compatibility.

### Complete example with legal and illegal uses

```systemverilog file=tb_reg_wire_logic.sv
module tb_reg_wire_logic;

  logic       a, b;
  wire        w_and;        // net
  logic       l_or;         // variable driven by one continuous assignment
  logic       l_xor;        // variable assigned procedurally
  logic [3:0] sum;

  assign w_and = a & b;                 // legal: continuous assignment to a net
  assign l_or  = a | b;                 // legal: ONE continuous assignment to a variable

  always_comb l_xor = a ^ b;            // legal: procedural assignment to a variable

  // assign l_or = a;                   // ILLEGAL: second continuous driver on a variable
  // always_comb w_and = a;             // ILLEGAL: procedural assignment to a net
  // assign l_xor = a;                  // ILLEGAL: variable driven both procedurally and continuously

  initial begin
    a = 1; b = 0;
    #1 $display("a=%b b=%b : and=%b or=%b xor=%b", a, b, w_and, l_or, l_xor);
    a = 1; b = 1;
    #1 $display("a=%b b=%b : and=%b or=%b xor=%b", a, b, w_and, l_or, l_xor);
  end

endmodule
```

```output
a=1 b=0 : and=0 or=1 xor=1
a=1 b=1 : and=1 or=1 xor=0
```

The three commented lines are the three classic compile errors. Remove a comment marker and compile to see the message your simulator gives; recognising that message is useful when debugging.

### Interview questions

**Q1. What is the difference between `reg`, `wire` and `logic`?**
`wire` is a net: it has no storage, it reflects the resolved value of its drivers, it can have several drivers, and it cannot be assigned in a procedural block. `reg` is a Verilog variable: it stores a value and is assigned procedurally. `logic` is the SystemVerilog replacement for `reg`: the same four-state variable type, which may additionally be driven by a single continuous assignment or a single port, so it can replace both `reg` and `wire` everywhere except where multiple drivers are needed.

**Q2. Does `reg` always become a flip-flop?**
No. It becomes a flip-flop only if it is assigned in a clocked block. In a combinational block it becomes combinational logic, or a latch if it is not assigned on every path.

**Q3. Can `logic` replace `wire` everywhere?**
No. A signal with more than one driver, such as a bidirectional or tri-state bus, must be a net. `inout` ports must be nets.

**Q4. What happens if two `assign` statements drive the same `logic` signal?**
Compile (or elaboration) error, because a variable may have at most one continuous driver. With a `wire`, the same code compiles, and a conflict shows up as X at run time. This is an advantage of `logic`: accidental multiple drivers are caught at compile time.

## 2.4 Net Types and Variable Types

### Two independent properties of every signal

This is the idea that makes the previous section precise. Every signal ("data object") has two separate properties:

1. Its **kind**: is it a **net** or a **variable**?
2. Its **data type**: what set of values can it hold (`logic`, `bit`, `int`, an enum, a struct...)?

```text
        kind            data type               name
        ----            ---------               ----
        wire            logic [7:0]             bus;       // net of type logic (written in full)
        wire            [7:0]                   bus;       // same thing: data type defaults to logic
        var             logic [7:0]             data;      // variable of type logic (written in full)
                        logic [7:0]             data;      // same thing: kind defaults to var
        var             bit                     flag;      // variable of type bit
```

So `wire` is not a data type; it is a kind of net whose default data type is `logic`. And `logic` is not a kind; it is a data type, which by default creates a variable. This is the technically exact answer to "what is the difference between `wire` and `logic`?".

### Nets

A net models a physical connection. It does not store anything (except `trireg`). Its value is continuously computed from all of its drivers by a **resolution function**.

| Net type | Behaviour | Typical use |
|---|---|---|
| `wire`, `tri` | Identical to each other. Multiple drivers are resolved; a conflict gives X | General connections; `tri` documents a tri-state bus |
| `uwire` | "Unresolved wire": only one driver allowed, more is an error | Enforcing single-driver nets |
| `wand`, `triand` | Wired-AND: if any driver is 0 the result is 0 | Open-drain / open-collector buses |
| `wor`, `trior` | Wired-OR: if any driver is 1 the result is 1 | Wired-OR logic |
| `tri0` | Like `tri`, but reads 0 when undriven | Net with pull-down resistor |
| `tri1` | Like `tri`, but reads 1 when undriven | Net with pull-up resistor (I2C `sda`, `scl`) |
| `trireg` | Keeps its last driven value when undriven; defaults to X | Capacitive storage nodes |
| `supply0`, `supply1` | Constant 0 or 1 at supply strength | Ground and power |

**Resolution of two drivers on a `wire` or `tri`**

| Driver A \ Driver B | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | X | X | 0 |
| **1** | X | 1 | X | 1 |
| **X** | X | X | X | X |
| **Z** | 0 | 1 | X | Z |

Read it like this: Z means "not driving", so the other driver wins. Two drivers that agree give that value. Two drivers that disagree give X, which in real hardware is a short circuit (bus contention).

### Variables

A variable stores a value. It keeps that value until the next assignment. Variables include everything declared with a data type and no net keyword: `logic`, `reg`, `bit`, `byte`, `shortint`, `int`, `longint`, `integer`, `time`, `real`, `string`, enums, structs, arrays, class handles.

### The assignment rules

| Rule | Net | Variable |
|---|---|---|
| Procedural assignment (`always`, `initial`, task, function) | Never | Yes, from any number of statements |
| Continuous assignment (`assign`) | Yes, any number | Yes, but only one, and then no procedural assignment |
| Driven by a module instance output port | Yes, any number | Yes, but only one |
| Multiple drivers | Resolved | Error |
| Value when never assigned | Z (`trireg`: X) | Default of its data type (X for four-state, 0 for two-state) |
| Can be initialised in its declaration | `wire w = a & b;` is a continuous assignment | `logic v = 1'b0;` is a one-time initial value |

> **Interview trap:** `wire w = a & b;` and `logic v = a & b;` look alike and behave completely differently. The first is a continuous assignment: `w` follows `a & b` for the whole simulation. The second is an initialisation: `v` gets the value of `a & b` once, at time 0 (probably X), and never updates.

### Port kinds

| Port declaration | What you get |
|---|---|
| `input a` | Net (`wire logic`) |
| `input logic a` | Still a net: for `input` and `inout` ports the kind defaults to `wire` even when a data type is written |
| `output a` | Net |
| `output logic a` | Variable: for `output` ports, writing a data type makes it a variable |
| `inout wire a` | Net. `inout` ports must be nets |

In practice you write `input logic` and `output logic` everywhere and it works. The table matters only for the interview question "is `input logic a` a net or a variable?".

### Implicit nets

If a name that was never declared appears in a port connection or on the left of an `assign`, Verilog silently creates a 1-bit `wire`. A typing mistake therefore creates a new unconnected 1-bit net instead of an error. Adding `` `default_nettype none `` at the top of a file turns this into a compile error, which is why many companies require it in RTL.

### Complete example: a tri-state bus

```systemverilog file=tb_net_resolution.sv
module tb_net_resolution;

  logic       en_a, en_b;
  logic [3:0] data_a, data_b;
  wire  [3:0] bus;                         // must be a net: it has two drivers

  assign bus = en_a ? data_a : 4'bzzzz;    // driver A
  assign bus = en_b ? data_b : 4'bzzzz;    // driver B

  initial begin
    data_a = 4'b1100;
    data_b = 4'b1010;

    en_a = 0; en_b = 0; #1 $display("nobody drives : bus=%b", bus);
    en_a = 1; en_b = 0; #1 $display("A drives      : bus=%b", bus);
    en_a = 0; en_b = 1; #1 $display("B drives      : bus=%b", bus);
    en_a = 1; en_b = 1; #1 $display("A and B drive : bus=%b", bus);
  end

endmodule
```

```output
nobody drives : bus=zzzz
A drives      : bus=1100
B drives      : bus=1010
A and B drive : bus=1xx0
```

**Explanation**

- `bus` is declared as `wire` because it has two `assign` statements. Declaring it as `logic` would be a compile error.
- Each driver either drives its data or drives Z ("releases the bus").
- When both are disabled the bus floats: `zzzz`.
- When both drive, each bit is resolved separately using the table above. Bit 3 is 1 and 1 → 1. Bit 2 is 1 and 0 → X. Bit 1 is 0 and 1 → X. Bit 0 is 0 and 0 → 0. Result `1xx0`.

> **Verification application:** A bidirectional pin such as I2C `sda` is declared as a net inside the interface. The testbench driver cannot assign to a net from a class, so the interface contains a `logic` variable (for example `sda_drv`) that the class writes, plus `assign sda = sda_oe ? sda_drv : 1'bz;`. This pattern is asked about frequently and is shown in Module 8.

### Interview questions

**Q1. What is the difference between a net and a variable?**
A net represents a connection, has no storage, takes the resolved value of its drivers, may have multiple drivers, and cannot be assigned procedurally. A variable stores a value, is assigned procedurally (or by exactly one continuous assignment or port), and cannot have multiple drivers.

**Q2. Is `logic` a net or a variable?**
Neither: `logic` is a data type. A declaration `logic x;` creates a variable of type `logic`. A declaration `wire logic x;` (or just `wire x;`) creates a net of type `logic`.

**Q3. What is the default value of a `wire`? Of a `logic`?**
An undriven `wire` is Z. An unassigned `logic` variable is X.

**Q4. What is the difference between `wire` and `tri`?**
None in behaviour. `tri` is used to document that the net is intended to have several tri-state drivers.

**Q5. What are `wand` and `wor`?**
Nets with a wired-AND or wired-OR resolution function. On a `wand`, any driver at 0 forces the net to 0. On a `wor`, any driver at 1 forces the net to 1. They model open-drain style buses.

**Q6. What does `` `default_nettype none `` do?**
It disables implicit net declaration, so that an undeclared (often misspelled) signal name is a compile error instead of a silently created 1-bit wire.

## 2.5 Integer Data Types

### Overview

"Integer data types" (the standard calls them integral types) are all the types that hold whole numbers as a group of bits.

| Type | Width | States | Signed by default | Default value | Range | From Verilog? |
|---|---|---|---|---|---|---|
| `bit` | 1 bit, or user-defined vector | 2 | No | 0 | 0 to 2^N - 1 | No |
| `logic` | 1 bit, or user-defined vector | 4 | No | X | 0 to 2^N - 1 | No |
| `reg` | 1 bit, or user-defined vector | 4 | No | X | 0 to 2^N - 1 | Yes |
| `byte` | 8 | 2 | Yes | 0 | -128 to 127 | No |
| `shortint` | 16 | 2 | Yes | 0 | -32,768 to 32,767 | No |
| `int` | 32 | 2 | Yes | 0 | -2,147,483,648 to 2,147,483,647 | No |
| `longint` | 64 | 2 | Yes | 0 | -2^63 to 2^63 - 1 | No |
| `integer` | 32 | 4 | Yes | X | -2,147,483,648 to 2,147,483,647 | Yes |
| `time` | 64 | 4 | No | X | 0 to 2^64 - 1 | Yes |

A way to remember it: the four C-like types (`byte`, `shortint`, `int`, `longint`) are two-state and signed. The two old Verilog types (`integer`, `time`) are four-state. The single-bit types (`bit`, `logic`, `reg`) are unsigned and are the only ones whose width you choose.

### Memory representation

```text
  bit              [ b ]                                     1 storage bit
  logic            [ a | b ]                                 2 storage bits (aval, bval)

  byte             [ S | 6 5 4 3 2 1 0 ]                     8 bits, S = sign bit (bit 7)
  shortint         [ S | 14 ................ 0 ]             16 bits
  int              [ S | 30 .............................. 0 ]            32 bits
  longint          [ S | 62 .............................................. 0 ]   64 bits

  integer          [ S | 30 .............................. 0 ]   aval   32 bits
                   [                                         ]   bval   32 bits  (64 storage bits)

  time             [ 63 .......................................... 0 ]   aval   64 bits
                   [                                               ]   bval   64 bits  (128 storage bits)
```

Signed types use **two's complement**, described in Section 2.6.

### Each type in detail

#### bit

- **Declaration:** `bit flag;` `bit [7:0] data;` `bit [3:0][7:0] word;`
- **States / default:** two-state, 0. Unsigned unless declared `bit signed`.
- **Use:** flags, `rand` transaction fields of any width (`rand bit [15:0] addr;`), masks. It is the most used type in class-based testbenches.

#### logic

- **Declaration:** `logic ready;` `logic [31:0] rdata;`
- **States / default:** four-state, X. Unsigned unless declared `logic signed`.
- **Use:** all RTL signals, all interface signals, any testbench field that stores a value sampled from the DUT.

#### reg

- Identical to `logic`. Found in Verilog code and older testbenches. Do not use it in new code.

#### byte

- **Declaration:** `byte b;` `byte unsigned ub;`
- **States / default:** two-state, 0, **signed**, 8 bits.
- **Use:** characters (a `string` is a sequence of bytes), C-style data, DPI arguments matching C `char`.
- **Warning:** because it is signed, `byte` holds -128 to 127. For a payload byte that should hold 0 to 255, use `bit [7:0]` or `byte unsigned`.

#### shortint

- **Declaration:** `shortint s;` `shortint unsigned us;`
- **States / default:** two-state, 0, signed, 16 bits.
- **Use:** rare. Mostly to match C `short` in DPI calls, or 16-bit signed samples in DSP testbenches.

#### int

- **Declaration:** `int i;` `int unsigned count;`
- **States / default:** two-state, 0, signed, 32 bits.
- **Use:** the default choice for loop variables, counters, array indices, sizes, IDs, error counts.

#### longint

- **Declaration:** `longint big;` `longint unsigned ubig;`
- **States / default:** two-state, 0, signed, 64 bits.
- **Use:** values that can exceed about 2 billion: byte counters in long simulations, 64-bit addresses, timestamps in small time units, DPI arguments matching C `long long`.

#### integer

- **Declaration:** `integer n;`
- **States / default:** four-state, X, signed, 32 bits.
- **Use:** legacy Verilog code. In new testbench code `int` is preferred because it is faster and starts at 0. `integer` is appropriate only when you need a 32-bit signed number that can also show X.

#### time

- **Declaration:** `time t_start;`
- **States / default:** four-state, X, unsigned, 64 bits.
- **Use:** storing simulation timestamps returned by `$time`, for example to measure latency. Covered with `realtime` in Section 2.7.

### int versus integer

| Property | `int` | `integer` |
|---|---|---|
| States | 2 | 4 |
| Default value | 0 | X |
| Width | 32 | 32 |
| Signed | Yes | Yes |
| Speed and memory | Better | Worse |
| Origin | SystemVerilog | Verilog |

### Changing signedness and building your own widths

```systemverilog
int unsigned       count;      // 32-bit unsigned, 0 to 4,294,967,295
byte unsigned      ubyte;      // 8-bit unsigned, 0 to 255
bit signed [11:0]  sample;     // 12-bit signed two-state
logic signed [7:0] offset;     // 8-bit signed four-state
// byte [3:0] x;               // ILLEGAL: types with a fixed width cannot take a packed dimension
```

### Complete example

```systemverilog file=tb_integer_types.sv
module tb_integer_types;

  bit      v_bit;
  logic    v_logic;
  byte     v_byte;
  shortint v_shortint;
  int      v_int;
  longint  v_longint;
  integer  v_integer;
  time     v_time;

  initial begin
    $display("--- default values ---");
    $display("bit=%b logic=%b byte=%0d shortint=%0d", v_bit, v_logic, v_byte, v_shortint);
    $display("int=%0d longint=%0d integer=%0d time=%0d", v_int, v_longint, v_integer, v_time);

    $display("--- width in bits ---");
    $display("bit=%0d logic=%0d byte=%0d shortint=%0d",
             $bits(v_bit), $bits(v_logic), $bits(v_byte), $bits(v_shortint));
    $display("int=%0d longint=%0d integer=%0d time=%0d",
             $bits(v_int), $bits(v_longint), $bits(v_integer), $bits(v_time));

    $display("--- overflow wraps around ---");
    v_byte = 127;          v_byte++;     $display("byte     127 + 1        = %0d", v_byte);
    v_shortint = 32767;    v_shortint++; $display("shortint 32767 + 1      = %0d", v_shortint);
    v_int = 2147483647;    v_int++;      $display("int      2147483647 + 1 = %0d", v_int);
    v_byte = 200;                        $display("byte     assigned 200   = %0d", v_byte);

    $display("--- four-state to two-state ---");
    v_integer = 'x;
    v_int     = v_integer;
    $display("integer=%0d copied into int=%0d", v_integer, v_int);
  end

endmodule
```

```output
--- default values ---
bit=0 logic=x byte=0 shortint=0
int=0 longint=0 integer=x time=x
--- width in bits ---
bit=1 logic=1 byte=8 shortint=16
int=32 longint=64 integer=32 time=64
--- overflow wraps around ---
byte     127 + 1        = -128
shortint 32767 + 1      = -32768
int      2147483647 + 1 = -2147483648
byte     assigned 200   = -56
--- four-state to two-state ---
integer=x copied into int=0
```

**Explanation**

| Code | Explanation |
|---|---|
| Default values | The two-state types start at 0. `logic`, `integer` and `time` start at X. With `%d`, a value whose bits are all X prints as a lowercase `x`; a value with only some X bits prints as an uppercase `X`. |
| `$bits(v)` | System function returning the number of bits a variable or type occupies. |
| `v_byte = 127; v_byte++;` | 127 is `0111_1111`. Adding 1 gives `1000_0000`, which in two's complement is -128. There is no overflow error in SystemVerilog; the value wraps silently. |
| `v_byte = 200;` | 200 is `1100_1000`. In an 8-bit signed type the top bit is the sign, so this pattern means 200 - 256 = -56. |
| `v_integer = 'x;` | `'x` sets every bit to X. Copying it to `int` turns every X into 0. |

> **Interview trap:** What does this loop do?
> `for (byte i = 0; i < 200; i++) ...`
> It never ends. A `byte` cannot exceed 127; after 127 it wraps to -128, which is still less than 200. The same bug appears with `bit [3:0] i; for (i = 0; i < 16; i++)`: a 4-bit variable is always less than 16. Use `int` for loop variables.

### Which type to use: a quick guide

| Situation | Type |
|---|---|
| RTL signal, interface signal | `logic [N-1:0]` |
| Random field of a transaction | `rand bit [N-1:0]` |
| Loop variable, counter, index, size | `int` |
| Count that may exceed 2^31 | `longint` |
| Payload byte, 0 to 255 | `bit [7:0]` (not `byte`) |
| Signed quantity of a specific width | `bit signed [N-1:0]` or `logic signed [N-1:0]` |
| Timestamp | `time` or `realtime` |
| Value passed to or from C through DPI | The matching C-like type (`byte`, `shortint`, `int`, `longint`) |

### Interview questions

**Q1. List the integer data types with their sizes.**
`bit` and `logic` (1 bit, or a user-defined vector), `byte` 8, `shortint` 16, `int` 32, `longint` 64, `integer` 32, `time` 64.

**Q2. Which of them are four-state?**
`logic`, `reg`, `integer`, `time`. The others are two-state.

**Q3. Which are signed by default?**
`byte`, `shortint`, `int`, `longint`, `integer`. Unsigned by default: `bit`, `logic`, `reg`, `time`.

**Q4. What is the difference between `int` and `integer`?**
Both are 32-bit signed. `int` is two-state with default 0. `integer` is four-state with default X.

**Q5. What is the range of `byte`? What is stored if you assign 255 to it?**
-128 to 127. Assigning 255 (`1111_1111`) stores -1.

**Q6. What is the difference between `byte` and `bit [7:0]`?**
Both are 8-bit two-state. `byte` is signed (-128 to 127); `bit [7:0]` is unsigned (0 to 255). They hold the same bit patterns but behave differently in comparisons, in arithmetic, when extended to a wider type, and when printed with `%d`.

**Q7. Can you write `int [7:0] x;`?**
No. Types with a predefined width (`byte`, `shortint`, `int`, `longint`, `integer`, `time`) cannot take a packed dimension. You can make an unpacked array of them: `int x [8];`.

## 2.6 Signed and Unsigned Data Types

### In plain English

The bits stored in a variable are just a pattern. "Signed" or "unsigned" is the rule for interpreting that pattern as a number. The 8-bit pattern `1111_1111` means 255 if the variable is unsigned, and -1 if it is signed. The stored bits are identical.

### Two's complement

Signed integers use two's complement. The most significant bit (MSB) has a negative weight:

```text
  8-bit pattern :    b7     b6    b5    b4    b3    b2    b1    b0
  unsigned weight:   128    64    32    16     8     4     2     1
  signed weight  :  -128    64    32    16     8     4     2     1

  1111_1111 unsigned = 128+64+32+16+8+4+2+1 = 255
  1111_1111 signed   = -128+64+32+16+8+4+2+1 = -1
  1000_0000 signed   = -128        (most negative value)
  0111_1111 signed   = 127         (most positive value)

  To negate a number: invert every bit, then add 1.
      5 = 0000_0101  ->  invert: 1111_1010  ->  add 1: 1111_1011 = -5
```

### What signedness actually changes

Signedness affects exactly four things:

| Operation | Unsigned | Signed |
|---|---|---|
| Extension to a wider size | Zero-extended (padded with 0) | Sign-extended (padded with copies of the MSB) |
| Relational comparison `<`, `>`, `<=`, `>=` | Compared as magnitudes | Compared as two's complement numbers |
| Arithmetic right shift `>>>` | Fills with 0 | Fills with the sign bit |
| Printing with `%d`, and `*`, `/`, `%` results | Non-negative value | May be negative |

Addition, subtraction, bitwise operations and `==` on equal-width operands produce the same bits either way.

### Syntax

```systemverilog
logic signed [7:0] s_vec;       // signed vector
bit   signed [15:0] s_bits;
int unsigned        u_int;      // remove the default sign
byte unsigned       u_byte;

8'sd5          // signed sized literal
4'sb1111       // signed 4-bit literal with value -1
-8'sd3         // signed literal, value -3
5              // unsized decimal literal: a signed 32-bit int
'd5            // based literal without s: UNSIGNED 32-bit
8'hFF          // sized based literal without s: unsigned

signed'(expr)     // cast: reinterpret as signed
unsigned'(expr)   // cast: reinterpret as unsigned
$signed(expr)     // Verilog-2001 equivalent
$unsigned(expr)
```

### The rules of signed expressions

These five rules explain nearly every signed/unsigned interview question.

1. **An expression is signed only if every operand is signed.** If any one operand is unsigned, all operands are treated as unsigned.
2. **Extension depends on the right-hand side, never on the left-hand side.** When a narrow value is assigned to a wider variable, it is sign-extended if the *source expression* is signed and zero-extended if it is unsigned. The type of the destination is irrelevant.
3. **A bit-select or part-select is always unsigned**, even if it selects the whole vector: `s_vec[7:0]` is unsigned.
4. **A concatenation is always unsigned.**
5. **A based literal is unsigned unless it has the `s` flag.** `4'b1111` is 15; `4'sb1111` is -1. A plain decimal literal such as `15` is signed.

### Complete example

```systemverilog file=tb_signed.sv
module tb_signed;

  byte             s8;     // signed by default
  bit        [7:0] u8;     // unsigned by default
  bit signed [7:0] sv8;    // vector made signed
  int              i;
  int unsigned     ui;
  longint          li;

  initial begin
    s8 = 8'hFF;  u8 = 8'hFF;  sv8 = 8'hFF;
    $display("1. same bits FF     : s8=%0d  u8=%0d  sv8=%0d", s8, u8, sv8);

    i = s8;  $display("2. int = byte       : %0d  (sign-extended)", i);
    i = u8;  $display("3. int = bit [7:0]  : %0d  (zero-extended)", i);

    i  = -1;
    ui = 1;
    if (i < ui) $display("4. -1 < 1           : true");
    else        $display("4. -1 < 1           : false, -1 was treated as %0d", unsigned'(i));

    s8 = -8;
    $display("5. -8 >>> 1 = %0d    -8 >> 1 = %0d", s8 >>> 1, s8 >> 1);
    u8 = 8'hF8;
    $display("6. unsigned F8 >>> 1 = %0d", u8 >>> 1);

    $display("7. s8 = %0d   s8[7:0] = %0d", s8, s8[7:0]);

    i = 4'sb1111;  $display("8. int = 4'sb1111   : %0d", i);
    i = 4'b1111;   $display("9. int = 4'b1111    : %0d", i);

    li = -1;              $display("10. longint = -1            : %0d", li);
    li = unsigned'(-1);   $display("11. longint = unsigned'(-1) : %0d", li);
  end

endmodule
```

```output
1. same bits FF     : s8=-1  u8=255  sv8=-1
2. int = byte       : -1  (sign-extended)
3. int = bit [7:0]  : 255  (zero-extended)
4. -1 < 1           : false, -1 was treated as 4294967295
5. -8 >>> 1 = -4    -8 >> 1 = 124
6. unsigned F8 >>> 1 = 124
7. s8 = -8   s8[7:0] = 248
8. int = 4'sb1111   : -1
9. int = 4'b1111    : 15
10. longint = -1            : -1
11. longint = unsigned'(-1) : 4294967295
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | The same bit pattern `1111_1111` prints as -1 for the signed variables and 255 for the unsigned one. |
| 2 | The source `s8` is signed, so its MSB (1) is copied into the upper 24 bits: `FFFF_FFFF` = -1. |
| 3 | The source `u8` is unsigned, so the upper 24 bits are filled with 0: `0000_00FF` = 255. The destination is a signed `int` in both cases; only the source decides (rule 2). |
| 4 | `i` is signed and `ui` is unsigned. Rule 1: the comparison is unsigned. The pattern of -1 is `FFFF_FFFF`, which as an unsigned number is 4,294,967,295, and that is not less than 1. |
| 5 | -8 is `1111_1000`. `>>>` on a signed operand shifts in copies of the sign bit: `1111_1100` = -4. `>>` always shifts in 0: `0111_1100` = 124. |
| 6 | `>>>` on an unsigned operand behaves exactly like `>>`. The operator is "arithmetic" only when its left operand is signed. |
| 7 | A part-select is unsigned (rule 3), so the same eight bits print as 248. |
| 8, 9 | The `s` in the literal decides whether the 4-bit value `1111` is extended with ones (giving -1) or zeros (giving 15). |
| 10 | The literal `-1` is a signed 32-bit value; it is sign-extended to 64 bits and stays -1. |
| 11 | `unsigned'(-1)` is the 32-bit pattern `FFFF_FFFF` regarded as unsigned. It is zero-extended to 64 bits, giving 4,294,967,295. |

> **Interview trap:** "I declared the destination as signed, so the value will be sign-extended." Wrong. Extension is decided by the signedness of the expression on the right-hand side. `int i = u8;` zero-extends even though `i` is signed.

> **Common mistake:** Mixing one unsigned operand into signed arithmetic. In `result = s_a * s_b + u_offset;` the single unsigned `u_offset` makes the entire expression unsigned, so `s_a` and `s_b` are zero-extended instead of sign-extended and the product is wrong for negative inputs. Fix: `result = s_a * s_b + signed'({1'b0, u_offset});` or cast as appropriate.

> **Verification application:** A scoreboard's reference model must use the same signedness as the DUT. If the DUT has a signed multiplier and the reference model computes with unsigned `bit [7:0]` fields, every negative operand produces a false mismatch. When a comparison fails only for values with the MSB set, suspect signedness first.

### Interview questions

**Q1. How are negative numbers represented in SystemVerilog?**
In two's complement.

**Q2. What is the difference between `>>` and `>>>`?**
`>>` is a logical right shift and always fills the vacated bits with 0. `>>>` is an arithmetic right shift: it fills with the sign bit when the left operand is signed, and with 0 when the left operand is unsigned.

**Q3. `logic signed [3:0] a = -2; logic [7:0] b; b = a;` What is `b`?**
`a` is `1110` and is signed, so it is sign-extended: `b` = `1111_1110` = 254 as an unsigned value. The destination being unsigned does not prevent sign extension.

**Q4. What is the result of comparing a signed and an unsigned operand?**
Both are treated as unsigned. A negative signed value becomes a large positive value, so `-1 < 1` is false when one side is unsigned.

**Q5. What is the difference between `8'd200` and `8'sd200`?**
Both store the pattern `1100_1000`. `8'd200` is unsigned and has the value 200. `8'sd200` is signed and has the value -56.

**Q6. How do you convert between signed and unsigned?**
With the casts `signed'(x)` and `unsigned'(x)`, or the system functions `$signed(x)` and `$unsigned(x)`. They do not change any bit; they change how the bits are interpreted in the surrounding expression.

## 2.7 Real and Realtime Data Types

### In plain English

All the types so far hold whole numbers. A testbench also needs numbers with a fractional part: a clock period of 3.333 ns, a frequency of 2.4 GHz, a coverage figure of 87.5 percent, a voltage in an analogue model. These are stored in **real** (floating-point) types.

### Technical definition

| Type | Width | Equivalent C type | Default value | Use |
|---|---|---|---|---|
| `real` | 64 bits | `double` (IEEE 754 double precision) | 0.0 | General floating-point numbers |
| `shortreal` | 32 bits | `float` (IEEE 754 single precision) | 0.0 | Lower precision; mostly for DPI |
| `realtime` | 64 bits | `double` | 0.0 | Exactly the same type as `real`; the name documents that the value is a time |

Real types are not two-state or four-state. They are not built from individually accessible bits at all, so the concept does not apply: a real variable can never hold X or Z.

### Memory representation

```text
   real (64 bits, IEEE 754 double)
   +------+-------------+------------------------------------------------------+
   | sign |  exponent   |                      fraction                        |
   | 1 bit|   11 bits   |                      52 bits                         |
   +------+-------------+------------------------------------------------------+
   about 15 to 16 significant decimal digits

   shortreal (32 bits, IEEE 754 single)
   +------+-------------+---------------------------+
   | sign |  exponent   |         fraction          |
   | 1 bit|   8 bits    |         23 bits           |
   +------+-------------+---------------------------+
   about 7 significant decimal digits
```

### What you can and cannot do with a real

| Allowed | Not allowed |
|---|---|
| `+`, `-`, `*`, `/`, `**`, unary `-` | `%` (modulus) |
| `<`, `<=`, `>`, `>=`, `==`, `!=` | `===`, `!==`, `==?`, `!=?` |
| `&&`, `\|\|`, `!`, `?:` | Bitwise, reduction and shift operators |
| Assignment to and from integer types (with conversion) | Bit-select or part-select such as `r[3]` |
| `$display` with `%f`, `%e`, `%g` | Use as an array index, or edge detection with `posedge` |

Real types are **not synthesizable**.

### Conversion between real and integer

| Operation | Behaviour | 3.7 | 2.5 | -2.5 |
|---|---|---|---|---|
| Implicit assignment `i = r;` | Rounds to nearest; a tie rounds away from zero | 4 | 3 | -3 |
| Cast `int'(r)` | Same as implicit assignment: rounds | 4 | 3 | -3 |
| `$rtoi(r)` | Truncates toward zero | 3 | 2 | -2 |
| `$itor(i)` | Integer to real | | | |
| `$realtobits(r)` | The 64-bit IEEE pattern as a `bit [63:0]`, no numeric conversion | | | |
| `$bitstoreal(b)` | The reverse of `$realtobits` | | | |
| `$ceil(r)`, `$floor(r)` | Round up / round down, result is a real | 4.0 / 3.0 | 3.0 / 2.0 | -2.0 / -3.0 |

> **Interview trap:** In C, converting a `double` to an `int` truncates. In SystemVerilog, assigning a real to an integer **rounds**. Use `$rtoi` when you need truncation.

### Complete example

```systemverilog file=tb_real.sv
module tb_real;

  real r;
  int  i;

  initial begin
    $display("1. default real      = %0f", r);

    r = 3.7;
    i = r;         $display("2. i = r      (3.7)  = %0d", i);
    i = int'(r);   $display("3. int'(r)    (3.7)  = %0d", i);
    i = $rtoi(r);  $display("4. $rtoi(r)   (3.7)  = %0d", i);
    i = int'(2.5); $display("5. int'(2.5)         = %0d", i);
    i = int'(-2.5);$display("6. int'(-2.5)        = %0d", i);

    r = 7 / 2;     $display("7. r = 7 / 2         = %0.2f", r);
    r = 7 / 2.0;   $display("8. r = 7 / 2.0       = %0.2f", r);

    r = 0.1 + 0.2;
    if (r == 0.3) $display("9. 0.1 + 0.2 == 0.3");
    else          $display("9. 0.1 + 0.2 != 0.3, it is %0.17f", r);

    if ((r - 0.3) < 1.0e-9 && (0.3 - r) < 1.0e-9)
      $display("10. equal within a tolerance of 1e-9");
  end

endmodule
```

```output
1. default real      = 0.000000
2. i = r      (3.7)  = 4
3. int'(r)    (3.7)  = 4
4. $rtoi(r)   (3.7)  = 3
5. int'(2.5)         = 3
6. int'(-2.5)        = -3
7. r = 7 / 2         = 3.00
8. r = 7 / 2.0       = 3.50
9. 0.1 + 0.2 != 0.3, it is 0.30000000000000004
10. equal within a tolerance of 1e-9
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | A real starts at 0.0, not X. |
| 2, 3 | Implicit conversion and the `int'()` cast both round 3.7 to 4. |
| 4 | `$rtoi` discards the fraction: 3. |
| 5, 6 | A value exactly halfway is rounded away from zero: 2.5 → 3 and -2.5 → -3. |
| 7 | Both operands of `7 / 2` are integers, so integer division is performed first (result 3) and only then converted to real: 3.00. The type of the destination does not influence how the right-hand side is calculated. |
| 8 | One real operand makes the whole division real: 3.50. |
| 9 | 0.1, 0.2 and 0.3 cannot be represented exactly in binary floating point, so the sum differs from 0.3 in the 17th digit. |
| 10 | The correct way to compare reals: check that the difference is smaller than a tolerance. |

### time, realtime, $time and $realtime

Simulation time is measured in units set by the **time unit** and rounded to the **time precision**. They are set with the `` `timescale `` directive or, preferably in SystemVerilog, with `timeunit` and `timeprecision` inside the module.

| Item | What it is |
|---|---|
| `` `timescale 1ns/1ps `` | Time unit 1 ns (so `#1` means 1 ns); precision 1 ps (delays are rounded to the nearest ps) |
| `time` | 64-bit unsigned four-state integer variable for storing times |
| `realtime` | A `real` variable for storing times with a fraction |
| `$time` | Returns the current time as a 64-bit integer, in time units, **rounded** to a whole unit |
| `$realtime` | Returns the current time as a real, in time units, including the fraction |
| `$stime` | Returns the low 32 bits of the current time |
| `$timeformat(unit, digits, suffix, width)` | Controls how `%t` prints times |

```systemverilog file=tb_time.sv
`timescale 1ns/1ps

module tb_time;

  time     t_int;
  realtime t_real;
  realtime t_start, latency;

  initial begin
    $timeformat(-9, 3, " ns", 0);    // unit = ns, 3 decimals, suffix, no minimum width

    #1.75;
    t_int  = $time;
    t_real = $realtime;
    $display("$time     = %0d", t_int);
    $display("$realtime = %0.3f", t_real);
    $display("with %%t   = %t", $realtime);

    t_start = $realtime;
    #12.5;
    latency = $realtime - t_start;
    $display("latency   = %0.2f ns", latency);
  end

endmodule
```

```output
$time     = 2
$realtime = 1.750
with %t   = 1.750 ns
latency   = 12.50 ns
```

**Explanation**

| Code | Explanation |
|---|---|
| `` `timescale 1ns/1ps `` | One time unit is 1 ns; the simulator keeps time to 1 ps. |
| `$timeformat(-9, 3, " ns", 0);` | `-9` means "print in units of 10^-9 s". Called once, usually at the start of the test. |
| `#1.75;` | A delay of 1.75 ns, which is exactly 1750 ps, so nothing is lost to rounding. |
| `t_int = $time;` | `$time` rounds 1.75 to the nearest whole time unit: 2. This is why `$time` can mislead you when delays have fractions. |
| `t_real = $realtime;` | Keeps the fraction: 1.750. |
| `latency = $realtime - t_start;` | The usual way to measure how long something took. |

> **Common mistake:** With `` `timescale 1ns/100ps ``, the delay `#1.75` is rounded to the precision and becomes 1.8 ns. If a generated clock has the wrong frequency, check the time precision first.

### Real-world verification uses of real

```systemverilog
`timescale 1ns/1ps
module tb_clock_gen;
  logic clk = 0;
  real  freq_mhz  = 150.0;
  real  period_ns = 1000.0 / freq_mhz;      // 6.667 ns
  always #(period_ns / 2.0) clk = ~clk;
endmodule
```

- Clock generators with periods that are not whole numbers, as above.
- Measuring frequency, duty cycle, latency and throughput in monitors and checkers.
- Coverage: `$get_coverage()` and the `get_coverage()` method of a covergroup return a `real` percentage.
- Real-number modelling of analogue blocks (PLLs, ADCs, voltage regulators) in mixed-signal verification.
- Computing percentages and averages for end-of-test reports.

### Interview questions

**Q1. What is the difference between `real` and `shortreal`?**
`real` is 64-bit double precision (C `double`). `shortreal` is 32-bit single precision (C `float`).

**Q2. What is the difference between `real` and `realtime`?**
None in behaviour. They are the same type. `realtime` is used for variables that hold time values, to make the code self-documenting.

**Q3. What is the difference between `time` and `realtime`?**
`time` is a 64-bit unsigned four-state integer and holds a whole number of time units. `realtime` is a real and can hold fractional time.

**Q4. What is the difference between `$time` and `$realtime`?**
`$time` returns an integer, rounded to the nearest whole time unit. `$realtime` returns a real number that includes the fractional part.

**Q5. What is the default value of a `real`?**
0.0.

**Q6. `real r = 5 / 2;` What is `r`?**
2.0. The division is done with integers because both operands are integers; the result 2 is then converted to real. Write `5.0 / 2` or `real'(5) / 2` to get 2.5.

**Q7. `int i = 2.5;` What is `i`?**
3. Real-to-integer conversion rounds, with ties away from zero. `$rtoi(2.5)` gives 2.

**Q8. Are real types synthesizable?**
No. They are used in testbenches and in behavioural or real-number models.

**Q9. Why should you not compare two reals with `==`?**
Because most decimal fractions cannot be represented exactly in binary floating point, so two values that are mathematically equal can differ in the last bits. Compare the absolute difference against a small tolerance instead.
