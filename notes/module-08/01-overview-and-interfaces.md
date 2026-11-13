# Module 8 Overview

This module explains how a testbench is physically connected to the design. Modules 4 to 7 built the software side of a testbench: classes, random transactions, mailboxes, parallel threads. None of that can touch a DUT pin yet. The constructs in this module are the bridge between class-based code and the signals of the DUT.

**What this module covers**

| Part | Topic | Question it answers |
|---|---|---|
| 1 | Interfaces | How do I bundle the signals of a bus into one reusable unit? |
| 2 | Modports and interface arrays | How do I say who drives which signal, and how do I handle several copies of a bus? |
| 3 | Virtual interfaces | How does a class, which is created at run time, reach signals that were created at elaboration time? |
| 4 | Clocking blocks | When exactly should the testbench sample and drive, so that it never races with the DUT? |
| 5 | Putting it together | The final ALU interface, classes that drive and monitor the ALU, bidirectional signals, program blocks |
| 6 | Revision and practice | Summary, interview questions, output prediction, debugging, exercises |

**What you need from earlier modules**

| From | You must already know |
|---|---|
| Module 1 | `logic` versus `wire`, the single-driver rule for variables, four-state values, the ALU design (`alu_pkg`, `alu`) |
| Module 3 | Tasks, functions, `automatic` lifetime, argument directions |
| Module 4 | Classes, handles, `null`, constructors, the `this` keyword |
| Module 7 | `fork`...`join_none`, events, blocking and nonblocking behaviour of processes |

**Naming used in this module**

| Name | Meaning |
|---|---|
| `alu_if` | The interface for the ALU. Its final form (with clocking blocks and modports) is used unchanged in Module 9 |
| `vif` | A virtual interface handle inside a class. Always this name |
| `drv_cb`, `mon_cb` | The clocking blocks used by the driver and by the monitor |
| `DUT`, `DRV`, `MON` | The modports of `alu_if` |
| `cnt_if`, `counter` | A 4-bit counter and its interface: a small design used to demonstrate one idea at a time |
| `tb_<topic>` | A small demonstration testbench |

**How the examples are organised.** Small examples are complete in one file. Several examples share a design, which is given once in its own file; the text before each example lists the files to compile and their order. The ALU examples need `alu_pkg.sv` and `alu.sv` from `examples/module-01/` to be compiled first.

> **Note:** As in the other modules, the "Expected output" blocks were derived by hand from the IEEE 1800-2017 rules by tracing every clock edge; they were not captured from a simulator. All stimulus in this module is set by hand (no randomization), so each output is fully determined. Where an example is deliberately racy, the text says that the result depends on the simulator instead of printing one result as fact.

# Part 1: Interfaces

## 1.1 The Problem: Connecting Blocks Port by Port

### In plain English

A chip is built from blocks that talk to each other over groups of wires. A group of wires that belong together, with rules about how they are used, is called a **bus** or a **protocol interface**: an AXI bus, an APB bus, an SPI link, or the handful of signals between our testbench and the ALU.

In Verilog there is no way to say "this is one bus". Every wire of the bus is listed separately, again and again: in the port list of each module that uses it, in the declarations of the parent module, and in every instantiation. A bus with 40 signals connecting three blocks means writing each of those 40 names about ten times.

### What this looks like for the ALU

The ALU from Module 1 has eight ports. Here is everything a Verilog-style testbench must write to connect it:

```systemverilog
module tb_top;
  import alu_pkg::*;

  // 1. Declare every signal once more in the testbench
  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  // 2. Connect every signal by name
  alu dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_in),
    .a         (a),
    .b         (b),
    .op        (op),
    .valid_out (valid_out),
    .result    (result)
  );

  // 3. A driver module and a monitor module would each need the same eight ports,
  //    the same eight declarations and the same eight connections again.
endmodule
```

### Why this is a real problem

