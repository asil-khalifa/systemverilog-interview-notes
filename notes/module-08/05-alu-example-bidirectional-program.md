# Part 5: Putting It Together

## 5.1 The Final ALU Interface

This is the interface used for the rest of the course. Module 9 builds the layered testbench on it without changing a line.

```systemverilog file=alu_if.sv
interface alu_if (input logic clk);
  import alu_pkg::*;

  // ---- signals ----
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  // ---- timing for the driver ----
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid_in, a, b, op;
    input  valid_out, result;
  endclocking

  // ---- timing for the monitor ----
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid_in, a, b, op, valid_out, result;
  endclocking

  // ---- views ----
  modport DUT (input clk, rst_n, valid_in, a, b, op, output valid_out, result);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);
endinterface
```

**Line by line**

| Line | Explanation |
|---|---|
| `interface alu_if (input logic clk);` | The clock comes from outside, so that the DUT and the interface share one clock. |
| `import alu_pkg::*;` | Makes the opcode type `alu_op_e` visible inside the interface. |
| `logic rst_n;` ... `logic [8:0] result;` | One signal per DUT port (except the clock), with the same names and types as the ports. `rst_n` is driven by `tb_top`. |
| `clocking drv_cb @(posedge clk);` | The driver's clocking block, synchronous to the rising edge. |
| `default input #1step output #1;` | Inputs are sampled just before the edge; outputs change one time unit after it. |
| `output valid_in, a, b, op;` | The driver drives every DUT input except reset. |
| `input valid_out, result;` | The driver may also look at the DUT outputs, for protocols where the driver must react to the DUT. The ALU driver does not need them, but they are available. |
| `clocking mon_cb @(posedge clk);` | The monitor's clocking block. |
| `input valid_in, a, b, op, valid_out, result;` | Everything is an input: the monitor observes both what went into the DUT and what came out, and can drive nothing. |
| `modport DUT (...)` | The design's view: plain signals with directions. It has no clocking block, because RTL does not use one. |
| `modport DRV (clocking drv_cb, input clk, rst_n);` | The driver's view: the clocking block, plus `clk` and `rst_n` as plain inputs. The raw signals `a`, `b` and so on are **not** listed, so the driver can reach them only through `drv_cb`. |
| `modport MON (clocking mon_cb, input clk, rst_n);` | The monitor's view. |

**Why `rst_n` is not inside the clocking blocks.** The reset is asynchronous: it is applied while the clock may not even be running, and the DUT reacts to it immediately. A clocking block only acts at clock edges. So reset is driven directly by `tb_top` and is visible to the driver and the monitor as a plain input, for example to wait with `@(posedge vif.rst_n)` or `wait (vif.rst_n);`.

**Why the driver and the monitor have separate clocking blocks.** Their directions differ. The DUT inputs are outputs of the driver and inputs of the monitor. One clocking block cannot give a signal two directions.

### How the three users see the interface

| Signal | `modport DUT` | `modport DRV` | `modport MON` |
|---|---|---|---|
| `clk` | input | input | input |
| `rst_n` | input | input | input |
| `valid_in`, `a`, `b`, `op` | input | `drv_cb` output (synchronous drive) | `mon_cb` input (sampled) |
| `valid_out`, `result` | output | `drv_cb` input (sampled) | `mon_cb` input (sampled) |

## 5.2 Complete Example: Classes Driving and Monitoring the ALU

### What is built

```text
   tb_alu_vif (module)
  +--------------------------------------------------------------------------+
  |   clk generator                                                          |
  |                                                                          |
  |   alu_driver object                                   alu_monitor object |
  |   vif (virtual alu_if.DRV)                    vif (virtual alu_if.MON)   |
  |        |  vif.drv_cb.a <= ...                          ^ vif.mon_cb.result|
  |        v                                               |                 |
  |   +----------------------- alu_if aif ---------------------------+       |
  |   |  drv_cb (drive at edge + 1)        mon_cb (sample before edge)|      |
  |   |  rst_n  valid_in  a  b  op                valid_out  result  |       |
  |   +---------|---------|--|--|--------------------^---------^-----+       |
  |             v         v  v  v                    |         |             |
  |           +-----------------------------------------------------+        |
  |           |                       alu  dut                      |        |
  |           +-----------------------------------------------------+        |
  +--------------------------------------------------------------------------+
```

