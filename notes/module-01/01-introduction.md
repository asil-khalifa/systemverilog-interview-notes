# How to Use These Notes

These notes are Module 1 of an eleven-module course that prepares you for SystemVerilog interviews for Design Verification (DV) roles. The goal is understanding, not memorising syntax: for each concept you should be able to say what it is, why it exists, how it behaves in a simulator, where it is used in a real testbench, and what mistakes people make with it.

**How each topic is organised**

1. The idea in plain English.
2. The technical definition, using the terms an interviewer expects.
3. Why it is needed.
4. How it works internally (memory layout, simulator behaviour).
5. Syntax.
6. Complete, runnable SystemVerilog code with the expected output.
7. A line-by-line explanation of that code.
8. Comparison tables against related concepts.
9. Common mistakes and interview traps.
10. Interview questions with answers.

**Conventions used in the code**

| Convention | Meaning |
|---|---|
| `_t` suffix | A user-defined type made with `typedef` (for example `hdr_t`) |
| `_e` suffix | An enumerated type (for example `alu_op_e`) |
| `_u` suffix | A union type |
| `tb_` prefix | A small testbench module whose only purpose is to demonstrate a concept |
| `alu`, `alu_pkg` | The 8-bit ALU that is the running example DUT for the whole course |
| `clk`, `rst_n` | Clock, and active-low reset |

**About the code examples.** Every example that carries a file name (such as `tb_states.sv`) is also saved as a separate file in the `examples/module-01/` folder of the repository, so you can paste it into any simulator. All examples use standard IEEE 1800 SystemVerilog and are written to run on the commercial simulators (Synopsys VCS, Cadence Xcelium, Siemens Questa). The free website EDA Playground gives you access to these simulators in a browser, and that is the easiest way to run the code.

> **Note:** The "Expected output" blocks in this module were worked out by hand from the rules in the IEEE 1800 standard; they were not captured from a simulator run. Run each example yourself. Doing so is the best way to learn, and if a simulator prints something different, working out why is exactly the kind of understanding an interviewer is testing. Where behaviour is known to differ between simulators (for example the exact layout printed by `%p`), the text says so.

**Terms you will meet immediately**

| Term | Meaning |
|---|---|
| RTL | Register Transfer Level: the synthesizable description of the hardware |
| DUT | Design Under Test: the RTL block being verified |
| Testbench (TB) | Non-synthesizable code that drives the DUT and checks its outputs |
| Simulator | The software tool that executes the RTL and testbench (VCS, Xcelium, Questa) |
| Synthesis | Conversion of RTL into a gate-level netlist by a synthesis tool |
| LRM | Language Reference Manual: the IEEE 1800 standard document |
| Synthesizable | Can be converted into real hardware by a synthesis tool |
| Simulation-only | Understood by the simulator only; has no hardware equivalent |

# Part 1: Introduction to SystemVerilog

## 1.1 Introduction to SystemVerilog

### In plain English

A chip is first described as text. Engineers write code that describes what the hardware should do, a tool turns that code into logic gates, and a factory turns the gates into silicon. A mistake found after the chip is manufactured costs millions of dollars and months of delay, so the code is tested very heavily before manufacturing. That testing is called **verification**, and it takes more engineering effort than writing the design itself.

SystemVerilog is one language that serves both jobs. One part of the language describes hardware. A larger part of the language exists only to test that hardware: it can generate random stimulus, model expected behaviour, check results automatically and measure how much has been tested.

### Technical definition

SystemVerilog is a **Hardware Description and Verification Language (HDVL)**, standardised as **IEEE 1800**. It is a superset of Verilog (IEEE 1364): every legal Verilog-2005 construct is legal SystemVerilog, and SystemVerilog adds

- richer data types (`logic`, `bit`, `int`, `enum`, `struct`, `union`, `typedef`, dynamic arrays, queues, associative arrays, strings),
- design constructs that state the designer's intent (`always_ff`, `always_comb`, `always_latch`, `unique`/`priority`, interfaces, packages),
- object-oriented programming (classes, inheritance, polymorphism),
- constrained-random stimulus generation (`rand`, `randc`, `constraint`, `randomize()`),
- functional coverage (`covergroup`, `coverpoint`, `cross`),
- assertions (immediate assertions and concurrent SystemVerilog Assertions, SVA),
- inter-process communication (mailboxes, semaphores, events, `fork`...`join`),
- a direct interface to C code (DPI).