| Problem | Consequence |
|---|---|
| The same list of signals is repeated in many places | Long, repetitive code. For a real bus this is hundreds of lines |
| Adding or renaming one signal means editing every one of those places | A change that should take one line takes an hour, and one missed place is a bug |
| Nothing ties the declarations together | One module can declare `addr` as 16 bits and another as 32 bits. The tool gives at most a width warning |
| A misspelled name in a connection creates an implicit 1-bit wire | The signal is silently left unconnected (Module 1, Section 2.4) |
| The protocol rules live somewhere else | The checks and helper tasks for the bus cannot be kept with the bus signals |
| A class cannot have ports | There is no way at all to hand "the bus" to a driver class |

The last row is the important one for verification. Even if you accept all the typing, a class-based testbench needs a single object that represents the bus and can be passed around. Verilog has nothing like that.

### Interview questions

**Q1. What problems do Verilog port connections have for large designs?**
Every signal of a bus is declared and connected separately in every module that uses it, so the code is long and repetitive, a change to the bus has to be repeated in many files, mismatched widths and misspelled names are easy to introduce, and the protocol's checks and tasks cannot be packaged with the signals.

**Q2. Does `.*` solve the problem?**
Only the typing at the instantiation. The signals must still be declared individually in each module, the port lists are still long, and there is still no single object that represents the bus.

## 1.2 What Is an Interface?

### In plain English

An interface is a named bundle of signals. You declare the bundle once, create one copy of it, and connect that single copy to every block that uses the bus. A block that receives the bundle refers to a signal inside it with a dot, like a struct member: `bus.addr`.

Unlike a struct, the bundle can contain more than data. It can hold the direction rules of the bus, the timing rules for the testbench, helper tasks, and protocol checks.

### Technical definition

An `interface` is a SystemVerilog design element, declared between `interface` and `endinterface`, that encapsulates the communication between blocks. It is instantiated like a module and creates its own level of hierarchy. It may contain:

| An interface may contain | Purpose | Covered in |
|---|---|---|
| Nets and variables | The signals of the bus | 1.3 |
| Ports and parameters | Signals that come from outside (usually clock), configurable widths | 1.4 |
| `modport` declarations | Direction of each signal as seen by each kind of user | Part 2 |
| `clocking` blocks | Synchronous sampling and driving rules for the testbench | Part 4 |
| Tasks and functions | Bus operations such as "write one word" (a bus functional model) | 1.8 |
| `initial`, `always`, `assign` | Clock generation, tri-state drivers, simple glue logic | 1.6, 5.3 |
| Assertions and covergroups | Protocol checks and coverage that travel with the bus | 1.8, Module 10 |
| Instances of other interfaces | Building a large bus out of smaller ones | |

An interface may **not** contain an instance of a module.

### Why it is needed

| Need | How the interface meets it |
|---|---|
| Declare the bus once | One `interface` declaration; every user refers to it |
| Change the bus in one place | Add the signal to the interface. Blocks that do not use it need no change |
| Consistent widths and types | There is one declaration, so there is nothing to mismatch |
| Fewer connection errors | One connection per block instead of one per signal |
| Keep protocol knowledge with the signals | Tasks, assertions and coverage are written inside the interface |
| Give class-based code access to the signals | A class holds a *virtual interface* handle that refers to the interface instance (Part 3) |

### How it works internally

```text
                    tb_top
   +-------------------------------------------------------------+
   |                                                             |
   |    cnt_if cif (clk);          <- ONE instance: the signals  |
   |   +-------------------+          exist exactly once, here   |
   |   |  rst_n            |                                     |
   |   |  en               |                                     |
   |   |  count [3:0]      |                                     |
   |   +---------+---------+                                     |
   |             |                                               |
   |     +-------+------------------+                            |
   |     | (a reference, not a copy)|                            |
   |     v                          v                            |
   |  counter dut (cif);      testbench code: cif.en = 1;        |
   |  uses cif.en, cif.count                                     |
   +-------------------------------------------------------------+
```

- An interface instance is a scope in the design hierarchy, exactly like a module instance. Its full name here is `tb_top.cif`, and the counter value is `tb_top.cif.count`.
- The signals are created once, inside that instance, when the design is **elaborated** (before simulation starts). They exist for the whole simulation. This is called *static*.
- Passing the interface to a module through an interface port does not copy anything. The port is a reference to the instance. When the DUT writes `cif.count` and the testbench reads `cif.count`, they are using the same variable.

