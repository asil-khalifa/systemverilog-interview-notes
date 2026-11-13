# Part 2: Modports and Interface Arrays

## 2.1 What Is a Modport and Why Is It Required?

### In plain English

The interface in Part 1 says which signals exist. It does not say who is allowed to drive them. The counter drives `count`; the testbench drives `rst_n` and `en`. Nothing in `cnt_if` records that, so nothing stops the testbench from writing `count` or the design from writing `en` by mistake.

A **modport** (short for "module port") is a named view of the interface for one kind of user. It lists the signals that user may access and gives each one a direction **as seen by that user**. An interface normally has one modport per role: one for the DUT, one for the testbench or driver, one for the monitor.

### Technical definition

A `modport` is a declaration inside an interface that defines, for a named role, a subset of the interface's signals together with their port directions (`input`, `output`, `inout`, `ref`). When a module port, an instance connection or a virtual interface selects that modport, access through it is restricted to the listed signals in the listed directions.

### Why it is required

| Without modports | With modports |
|---|---|
| Every user has read and write access to every signal | Each role sees only its own signals, with a fixed direction |
| A write to the wrong signal is found late, in simulation, as contention or wrong data | It is a compile or elaboration error at the offending line |
| Direction of each signal is known only from comments | Direction is part of the code and is checked |
| A synthesis tool cannot tell inputs from outputs on an interface port | The modport gives the synthesis tool the port directions |
| A monitor could drive the bus by accident | The monitor's modport has only inputs, so a monitor cannot drive anything |

### Syntax

```systemverilog
interface <name> (...);
  <signals>

  modport <modport_name> (
    input  <signal>, <signal>,
    output <signal>,
    inout  <signal>,
    ref    <signal>
  );
endinterface
```

A direction keyword applies to every name after it until the next direction keyword. Several modports may list the same signal with different directions; that is the whole point.

### A first picture

```text
                       interface  cnt_mp_if
                 +-----------------------------+
                 |   clk    rst_n   en   count |
                 +-----------------------------+
                    |                      |
       modport DUT  |                      |  modport TB
       -----------  |                      |  ----------
       input  clk   |                      |  input  clk
       input  rst_n |                      |  output rst_n
       input  en    |                      |  output en
       output count |                      |  input  count
                    v                      v
              +-----------+          +-----------+
              |  counter  |          | testbench |
              +-----------+          +-----------+

   The same wire has opposite directions in the two modports:
   en    is an INPUT  for the DUT and an OUTPUT for the testbench.
   count is an OUTPUT for the DUT and an INPUT  for the testbench.
```

### Interview questions

**Q1. What is a modport?**
A named list, inside an interface, of the signals that one kind of module may access and the direction of each signal from that module's point of view.

**Q2. Why are modports needed?**
An interface alone gives every connected block full access to all signals. Modports define direction, so that a block cannot drive a signal it should only read, different roles (DUT, driver, monitor) get different views of the same signals, and synthesis tools know which interface signals are inputs and outputs of a module.

**Q3. Does a modport create new signals?**
No. It creates nothing. It is a set of access rules for signals that already exist in the interface.

## 2.2 Input, Output and Inout Directions in a Modport

### The four directions

Directions are always written **from the point of view of the module that uses the modport**.

| Direction | The user may read | The user may write | Typical use |
|---|---|---|---|
| `input` | Yes | **No**: an assignment is an error | Signals this role only observes |
| `output` | Yes | Yes | Signals this role drives |
| `inout` | Yes | Yes | Bidirectional nets (`wire`) such as a shared data bus |
| `ref` | Yes | Yes | A variable shared by reference: every user sees every change immediately |

Signals that are **not listed** in a modport cannot be accessed through it at all. A modport therefore also hides signals.

### What a modport enforces, and what it does not

This is asked often, because many people assume modports do more than they do.

| A modport does | A modport does not |
|---|---|
| Make writing an `input` signal through that modport an error | Stop code that bypasses the modport. A hierarchical reference such as `tb_top.cif.count = 0;` is still accepted |
| Make any access to an unlisted signal through that modport an error | Check that an `output` is actually driven by somebody |
| Tell synthesis the direction of each signal of an interface port | Add buffers, drivers or any hardware |
| Restrict a virtual interface declared with that modport | Define any timing: when to sample or drive is the job of a clocking block (Part 4) |
| Document the role of each signal | Prevent two users from both selecting a modport with the same `output`. That is caught, if at all, by the ordinary multiple-driver rules |

> **Key point:** A modport is checked only when the access goes **through** it: through a module port declared with the modport, an instance connected with the modport, or a virtual interface declared with the modport. If nobody selects a modport, it has no effect.