### Where SystemVerilog sits in the chip design flow

```text
  Specification (what the chip must do)
        |
        v
  RTL design in SystemVerilog  ---------------------+
  (synthesizable subset)                            |
        |                                           v
        |                              Functional verification
        |                              (SystemVerilog testbench, usually UVM)
        |                              simulate, find bugs, fix RTL, repeat
        |                                           |
        v                                           |
  Synthesis  (RTL -> gate-level netlist)  <---------+   only after verification
        |                                               reaches its coverage goals
        v
  Place and route, timing closure, physical checks
        |
        v
  Tape-out  (design sent to the factory)
```

A Design Verification engineer works in the box on the right. The job is to prove, before tape-out, that the RTL does what the specification says.

### DUT and testbench

Everything in verification is built around two things:

```text
  +---------------------------- Testbench (not synthesizable) ----------------------------+
  |                                                                                        |
  |   stimulus                +------------------+                 response                |
  |   generation   -------->  |       DUT        |  -------->      checking                |
  |   (what to drive)         | (synthesizable   |                 (is the output right?)  |
  |                           |      RTL)        |                                         |
  |                           +------------------+                                         |
  |                                                                                        |
  +----------------------------------------------------------------------------------------+
```

- The **DUT** must be synthesizable, because it becomes hardware.
- The **testbench** never becomes hardware. It only runs in a simulator, so it may use the whole language.

This split explains most of the "why" questions about SystemVerilog data types. Hardware signals need values such as "unknown" and "not driven", so the DUT uses four-state types. Testbench bookkeeping (loop counters, transaction counts, scoreboards) does not, so the testbench mostly uses faster two-state types. You will see this theme throughout this module.

### Your first SystemVerilog program

```systemverilog file=tb_hello.sv
module tb_hello;

  int unsigned count;
  string       name = "SystemVerilog";

  initial begin
    count = 3;
    repeat (count) begin
      $display("[%0t] Hello from %s", $time, name);
      #10;
    end
    $display("[%0t] Done", $time);
    $finish;
  end

endmodule
```

```output
[0] Hello from SystemVerilog
[10] Hello from SystemVerilog
[20] Hello from SystemVerilog
[30] Done
```

**Line by line**

| Line | Explanation |
|---|---|
| `module tb_hello;` | A module is the basic building block. A top-level testbench module has no ports because nothing is above it. |
| `int unsigned count;` | A 32-bit two-state unsigned variable. `int` does not exist in Verilog; it is a SystemVerilog type. |
| `string name = "SystemVerilog";` | `string` is a SystemVerilog type whose length changes automatically. In Verilog you had to use a fixed-width `reg` vector. |
| `initial begin` | An `initial` block starts at simulation time 0 and runs once. It is simulation-only. |
| `repeat (count)` | Executes the body `count` times. |
| `$display(...)` | A system task that prints a line. `%0t` prints the time with no padding, `%s` prints a string. |
| `$time` | A system function that returns the current simulation time. |
| `#10;` | Suspends this process for 10 time units. Simulation time advances; no real time is implied. |
| `$finish;` | Ends the simulation. |

### What a simulator does with your code

A simulator processes the source in three steps. Interviewers like to ask at which step a particular error is detected.

| Step | What happens | Typical errors found here |
|---|---|---|
| Compilation | Each file is parsed and checked for syntax and type rules | Missing semicolon, undeclared identifier, assigning to a net in a procedural block |
| Elaboration | The design hierarchy is built: modules are instantiated, parameters resolved, ports connected | Port width mismatch, missing module, illegal parameter value |
| Simulation (run time) | Processes execute and simulation time advances | Null handle access, `$cast` failure, randomization failure, array index out of range, assertion failure |

> **Key point:** SystemVerilog is "statically typed". The type of every variable is fixed at compile time. Only a few things are decided at run time: the size of dynamic arrays, queues and associative arrays, the object a class handle points to, and whether a `$cast` succeeds.