### Interface compared with module and struct

| Property | `module` | `interface` | `struct` |
|---|---|---|---|
| Purpose | Describes behaviour (logic) | Describes connections between blocks | Groups data values |
| Instantiated in the hierarchy | Yes | Yes | No, it is a data type |
| Can contain signals | Yes | Yes | Members only |
| Can contain `always`, `initial`, `assign` | Yes | Yes | No |
| Can contain tasks, functions, assertions | Yes | Yes | No |
| Can contain module instances | Yes | **No** | No |
| Can contain interface instances | Yes | Yes | No |
| Can be passed through a port as one item | No | Yes (interface port) | Yes (a port of struct type) |
| Per-user directions | Port directions | `modport` | None: a struct port has one direction for all members |
| Can be referenced from a class | No | Yes, through a virtual interface | A struct value can be copied into a class |
| Synthesizable | Yes | Yes, when its contents are | Yes |

> **Key point:** A struct port also bundles signals, but every member has the same direction. A bus has signals going both ways (request one way, response the other). That is why a bus is modelled with an interface plus modports and not with a single struct.

### Interview questions

**Q1. What is an interface in SystemVerilog?**
A design element that bundles the signals connecting two or more blocks into one named unit. It is instantiated once and connected to each block as a single port. It can also contain modports, clocking blocks, tasks, functions, assertions and procedural code related to the bus.

**Q2. What are the advantages of an interface?**
The bus is declared once; changes are made in one place; connections are shorter and less error-prone; directions (modports), timing (clocking blocks), protocol tasks, assertions and coverage can be kept with the signals; and it is the only way for class-based testbench code to reach DUT signals, through a virtual interface.

**Q3. Can an interface contain a module instance? Can a module contain an interface instance?**
An interface cannot instantiate a module. A module can instantiate an interface, and an interface can instantiate another interface.

**Q4. Is an interface synthesizable?**
Yes. An interface that contains signals, modports and synthesizable logic is accepted by synthesis tools, which flatten it into ordinary ports and wires. Clocking blocks, `initial` blocks, delays and assertions inside it are simulation-only.

**Q5. What is the difference between an interface and a struct?**
A struct is a data type whose members all travel in one direction through a port. An interface is a hierarchical instance that can give each signal its own direction per user, and can contain behaviour: tasks, assertions, clocking blocks and procedural blocks.

## 1.3 Interface Declaration, Signals and Instances

### Syntax

```systemverilog
// Declaration (at the same level as a module, never inside one)
interface <interface_name> [ #(<parameters>) ] [ (<ports>) ];
  <signal declarations>
  <modports, clocking blocks, tasks, functions, assertions ...>
endinterface

// Instantiation (inside a module, like a module instance)
<interface_name> <instance_name> (<port connections>);

// Use as a port of a module: the port "type" is the interface name
module <module_name> (<interface_name> <port_name>);
  ... <port_name>.<signal> ...
endmodule
```

### The demonstration design: a counter

The small examples in Parts 1 to 3 use a 4-bit counter. The interface and the design are in one file, which the later examples reuse.

```systemverilog file=counter_dut.sv
// The bundle of signals between the counter and whatever drives it
interface cnt_if (input logic clk);
  logic       rst_n;      // active-low asynchronous reset
  logic       en;         // count enable
  logic [3:0] count;      // counter value
endinterface

// The design: one interface port instead of four separate ports
module counter (cnt_if cif);

  always_ff @(posedge cif.clk or negedge cif.rst_n) begin
    if (!cif.rst_n)  cif.count <= '0;
    else if (cif.en) cif.count <= cif.count + 1'b1;
  end

endmodule
```

**Line by line**