### What happens when no modport is selected

If a module port is declared with just the interface name (`cnt_if cif`) and the instance is connected without a modport, the module gets full access: nets behave as `inout` and variables behave as `ref`. This is how the examples in Part 1 worked.

### Interview questions

**Q1. From whose point of view are modport directions written?**
From the point of view of the module (or class) that uses the modport. A signal the DUT drives is an `output` in the DUT's modport and an `input` in the testbench's modport.

**Q2. What happens if a module writes a signal that its modport declares as `input`?**
It is an error at compile or elaboration time.

**Q3. Can a testbench still write a signal that its modport does not allow?**
Yes, if it bypasses the modport by using the full hierarchical name of the interface instance. Modports restrict access only through the port or virtual interface that selected them.

**Q4. A signal is not listed in the modport. Can the module read it?**
No. Only listed signals are visible through a modport.

## 2.3 Different Modports for the DUT and the Testbench

### The counter interface with modports

This file is a second version of the counter and its interface, with modports added. It is separate from `counter_dut.sv` so that the Part 1 examples stay unchanged.

```systemverilog file=counter_mp.sv
interface cnt_mp_if (input logic clk);
  logic       rst_n;
  logic       en;
  logic [3:0] count;

  // View for the design: it reads the controls and drives the count
  modport DUT (input  clk, rst_n, en,
               output count);

  // View for the testbench: it drives the controls and reads the count
  modport TB  (input  clk, count,
               output rst_n, en);
endinterface

module counter_mp (cnt_mp_if.DUT cif);       // this module uses the DUT view

  always_ff @(posedge cif.clk or negedge cif.rst_n) begin
    if (!cif.rst_n)  cif.count <= '0;
    else if (cif.en) cif.count <= cif.count + 1'b1;
  end

  // assign cif.en = 1'b1;        // ILLEGAL: en is an input in modport DUT

endmodule
```

### Complete example

Compile `counter_mp.sv` first, then this file.

```systemverilog file=tb_modport.sv
// A stimulus module that uses the testbench view of the interface
module cnt_stim (cnt_mp_if.TB cif);

  initial begin
    cif.rst_n = 0;
    cif.en    = 0;
    @(negedge cif.clk);
    cif.rst_n = 1;
    cif.en    = 1;

    repeat (5) @(negedge cif.clk);
    $display("[%0t] count = %0d", $time, cif.count);

    // cif.count = 4'd0;          // ILLEGAL: count is an input in modport TB
    $finish;
  end

endmodule

module tb_modport;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_mp_if  cif  (clk);
  counter_mp dut  (cif);          // modport DUT was chosen in the module header
  cnt_stim   stim (cif.TB);       // the modport may also be named at the instance

endmodule
```

```output
[60] count = 5
```

**Line by line**

| Line | Explanation |
|---|---|
| `modport DUT (input clk, rst_n, en, output count);` | The design's view. `clk` is a port of the interface; ports may be listed in a modport like any other signal. |
| `modport TB (input clk, count, output rst_n, en);` | The testbench's view: exactly the opposite directions for `rst_n`, `en` and `count`. |
| `module counter_mp (cnt_mp_if.DUT cif);` | The port type is `<interface>.<modport>`. Inside this module, `cif` obeys modport `DUT`. |
| `// assign cif.en = 1'b1;` | Remove the comment marker and the compiler rejects the line, because `en` is an input for this module. |
| `module cnt_stim (cnt_mp_if.TB cif);` | A second module, with the opposite view. It may write `rst_n` and `en` but not `count`. |
| `cnt_stim stim (cif.TB);` | The modport is named again in the connection. This is allowed when it is the same modport as in the module header; it is only extra documentation here. |

**Execution flow**

| Time | Event |
|---|---|
| 0 | `rst_n` = 0, `en` = 0: the counter is reset. |
| 10 | Falling edge: reset released, `en` = 1. |
| 15, 25, 35, 45, 55 | Five rising edges: `count` = 1, 2, 3, 4, 5. |
| 60 | Fifth falling edge after time 10: prints `count = 5`. |

### Typical modport sets

| Interface for | Modports | Notes |
|---|---|---|
| A block and its testbench | `DUT`, `TB` | The simplest arrangement, as above |
| A class-based testbench | `DUT`, `DRV`, `MON` | The driver's view drives the DUT inputs; the monitor's view has only inputs. This is the arrangement of `alu_if` |
| A bus between two design blocks | `master` / `slave`, or `manager` / `subordinate`, `initiator` / `target` | Request signals are outputs of one side and inputs of the other; response signals the reverse |

