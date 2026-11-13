# Part 2: The Project at a Glance and Its Foundation Files

The syllabus lists the testbench top first, because it is the outermost box. It is explained last in this module (Section 5.4), because it instantiates and starts everything else and can only be read once the other files are known. This part gives the overall picture and then the three files everything else depends on: the DUT, the interface and the transaction.

## 2.1 What Is Being Verified

### The DUT specification (from Module 1)

- Inputs `a` and `b` are 8 bits. Input `op` selects one of eight operations.
- When `valid_in` is 1 at a rising clock edge, the ALU computes the result and presents it **on the next cycle** with `valid_out` = 1.
- `result` is 9 bits: bit 8 is the carry of an addition, the borrow of a subtraction, or the bit shifted out by a left shift.
- `rst_n` is an asynchronous, active-low reset. During reset `valid_out` is 0 and `result` is 0.

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

### The protocol in one picture

The testbench is built around this timing. Every later section refers back to it.

```text
                 edge N-1        edge N          edge N+1
   clk        ______|‾‾‾‾‾‾|______|‾‾‾‾‾‾|______|‾‾‾‾‾‾|______

   valid_in   ________|‾‾‾‾‾‾‾‾‾‾‾‾‾|___________________________
   a, b, op   --------<   operands   >--------------------------
                       driven just    ^
                       after edge N-1 | DUT samples the inputs at edge N

   valid_out  ______________________|‾‾‾‾‾‾‾‾‾‾‾‾‾|____________
   result     ----------------------<    result    >------------
                                     changes just    ^
                                     after edge N    | visible to a sampler at edge N+1
```

The rule that the monitor and scoreboard depend on: **inputs sampled at edge N belong with the output sampled at edge N+1.** The latency is exactly one clock cycle.

### What the testbench must check

A small verification plan (Module 6 covers planning in general):

| # | Feature | How it is checked in this project |
|---|---|---|
| 1 | Each of the eight operations gives the specified result | Scoreboard reference model `alu_predict`, for every transaction |
| 2 | Carry, borrow and shift-out appear in bit 8 | Same reference model, computing in 9 bits; operands 0 and 255 are made more likely by a constraint |
| 3 | `valid_out` follows `valid_in` by exactly one cycle | Monitor: every sampled input must be followed by `valid_out` on the next edge, and `valid_out` must never appear without one |
| 4 | Outputs are never X when valid | Scoreboard compares with `===`; X fails the comparison |
| 5 | Reset clears `valid_out` | Monitor ignores activity during reset; a `valid_out` right after reset is reported as unexpected |
| 6 | All checked transactions are accounted for | End-of-test check: number checked equals number sent; a summary is printed |

Functional coverage ("were all eight operations and the corner operands actually generated?") is added in Module 10; Exercise 3 of this module shows where it plugs in.

## 2.2 Who Creates Whom, and Who Shares What

### Object hierarchy

Static things (modules, interfaces) exist from the start of simulation. Class objects exist only after `new()` is called. The chain of construction is:

```text
   tb_top  (module, static)
     |-- aif            : alu_if instance            (static)
     |-- dut            : alu instance               (static)
     `-- initial block  : test = new(aif);           (dynamic from here down)
           |
           `-- alu_test.new(vif)
                 `-- env = new(vif)                           alu_env
                       |-- gen2drv_mbx = new()                mailbox #(alu_txn)
                       |-- mon2scb_mbx = new()                mailbox #(alu_txn)
                       |-- gen = new(gen2drv_mbx, drv_done, gen_done)      alu_generator
                       |     `-- blueprint = new()                         alu_txn
                       |-- drv = new(vif, gen2drv_mbx, drv_done)           alu_driver
                       |-- mon = new(vif, mon2scb_mbx)                     alu_monitor
                       `-- scb = new(mon2scb_mbx)                          alu_scoreboard