| Line | Explanation |
|---|---|
| `interface cnt_if (input logic clk);` | Declares an interface named `cnt_if`. It has one port, `clk`, because the clock is generated outside and is shared with other blocks. Section 1.4 explains interface ports. |
| `logic rst_n;` `logic en;` `logic [3:0] count;` | The signals of the bundle. They are declared as `logic` variables. No directions are given here: an interface by itself only says which signals exist. |
| `endinterface` | Ends the declaration. |
| `module counter (cnt_if cif);` | The module has a single port named `cif` whose type is the interface `cnt_if`. This is called an **interface port**. |
| `cif.clk`, `cif.rst_n`, `cif.en`, `cif.count` | Signals inside the interface are accessed with `<port_name>.<signal_name>`. |
| `cif.count <= ...` | The design writes a variable that lives inside the interface. This is legal because `count` has exactly one writer, this `always_ff` block. |

### Complete example

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_if_basic.sv
module tb_if_basic;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);     // interface instance: creates rst_n, en and count
  counter dut (cif);     // one connection carries all the signals

  initial begin
    cif.rst_n = 0;
    cif.en    = 0;
    @(negedge clk);
    cif.rst_n = 1;
    cif.en    = 1;

    repeat (3) @(negedge clk);
    $display("[%0t] count = %0d", $time, cif.count);

    cif.en = 0;
    repeat (2) @(negedge clk);
    $display("[%0t] count = %0d", $time, cif.count);
    $finish;
  end

endmodule
```

```output
[40] count = 3
[60] count = 3
```

**Line by line**

| Line | Explanation |
|---|---|
| `cnt_if cif (clk);` | Creates one instance of the interface, named `cif`, and connects the testbench clock to its `clk` port. From this line on, the signals `cif.rst_n`, `cif.en` and `cif.count` exist. |
| `counter dut (cif);` | Connects the whole bundle to the design in one go. The instance name in the testbench (`cif`) and the port name in the module (`cif`) happen to be the same here; they do not have to be. |
| `cif.rst_n = 0;` | The testbench drives an interface signal directly, using the instance name. |
| `$display(..., cif.count)` | The testbench reads the value the design wrote into the same interface. |

**Execution flow**

| Time | Event |
|---|---|
| 0 | `rst_n` goes from X to 0, which is a negative edge, so the counter is reset to 0. `en` = 0. |
| 5 | Rising clock edge. Reset is still active; `count` stays 0. |
| 10 | Falling edge. The testbench releases reset and sets `en` = 1. |
| 15, 25, 35 | Rising edges. `count` becomes 1, 2, 3. |
| 40 | Third falling edge after time 10. The testbench prints `count = 3` and sets `en` = 0. |
| 45, 55 | Rising edges with `en` = 0. `count` stays 3. |
| 60 | The testbench prints `count = 3` and ends the simulation. |

The testbench changes its outputs on the **falling** edge and the design samples on the **rising** edge. This simple habit keeps the stimulus stable around the active edge and avoids a race. Part 4 replaces it with clocking blocks, which do the same job properly.

### Ways to connect an interface instance to an interface port

```systemverilog
counter dut (cif);          // by position
counter dut (.cif(cif));    // by name
counter dut (.cif);         // .name shorthand: instance name equals port name
counter dut (.*);           // implicit: connects ports to same-named instances and signals
```

> **Common mistake:** Forgetting the parentheses on an instance of an interface that has no ports. It is instantiated as `my_if bus ();` with empty parentheses. Without them the line is read as a variable declaration of an unknown type and fails to compile.

> **Common mistake:** Leaving an interface port unconnected. A module port of interface type must always be connected to an interface instance; unlike an ordinary port it cannot be left open.

### Interview questions

**Q1. How do you declare and instantiate an interface?**
Declare it with `interface name (ports); ... endinterface` outside any module. Instantiate it inside a module like a module instance: `name inst (port_connections);`.

**Q2. How does a module use an interface?**
It declares a port whose type is the interface name, for example `module counter (cnt_if cif);`, and accesses the signals as `cif.en`, `cif.count`.

**Q3. Are the signals copied when an interface is passed to two modules?**
No. There is one set of signals, inside the interface instance. Each module's interface port is a reference to that instance.

**Q4. Where can an interface be declared?**
At the same level as a module: in the compilation unit, not inside a module, package or class. (The standard allows nested interface declarations, but they are almost never used.)

## 1.4 Interface Ports and Parameters

### Interface ports

Some signals are not owned by the bus. The clock and often the reset are generated once and shared by many interfaces and modules. Such signals enter the interface through **ports**, declared like module ports:

```systemverilog
interface bus_if (input logic clk, input logic rst_n);
  logic        valid;
  logic        ready;
  logic [31:0] data;
