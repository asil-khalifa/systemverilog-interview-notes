# Part 6: Module 8 Revision and Practice

## 6.1 Revision Summary

### The four constructs on one page

| Construct | What it is | Declared | Key syntax |
|---|---|---|---|
| Interface | A named bundle of signals, instantiated once and shared | Outside modules, like a module | `interface alu_if (input logic clk); ... endinterface` |
| Modport | A named view: which signals, which direction, for one role | Inside the interface | `modport DUT (input a, output result);` |
| Clocking block | Sampling and driving times relative to a clock | Inside the interface | `clocking cb @(posedge clk); default input #1step output #1; ... endclocking` |
| Virtual interface | A handle that lets a class reach an interface instance | In a class | `virtual alu_if.DRV vif;` |

### Rules to remember

**Interfaces**

- An interface instance holds the signals once. Interface ports and virtual interfaces are references to it, never copies.
- It may contain signals, parameters, ports, modports, clocking blocks, tasks, functions, `initial`/`always`/`assign` and assertions. It may not contain module instances.
- The clock is normally an input port of the interface, generated once in the top module.
- A DUT with ordinary ports is connected signal by signal, once, in the top module: `.a(aif.a)`.
- `logic` signals in an interface follow the single-driver rule. A signal with two drivers must be a `wire`.

**Modports**

- Directions are from the user's side. What the testbench drives is an `output` in the testbench's modport.
- A modport is selected in the module header (`alu_if.DUT p`), at the instance (`aif.DUT`), or in a virtual interface declaration (`virtual alu_if.DRV vif`).
- Writing an `input`, or touching an unlisted signal, through a modport is a compile error.
- Modports do not stop hierarchical access, add no hardware and define no timing.
- A modport can contain a clocking block and can import tasks.

**Interface arrays**

- `my_if bus [4] (clk);` creates four independent instances that share the port connections.
- The index must be a constant. For variable indexing, use an array of virtual interfaces.

**Virtual interfaces**

- A class cannot instantiate an interface and has no ports. It holds a `virtual <interface> vif` handle instead.
- The handle is `null` until the top module assigns the physical instance to it, usually through the constructor.
- Using a null handle is a fatal run-time error.
- A handle for a parameterised interface must repeat the same parameter values.
- Nets cannot be assigned through a virtual interface; only variables can.

**Clocking blocks**

- Directions are from the testbench's side: `input` = sampled, `output` = driven.
- Default skews: input `#1step`, output `#0`.
- `#1step` samples in the Preponed region (value before the edge). `#0` on an input samples in the Observed region (value after the edge).
- Wait with `@(vif.cb)`, read `vif.cb.sig`, drive with `vif.cb.sig <= value`. Only `<=` is allowed; an output-only clockvar cannot be read.
- A drive executed away from a clocking event takes effect as if executed at the next one.
- `##N` needs a default clocking and is not available in classes; use `repeat (N) @(vif.cb)`.
- Reset is asynchronous and stays outside the clocking block.

**Scheduler regions (simplified order)**

Preponed (sample) → Active (design reads, blocking assignments) → Inactive (`#0`) → NBA (nonblocking updates) → Observed (assertions, `#0` input sampling, clocking event) → Reactive (program code) → Re-NBA (zero-skew clocking drives) → Postponed (`$monitor`, `$strobe`).

### The recipe for connecting a class to a DUT

| Step | Code |
|---|---|
| 1. Interface with clocking blocks and modports | `interface alu_if (input logic clk); ... endinterface` |
| 2. Instantiate in the top module and connect the DUT | `alu_if aif (clk); alu dut (.a(aif.a), ...);` |
| 3. Handle in the class | `virtual alu_if.DRV vif;` |
| 4. Constructor stores the handle | `function new(virtual alu_if.DRV vif); this.vif = vif; endfunction` |
| 5. Top module passes the instance | `drv = new(aif);` |
| 6. Class drives and samples synchronously | `@(vif.drv_cb); vif.drv_cb.a <= 8'd5;` |

### Synthesizable or simulation-only

| Synthesizable | Simulation-only |
|---|---|
| Interface with signals and parameters | Clocking blocks |
| Modports | Virtual interfaces |
| Interface ports of modules | Program blocks |
| Synthesizable `always`/`assign` logic and functions inside an interface | `initial` blocks, delays, clock generators, testbench tasks and assertions inside an interface |

## 6.2 Interview Questions and Answers

The questions inside Parts 1 to 5 cover the direct definitions. The questions below are additional.

### Basic level

**Q1. What can an interface contain?**
Signals (nets and variables), ports, parameters, modports, clocking blocks, tasks, functions, `initial` and `always` blocks, continuous assignments, assertions, covergroups and instances of other interfaces. It cannot contain module instances.

**Q2. How is an interface different from a module?**
A module describes functionality and can instantiate modules. An interface describes the connection between blocks, cannot instantiate modules, can be passed as a single port, supports modports, and can be referenced from classes through a virtual interface.