```

Each object is created by the level above it, in its constructor. Nothing is created inside a `run()` task except transactions.

### Shared handles

Two components can communicate only if they hold handles to the **same** object. The environment creates each shared object once and passes the handle to both sides.

```text
                        created once in alu_env
                                 |
            +--------------------+---------------------+
            |                    |                     |
     gen2drv_mbx            mon2scb_mbx        drv_done, gen_done
     (one mailbox)          (one mailbox)      (event handles)
        /      \               /      \            /        \
   gen.gen2drv  drv.gen2drv  mon.mon2scb scb.mon2scb  gen.drv_done  drv.drv_done
   _mbx         _mbx         _mbx        _mbx

   and the virtual interface:

          aif (in tb_top)  --->  test  --->  env.vif  --->  drv.vif
                                                      `-->  mon.vif
```

> **Key point:** A mailbox variable, an event variable and a virtual interface variable are all *handles*. Copying the handle does not copy the mailbox, the event or the interface; it creates a second name for the same one. That is what makes them usable as communication channels.

### Build, connect, run

Every class-based testbench goes through the same three stages, and it helps to know which code belongs to which:

| Stage | What happens | Where in this project |
|---|---|---|
| Build | Objects are created with `new()` | Constructors of `alu_test` and `alu_env` |
| Connect | Shared handles (mailboxes, events, `vif`) are passed to the components | The arguments of the component constructors, in `alu_env::new` |
| Run | Each component's `run()` task executes as a parallel thread | `alu_env::run`, inside `fork`...`join_any` |

In this project build and connect happen together in the constructors. UVM separates them into `build_phase` and `connect_phase`.

## 2.3 The DUT Files

These two files are repeated from Module 1 without any change, so that this module's example folder is complete.

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

**What matters for the testbench**

| Property of the DUT | Consequence for the testbench |
|---|---|
| Inputs are sampled at the rising edge when `valid_in` is 1 | The driver must have the inputs stable before a rising edge and hold them through it |
| `valid_out <= valid_in;` | `valid_out` is `valid_in` delayed by one cycle; the monitor pairs input edge N with output edge N+1 |
| `if (valid_in) result <= result_nxt;` | `result` keeps its old value in idle cycles; it must only be checked when `valid_out` is 1 |
| The package holds `alu_op_e` | The testbench imports the same package, so DUT and testbench share one definition of the opcodes |
| The opcode type is shared with the DUT | The reference model must **not** copy the DUT's `case` statement; it is written independently from the specification (Section 4.2) |

Module 1, Section 1.4 explains the design itself line by line.

## 2.4 The Interface: alu_if.sv

### Why the testbench needs an interface

Module 8 covered this in depth; the short version:

1. **Bundling.** The DUT has eight ports. Without an interface, every one would be declared in the top module, connected to the DUT, and somehow made reachable from the classes.
2. **A class cannot have ports.** A class object is created at run time; it cannot be wired to signals the way a module instance is. The only way a class can reach static signals is through a **virtual interface**: a handle that points to an interface instance.
3. **Timing in one place.** Clocking blocks inside the interface define when signals are sampled and driven relative to the clock, so that the driver and monitor cannot race with the DUT.
4. **Access control.** Modports state which signals each user may read or write.

### The file

```systemverilog file=alu_if.sv
interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n;
  logic       valid_in;
  logic [7:0] a;
  logic [7:0] b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  // Driver's view: drive the DUT inputs, sample the DUT outputs
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid_in, a, b, op;
    input  valid_out, result;
  endclocking

  // Monitor's view: sample everything, drive nothing
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid_in, a, b, op, valid_out, result;
  endclocking

  modport DUT (input clk, rst_n, valid_in, a, b, op, output valid_out, result);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);

endinterface
```

### Line by line