The driver and the monitor here are simplified: the driver's `drive` task takes the operand values as arguments, and the monitor prints what it sees. Module 9 gives them mailboxes and transaction objects; the pin-level code stays as it is here.

### The classes

```systemverilog file=alu_vif_classes.sv
import alu_pkg::*;

class alu_driver;

  virtual alu_if.DRV vif;

  function new(virtual alu_if.DRV vif);
    this.vif = vif;
  endfunction

  // Drive one operation: one cycle with valid_in = 1, then valid_in = 0
  task drive(bit [7:0] a, bit [7:0] b, alu_op_e op);
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b1;
    vif.drv_cb.a        <= a;
    vif.drv_cb.b        <= b;
    vif.drv_cb.op       <= op;
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b0;
    $display("[%0t] DRV: %s a=%0d b=%0d accepted by the DUT", $time, op.name(), a, b);
  endtask

endclass

class alu_monitor;

  virtual alu_if.MON vif;

  function new(virtual alu_if.MON vif);
    this.vif = vif;
  endfunction

  task run();
    logic [7:0] a, b;        // the most recent request seen on the DUT inputs
    alu_op_e    op;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid_out)
        $display("[%0t] MON: %s a=%0d b=%0d -> result=%0d",
                 $time, op.name(), a, b, vif.mon_cb.result);
      if (vif.mon_cb.valid_in) begin
        a  = vif.mon_cb.a;
        b  = vif.mon_cb.b;
        op = vif.mon_cb.op;
      end
    end
  endtask

endclass
```

### The top module

Compile in this order: `alu_pkg.sv` and `alu.sv` (from `examples/module-01/`), `alu_if.sv`, `alu_vif_classes.sv`, then this file.

```systemverilog file=tb_alu_vif.sv
module tb_alu_vif;
  import alu_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);                          // physical interface

  alu dut (                                  // DUT with ordinary ports
    .clk       (clk),
    .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),
    .a         (aif.a),
    .b         (aif.b),
    .op        (aif.op),
    .valid_out (aif.valid_out),
    .result    (aif.result)
  );

  alu_driver  drv;
  alu_monitor mon;

  initial begin
    // Reset is asynchronous, so the reset-time values are assigned directly
    aif.rst_n    = 0;
    aif.valid_in = 0;
    aif.a        = '0;
    aif.b        = '0;
    aif.op       = ALU_ADD;

    drv = new(aif);                          // physical -> virtual (modport DRV)
    mon = new(aif);                          // physical -> virtual (modport MON)

    repeat (2) @(negedge clk);
    aif.rst_n = 1;                           // released at time 20, away from the edge

    fork
      mon.run();                             // the monitor runs in the background
    join_none

    drv.drive(8'd200, 8'd100, ALU_ADD);
    drv.drive(8'd5,   8'd10,  ALU_SUB);
    drv.drive(8'hF0,  8'h3C,  ALU_XOR);

    repeat (3) @(posedge clk);
    $finish;
  end

endmodule
```

```output
[35] DRV: ALU_ADD a=200 b=100 accepted by the DUT
[45] MON: ALU_ADD a=200 b=100 -> result=300
[55] DRV: ALU_SUB a=5 b=10 accepted by the DUT
[65] MON: ALU_SUB a=5 b=10 -> result=507
[75] DRV: ALU_XOR a=240 b=60 accepted by the DUT
[85] MON: ALU_XOR a=240 b=60 -> result=204
```

### Line by line: the driver