endinterface

module tb;
  logic clk = 0, rst_n;
  bus_if bus_a (clk, rst_n);            // both instances share the same clock and reset
  bus_if bus_b (.clk(clk), .rst_n(rst_n));
endmodule
```

| Signal declared | Meaning |
|---|---|
| As an interface **port** (`input logic clk`) | Comes from outside. Every instance can be connected to the same source. Inside the interface it is used like any other signal: `bus_a.clk` |
| As an **internal signal** (`logic valid;`) | Belongs to this instance. Each instance has its own copy |

### Parameters

An interface can be parameterised exactly like a module, so one declaration serves buses of different widths.

```systemverilog
interface mem_if #(parameter int AW = 4, parameter int DW = 8) (input logic clk);
  logic          we;
  logic [AW-1:0] addr;
  logic [DW-1:0] wdata;
  logic [DW-1:0] rdata;
endinterface

module tb;
  logic clk = 0;
  mem_if                      small_mem (clk);   // default: 4-bit address, 8-bit data
  mem_if #(.AW(16), .DW(32))  large_mem (clk);   // 16-bit address, 32-bit data
endmodule
```

> **Interview trap:** Two instances of the same interface with different parameter values are two **different types**. A virtual interface handle (Part 3) must be declared with the same parameter values as the instance it will point to: `virtual mem_if #(16, 32) vif;`. Assigning `large_mem` to a handle declared as plain `virtual mem_if` (default parameters) is a compile error. Exercise 3 in Part 6 shows a complete example.

### Interview questions

**Q1. Why is the clock usually a port of the interface instead of an internal signal?**
Because the clock is generated once, outside, and is shared by the DUT and by every interface. Making it a port lets all instances be connected to the same clock. Clocking blocks and assertions inside the interface need a clock to refer to, so it must be visible inside the interface.

**Q2. Can an interface have parameters?**
Yes, with the same syntax as a module: `interface my_if #(parameter int W = 8) (input logic clk);`. Each distinct set of parameter values is a distinct type.

## 1.5 Connecting an Interface to a DUT

There are two styles of DUT, and you will meet both.

### Style 1: the DUT has an interface port

The counter above is written this way. The connection is one line: `counter dut (cif);`.

### Style 2: the DUT has ordinary ports

Most real RTL, and the ALU from Module 1, has ordinary ports. Many companies keep interfaces out of RTL port lists so that the netlist after synthesis has plain, predictable port names. The interface is then used on the **testbench side only**, and the instantiation connects each DUT port to the corresponding interface signal:

```systemverilog
// First version of the ALU interface: signals only.
// Parts 2 and 4 add modports and clocking blocks to reach the final form.
interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;
endinterface

module tb_top;
  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);                   // the one and only bundle of ALU signals

  alu dut (                           // the DUT keeps its ordinary ports
    .clk       (clk),
    .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),
    .a         (aif.a),
    .b         (aif.b),
    .op        (aif.op),
    .valid_out (aif.valid_out),
    .result    (aif.result)
  );

  // Everything else in the testbench receives "aif", never the individual signals.
endmodule
```

This still lists each signal, but only **once**, in the top module. The driver, the monitor and every other testbench component receive `aif` as a single item.

| Style | Connection | Used when |
|---|---|---|
| DUT with an interface port | `counter dut (cif);` | The RTL team uses interfaces in the design |
| DUT with ordinary ports | `.a(aif.a), .b(aif.b), ...` once in `tb_top` | The RTL has plain ports (very common). The interface exists for the testbench |