```systemverilog
// A valid/ready handshake bus between two design blocks
interface stream_if (input logic clk, input logic rst_n);
  logic        valid;
  logic        ready;
  logic [31:0] data;

  modport source (input clk, rst_n, ready, output valid, data);   // sends data
  modport sink   (input clk, rst_n, valid, data, output ready);   // receives data
  modport mon    (input clk, rst_n, valid, ready, data);          // only observes
endinterface
```

### The ALU interface with modports (second version)

```systemverilog
interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  modport DUT (input clk, rst_n, valid_in, a, b, op, output valid_out, result);
  // The DRV and MON modports refer to clocking blocks and are added in Part 4.
endinterface
```

> **Common mistake:** Writing the directions from the wrong side. In the testbench modport, a signal that the testbench drives **into** the DUT is an `output`, even though it is an input of the DUT. Read every modport as "I am this role; what do I drive, what do I read?".

> **Verification application:** The monitor must be passive: it may never change a DUT signal. Giving the monitor a modport that contains only inputs makes that a compile-time guarantee instead of a coding guideline.

### Interview questions

**Q1. Why do the DUT and the testbench need different modports?**
Because their directions are opposite. The DUT's inputs are driven by the testbench and the DUT's outputs are read by it. One modport cannot describe both views.

**Q2. In the testbench modport, is a DUT input signal an `input` or an `output`?**
An `output`, because the testbench drives it.

**Q3. Why should a monitor have its own modport?**
So that all signals are inputs for the monitor. Any accidental attempt by the monitor to drive the bus then fails to compile.

## 2.4 Selecting the Modport: Module Header or Instance

There are two places where a modport can be chosen.

### Method 1: in the module header (preferred)

```systemverilog
module counter_mp (cnt_mp_if.DUT cif);     // the module itself declares its role
  ...
endmodule

counter_mp dut (cif);                      // plain connection
```

### Method 2: at the instantiation

```systemverilog
module counter_any (cnt_mp_if cif);        // no modport in the header
  ...
endmodule

counter_any dut (cif.DUT);                 // the role is chosen where the module is used
```

### Comparison

| Property | In the module header | At the instance |
|---|---|---|
| Syntax | `module m (my_if.MP port);` | `m inst (my_if_inst.MP);` |
| Who decides the role | The author of the module | The person who instantiates it |
| The module can be used with only one role | Yes: the restriction travels with the module | No: each instance may choose a different modport |
| Protection if the instantiator forgets the modport | Still protected | None: without `.DUT` the module has full access |
| Both specified | Allowed only if they name the **same** modport; otherwise an error | |
| Neither specified | Full access to every signal | |
| Usual practice | RTL modules and testbench components | Rare |

> **Interview trap:** "If the module header says `cnt_mp_if.DUT` and the instance connects `cif.TB`, which one wins?" Neither. It is an error. When a modport is given in both places it must be the same one.

### Selecting a modport in a virtual interface

A class has no ports, so the third place to select a modport is the declaration of a virtual interface handle (Part 3):

```systemverilog
virtual cnt_mp_if.TB vif;        // a class property restricted to the TB view
```

### Interview questions

**Q1. In how many ways can a modport be selected?**
Three: in the port declaration of the module (`module m (my_if.MP p);`), in the port connection of the instance (`m i (bus.MP);`), and in the declaration of a virtual interface (`virtual my_if.MP vif;`).

**Q2. Which way is preferred for a module, and why?**
In the module header. The module then always has the correct restricted view, whoever instantiates it, and a reader of the module sees its role immediately.

## 2.5 Accessing Interface Signals

This section collects every way of reaching a signal that lives inside an interface. Each has been or will be shown in an example.

| Where the code is | How it names the signal | Restricted by a modport? | Section |
|---|---|---|---|
| In the module that instantiates the interface | `<instance>.<signal>`: `cif.en` | No | 1.3 |
| Anywhere, by full hierarchical path | `tb_top.cif.en` | No | 2.2 |
| In a module with an interface port | `<port>.<signal>`: `cif.en` | Yes, if the port or the connection names a modport | 2.3, 2.4 |
| Inside the interface (its own tasks, assertions, `always` blocks) | The plain name: `en` | No | 1.8 |
| In a class | `<virtual interface handle>.<signal>`: `vif.en` | Yes, if the handle is declared with a modport | Part 3 |
| Through a clocking block | `<handle>.<clocking block>.<signal>`: `vif.drv_cb.a` | Yes, and also by the clocking block's own directions | Part 4 |
| An element of an interface array | `<instance>[<constant index>].<signal>`: `cif[1].en` | No | 2.7 |
| A task or function of the interface | `<instance or handle>.<task>(...)`: `vif.write(...)` | Yes: a modport must `import` the task to make it callable | 2.6 |