**Q3. Write an interface for a simple bus with `valid`, `ready` and 8-bit `data`.**
`interface bus_if (input logic clk); logic valid; logic ready; logic [7:0] data; endinterface`

**Q4. How do you instantiate an interface that has no ports?**
With empty parentheses: `bus_if bus ();`.

**Q5. What directions can a modport give a signal?**
`input`, `output`, `inout` and `ref`.

**Q6. What is the default value of a virtual interface?**
`null`.

**Q7. What are the default skews of a clocking block?**
`#1step` for inputs and `#0` for outputs.

**Q8. Which operator drives a clocking block output?**
The nonblocking-style operator `<=`. A blocking assignment to a clockvar is illegal.

**Q9. Write the declaration of a virtual interface for `alu_if` restricted to the monitor modport.**
`virtual alu_if.MON vif;`

**Q10. Where is the physical interface instantiated?**
In the top-level testbench module, next to the DUT.

**Q11. Can a class have a port?**
No. A class receives everything through constructor or method arguments, or by assignment to its properties.

**Q12. What does `@(vif.mon_cb);` do?**
It waits for the next clocking event of `mon_cb` (the next rising clock edge). When the process resumes, `vif.mon_cb.<signal>` holds the values sampled at that edge.

### Intermediate level

**Q13. Why is the monitor given a clocking block with only inputs?**
The monitor must observe without disturbing. With only inputs it cannot drive any signal, and it samples every signal at a race-free point, just before the clock edge.

**Q14. Why do the driver and the monitor use different clocking blocks?**
The DUT's inputs are outputs for the driver and inputs for the monitor. A signal has one direction inside a clocking block, so two blocks are needed.

**Q15. A signal is driven through a clocking block at the clock edge at time 100 with output skew `#2`. When does the DUT see it?**
The signal changes at time 102. The DUT, which samples at rising edges, sees it at the next rising edge after 102.

**Q16. The DUT changes an output at the clock edge at time 100. When does `vif.mon_cb.out` show the new value?**
At the next clocking event. At time 100 the monitor's sample was taken in the Preponed region, before the change, so it still shows the old value.

**Q17. What is the difference between `vif.a` and `vif.drv_cb.a`?**
`vif.a` is the raw interface signal: reading gives its current value, writing changes it at once, and both can race with the DUT. `vif.drv_cb.a` is the clockvar: writes are applied at the clock edge plus the output skew, and reads (for an input) return the value sampled before the edge.

**Q18. Can the same interface signal be in two clocking blocks?**
Yes. In `alu_if`, `valid_in`, `a`, `b` and `op` are outputs of `drv_cb` and inputs of `mon_cb`.

**Q19. How can a clocking block be triggered by the falling edge, or by both edges?**
By its clocking event: `clocking cb @(negedge clk);` or `clocking cb @(clk);` for both edges.

**Q20. What is the difference between `##2` and `repeat (2) @(posedge clk)`?**
In a scope with a default clocking, `##2` waits two clocking events of that block, which is the same amount of time. `##2` is tied to the default clocking block and its event; it cannot be used in a class. `repeat (2) @(posedge clk)` waits on the raw clock signal.

**Q21. How do you pass an interface to a task?**
As a virtual interface argument: `task automatic send(virtual bus_if vif, input logic [7:0] d);`. The caller passes the interface instance or a handle.

**Q22. Two driver objects are created and both are given the same interface instance. What happens?**
Both handles refer to the same signals, so both objects drive the same pins. With procedural or clocking block drives, the last write wins and the stimulus is corrupted. Each interface instance should have one driver.

**Q23. Can an interface be passed to a class without a virtual interface, for example by `ref` argument?**
No. Individual signals can be passed by `ref` to an automatic task, but an interface instance is not a variable. The only handle to an interface instance is a virtual interface.

**Q24. Why might a design team avoid interfaces in RTL port lists while the verification team uses them heavily?**
Some synthesis, lint and physical design flows handle interface ports less uniformly than plain ports, and the synthesised netlist gets tool-generated port names. Plain RTL ports avoid that. In the testbench there are no such concerns, and interfaces are required for class-based code.

**Q25. What happens to modport checking when the testbench accesses `tb_top.aif.a` directly?**
Nothing is checked. Modports apply only to access through a port or a virtual interface that selected the modport.

### Advanced and scenario-based

**Q26. A test passes on one simulator and fails on another with results shifted by one clock cycle. What do you suspect?**
A race between the testbench and the DUT. Typical causes: the driver assigns DUT inputs with blocking assignments at the active clock edge; the monitor reads raw signals at the clock edge; the code waits on `@(posedge vif.clk)` but reads clocking block samples. The fix is to drive and sample only through clocking blocks and to wait on the clocking block event.