| Line | Explanation |
|---|---|
| `import alu_pkg::*;` | At the top of the file, so that the classes can use `alu_op_e`. |
| `virtual alu_if.DRV vif;` | The handle, restricted to the driver's modport. Through it the class can use `vif.drv_cb`, `vif.clk` and `vif.rst_n`, and nothing else. |
| `function new(virtual alu_if.DRV vif);` | The handle arrives through the constructor. |
| `@(vif.drv_cb);` | Wait for the next rising clock edge, as defined by the clocking block. |
| `vif.drv_cb.valid_in <= 1'b1;` and the three lines after it | Synchronous drives. All four signals change together, one time unit after this edge. The DUT, which sampled at the edge itself, has not seen them yet. |
| `@(vif.drv_cb);` | Wait one cycle. At this edge the DUT samples `valid_in` = 1 together with `a`, `b` and `op`. |
| `vif.drv_cb.valid_in <= 1'b0;` | End of the request: `valid_in` goes low one time unit after this edge. |
| `$display(... op.name() ...)` | Printed at the edge at which the DUT captured the request. |

### Line by line: the monitor

| Line | Explanation |
|---|---|
| `virtual alu_if.MON vif;` | Restricted to the monitor's modport: only sampled inputs. An attempt to drive anything from this class does not compile. |
| `logic [7:0] a, b;` | Four-state, so that an X on the DUT inputs would be preserved (Module 1, Section 2.1). |
| `forever begin @(vif.mon_cb);` | The monitor looks at the bus at every clock edge for the whole simulation. |
| `if (vif.mon_cb.valid_out)` | The sampled value of `valid_out`. When it is 1, `result` belongs to the request that was captured one cycle earlier, which is held in `a`, `b` and `op`. |
| `if (vif.mon_cb.valid_in) begin ... end` | A request was presented to the DUT at this edge. Its operands are remembered for the next cycle. This check comes after the result check so that a result is always paired with the previous request, even if requests arrive in consecutive cycles. |

### Line by line: the top module

| Line | Explanation |
|---|---|
| `alu_if aif (clk);` | The one physical interface instance. |
| `alu dut (... .a(aif.a) ...);` | The DUT's ordinary ports are connected to the interface signals (Section 1.5). |
| `aif.rst_n = 0;` ... `aif.op = ALU_ADD;` | During reset the top module assigns the signals directly, by instance name. A clocking block drive could not do this at time 0, because it only acts at a clock edge. A known `op` also keeps the `unique case` in the ALU from reporting an X opcode. |
| `drv = new(aif);` | The instance is passed to a constructor that expects `virtual alu_if.DRV`. The handle inside the driver is restricted to that modport. Writing `new(aif.DRV)` is equivalent. |
| `repeat (2) @(negedge clk); aif.rst_n = 1;` | Reset is held for two falling edges and released at time 20. |
| `fork mon.run(); join_none` | The monitor's endless loop is started as a parallel thread (Module 7). |
| `drv.drive(...)` three times | Hand-written stimulus. Module 9 replaces these calls with a generator and a mailbox. |
| `repeat (3) @(posedge clk); $finish;` | Leaves time for the last result to be observed. |

### Execution flow of the first operation

| Time | DUT | Driver | Monitor |
|---|---|---|---|
| 20 | Reset released | `drive()` is called and waits for `drv_cb` | Started, waits for `mon_cb` |
| 25 | Samples `valid_in` = 0 | Wakes; requests `valid_in` = 1, `a` = 200, `b` = 100, `op` = `ALU_ADD` | Samples `valid_in` = 0, `valid_out` = 0: nothing to do |
| 26 | Inputs change | | |
| 35 | Samples `valid_in` = 1: stores `result` = 300, sets `valid_out` = 1 | Wakes; requests `valid_in` = 0; prints the `DRV` line; `drive()` returns | Samples `valid_in` = 1 (value before the edge): remembers 200, 100, `ALU_ADD`. `valid_out` is still 0 in the sample |
| 36 | `valid_in` goes low | | |
| 45 | Samples `valid_in` = 0: sets `valid_out` = 0 | Second `drive()` wakes and drives the next request | Samples `valid_out` = 1 and `result` = 300: prints the `MON` line |

The second and third operations repeat this pattern twenty time units later each. Check the results: 5 - 10 in 9 bits is `1_1111_1011` = 507 (bit 8 is the borrow), and `F0 ^ 3C` = `CC` = 204.

Each number in the log is determined by the clocking blocks, not by the order in which the simulator runs the driver, the monitor and the DUT at an edge. That is the property a testbench must have.