### Interview questions

**Q1. What is SystemVerilog?**
SystemVerilog is a hardware description and verification language standardised as IEEE 1800. It is a superset of Verilog. It adds design features such as `logic`, `always_ff`, `always_comb`, interfaces, enums and structs, and verification features such as classes, constrained randomization, functional coverage, assertions and inter-process communication.

**Q2. Is SystemVerilog a design language or a verification language?**
Both. A synthesizable subset is used for RTL design. The complete language, including the non-synthesizable part (classes, randomization, coverage, mailboxes and so on), is used for verification.

**Q3. What does "HDVL" mean?**
Hardware Description and Verification Language. Verilog and VHDL are HDLs. SystemVerilog adds the "V" because verification features are part of the same language instead of being a separate language.

## 1.2 Difference Between Verilog and SystemVerilog

### A short history

Knowing the history lets you answer "why was it introduced?" with facts.

| Year | Event |
|---|---|
| 1984-85 | Verilog created at Gateway Design Automation |
| 1995 | Verilog becomes IEEE 1364-1995 |
| 2001 | IEEE 1364-2001 (Verilog-2001): `generate`, ANSI-style ports, signed arithmetic, `always @*` |
| 2002-04 | Accellera publishes SystemVerilog 3.0, 3.1 and 3.1a. Much of it comes from donated technology: the Superlog language (design extensions), OpenVera (testbench features), and assertion languages |
| 2005 | SystemVerilog becomes IEEE 1800-2005. Verilog is updated as IEEE 1364-2005 |
| 2009 | IEEE 1800-2009 merges Verilog and SystemVerilog into one standard. From here on, "Verilog" is formally just a subset of SystemVerilog |
| 2012, 2017, 2023 | Later revisions of IEEE 1800. Most tools and interview questions assume 1800-2012 or 1800-2017 |

### Comparison table

| Aspect | Verilog (IEEE 1364) | SystemVerilog (IEEE 1800) |
|---|---|---|
| Category | HDL | HDVL (design and verification) |
| Main data types | `wire`, `reg`, `integer`, `real`, `time` | All Verilog types plus `logic`, `bit`, `byte`, `shortint`, `int`, `longint`, `string`, `enum`, `struct`, `union`, `class` |
| Number of states | Four-state only (0, 1, X, Z) | Four-state and two-state types |
| User-defined types | None | `typedef`, `enum`, `struct`, `union`, `class` |
| Arrays | Fixed-size only | Fixed-size, dynamic, associative, queues, with built-in methods |
| Strings | Stored in fixed-width `reg` vectors | Built-in dynamic `string` type with methods |
| Procedural blocks | `always`, `initial` | Adds `always_ff`, `always_comb`, `always_latch`, `final` |
| Programming style | Procedural, module based | Procedural plus object-oriented |
| Randomization | `$random` only, no constraints | `rand`, `randc`, constraint blocks, `randomize()`, `$urandom`, `$urandom_range` |
| Coverage | Code coverage from the tool only | Functional coverage built in: `covergroup`, `coverpoint`, `cross` |
| Assertions | None (use `if` plus `$display`) | Immediate and concurrent assertions (SVA) |
| Connecting blocks | Individual ports and wires | `interface`, `modport`, `clocking` block, `.*` and `.name` connections |
| Process communication | Named events only | Events, mailboxes, semaphores, `fork`...`join_any`/`join_none`, process control |
| Code sharing | `` `include `` and `` `define `` | Packages with `import` |
| Tasks and functions | Static by default, no `ref`, no default arguments, a function must return a value | `automatic` lifetime, `ref` arguments, default arguments, `void` functions, `return` |
| Loops and control | `for`, `while`, `repeat`, `forever` | Adds `foreach`, `do`...`while`, `break`, `continue`, `return` |
| Operators | No `++`, `+=` | `++`, `--`, `+=` and similar, `inside`, `==?`, `!=?`, streaming operators |
| C integration | PLI/VPI (complex) | DPI (simple function calls to and from C) |
| Typical use | RTL design, simple testbenches | RTL design and complete verification environments, base language of UVM |