> **Common mistake:** Using the interface **type** name instead of an **instance** name: `cnt_if.en = 1;`. `cnt_if` is a declaration. Signals exist only in instances (`cif.en`).

> **Common mistake:** Reading or writing an interface signal from a class by hierarchical path (`tb_top.cif.en = 1;`). It may compile if the class is declared in the same file, but it fails when the class is in a package, and it ties the class to one particular testbench. A class must use a virtual interface.

### Interview questions

**Q1. How do you access a signal inside an interface from a module?**
With the dot operator on the interface instance or interface port: `<instance_or_port>.<signal>`.

**Q2. How do you access it from a class?**
Through a virtual interface handle: `vif.<signal>`, or `vif.<clocking_block>.<signal>` when a clocking block is used.

## 2.6 Tasks and Clocking Blocks in Modports

This section is for awareness.

### Clocking blocks in a modport

A modport may list a clocking block instead of individual signals. The user of that modport can then reach those signals only through the clocking block, which forces synchronous access. This is how the final `alu_if` gives the driver and the monitor their views:

```systemverilog
modport DRV (clocking drv_cb, input clk, rst_n);
modport MON (clocking mon_cb, input clk, rst_n);
```

Part 4 explains clocking blocks and comes back to these two lines.

### Importing tasks and functions

A task or function declared in the interface is not visible through a modport unless the modport imports it:

```systemverilog
interface mem_if (input logic clk);
  logic       we;
  logic [3:0] addr;
  logic [7:0] wdata, rdata;

  task automatic write(input logic [3:0] wr_addr, input logic [7:0] wr_data);
    @(negedge clk);  we = 1;  addr = wr_addr;  wdata = wr_data;
    @(negedge clk);  we = 0;
  endtask

  modport TB  (import write, input clk, rdata);          // may call write()
  modport DUT (input clk, we, addr, wdata, output rdata); // cannot call write()
endinterface
```

The opposite keyword, `export`, lets a module that is connected to the interface provide the body of a task, so that other users of the interface can call it. It is rarely used.

### Interview questions

**Q1. Can a modport contain something other than signals?**
Yes. It can list a clocking block (`clocking cb_name`), and it can import tasks and functions of the interface (`import task_name`) so that they can be called through the modport.

**Q2. A task is declared in an interface. A module connected through a modport cannot call it. Why?**
The modport does not import the task. Only what a modport lists is accessible through it; add `import <task_name>` to the modport.

## 2.7 Interface Arrays

### In plain English

A design often has several identical ports: a switch with four input channels, a system with eight identical peripherals. Each needs its own copy of the bus. Instead of declaring `bus0`, `bus1`, `bus2`, `bus3`, you declare an **array of interface instances**.

### Syntax

```systemverilog
cnt_if cif [4] (clk);          // four instances: cif[0], cif[1], cif[2], cif[3]
cnt_if cif [0:3] (clk);        // the same, with an explicit range
```

- Each element is a complete, independent instance with its own signals.
- A single port connection such as `(clk)` is connected to **every** element, so all four instances share the clock.
- An element is selected with a **constant** index: `cif[2].en`.

### How it works internally

```text
   cnt_if cif [2] (clk);

            clk ------------+------------------+
                            |                  |
                   +--------v-------+  +-------v--------+
                   |    cif[0]      |  |    cif[1]      |
                   |  rst_n         |  |  rst_n         |
                   |  en            |  |  en            |
                   |  count         |  |  count         |
                   +--------+-------+  +-------+--------+
                            |                  |
                   +--------v-------+  +-------v--------+
                   | g_dut[0].dut   |  | g_dut[1].dut   |
                   |   (counter)    |  |   (counter)    |
                   +----------------+  +----------------+

   Two separate sets of signals. Only the clock is common.
```

An interface array is an array of **instances**, created at elaboration like an array of module instances. It is not an unpacked array variable: it has no array methods, it cannot be resized, and it cannot be indexed with a variable.

### Complete example

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_if_array.sv
module tb_if_array;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if cif [2] (clk);                   // two interface instances

  for (genvar i = 0; i < 2; i++) begin : g_dut
    counter dut (cif[i]);                 // one counter per interface instance
  end

  initial begin
    cif[0].rst_n = 0;   cif[1].rst_n = 0;
    cif[0].en    = 1;   cif[1].en    = 0;
    @(negedge clk);
    cif[0].rst_n = 1;   cif[1].rst_n = 1;

    repeat (2) @(negedge clk);
    cif[1].en = 1;                        // the second counter starts later

    repeat (2) @(negedge clk);
    $display("[%0t] count0 = %0d  count1 = %0d", $time, cif[0].count, cif[1].count);
    $finish;
  end