**Q27. The monitor reports every result one cycle earlier than expected and the scoreboard pairs it with the wrong request. The monitor uses a clocking block. What is wrong?**
Probably the input skew is `#0` instead of `#1step`. With `#0` the monitor samples in the Observed region, after the DUT's registers have updated, so it sees the output of this edge instead of the value before it.

**Q28. The simulation dies at time 0 with a null handle error in the driver's `run` task. List the possible causes.**
The driver object itself was never constructed; or its virtual interface was never assigned: not passed to the constructor, the constructor wrote `vif = vif` without `this.`, the environment did not forward the handle, or `run()` was started before the connection was made.

**Q29. A driver uses `vif.drv_cb.rst_n <= 0` to apply reset at the start of the test, and the DUT is never reset. Why?**
Clocking block drives only happen at clocking events. If the clock is not running yet, or the first edge comes later than expected, the reset is not applied when needed. Reset is asynchronous and should be driven directly (from the top module or by direct assignment), not through a clocking block.

**Q30. You need to verify a design with eight identical ports. How do you organise the interfaces and the testbench?**
Declare an array of eight interface instances and connect element `i` to DUT port `i` in a generate loop. Copy the instances into an array of eight virtual interfaces. Create eight agents in a loop and give agent `i` the handle `vifs[i]`. The driver and monitor classes are written once.

**Q31. Explain what happens, region by region, when a driver executes `vif.drv_cb.a <= 5` after `@(vif.drv_cb)` with `output #0`.**
At the clock edge, the DUT's flip-flops sample their inputs in the Active region and update in the NBA region. The clocking block event is triggered in the Observed region and the driver process resumes. Its drive is applied to the raw signal `a` in the Re-NBA region of the same time step. The DUT has already sampled, so it sees the value 5 at the next clock edge.

**Q32. Can you drive the same DUT input from a clocking block and from a continuous assignment?**
No. A variable associated with a clocking block output may not also be driven by a continuous assignment. Choose one mechanism.

**Q33. What is a BFM and how does it relate to interfaces?**
A bus functional model is code that performs bus-level operations (read, write) by toggling the pins with the correct protocol timing. It can be implemented as tasks inside the interface, called from tests or classes, or as a driver class that uses a virtual interface. The first form is preferred when the model must run in an emulator; the second is the normal class-based style.

**Q34. In UVM, how does the driver get its virtual interface?**
The top module stores the interface instance in the configuration database with `uvm_config_db #(virtual alu_if)::set(...)`, and the driver (or its agent) retrieves it in the build phase with `uvm_config_db #(virtual alu_if)::get(...)`, reporting a fatal error if it is missing.

**Q35. Why is `#1step` better than a fixed input skew such as `#1`?**
`#1step` always means "the last value before the clock event", independent of the time unit, the clock period and the time precision. A fixed number is measured in time units and may be wrong for a different timescale or a faster clock; it is used only when a specific setup time must be modelled, as in gate-level simulation.

**Q36. What would you put in the interface besides signals, in a real project?**
Clocking blocks for driver and monitor, modports for DUT, driver and monitor, protocol assertions, sometimes functional coverage of the bus, and occasionally helper tasks such as `wait_clocks(n)` or a reset task.

## 6.3 Output-Prediction Questions

Work out the answer on paper first. P1, P4 and P5 need `counter_dut.sv` or `dff.sv` from this module to be compiled first.

**P1.**

```systemverilog
module p1;
  logic clk = 0;
  always #5 clk = ~clk;
  cnt_if  cif (clk);
  counter dut (cif);
  virtual cnt_if v1, v2;
  initial begin
    v1 = cif;
    v2 = v1;
    v1.rst_n = 0;
    v2.en    = 1;
    @(negedge clk);
    v2.rst_n = 1;
    repeat (2) @(negedge clk);
    $display("%0d %0d %b", v1.count, cif.count, v1 == v2);
    v2 = null;
    $display("%b %b", v1 == null, v2 == null);
    $finish;
  end
endmodule
```

Answer: `2 2 1` then `0 1`. Both handles refer to the one instance `cif`, so a write through either reaches the same signals and the comparison `v1 == v2` is true. Reset is released at time 10 and two rising edges (15 and 25) follow before time 30. Setting `v2` to `null` changes only that handle.

**P2.**

```systemverilog
module p2;
  logic       clk = 0;
  logic [3:0] n   = 0;
  always #5 clk = ~clk;
  always @(posedge clk) n <= n + 4'd2;
  clocking cb @(posedge clk);
    input n;
  endclocking
  initial begin
    repeat (3) begin
      @(cb);
      $display("%0d", cb.n);
    end
    $finish;
  end
endmodule
```

Answer: `0`, `2`, `4` on three lines. The default input skew is `#1step`, so at each rising edge the clocking block holds the value of `n` from just before that edge: 0 at time 5, 2 at time 15, 4 at time 25.

**P3.**