### The same design in both languages

A 4-bit counter in Verilog:

```systemverilog
module counter_v (clk, rst_n, en, count);
  input        clk, rst_n, en;
  output [3:0] count;
  reg    [3:0] count;                 // must be reg: assigned in always

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  count <= 4'b0000;
    else if (en) count <= count + 1;
  end
endmodule
```

The same counter in SystemVerilog:

```systemverilog
module counter_sv (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       en,
  output logic [3:0] count           // logic: no reg/wire decision needed
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  count <= '0;        // '0 fills any width with zeros
    else if (en) count <= count + 1'b1;
  end
endmodule
```

What changed, and why each change matters:

| Change | Benefit |
|---|---|
| `reg` replaced by `logic` | You no longer choose between `reg` and `wire` based on how the signal is assigned |
| `always` replaced by `always_ff` | States the intent "this is a flip-flop". Tools report an error if the block does not describe sequential logic, or if the same variable is also written from another process |
| `4'b0000` replaced by `'0` | Works for any width, so the code survives a width change |

### Interview questions

**Q1. Give five differences between Verilog and SystemVerilog.**
Pick the ones you can explain: (1) SystemVerilog has two-state types such as `bit` and `int`; Verilog has only four-state types. (2) SystemVerilog has classes and OOP. (3) SystemVerilog has constrained randomization. (4) SystemVerilog has functional coverage and assertions built in. (5) SystemVerilog has interfaces to bundle signals. (6) SystemVerilog has dynamic arrays, queues and associative arrays. (7) SystemVerilog has `always_ff`, `always_comb` and `always_latch`.

**Q2. Is Verilog code valid SystemVerilog?**
Yes, with one practical exception: SystemVerilog added many reserved keywords (`bit`, `logic`, `class`, `rand`, `interface`, `priority`, `do`, `final` and others). Old Verilog code that used one of these as a signal name will not compile as SystemVerilog until it is renamed, or the file is compiled with the `` `begin_keywords "1364-2005" `` directive.

**Q3. Is Verilog still a separate standard?**
No. Since IEEE 1800-2009 there is one merged standard. The IEEE 1364 standard is no longer maintained.

## 1.3 Why SystemVerilog Was Introduced

### The problem: the verification gap

Chip complexity grows much faster than the ability to verify it by hand. With Verilog, a testbench was a set of **directed tests**: the engineer wrote each stimulus value and each expected value manually. That works for a counter. It does not work for a processor or a network switch, where the number of possible scenarios is far too large to list. Projects were spending about 60 to 70 percent of their effort on verification and bugs were still reaching silicon.

### Specific limitations of Verilog

| Limitation in Verilog | Consequence | What SystemVerilog added |
|---|---|---|
| Only `$random`, with no way to constrain values | Random stimulus was mostly illegal or uninteresting | `rand`/`randc` variables, constraints, a constraint solver |
| No data structures | Packets and transactions were handled as many separate variables | `struct`, `class`, queues, dynamic and associative arrays |
| No object-oriented programming | Testbench code could not be reused or extended cleanly | Classes, inheritance, polymorphism |
| No way to measure what was tested | "Are we done?" could not be answered objectively | Functional coverage |
| No assertion language | Protocol checks were hand-written `always` blocks | SystemVerilog Assertions |
| Only four-state types | Slow, memory-hungry testbenches | Two-state types |
| `reg` versus `wire` confusion | Constant source of compile errors for beginners | `logic` |
| Ports connected signal by signal | Hundreds of repeated lines, easy to mis-connect | `interface`, `.*` connections |
| `always` does not state intent | Unintended latches, simulation and synthesis mismatches | `always_ff`, `always_comb`, `always_latch` |
| DUT and testbench race at clock edges | Testbench results depended on simulator ordering | `program` blocks and `clocking` blocks with defined sampling and driving regions |
| No good way to synchronise parallel threads | Hand-built handshakes with events | Mailboxes, semaphores, `fork`...`join_any`/`join_none` |

### The second reason: too many languages

Before SystemVerilog, a typical project used Verilog or VHDL for RTL, a separate Hardware Verification Language such as Vera or *e* for the testbench, another language such as PSL for assertions, and C for reference models. Each needed its own tool, licence and training, and the boundaries between them caused problems. SystemVerilog unified design, testbench and assertions in one language, with DPI as a simple bridge to C.

> **How to say it in an interview:** "Verilog was adequate for describing hardware, but not for verifying large designs. It had no constrained randomization, no OOP, no functional coverage and no assertions, so teams used separate verification languages. SystemVerilog was introduced to unify design and verification in one language, and to raise verification productivity through constrained-random, coverage-driven testing."

### Interview questions

**Q1. Why was SystemVerilog introduced when Verilog already existed?**
Use the answer in the box above, then give two concrete examples from the table.

**Q2. What is constrained-random verification and why is it better than directed testing?**
In directed testing the engineer writes every stimulus by hand, so only the scenarios the engineer thought of are tested. In constrained-random verification the testbench generates random stimulus that is restricted to legal values by constraints. Thousands of scenarios are generated automatically, including corner cases nobody thought of. Functional coverage then measures which scenarios actually occurred. Directed tests are still used for the few specific cases that random stimulus does not reach. This is covered in depth in Modules 5, 6 and 10.

## 1.4 SystemVerilog Applications in Design and Verification

### Two subsets of one language

```text
  +--------------------------- SystemVerilog (IEEE 1800) ----------------------------+
  |                                                                                  |
  |   +----------- Synthesizable subset (RTL design) -----------+                    |
  |   | module, logic, always_ff, always_comb, assign, enum,    |                    |
  |   | packed struct, interface, package, parameter, generate  |                    |
  |   +---------------------------------------------------------+                    |
  |                                                                                  |
  |   Simulation-only constructs (verification)                                      |
  |   class, rand, constraint, covergroup, mailbox, semaphore, event, fork-join,     |
  |   initial, #delay, queue, dynamic array, associative array, string, program,     |
  |   $display, DPI, concurrent assertions (also usable in formal verification)      |
  |                                                                                  |
  +----------------------------------------------------------------------------------+