> **Verification application:** In a real project you receive the DUT as it is. If it has plain ports you write the interface yourself, with the same signal names as the DUT ports, and connect them in the top module exactly as above. Writing that interface is normally the first task when building a testbench for a new block.

### Interview questions

**Q1. The DUT has no interface in its port list. Can you still use an interface in the testbench?**
Yes. Instantiate the interface in the top module and connect each DUT port to the matching interface signal, for example `.a(aif.a)`. The rest of the testbench uses the interface.

**Q2. Where is the interface instantiated?**
In the top-level testbench module, next to the DUT instance, because both the DUT and the testbench must be connected to it.

## 1.6 Clock and Reset Generation Inside Interfaces

### In plain English

An interface may contain `initial` and `always` blocks, so it can generate a clock and apply a reset by itself. Whether it *should* depends on what the interface is for.

### Syntax

```systemverilog
interface clk_rst_if;

  logic clk = 0;
  logic rst_n;

  always #5 clk = ~clk;                        // clock generated inside the interface

  task automatic apply_reset(int unsigned cycles = 2);
    rst_n = 0;
    repeat (cycles) @(negedge clk);
    rst_n = 1;                                 // released away from the rising edge
  endtask

endinterface
```

### Complete example

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_if_clkgen.sv
interface clk_rst_if;

  logic clk = 0;
  logic rst_n;

  always #5 clk = ~clk;

  task automatic apply_reset(int unsigned cycles = 2);
    rst_n = 0;
    repeat (cycles) @(negedge clk);
    rst_n = 1;
  endtask

endinterface

module tb_if_clkgen;

  clk_rst_if cr  ();              // generates clock and reset
  cnt_if     cif (cr.clk);        // the counter bus uses that clock
  counter    dut (cif);

  assign cif.rst_n = cr.rst_n;    // the counter bus uses that reset

  initial begin
    cif.en = 1;
    cr.apply_reset(2);
    $display("[%0t] reset released", $time);

    repeat (4) @(negedge cr.clk);
    $display("[%0t] count = %0d", $time, cif.count);
    $finish;
  end

endmodule
```

```output
[20] reset released
[60] count = 4
```

**Line by line**

| Line | Explanation |
|---|---|
| `interface clk_rst_if;` | An interface with no ports. It owns the clock and the reset. |
| `logic clk = 0; always #5 clk = ~clk;` | A free-running clock with a period of 10 time units, generated by the interface itself. |
| `task automatic apply_reset(...)` | A task inside the interface. It drives `rst_n` low, waits a number of falling edges, and drives it high. |
| `clk_rst_if cr ();` | Instance with empty parentheses because the interface has no ports. |
| `cnt_if cif (cr.clk);` | The clock of one interface is connected to the clock port of another. |
| `assign cif.rst_n = cr.rst_n;` | A continuous assignment drives the counter's reset from the clock/reset interface. `cif.rst_n` now has its one permitted driver, so the testbench must not also assign it procedurally. |
| `cr.apply_reset(2);` | A task of an interface instance is called as `<instance>.<task>`. |

**Execution flow**

| Time | Event |
|---|---|
| 0 | `apply_reset` drives `rst_n` = 0. The counter is reset. `en` = 1. |
| 10, 20 | Falling edges counted by the task. At 20 it releases the reset and returns. |
| 25, 35, 45, 55 | Rising edges with reset released and `en` = 1: `count` = 1, 2, 3, 4. |
| 60 | Fourth falling edge after time 20: prints `count = 4`. |

The reset is released on a falling edge on purpose. Releasing it at exactly the rising edge would create a race between the testbench (changing `rst_n`) and the design (reading `rst_n`) in the same instant.

### Should the clock be generated inside the interface?