endmodule
```

```output
[50] count0 = 4  count1 = 2
```

**Line by line**

| Line | Explanation |
|---|---|
| `cnt_if cif [2] (clk);` | Creates `cif[0]` and `cif[1]`. Both receive the same `clk`. |
| `for (genvar i ...) begin : g_dut` | A generate loop. It is evaluated at elaboration and creates two counter instances, `g_dut[0].dut` and `g_dut[1].dut`. |
| `counter dut (cif[i]);` | Inside a generate loop the index `i` is a constant for each iteration, so `cif[i]` is legal here. |
| `cif[0].en = 1; cif[1].en = 0;` | Each instance has its own `en`. |

**Execution flow**

| Time | Counter 0 (`en` = 1 from the start) | Counter 1 |
|---|---|---|
| 0 to 10 | In reset, 0 | In reset, 0 |
| 15, 25 | 1, 2 | `en` = 0: stays 0 |
| 30 | | `en` set to 1 |
| 35, 45 | 3, 4 | 1, 2 |
| 50 | Printed: 4 | Printed: 2 |

### The constant-index rule

```systemverilog
initial begin
  for (int i = 0; i < 2; i++)
    cif[i].en = 1;      // ILLEGAL: i is a variable; an instance needs a constant index
end
```

`cif[i]` is part of a hierarchical name, and the hierarchy is fixed at elaboration. Selecting an instance with a run-time variable is therefore not allowed. The working alternatives are:

| Need | Solution |
|---|---|
| Connect each element to a module | A `generate` loop with a `genvar`, as in the example |
| Do the same thing to every element from procedural code | An **array of virtual interfaces**, which is an ordinary array of handles and can be indexed with a variable (Section 3.7) |
| A few elements | Write the constant indices out: `cif[0].en = 1; cif[1].en = 1;` |

> **Interview trap:** "Can you loop over an array of interfaces with a `for` loop inside an `initial` block?" Not directly: the index of an instance array must be a constant expression. The standard answer is to copy the instances into an array of virtual interfaces and loop over that.

> **Verification application:** A testbench for a 4-port switch has `port_if pif [4] (clk);`, connects `pif[i]` to DUT port `i` in a generate loop, and creates four agents. Each agent receives one element of an array of virtual interfaces, so the same driver and monitor classes serve all four ports.

### Interview questions

**Q1. How do you declare an array of interfaces?**
`my_if bus [N] (clk);` creates N independent instances, `bus[0]` to `bus[N-1]`. A single port connection is shared by all elements.

**Q2. Can the index of an interface array be a variable?**
No. It must be a constant, a parameter or a `genvar`, because the element is an instance in the static hierarchy. To use a variable index, use an array of virtual interfaces.

**Q3. Do the elements of an interface array share signals?**
No. Each element has its own copy of all internal signals. Only signals connected through the interface's ports (such as the clock) are common.

## 2.8 Generic Interface Ports

For awareness: a module port can be declared with the keyword `interface` instead of a specific interface name. The module then accepts **any** interface, and the actual type is fixed when the module is instantiated.

```systemverilog
module generic_probe (interface bus);            // any interface may be connected
  always @(posedge bus.clk)
    if (bus.valid) $display("[%0t] valid seen", $time);
endmodule

generic_probe p1 (stream_bus);                   // works if stream_bus has clk and valid
```

The module compiles for any connected interface that has the signals it uses (`clk` and `valid` here); otherwise elaboration fails. A modport can be chosen at the instance (`generic_probe p1 (stream_bus.mon);`) or in the header (`interface.mon bus`). Generic interface ports are rare in practice because the errors appear late and are harder to read.

### Interview questions

**Q1. What is a generic interface port?**
A module port declared as `interface <name>` without naming an interface type. Any interface instance may be connected to it, provided it contains the signals the module refers to.

## 2.9 Summary of Part 2

| Concept | One-line summary |
|---|---|
| Modport | A named view of an interface: which signals, in which direction, for one role |
| Direction | Written from the user's side: what the testbench drives is an `output` in the testbench modport |
| Selection | In the module header (preferred), at the instance, or in a virtual interface declaration |
| Enforcement | Only for access through the modport. Hierarchical references bypass it |
| Not listed | Not accessible through that modport |
| Interface array | Several independent instances; constant index only |
| Modport with a clocking block | Forces the user to go through the clocking block (Part 4) |