```systemverilog
module p3;
  logic       clk = 0;
  logic [7:0] d   = 8'd1;
  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    output #3 d;
  endclocking
  always @(d) $display("[%0t] d = %0d", $time, d);
  initial begin
    @(cb);
    cb.d <= 8'd2;
    @(negedge clk);
    cb.d <= 8'd3;
    repeat (2) @(cb);
    $finish;
  end
endmodule
```

Answer: `[8] d = 2` then `[18] d = 3`. The first drive is executed at the clocking event of time 5 and is applied 3 time units later. The second is executed at time 10, which is not a clocking event, so it is treated as if executed at the next event (15) and applied at 18.

**P4.**

```systemverilog
module p4;
  logic clk = 0, d = 0, q;
  always #5 clk = ~clk;
  dff dut (.*);
  initial begin
    @(posedge clk);
    d <= 1;
    @(posedge clk);
    $display("%b", q);
    @(negedge clk);
    $display("%b", q);
    $finish;
  end
endmodule
```

Answer: `0` then `1`, on every simulator. Compare with `tb_race.sv`: the only change is `d <= 1` instead of `d = 1`. The nonblocking update of `d` happens in the NBA region of time 5, after the flip-flop has sampled `d` = 0. At time 15 the flip-flop samples 1, but `q` changes in the NBA region, after the `$display` in the Active region has printed the old value 0. At time 20, `q` is 1.

**P5.**

```systemverilog
module p5;
  logic clk = 0;
  always #5 clk = ~clk;
  cnt_if cif [3] (clk);
  for (genvar i = 0; i < 3; i++) begin : g
    counter dut (cif[i]);
  end
  virtual cnt_if v [3];
  initial begin
    v[0] = cif[0];  v[1] = cif[1];  v[2] = cif[2];
    foreach (v[i]) begin
      v[i].rst_n = 0;
      v[i].en    = (i != 1);
    end
    @(negedge clk);
    foreach (v[i]) v[i].rst_n = 1;
    repeat (3) @(negedge clk);
    v[2] = v[1];
    $display("%0d %0d %0d", v[0].count, v[1].count, v[2].count);
    $finish;
  end
endmodule
```

Answer: `3 0 0`. Counters 0 and 2 are enabled and count three edges (15, 25, 35); counter 1 is disabled. Before printing, handle `v[2]` is re-pointed to the instance that `v[1]` refers to, so the third value printed is counter 1's value, 0. Counter 2 still holds 3, but no handle refers to it any more.

**P6.** `tb_race.sv` of Section 4.1 prints `q` once. What are the possible outputs, and why?

Answer: `q = 0` or `q = 1`, depending on the simulator. The testbench changes `d` with a blocking assignment in the same time step and region in which the flip-flop samples it, so the order of the two processes decides the result.

## 6.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
class alu_driver;
  alu_if aif (clk);
endclass
```

An interface cannot be instantiated in a class. Declare a handle: `virtual alu_if vif;`.

**E2.**

```systemverilog
task alu_driver::send();
  @(vif.drv_cb);
  vif.drv_cb.a = 8'h10;
endtask
```

A clockvar cannot be assigned with `=`. Use `vif.drv_cb.a <= 8'h10;`.

**E3.**

```systemverilog
class alu_driver;
  virtual alu_if.DRV vif;
  task wait_two();
    ##2;
  endtask
endclass
```

`##N` requires a default clocking, which a class does not have. Use `repeat (2) @(vif.drv_cb);`.

**E4.**

```systemverilog
module counter_mp (cnt_mp_if.DUT cif);
  always_ff @(posedge cif.clk) cif.en <= 1'b1;
endmodule
```

`en` is an `input` in modport `DUT`; it cannot be written through this port.

**E5.**

```systemverilog
virtual cnt_if vif = new();
```

A virtual interface is not constructed. Assign an existing instance: `vif = cif;`.

**E6.**

```systemverilog
cnt_if cif [4] (clk);
initial
  for (int i = 0; i < 4; i++) cif[i].en = 0;
```

An array of interface instances cannot be indexed with a variable. Use constant indices, a generate loop, or an array of virtual interfaces.

**E7.**

```systemverilog
interface io_if;
  wire [7:0] data;
endinterface

class io_driver;
  virtual io_if vif;
  task put(bit [7:0] v);
    vif.data = v;
  endtask
endclass
```

`data` is a net and cannot be assigned procedurally. Add `logic [7:0] data_drv; logic data_oe; assign data = data_oe ? data_drv : 'z;` to the interface and assign those variables.

**E8.**

```systemverilog
task alu_driver::check();
  @(vif.drv_cb);
  if (vif.drv_cb.a == 8'd0) $display("a is zero");
endtask
```

`a` is an `output` of `drv_cb`, and an output clockvar cannot be read. Read it through a clocking block where it is an input (`mon_cb`), or declare it `inout` in the clocking block.

**E9.**

```systemverilog
mem_if #(.AW(16), .DW(32)) mif (clk);
virtual mem_if vif;
initial vif = mif;
```