| Approach | Advantages | Disadvantages |
|---|---|---|
| Clock generated in `tb_top` and passed to interfaces as a port (the usual choice) | One clock source for the DUT and all interfaces. The bus interface stays free of testbench-only code, so it can also be used by RTL and be synthesised | A few more lines in `tb_top` |
| Clock generated inside the **bus** interface | Fewer lines | Every instance generates its own clock: two instances of the bus give two separate clocks. The interface can no longer be shared with synthesizable RTL. The clock frequency is fixed inside the interface |
| A dedicated clock-and-reset interface (as in the example) | Keeps clock control in one place; tasks such as `apply_reset`, `stop_clock`, `set_period` can be called from classes through a virtual interface | One more interface to write |

> **Key point:** The bus interface (`alu_if`) receives the clock as an input port. The clock is generated once, in `tb_top` or in a dedicated clock interface. This is the arrangement used in the rest of the course and in almost every industrial testbench.

> **Interview trap:** "Can an interface contain an `always` block or an `initial` block?" Yes. Candidates often think an interface is only a list of wires. It can contain procedural blocks, continuous assignments, tasks, functions and assertions. What it cannot contain is a module instance.

### Interview questions

**Q1. Can you generate a clock inside an interface?**
Yes, for example `logic clk = 0; always #5 clk = ~clk;`. It is legal because an interface may contain procedural blocks.

**Q2. Why is the clock normally not generated inside the bus interface?**
Because each instance of the interface would create its own independent clock, the DUT and the other interfaces need the same clock, and delay-based code makes the interface unusable in synthesizable RTL. The clock is generated once in the top module (or in a dedicated clock interface) and passed in as a port.

**Q3. How would a test class control the reset?**
Through a virtual interface handle to an interface that owns the reset, calling a task such as `vif.apply_reset(5)` or assigning `vif.rst_n` directly.

## 1.7 Adding Values to Interface Signals

"Adding values" means driving the signals of the interface. There are several places a value can come from, and the single-driver rule from Module 1 decides which combinations are legal.

### Who can drive an interface signal

| Source | Example | Kind of assignment |
|---|---|---|
| Testbench code, by instance name | `cif.en = 1;` in an `initial` block of `tb_top` | Procedural |
| A module, through its interface port | `cif.count <= cif.count + 1;` in the DUT | Procedural |
| A module output port connected to the signal | `.result(aif.result)` | Port (continuous) |
| A continuous assignment | `assign cif.rst_n = cr.rst_n;` | Continuous |
| Code inside the interface | A task, an `initial` block or an `assign` in the interface | Either |
| A class, through a virtual interface | `vif.en = 1;` (Part 3) | Procedural |
| A clocking block output | `vif.drv_cb.a <= 5;` (Part 4) | Synchronous drive |
| A declaration initialiser | `logic en = 0;` inside the interface | Initial value at time 0 |

### The rules

Interface signals declared as `logic` are **variables**, so the rules of Module 1, Section 2.4 apply:

| Combination on one `logic` signal | Legal? |
|---|---|
| Any number of procedural assignments (testbench, tasks, classes) | Yes. The last value written wins |
| Exactly one continuous assignment or one module output port | Yes |
| A continuous assignment (or output port) **and** a procedural assignment | **No**: compile or elaboration error |
| Two continuous assignments or two output ports | **No** |
| Several drivers that must be resolved (bidirectional bus) | Only if the signal is declared as a net (`wire`); see Section 5.3 |

```systemverilog
interface cnt_if (input logic clk);
  logic       rst_n;
  logic       en = 0;        // initial value: en is 0 from time 0 instead of X
  logic [3:0] count;
endinterface

module tb;
  logic clk = 0;
  cnt_if  cif (clk);
  counter dut (cif);          // dut writes cif.count procedurally

  initial begin
    cif.rst_n = 0;            // legal: procedural, only the testbench writes rst_n
    cif.en    = 1;            // legal
    // cif.count = 4'd7;      // BUG: count is the DUT's output. Here the tool reports it,
                              // because always_ff allows no second writer. With a plain
                              // "always" block in the DUT it would compile silently.
  end

  // assign cif.en = 1'b1;    // ILLEGAL: en would be driven continuously AND procedurally
endmodule
```