```

### What is synthesizable and what is not

| Construct | Synthesizable? | Notes |
|---|---|---|
| `module`, ports, `parameter`, `localparam`, `generate` | Yes | |
| `logic`, `bit`, `wire`, `reg`, packed arrays | Yes | `bit` is accepted but hides X in simulation, so `logic` is preferred in RTL |
| `int`, `byte`, `integer` | Yes | Mostly used for loop variables and constants in RTL |
| `real`, `shortreal`, `realtime`, `time` | No | |
| `string` | No | Accepted only in parameters by some tools |
| `enum`, `typedef`, packed `struct`, packed `union` | Yes | Heavily used in modern RTL |
| Unpacked `struct`, fixed-size unpacked arrays | Yes | Supported by most tools |
| Dynamic arrays, queues, associative arrays | No | Size is not known at compile time |
| `always_ff`, `always_comb`, `always_latch`, `assign` | Yes | |
| `initial` | No | FPGA tools accept it for power-up values; ASIC flows ignore it |
| `#delay`, `wait`, `fork`...`join` | No | |
| `function` | Yes | If it contains no timing and no simulation-only constructs |
| `task` | Limited | Only if it contains no timing control |
| `interface`, `modport` | Yes | |
| `package` | Yes | When it contains synthesizable items (types, parameters, functions) |
| `class`, `rand`, `constraint`, `covergroup` | No | |
| `mailbox`, `semaphore`, `event` | No | |
| `program`, `clocking` block | No | Testbench constructs |
| Immediate and concurrent assertions | Ignored by synthesis | Used in simulation and formal verification |
| `$display`, `$finish`, `$random` and other system tasks | Ignored by synthesis | |

> **Key point:** "Not synthesizable" does not mean "bad". The whole testbench is not synthesizable, and it does not need to be.

### The course DUT: an 8-bit ALU

The following design is used as the running example throughout this course. In this module it shows the design-side features of SystemVerilog. From Module 6 onward we build a complete class-based testbench around it.

**Specification**