Type mismatch. The handle has the default parameters; the instance has others. Declare `virtual mem_if #(.AW(16), .DW(32)) vif;`.

**E10.**

```systemverilog
class alu_driver;
  virtual alu_if.DRV vif;
  task idle();
    vif.valid_in = 1'b0;
  endtask
endclass
```

`valid_in` is not listed in modport `DRV`; only `drv_cb`, `clk` and `rst_n` are. Use `vif.drv_cb.valid_in <= 1'b0;`.

**E11.**

```systemverilog
package alu_tb_pkg;
  clocking cb @(posedge clk);
    input result;
  endclocking
endpackage
```

A clocking block cannot be declared in a package (or in a class). It belongs in the interface, a module or a program.

**E12.**

```systemverilog
module counter_mp (cnt_mp_if.DUT cif);  ...  endmodule
// ...
counter_mp dut (cif.TB);
```

The module header selects modport `DUT` and the instance selects `TB`. When both are given they must be the same modport.

### Run-time bugs (the code compiles)

**D1.**

```systemverilog
function alu_driver::new(virtual alu_if.DRV vif);
  vif = vif;
endfunction
```

The argument is assigned to itself; the class property stays `null`, and the first use of `vif` in `run()` is a fatal error. Write `this.vif = vif;`.

**D2.**

```systemverilog
forever begin
  @(posedge vif.clk);
  if (vif.mon_cb.valid_out) record(vif.mon_cb.result);
end
```

The loop waits on the raw clock but reads clocking block samples, which may not have been refreshed yet for this edge. Wait on `@(vif.mon_cb);`.

**D3.**

```systemverilog
task run();
  forever begin
    @(posedge vif.clk);
    vif.valid_in = 1;
    vif.a        = txn.a;
  end
endtask
```

Blocking assignments to DUT inputs at the active clock edge: a drive race. Whether the DUT sees the new values at this edge or the next depends on the simulator. Drive through the clocking block.

**D4.**

```systemverilog
clocking mon_cb @(posedge clk);
  default input #0;
  input valid_out, result;
endclocking
```

With `#0` the monitor samples after the DUT has updated its outputs, one cycle ahead of what a synchronous receiver would see. Use `#1step`.

**D5.**

```systemverilog
interface alu_if;
  logic clk = 0;
  always #5 clk = ~clk;
  ...
endinterface

alu_if in_if  ();
alu_if out_if ();
```

Each instance generates its own clock. The two clocks happen to be identical here, but they are separate signals with no guaranteed ordering between their edges, and they are not the DUT's clock. Generate the clock once in the top module and pass it to the interfaces as a port.

**D6.**

```systemverilog
task read(output logic [7:0] value);
  @(negedge vif.clk);
  vif.rd = 1;
  @(negedge vif.clk);
  value = vif.data;          // X in some bits
  vif.rd = 0;
endtask
```

In the bidirectional pattern of Section 5.3, X during a read means the testbench is still driving: an earlier `write` did not set `data_oe` back to 0, so both drivers are active.

**D7.**

```systemverilog
initial begin
  env = new(aif);
  fork env.run(); join_none
  aif.rst_n = 0;
  #100 aif.rst_n = 1;
end
```

The environment starts driving stimulus at time 0, while the DUT is still in reset, so the first transactions are lost and the scoreboard reports missing results. Apply and release reset first, or make the driver wait for `vif.rst_n` to be 1 before its first drive.

**D8.**

```systemverilog
task drive(alu_txn t);
  vif.drv_cb.valid_in <= 1'b1;
  vif.drv_cb.a        <= t.a;
  @(vif.drv_cb);
  vif.drv_cb.valid_in <= 1'b0;
endtask
```

The task does not synchronise to the clocking event before driving. If it is called between edges, the drives are deferred to the next event, and the `@(vif.drv_cb)` that follows wakes at that same event. `valid_in <= 0` is then requested for the same event as `valid_in <= 1`; the last drive wins and `valid_in` never goes high. Start the task with `@(vif.drv_cb);`.

## 6.5 Coding Exercises with Solutions

### Exercise 1: an interface for a FIFO

The synchronous FIFO used later in the course has the ports `clk`, `rst_n`, `wr_en`, `rd_en`, `din[7:0]`, `dout[7:0]`, `full` and `empty`. Write `fifo_if` with a driver clocking block, a monitor clocking block and modports `DUT`, `DRV` and `MON`, following the pattern of `alu_if`.

```systemverilog file=fifo_if.sv
interface fifo_if (input logic clk);

  logic       rst_n;
  logic       wr_en;
  logic       rd_en;
  logic [7:0] din;
  logic [7:0] dout;
  logic       full;
  logic       empty;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output wr_en, rd_en, din;
    input  dout, full, empty;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input wr_en, rd_en, din, dout, full, empty;
  endclocking

  modport DUT (input clk, rst_n, wr_en, rd_en, din, output dout, full, empty);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);

endinterface
```