> **Common mistake:** Leaving DUT inputs at X. Every interface signal that feeds the DUT starts as X. Give each one a value at time 0 (in the testbench's first statements, or with an initialiser in the interface), and apply reset before the first real stimulus.

> **Common mistake:** Writing a DUT output from the testbench. Whether the tool notices depends on how the DUT drives the signal: an output port or an `always_ff` block gives an error, but two plain procedural writers are accepted silently and simply overwrite each other. Modports (Part 2) make the intended direction explicit, so the mistake is reported where it is made.

### Interview questions

**Q1. How does a testbench drive a signal that is inside an interface?**
By hierarchical name from a module (`cif.en = 1;`), through an interface port, from a task inside the interface, or from a class through a virtual interface (`vif.en = 1;` or, with a clocking block, `vif.drv_cb.en <= 1;`).

**Q2. An interface signal is driven by `assign` inside the interface. Can the testbench also assign it in an `initial` block?**
No, if the signal is a `logic` variable. A variable may be driven either by one continuous assignment or by procedural assignments, not both.

**Q3. What is the initial value of the signals in an interface?**
X for `logic` signals and Z for undriven nets, unless the declaration has an initialiser.

## 1.8 Tasks, Functions and Assertions Inside Interfaces

This section is for awareness. The class-based testbench in Module 9 keeps the driving code in the driver class, but you must be able to recognise and explain code written in the style below.

### Tasks and functions: a bus functional model

A task inside an interface can perform a complete bus operation. An interface that contains such tasks is called a **bus functional model (BFM)**: the user calls `write(addr, data)` and the interface wiggles the signals.

```systemverilog
interface mem_if (input logic clk);
  logic       we;
  logic [3:0] addr;
  logic [7:0] wdata;
  logic [7:0] rdata;

  // One complete write cycle
  task automatic write(input logic [3:0] wr_addr, input logic [7:0] wr_data);
    @(negedge clk);
    we    = 1;
    addr  = wr_addr;
    wdata = wr_data;
    @(negedge clk);
    we    = 0;
  endtask

  // A function that answers a question about the current state of the bus
  function automatic bit is_idle();
    return (we === 1'b0);
  endfunction
endinterface
```

A testbench calls `mif.write(4'h3, 8'hAB);`. A class calls the same task through its virtual interface: `vif.write(4'h3, 8'hAB);`.

### Assertions

An assertion placed in the interface checks the protocol wherever the interface is used: in block-level simulation, at chip level, and in formal verification. Assertions are the subject of Module 10; this is only the idea.

```systemverilog
interface alu_if (input logic clk);
  // ... signals ...

  // After reset, valid_in must never be X or Z
  property p_valid_known;
    @(posedge clk) disable iff (!rst_n) !$isunknown(valid_in);
  endproperty
  a_valid_known: assert property (p_valid_known)
    else $error("valid_in is X or Z");

  // A result must be flagged exactly one cycle after a valid request
  a_latency: assert property (@(posedge clk) disable iff (!rst_n)
                              valid_in |=> valid_out);
endinterface
```

### Tasks in the interface versus tasks in the driver class

| Property | Task inside the interface (BFM style) | Task inside the driver class |
|---|---|---|
| Where the pin-level protocol is written | In the interface | In the class |
| Can be overridden for a special test (inheritance) | No. An interface cannot be extended | Yes. A derived driver can override the task |
| Works in emulation (hardware acceleration) | Yes, the interface can be synthesised into the emulator | No, classes are not synthesizable |
| Usual in UVM testbenches | Only when emulation is a requirement | Yes, the standard approach |

### Interview questions

**Q1. Can an interface contain tasks and functions? Give a use.**
Yes. A task can implement one bus operation, such as a write cycle, so that all users call the task instead of driving signals individually. Such an interface is called a bus functional model.

**Q2. Why put assertions in an interface?**
The protocol rules belong to the bus, not to one particular testbench. An assertion in the interface is active everywhere the interface is instantiated, at block level and at chip level, with no extra work.

**Q3. Can an interface be extended like a class?**
No. Interfaces have no inheritance. This is one reason the driving code is normally written in a class, where it can be overridden.