| Code | Explanation |
|---|---|
| `interface alu_if (input logic clk);` | The clock enters as a port, because it is generated outside (in `tb_top`) and shared with the DUT. |
| `import alu_pkg::*;` | Needed for the type `alu_op_e`. |
| `logic rst_n;` ... `logic [8:0] result;` | One signal for every DUT port except the clock. All are four-state so that X and Z from the DUT stay visible (Module 1, Section 2.1). |
| `alu_op_e op;` | The opcode signal has the enum type, so waveforms show names. |
| `clocking drv_cb @(posedge clk);` | A clocking block: a named group of signals with timing defined relative to the rising edge of `clk`. |
| `default input #1step output #1;` | Inputs are sampled one "step" before the edge, that is, the value the signal had just before the edge, before anything changes at the edge. Outputs are driven 1 time unit after the edge. |
| `output valid_in, a, b, op;` | Directions are from the testbench's point of view: the driver *drives* these (they are DUT inputs). |
| `input valid_out, result;` | The driver may sample the DUT outputs. Our driver does not need them, but a driver for a protocol with back-pressure (`ready`) would. |
| `clocking mon_cb ...` with only `input` | The monitor is passive. Giving it a clocking block with no outputs makes it impossible for monitor code to drive a signal by accident. |
| `modport DUT (...)` | The direction of each signal as seen by the design. The `alu` module of this course has ordinary ports, so this modport is not used by it; it is there for a DUT written with an interface port (`module alu (alu_if.DUT bus);`). |
| `modport DRV (clocking drv_cb, input clk, rst_n);` | The driver's view: the clocking block, plus read access to `clk` and `rst_n`. |
| `modport MON (clocking mon_cb, input clk, rst_n);` | The monitor's view. |

`rst_n` is in no clocking block. Reset is asynchronous: it is driven directly by `tb_top` and read directly (`vif.rst_n`) by the driver and monitor.

### What the clocking blocks do to timing

```text
   time            24        25                 26          34        35
   clk       ________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|______________|‾‾‾‾‾‾‾‾
                             ^                  ^                     ^
                             |                  |                     |
       mon_cb / drv_cb       |                  |                     |
       INPUTS: value just ---+                  |                     +--- next sample
       before the edge                          |
       (#1step)                                 |
                                                |
       drv_cb OUTPUTS: a drive executed at -----+
       the edge at 25 appears on the signal
       at 26 (output #1)
```

| Action in class code | When it takes effect |
|---|---|
| `@(vif.drv_cb);` or `@(vif.mon_cb);` | The process resumes at the rising edge of `clk`, after the clocking block has taken its input samples |
| Reading `vif.mon_cb.valid_out` | Returns the value sampled at the most recent rising edge: the value the signal had immediately **before** that edge |
| `vif.drv_cb.valid_in <= 1'b1;` executed at an edge | The signal `valid_in` changes 1 time unit **after** that edge. The DUT sees the new value at the **following** rising edge |

Two consequences that the driver and monitor rely on:

- The DUT's flip-flops and the monitor both sample at the same edge, and both see the values from before the edge. The monitor therefore sees exactly what the DUT sees. There is no race.
- A value the driver writes at edge N-1 is sampled by the DUT at edge N. The driver is always one edge ahead of the DUT.

> **Common mistake:** Reading the raw signal (`vif.valid_out`) in the monitor instead of the clocking block signal (`vif.mon_cb.valid_out`). At a clock edge the raw signal may or may not have been updated yet by the DUT's nonblocking assignment, depending on the order in which the simulator runs the two processes. The clocking block sample is always the pre-edge value.

> **Common mistake:** Driving through a clocking block with a blocking assignment: `vif.drv_cb.valid_in = 1;`. Clocking block outputs can only be driven with `<=` (a "synchronous drive"). The `=` form is a compile error.

### Virtual interface

In every component, the handle is declared as

```systemverilog
virtual alu_if vif;
```

and it receives its value through the constructor chain that starts in `tb_top` with `new(aif)`. Until it is assigned, `vif` is `null`, and any access such as `vif.drv_cb` is a fatal run-time error. Module 8 explains virtual interfaces in detail.