The driver needs `full` and `empty` as inputs of its clocking block, because a FIFO driver must not write when the FIFO is full or read when it is empty.

### Exercise 2: push and pop through a virtual interface

Write a class `fifo_driver` with tasks `push(value)` and `pop(value)` that use `fifo_if` through its `DRV` modport. Push `11`, `22`, `33` (hex) into the FIFO below, pop three values and print them.

The FIFO design (reading takes one clock: `dout` holds the value after the edge at which `rd_en` was sampled):

```systemverilog file=sync_fifo.sv
module sync_fifo (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       wr_en,
  input  logic       rd_en,
  input  logic [7:0] din,
  output logic [7:0] dout,
  output logic       full,
  output logic       empty
);

  logic [7:0] mem [16];
  logic [3:0] wr_ptr, rd_ptr;
  logic [4:0] count;
  logic       do_wr, do_rd;

  assign full  = (count == 5'd16);
  assign empty = (count == 5'd0);
  assign do_wr = wr_en && !full;
  assign do_rd = rd_en && !empty;

  always_ff @(posedge clk)
    if (do_wr) mem[wr_ptr] <= din;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
      dout   <= '0;
    end
    else begin
      if (do_wr) wr_ptr <= wr_ptr + 1'b1;
      if (do_rd) begin
        dout   <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
      if      (do_wr && !do_rd) count <= count + 1'b1;
      else if (do_rd && !do_wr) count <= count - 1'b1;
    end
  end

endmodule
```

Solution. Compile `fifo_if.sv` and `sync_fifo.sv` first.

```systemverilog file=ex02_fifo_vif.sv
class fifo_driver;

  virtual fifo_if.DRV vif;

  function new(virtual fifo_if.DRV vif);
    this.vif = vif;
  endfunction

  task push(bit [7:0] value);
    @(vif.drv_cb);
    vif.drv_cb.wr_en <= 1'b1;
    vif.drv_cb.din   <= value;
    @(vif.drv_cb);                   // the FIFO stores the value at this edge
    vif.drv_cb.wr_en <= 1'b0;
  endtask

  task pop(output logic [7:0] value);
    @(vif.drv_cb);
    vif.drv_cb.rd_en <= 1'b1;
    @(vif.drv_cb);                   // the FIFO samples rd_en = 1 at this edge
    vif.drv_cb.rd_en <= 1'b0;
    @(vif.drv_cb);                   // dout, updated by that edge, is in the sample now
    value = vif.drv_cb.dout;
  endtask

endclass

module ex02_fifo_vif;

  logic clk = 0;
  always #5 clk = ~clk;

  fifo_if   fif (clk);
  sync_fifo dut (
    .clk   (clk),       .rst_n (fif.rst_n),
    .wr_en (fif.wr_en), .rd_en (fif.rd_en),
    .din   (fif.din),   .dout  (fif.dout),
    .full  (fif.full),  .empty (fif.empty)
  );

  fifo_driver drv;
  logic [7:0] value;

  initial begin
    fif.rst_n = 0;  fif.wr_en = 0;  fif.rd_en = 0;  fif.din = '0;
    drv = new(fif);
    repeat (2) @(negedge clk);
    fif.rst_n = 1;

    drv.push(8'h11);
    drv.push(8'h22);
    drv.push(8'h33);

    repeat (3) begin
      drv.pop(value);
      $display("[%0t] popped %h", $time, value);
    end

    @(fif.drv_cb);
    $display("[%0t] empty=%b full=%b", $time, fif.drv_cb.empty, fif.drv_cb.full);
    $finish;
  end

endmodule
```

```output
[105] popped 11
[135] popped 22
[165] popped 33
[175] empty=1 full=0
```

Timeline: reset is released at 20. Each `push` takes two clock edges; the three values are stored at the edges at 35, 55 and 75. The first `pop` drives `rd_en` after the edge at 85, the FIFO reads at the edge at 95, and the value is in the clocking block's sample at the edge at 105. The need for the third `@(vif.drv_cb)` in `pop` is the main lesson: `dout` changes **at** the edge where `rd_en` is sampled, and a `#1step` sample taken at that edge still holds the old value.

### Exercise 3: a parameterised interface and a matching virtual interface

Write a parameterised memory interface `mem_if #(AW, DW)`, a RAM that uses it, and a driver class for a memory with a 6-bit address and 16-bit data. Write two locations, read them back, and read one location that was never written.