- Inputs `a` and `b` are 8 bits wide. Input `op` selects the operation.
- When `valid_in` is 1 at a rising clock edge, the ALU computes the result and presents it on the next cycle with `valid_out` = 1.
- `result` is 9 bits wide so that the carry of an addition (or the borrow of a subtraction) is visible in bit 8.
- `rst_n` is an asynchronous, active-low reset.

| `op` | Name | `result` |
|---|---|---|
| 000 | `ALU_ADD` | `a + b` (bit 8 is the carry) |
| 001 | `ALU_SUB` | `a - b` (bit 8 is the borrow) |
| 010 | `ALU_AND` | `a & b` |
| 011 | `ALU_OR` | `a \| b` |
| 100 | `ALU_XOR` | `a ^ b` |
| 101 | `ALU_NOT` | `~a` |
| 110 | `ALU_SHL` | `a` shifted left by one (bit 8 receives the old `a[7]`) |
| 111 | `ALU_SHR` | `a` shifted right by one |

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

```systemverilog file=alu.sv
module alu
  import alu_pkg::*;
(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       valid_in,
  input  logic [7:0] a,
  input  logic [7:0] b,
  input  alu_op_e    op,
  output logic       valid_out,
  output logic [8:0] result
);

  logic [8:0] result_nxt;

  always_comb begin
    unique case (op)
      ALU_ADD: result_nxt = a + b;
      ALU_SUB: result_nxt = a - b;
      ALU_AND: result_nxt = {1'b0, a & b};
      ALU_OR : result_nxt = {1'b0, a | b};
      ALU_XOR: result_nxt = {1'b0, a ^ b};
      ALU_NOT: result_nxt = {1'b0, ~a};
      ALU_SHL: result_nxt = {a, 1'b0};
      ALU_SHR: result_nxt = {2'b00, a[7:1]};
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 1'b0;
      result    <= '0;
    end
    else begin
      valid_out <= valid_in;
      if (valid_in) result <= result_nxt;
    end
  end

endmodule
```

**Explanation of the design**

| Code | Explanation |
|---|---|
| `package alu_pkg; ... endpackage` | A package is a named container for declarations that several files need. Here it holds the opcode type so that the DUT and the testbench share one definition. Packages are covered in Module 11. |
| `typedef enum logic [2:0] {...} alu_op_e;` | Creates a new type with eight named values stored in 3 bits. Section 3.5 explains enums. |
| `import alu_pkg::*;` | Makes the names in the package visible inside the module. Placed before the port list so the port `op` can use the type. |
| `input logic [7:0] a` | An 8-bit four-state input. |
| `input alu_op_e op` | The port type is the enum, so waveforms show `ALU_ADD` instead of `000`. |
| `logic [8:0] result_nxt;` | Internal signal that carries the combinational result to the flip-flops. |
| `always_comb` | Combinational logic. The sensitivity list is inferred automatically, and the tool warns if a latch would be created. |
| `unique case (op)` | States that exactly one branch matches for every value. The simulator reports a violation if none or several match, and synthesis may optimise using that promise. |
| `result_nxt = a + b;` | The left side is 9 bits, so `a` and `b` are extended to 9 bits before the addition and the carry is kept. Section 4.4 explains this "context-determined width" rule. |
| `{1'b0, a & b}` | Concatenation. A zero is placed in bit 8 because logical operations produce no carry. |
| `{a, 1'b0}` | `a` shifted left by one position, written as a concatenation so that `a[7]` lands in bit 8. |
| `always_ff @(posedge clk or negedge rst_n)` | Sequential logic with asynchronous active-low reset. |
| `result <= '0;` | Nonblocking assignment, which is always used for flip-flops. `'0` sets every bit to 0. |
| `if (valid_in) result <= result_nxt;` | The result register only updates when the input is valid. |

### A first, directed testbench for the ALU

This is the Verilog style of testbench: one hand-written stimulus and one hand-written check. Its purpose here is to show simulation-only constructs next to the design. Module 9 replaces it with a layered, class-based testbench.