> **Common mistake:** Driving DUT inputs both through the clocking block and by direct assignment during normal operation. The direct assignments at time 0 above are acceptable because they happen once, before any synchronous drive. After that, use the clocking block only. And never drive a clocking block output with a continuous `assign` as well: that is illegal.

> **Verification application:** This is the complete "signal level" of a layered testbench. In Module 9 the generator creates `alu_txn` objects, a mailbox carries them to `alu_driver`, whose `run()` task calls exactly this `drive` logic; `alu_monitor` builds an `alu_txn` from what it samples and sends it through another mailbox to `alu_scoreboard`.

### Interview questions

**Q1. Explain how a driver class drives the DUT.**
The driver has a virtual interface handle that the top module set to the physical interface connected to the DUT. For each transaction the driver waits for the clocking block event, `@(vif.drv_cb)`, and applies the transaction's fields with synchronous drives, `vif.drv_cb.sig <= value`. The clocking block puts the values on the interface signals just after the clock edge, and the DUT samples them at the next edge.

**Q2. What is the difference between how the driver and the monitor use the interface?**
The driver drives DUT inputs through a clocking block whose signals are outputs. The monitor only samples, through a clocking block (and modport) in which every signal is an input; it never drives.

**Q3. Why is reset not driven through the clocking block?**
Reset is asynchronous and must be applied regardless of the clock, possibly before the clock runs. Clocking block drives take effect only at clock events.

## 5.3 Bidirectional Signals in an Interface

### The problem

Some pins are driven by the DUT at certain times and by the testbench at others: a memory data bus, I2C `sda`, a GPIO pin. Three facts from earlier collide here:

1. A signal with more than one driver must be a **net** (`wire`), because only a net resolves several drivers (Module 1, Section 2.4).
2. A net cannot be assigned procedurally.
3. A class can only make procedural assignments through its virtual interface.

So a class cannot drive a `wire` in the interface directly.

### The pattern

Put three things in the interface: the `wire` itself, a `logic` variable holding the value the testbench wants to drive, and a `logic` output-enable. A continuous assignment in the interface is the testbench's tri-state driver. The class writes only the two variables.

```text
   class (procedural)             interface                         DUT
   -----------------              ---------                        -----
   vif.data_drv = 8'hA5; ---->  data_drv ---+
                                            |  assign data =
   vif.data_oe  = 1;     ---->  data_oe ----+   data_oe ? data_drv : 'z;
                                            |
                                            v
   value = vif.data;     <----  wire data <=========================> inout data
                                 (resolved value of both drivers)
```

### Complete example

```systemverilog file=tb_bidir.sv
interface bidir_if (input logic clk);
  logic       wr;              // testbench -> DUT: store the value that is on the bus
  logic       rd;              // testbench -> DUT: put the stored value on the bus
  wire  [7:0] data;            // shared bus: a net, because it has two drivers

  logic [7:0] data_drv;        // value the testbench wants on the bus
  logic       data_oe;         // 1 = the testbench is driving the bus

  assign data = data_oe ? data_drv : 'z;       // the testbench's tri-state driver
endinterface

module bidir_reg (input logic clk, input logic wr, input logic rd, inout wire [7:0] data);
  logic [7:0] store;
  always_ff @(posedge clk) if (wr) store <= data;
  assign data = rd ? store : 'z;               // the DUT's tri-state driver
endmodule

class bidir_driver;

  virtual bidir_if vif;

  function new(virtual bidir_if vif);
    this.vif = vif;
  endfunction

  task write(bit [7:0] value);
    @(negedge vif.clk);
    vif.data_drv = value;
    vif.data_oe  = 1;          // take the bus
    vif.wr       = 1;
    @(negedge vif.clk);
    vif.wr       = 0;
    vif.data_oe  = 0;          // release the bus
  endtask

  task read(output logic [7:0] value);
    @(negedge vif.clk);
    vif.rd = 1;                // the DUT drives the bus now
    @(negedge vif.clk);
    value  = vif.data;         // reading a net through the handle is allowed
    vif.rd = 0;
  endtask

endclass

module tb_bidir;

  logic clk = 0;
  always #5 clk = ~clk;

  bidir_if     bif (clk);
  bidir_reg    dut (.clk(clk), .wr(bif.wr), .rd(bif.rd), .data(bif.data));
  bidir_driver drv;
  logic [7:0]  value;

  initial begin
    bif.wr = 0;  bif.rd = 0;  bif.data_oe = 0;  bif.data_drv = '0;
    drv = new(bif);

    #1 $display("[%0t] bus idle       : data = %h", $time, bif.data);
    drv.write(8'hA5);
    #1 $display("[%0t] after the write: data = %h", $time, bif.data);
    drv.read(value);
    $display("[%0t] value read back: %h", $time, value);
    #1 $display("[%0t] bus idle again : data = %h", $time, bif.data);
    $finish;
  end

endmodule
```