```systemverilog file=ex03_param_if.sv
interface mem_if #(parameter int AW = 4, parameter int DW = 8) (input logic clk);
  logic          we;
  logic [AW-1:0] addr;
  logic [DW-1:0] wdata;
  logic [DW-1:0] rdata;
endinterface

module ram #(parameter int AW = 4, parameter int DW = 8) (mem_if mif);
  logic [DW-1:0] mem [2**AW];
  always_ff @(posedge mif.clk) begin
    if (mif.we) mem[mif.addr] <= mif.wdata;
    mif.rdata <= mem[mif.addr];
  end
endmodule

// One name for the exact interface type this driver works with
typedef virtual mem_if #(.AW(6), .DW(16)) mem_vif_t;

class mem_driver;

  mem_vif_t vif;

  function new(mem_vif_t vif);
    this.vif = vif;
  endfunction

  task write(bit [5:0] addr, bit [15:0] data);
    @(negedge vif.clk);
    vif.we    = 1;
    vif.addr  = addr;
    vif.wdata = data;
    @(negedge vif.clk);
    vif.we    = 0;
  endtask

  task read(bit [5:0] addr, output logic [15:0] data);
    @(negedge vif.clk);
    vif.addr = addr;
    @(negedge vif.clk);
    data = vif.rdata;
  endtask

endclass

module ex03_param_if;

  logic clk = 0;
  always #5 clk = ~clk;

  mem_if #(.AW(6), .DW(16)) mif (clk);
  ram    #(.AW(6), .DW(16)) dut (mif);

  mem_driver   drv;
  logic [15:0] data;

  initial begin
    mif.we = 0;
    drv = new(mif);

    drv.write(6'd40, 16'hBEEF);
    drv.write(6'd41, 16'h1234);

    drv.read(6'd40, data);  $display("[%0t] mem[40] = %h", $time, data);
    drv.read(6'd41, data);  $display("[%0t] mem[41] = %h", $time, data);
    drv.read(6'd5,  data);  $display("[%0t] mem[5]  = %h", $time, data);
    $finish;
  end

endmodule
```

```output
[60] mem[40] = beef
[80] mem[41] = 1234
[100] mem[5]  = xxxx
```

The `typedef` gives the long virtual interface type a short name and guarantees that the property and the constructor argument have the same parameters. Location 5 was never written, and because the memory and the `data` variable are four-state, the read returns X instead of a misleading 0. This example drives on the falling edge, without a clocking block, to keep the focus on the parameters.

### Exercise 4: a self-checking monitor for the ALU

Using `alu_if` and the `alu_driver` class from Section 5.2, write a class `alu_checker` that watches the ALU through the `MON` modport, computes the expected result of every operation and prints PASS or FAIL. Drive `255 + 1`, `8'h80` shifted left, NOT of `8'h0F` and `9` shifted right.

Compile in this order: `alu_pkg.sv`, `alu.sv`, `alu_if.sv`, `alu_vif_classes.sv`, then this file.

```systemverilog file=ex04_alu_checker.sv
import alu_pkg::*;

class alu_checker;

  virtual alu_if.MON vif;
  int unsigned pass_cnt, fail_cnt;

  function new(virtual alu_if.MON vif);
    this.vif = vif;
  endfunction

  // Reference model: the same widths as the DUT (9-bit result)
  function logic [8:0] model(logic [7:0] a, logic [7:0] b, alu_op_e op);
    case (op)
      ALU_ADD: return {1'b0, a} + {1'b0, b};
      ALU_SUB: return {1'b0, a} - {1'b0, b};
      ALU_AND: return {1'b0, a & b};
      ALU_OR : return {1'b0, a | b};
      ALU_XOR: return {1'b0, a ^ b};
      ALU_NOT: return {1'b0, ~a};
      ALU_SHL: return {a, 1'b0};
      ALU_SHR: return {2'b00, a[7:1]};
      default: return 'x;
    endcase
  endfunction

  task run();
    logic [7:0] a, b;
    alu_op_e    op;
    logic [8:0] expected;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid_out) begin
        expected = model(a, b, op);
        if (vif.mon_cb.result !== expected) begin
          fail_cnt++;
          $display("[%0t] FAIL %s a=%0d b=%0d result=%0d expected=%0d",
                   $time, op.name(), a, b, vif.mon_cb.result, expected);
        end
        else begin
          pass_cnt++;
          $display("[%0t] PASS %s a=%0d b=%0d result=%0d",
                   $time, op.name(), a, b, vif.mon_cb.result);
        end
      end
      if (vif.mon_cb.valid_in) begin
        a  = vif.mon_cb.a;
        b  = vif.mon_cb.b;
        op = vif.mon_cb.op;
      end
    end
  endtask

endclass

module ex04_alu_checker;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);
  alu dut (
    .clk       (clk),           .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),  .a         (aif.a),
    .b         (aif.b),         .op        (aif.op),
    .valid_out (aif.valid_out), .result    (aif.result)
  );

  alu_driver  drv;
  alu_checker chk;

  initial begin
    aif.rst_n = 0;  aif.valid_in = 0;  aif.a = '0;  aif.b = '0;  aif.op = ALU_ADD;
    drv = new(aif);
    chk = new(aif);
    repeat (2) @(negedge clk);
    aif.rst_n = 1;

    fork
      chk.run();
    join_none

    drv.drive(8'd255, 8'd1, ALU_ADD);
    drv.drive(8'h80,  8'd0, ALU_SHL);
    drv.drive(8'h0F,  8'd0, ALU_NOT);
    drv.drive(8'd9,   8'd0, ALU_SHR);

    repeat (2) @(posedge clk);
    $display("[%0t] checker: %0d passed, %0d failed", $time, chk.pass_cnt, chk.fail_cnt);
    $finish;
  end

endmodule
```