This project declares the handles as plain `virtual alu_if`, which gives a component access to everything in the interface. A stricter style declares `virtual alu_if.DRV vif;` in the driver and `virtual alu_if.MON vif;` in the monitor, so that the compiler enforces the modport. The plain form is used here because it keeps the constructor chain simple (one handle type from top to bottom) and is the most widely supported.

## 2.5 The Transaction: alu_txn.sv

### Why a transaction class

A transaction is one complete operation of the DUT, described without any reference to clock edges: "ADD 200 and 100, result 300". It is the unit that travels through the mailboxes. Making it a class gives it three things a struct cannot have (Module 1, Section 3.3): randomization with constraints, methods, and extension by inheritance. Module 6 develops the transaction class step by step; here is its final form for this project.

### What goes into a transaction

| Kind of field | In `alu_txn` | Randomized? | Filled in by |
|---|---|---|---|
| Stimulus (DUT inputs) | `a`, `b`, `op` | Yes (`rand`) | Generator (driven side); monitor (observed side) |
| Response (DUT outputs) | `result` | No | Monitor |
| Bookkeeping | `id` | No | Generator or monitor |
| Control signals | None: `valid_in` and `valid_out` are protocol signals, not data. They are implied by the existence of the transaction | | |

> **Interview trap:** "Do you put `clk`, `rst_n`, `valid_in` in the transaction?" No. Clock and reset are not part of an operation. `valid_in` is how the driver *expresses* a transaction on the pins; it is protocol, and protocol belongs to the driver and monitor.

### The file

```systemverilog file=alu_txn.sv
class alu_txn;

  rand bit [7:0] a;
  rand bit [7:0] b;
  rand alu_op_e  op;
  logic [8:0]    result;
  int unsigned   id;

  // Make the corner operands 0 and 255 more likely than uniform random would
  constraint operand_c {
    a dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};
    b dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};
  }

  function void print(string tag = "");
    $display("[%0t] %s id=%0d op=%s a=%0d b=%0d result=%0d",
             $time, tag, id, op.name(), a, b, result);
  endfunction

  virtual function alu_txn copy();
    alu_txn c;
    c        = new();
    c.a      = a;
    c.b      = b;
    c.op     = op;
    c.result = result;
    c.id     = id;
    return c;
  endfunction

  function bit compare(alu_txn rhs);
    if (rhs == null) return 0;
    return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
  endfunction

endclass
```

There is no `package` or `import` in this file. It is not compiled on its own: it is pulled into the package `alu_tb_pkg` with `` `include `` (Section 5.3), and the package imports `alu_pkg`. The same is true of every class file in this project.

### Line by line

| Code | Explanation |
|---|---|
| `rand bit [7:0] a;` | Two-state, because random values are never X or Z. `rand` means `randomize()` chooses a new value each time. |
| `rand alu_op_e op;` | A random enum only ever receives one of its eight named values, so every generated opcode is legal. |
| `logic [8:0] result;` | Not `rand`: it is an output of the DUT. Four-state, so that an X from the DUT is preserved all the way to the scoreboard. Its default value is X, which correctly means "not known yet". |
| `int unsigned id;` | A serial number for matching log lines. Not random. |
| `constraint operand_c {...}` | A distribution: weight 1 for `00`, weight 1 for `FF`, and a total weight of 8 shared by the 254 values between them. So each operand is 0 about 10 percent of the time and 255 about 10 percent of the time. Carry, borrow and shift-out bugs live at those values. Module 5 covers `dist`. |
| `function void print(string tag = "");` | Prints all fields on one line. The `tag` says which component is printing (`GEN`, `DRV`, `MON`). Having one print routine keeps the log format identical everywhere. |
| `op.name()` | The enum method that returns the name as a string. |
| `result=%0d` | Prints `x` when the result has not been filled in yet, which is the case for transactions on the stimulus side. |
| `virtual function alu_txn copy();` | Returns a new object with the same field values (a deep copy; this class contains no handles, so copying the fields is enough). `virtual` lets a derived transaction with extra fields override it. |
| `alu_txn c; c = new();` | Declaration and construction are separate statements. |
| `function bit compare(alu_txn rhs);` | Returns 1 if the two transactions match. |
| `if (rhs == null) return 0;` | Protects against a null handle. |
| `result === rhs.result` | Case equality: an X in either result gives a definite "not equal" instead of an unknown. The inputs are two-state (`a`, `b`) or generated (`op`), so `==` is sufficient for them. |
| `id` is not compared | It is bookkeeping, not DUT behaviour. |

### How the same class is used on both sides

```text
   Stimulus side                             Observation side

   generator:                                monitor:
     blueprint.randomize()                     t = new()
     txn = blueprint.copy()                    t.a, t.b, t.op <- sampled pins
     a, b, op = random values                  t.result       <- sampled pins
     result   = x  (unknown)                   (a complete record of what happened)
          |                                         |
          v                                         v
   driver:                                   scoreboard:
     uses a, b, op                             expected = t.copy()
     ignores result                            expected.result = alu_predict(t)
                                               t.compare(expected)