```output
[1] bus idle       : data = zz
[21] after the write: data = zz
[40] value read back: a5
[41] bus idle again : data = zz
```

**Line by line**

| Line | Explanation |
|---|---|
| `wire [7:0] data;` | A net. It will have two continuous drivers: one in the interface, one in the DUT. |
| `logic [7:0] data_drv; logic data_oe;` | Variables that the class can assign procedurally. |
| `assign data = data_oe ? data_drv : 'z;` | When `data_oe` is 1 the testbench's value goes onto the bus; otherwise this driver is high impedance and does not disturb the bus. |
| `inout wire [7:0] data` | The DUT's bidirectional port. `inout` ports must be nets. |
| `assign data = rd ? store : 'z;` | The DUT drives the bus only while `rd` is 1. |
| `vif.data_oe = 1;` ... `vif.data_oe = 0;` | The driver takes the bus for one cycle and then releases it. Forgetting to release it would leave two drivers fighting during a later read. |
| `value = vif.data;` | The resolved value of the net: here only the DUT is driving, so it is the DUT's value. |
| `// vif.data = 8'h55;` (not in the code) | Would be a compile error: a net cannot be assigned procedurally. |

**Execution flow**

| Time | Event |
|---|---|
| 1 | Neither side drives: `data` = `zz`. |
| 10 | `write` drives `A5` onto the bus and sets `wr`. |
| 15 | Rising edge: the DUT stores `A5`. |
| 20 | `write` clears `wr` and releases the bus. |
| 21 | Printed: the bus is floating again, `zz`. |
| 30 | `read` sets `rd`. The DUT drives `A5`. |
| 40 | `read` copies `A5` from the bus and clears `rd`. Printed. |
| 41 | The DUT has stopped driving: `zz`. |

> **Interview trap:** "A class needs to drive an `inout` pin of the DUT. How?" Not directly: the pin must be a `wire`, and a class cannot assign a net. The interface holds a `logic` drive value and a `logic` output-enable, plus `assign pin = oe ? drive_value : 'z;`. The class assigns the two variables and reads the wire.

> **Common mistake:** Both sides driving at once. If the testbench keeps `data_oe` at 1 while the DUT also drives, any bit where the two values differ becomes X. An X on a bidirectional bus during a read almost always means the testbench did not release the bus.

A clocking block can also contain such a signal as an `inout`: the clocking block then samples the net like an input and drives it like an output, and driving it with `'z` releases it. The explicit pattern above is easier to read and to debug, and is the form most often asked about.

### Interview questions

**Q1. Why must a bidirectional signal in an interface be a `wire`?**
It has more than one driver, the DUT and the testbench. Only a net resolves multiple drivers; a `logic` variable with two continuous drivers is an error.

**Q2. How does a class-based driver drive a `wire` in the interface?**
Through an intermediate variable and an output-enable in the interface, with a continuous tri-state assignment from them to the wire. The class writes the variables; the assignment drives the net.

**Q3. What does X on a bidirectional bus usually indicate?**
Contention: two drivers are active with different values at the same time.

## 5.4 Program Blocks

This section is for awareness. You will be asked what a program block is, and why most current testbenches do not use one.

### Definition

A `program` block (`program` ... `endprogram`) is a container for testbench code. It looks like a module but is executed differently: all code in a program runs in the **Reactive** region of the time step, after the design's Active and NBA regions are finished. The testbench therefore always sees the design's settled values for the current time step, and its own drives reach the design after the design has sampled. It was introduced to separate testbench and design scheduling.