```systemverilog file=tb_alu_directed.sv
module tb_alu_directed;
  import alu_pkg::*;

  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  always #5 clk = ~clk;

  initial begin
    rst_n    = 0;
    valid_in = 0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    a        = 8'd200;
    b        = 8'd100;
    op       = ALU_ADD;
    valid_in = 1;

    @(negedge clk);
    valid_in = 0;
    if (valid_out !== 1'b1 || result !== 9'd300)
      $error("[%0t] FAIL: %0d + %0d gave %0d (valid_out=%b)", $time, a, b, result, valid_out);
    else
      $display("[%0t] PASS: %0d + %0d = %0d", $time, a, b, result);

    $finish;
  end

endmodule
```

```output
[30] PASS: 200 + 100 = 300
```

**Execution flow**

| Time | What happens |
|---|---|
| 0 | `clk` starts at 0. The `initial` block drives reset active and gives every input a known value. |
| 5, 15 | Rising clock edges. The `repeat (2) @(posedge clk)` statement waits for both. |
| 15 | Reset is released (`rst_n = 1`). |
| 20 | Falling edge. The testbench drives `a`=200, `b`=100, `op`=`ALU_ADD`, `valid_in`=1. Driving on the falling edge keeps the stimulus stable around the rising edge and avoids a race with the DUT. |
| 25 | Rising edge. The DUT samples `valid_in`=1, stores `result`=300 and sets `valid_out`=1. |
| 30 | Falling edge. The testbench removes `valid_in` and checks the outputs. 200 + 100 = 300, which needs the ninth bit. The check passes. |

**Points to notice**

| Code | Explanation |
|---|---|
| `alu dut (.*);` | Implicit port connection: each port is connected to the signal of the same name. It only compiles when names and types match. |
| `always #5 clk = ~clk;` | Clock with a period of 10 time units. `#5` is simulation-only. |
| `!==` in the check | The case-inequality operator. It also detects X and Z. If `!=` were used and `result` were X, the comparison would be unknown, the `if` would not execute, and the test would wrongly pass. Section 4.5 explains this trap in full. |
| `$error` | Prints an error message with severity "error". The simulator counts these, which regression scripts use to mark the test as failed. |

### Where SystemVerilog is used in verification

| Verification task | SystemVerilog feature | Module |
|---|---|---|
| Model one unit of stimulus (a packet, a bus transfer) | Transaction class | 4, 6 |
| Create many legal, varied stimuli | `rand`, constraints, `randomize()` | 5 |
| Pass transactions between testbench components | Mailbox | 7 |
| Run components in parallel | `fork`...`join` | 7 |
| Connect the class-based testbench to DUT pins | Interface, virtual interface, clocking block | 8 |
| Organise the testbench | Generator, driver, monitor, scoreboard, environment | 9 |
| Check protocol rules continuously | Assertions | 10 |
| Measure what has been tested | Functional coverage | 10 |
| Industry-standard methodology built from all of the above | UVM, a class library written in SystemVerilog | 11 |

### Interview questions

**Q1. Which SystemVerilog constructs are synthesizable?**
Modules, `logic`/`bit`/`wire` and packed arrays, `always_ff`, `always_comb`, `always_latch`, `assign`, enums, typedefs, packed structs and unions, interfaces, packages with synthesizable content, functions without timing, `generate`. Classes, randomization, coverage, dynamic arrays, queues, associative arrays, mailboxes, semaphores, delays and `initial` blocks are simulation-only.

**Q2. What is the advantage of `always_ff` and `always_comb` over `always`?**
They state the design intent, and tools check it. `always_comb` infers its own sensitivity list (including signals read inside called functions), executes once at time 0 so outputs are consistent from the start, and tools warn if it would infer a latch. `always_ff` must describe sequential logic. Both forbid the same variable from being written by any other process, which catches multiple-driver bugs at compile time.

**Q3. What does `unique case` do?**
It asserts that exactly one case item matches for every value of the case expression. In simulation a violation report is issued if no item matches or if more than one matches. For synthesis it means the items can be treated as mutually exclusive (parallel) and complete. `priority case` only asserts that at least one item matches, and keeps the priority order.

**Q4. Why did the testbench use `!==` instead of `!=`?**
Because `!=` returns X when either operand contains X or Z, and an `if` treats X as false. A DUT output stuck at X would then never be reported. `!==` compares X and Z literally and always returns 0 or 1.