```

One class serves both paths. On the stimulus side only the input fields are meaningful. On the observation side all fields are filled from the pins.

> **Common mistake:** Declaring `result` as `rand`. The solver would then invent a result, and a careless scoreboard might compare the DUT against a random number, or worse, against itself. Only fields the testbench is free to choose are `rand`.

> **Common mistake:** Declaring `result` as `bit [8:0]`. An X on the DUT output would silently become 0 in the monitor, and for an operation whose correct answer is 0 the scoreboard would report PASS.

### Interview questions

**Q1. What is a transaction?**
An object that describes one complete operation on the DUT at a level above the pins: the stimulus fields, the response fields and any bookkeeping. It is what the testbench components pass to each other.

**Q2. Which fields of a transaction are declared `rand`?**
Only the fields that the testbench is free to choose, that is, the DUT inputs (`a`, `b`, `op`). Outputs of the DUT (`result`) and bookkeeping fields (`id`) are not random.

**Q3. Why is `result` a `logic` and `a` a `bit`?**
`a` is stimulus: it is generated, never X, and two-state is faster and randomizes cleanly. `result` is sampled from the DUT and must be able to hold X or Z so that the scoreboard can detect them.

**Q4. Why does the transaction have a `copy()` method?**
Because assigning one handle to another does not copy the object. The generator needs a fresh, independent object for each transaction it sends, and the scoreboard needs an independent object to hold the expected values.

**Q5. Why is `===` used inside `compare()`?**
So that an X or Z in the observed result makes the comparison fail with a definite 0. With `==` the comparison would evaluate to X, which could be misread as a pass or silently skipped.

**Q6. Why are the class files not compiled directly?**
They are textually included into a package. A class that is declared inside a package can be imported wherever it is needed, and every user sees the same type. Compiling the same class file in two places would create two different, incompatible types.

**Q7. What do the two clocking blocks in the interface give you?**
A race-free timing discipline. Inputs are sampled just before the clock edge (`#1step`), so the testbench sees the same values the DUT sees. Outputs are driven a fixed skew after the edge, so the DUT never sees a testbench drive at the same instant as its own sampling. Having a separate input-only block for the monitor prevents the monitor from driving anything.

**Q8. Why can a class not connect to an interface instance directly?**
A class is a dynamic object created at run time and has no ports, while an interface instance is a static part of the design hierarchy. The class holds a `virtual interface` handle that is assigned, at run time, to point to the instance.

**Q9. Who drives `rst_n`?**
The top module. Reset is a property of the environment around the DUT, not of an individual transaction, and it must be active before any class object starts running.