```output
[35] DRV: ALU_ADD a=255 b=1 accepted by the DUT
[45] PASS ALU_ADD a=255 b=1 result=256
[55] DRV: ALU_SHL a=128 b=0 accepted by the DUT
[65] PASS ALU_SHL a=128 b=0 result=256
[75] DRV: ALU_NOT a=15 b=0 accepted by the DUT
[85] PASS ALU_NOT a=15 b=0 result=240
[95] DRV: ALU_SHR a=9 b=0 accepted by the DUT
[105] PASS ALU_SHR a=9 b=0 result=4
[115] checker: 4 passed, 0 failed
```

The `DRV` lines come from the `alu_driver` class of Section 5.2. The comparison uses `!==` so that an X on `result` would be reported (Module 1, Section 4.5). This class is a monitor and a scoreboard merged into one; Module 9 separates them and connects them with a mailbox.

### Further practice (no solutions given)

1. Add an `apply_reset(int unsigned cycles)` task to `alu_if` that drives `rst_n` directly, and call it from a class through the virtual interface. Why can this task not use `drv_cb`?
2. Change the output skew of `drv_cb` from `#1` to `#0` and to `#4`. Predict whether the log of `tb_alu_vif.sv` changes, then run it. What is the largest output skew that still works with a clock period of 10?
3. Change the input skew of `mon_cb` to `#0`. Predict the new log of `tb_alu_vif.sv` line by line, then run it.
4. Extend `fifo_driver::push` so that it waits while `vif.drv_cb.full` is 1 before writing. Test it by pushing 18 values into the 16-entry FIFO while a second thread pops slowly.
5. Create two ALUs with an interface array `alu_if aif [2] (clk);`, an array of two virtual interfaces and two `alu_driver` objects, and drive different operations into each.
6. Rewrite `tb_bidir.sv` so that the bus is driven and sampled through a clocking block with `inout data`.
7. Write an interface for an APB-like bus (`psel`, `penable`, `pwrite`, `paddr`, `pwdata`, `prdata`, `pready`) with modports for the requester, the completer and a monitor, and two clocking blocks.

## 6.6 Concepts You Must Understand Before Moving Forward

Do not start Module 9 until you can answer each of these without looking at the notes.

**Interfaces**

- [ ] I can explain three problems of port-by-port connections that an interface solves.
- [ ] I can write an interface with a clock port, instantiate it and connect a DUT that has ordinary ports.
- [ ] I can list what an interface may contain and the one thing it may not.
- [ ] I can explain why the clock is usually generated outside the bus interface.
- [ ] I can apply the single-driver rule to interface signals and say when a `wire` is needed.

**Modports and arrays**

- [ ] I can write DUT, driver and monitor modports and get the directions right from each side.
- [ ] I can state what modports enforce and two things they do not.
- [ ] I can name the three places where a modport is selected.
- [ ] I can explain why an interface array needs a constant index and how to work around it.

**Virtual interfaces**

- [ ] I can explain why a class cannot instantiate or directly reference an interface.
- [ ] I can declare a virtual interface, pass it through a constructor and use it to drive and sample.
- [ ] I can list four causes of a null virtual interface error.
- [ ] I can explain the three meanings of the keyword `virtual`.
- [ ] I can describe how the handle travels from the top module to the driver.

**Clocking blocks**

- [ ] I can describe the drive race and the sample race.
- [ ] I can list the scheduler regions in order and say what happens in Preponed, Active, NBA, Observed and Re-NBA.
- [ ] I can state the default skews and explain `#1step` versus `#0` for an input.
- [ ] I can write `@(vif.cb)`, a sample and a synchronous drive, and say when each takes effect.
- [ ] I can explain why `##N` does not work in a class and what to write instead.
- [ ] I can explain why reset is kept out of the clocking block.
- [ ] I can write the complete `alu_if` from memory.
- [ ] I can explain the pattern for driving a bidirectional signal from a class.

## 6.7 What Comes Next

Module 9 builds the complete layered testbench for the ALU. It uses `alu_if` exactly as defined in Section 5.1. The `alu_driver` and `alu_monitor` of Section 5.2 gain a `run()` task and mailboxes: the generator sends `alu_txn` objects to the driver through `gen2drv_mbx`, and the monitor sends observed transactions to the scoreboard through `mon2scb_mbx`. The environment creates all components and passes the virtual interface to them through their constructors, as described in Section 3.6, and `tb_top` instantiates the clock, the interface and the DUT and starts the test.