```systemverilog
program automatic alu_test_prog (alu_if aif);

  initial begin
    @(aif.drv_cb);
    aif.drv_cb.valid_in <= 1'b1;
    // ...
  end

endprogram

module tb_top;
  logic clk = 0;
  always #5 clk = ~clk;
  alu_if        aif  (clk);
  // alu        dut  (...);
  alu_test_prog test (aif);        // a program is instantiated like a module
endmodule
```

### Rules

| A program block may contain | A program block may not contain |
|---|---|
| `initial` blocks | `always` blocks |
| Variables, classes, tasks, functions | Instances of modules or interfaces |
| Clocking blocks | User-defined primitives |
| Assertions, covergroups | |

Other points:

- When every `initial` block of every program has finished, the simulation ends automatically, as if `$finish` had been called. `$exit` ends a program explicitly.
- A program can call tasks and functions in modules. A module cannot call tasks or functions of a program.

### Module, program and the practice today

| Property | `module` | `program` |
|---|---|---|
| Intended for | Design and testbench structure | Testbench code only |
| Region where its code runs | Active | Reactive |
| `always` blocks | Yes | No |
| Can instantiate modules and interfaces | Yes | No |
| Ends the simulation when its `initial` blocks finish | No | Yes |
| Race with the DUT at a clock edge | Possible, unless clocking blocks or nonblocking drives are used | Avoided by the region separation |

In current practice, and in UVM, the testbench is a set of classes in a package, started from an `initial` block in a top-level **module**, and race freedom comes from clocking blocks in the interface. Program blocks are therefore rare in new code: they add restrictions (no `always`, no instances), they do not help code that lives in classes called from a module, and a mixture of program-based and module-based testbench code can itself create ordering surprises. You still need to recognise them in older testbenches.

### Interview questions

**Q1. What is a program block?**
A testbench container whose code executes in the Reactive region, after the design has finished evaluating for the time step. It was introduced to avoid races between the testbench and the DUT.

**Q2. What is the difference between a module and a program?**
A program cannot contain `always` blocks or instantiate modules and interfaces; its code runs in the Reactive region instead of the Active region; and the simulation ends when all program `initial` blocks have completed.

**Q3. Are program blocks used in UVM testbenches?**
Generally not. UVM testbenches are class-based, started from a module, and rely on clocking blocks (and nonblocking drives) for race avoidance.

## 5.5 Interface, Modport, Clocking Block and Virtual Interface Compared

These four are often confused. Each answers a different question.

| Construct | Question it answers | Static or dynamic | Used by |
|---|---|---|---|
| `interface` | **Which** signals belong to this bus? | Static instance | DUT connection and testbench |
| `modport` | **Who** may read and write each signal (direction)? | Declaration inside the interface | Module ports and virtual interface declarations |
| `clocking` block | **When** are signals sampled and driven (timing)? | Declaration inside the interface | Testbench code only |
| `virtual interface` | **How** does a class reach the interface instance? | Dynamic handle | Classes |

### Modport versus clocking block

| Property | Modport | Clocking block |
|---|---|---|
| Purpose | Direction and visibility | Timing (synchronisation to a clock) |
| Specifies a clock | No | Yes: the clocking event |
| Specifies skews | No | Yes |
| Direction is from the point of view of | Whoever uses the modport | The testbench |
| Used by the DUT | Yes | No |
| Synthesizable | Yes | No |
| Prevents races | No | Yes |
| Prevents a wrong-direction write | Yes | Yes, for the signals it lists |
| How a signal is accessed | `vif.sig` | `vif.cb.sig` |
| Can be combined | A modport can contain a clocking block: `modport DRV (clocking drv_cb, ...);` | |

### The complete picture

```text
   1. interface alu_if        declares signals, drv_cb, mon_cb, modports       (static)
   2. tb_top                  alu_if aif (clk);  alu dut (... aif.a ...);       (static)
   3. class alu_driver        virtual alu_if.DRV vif;                           (dynamic)
   4. tb_top, at run time     drv = new(aif);            physical -> virtual
   5. class methods           @(vif.drv_cb);  vif.drv_cb.a <= value;            (race-free)
```
