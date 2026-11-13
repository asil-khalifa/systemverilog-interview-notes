# Part 3: Virtual Interfaces

## 3.1 The Problem: A Class Cannot Reach a Physical Interface

### In plain English

Everything so far used **modules** to drive the interface. But the testbench of this course, and every modern testbench, is built from **classes**: the driver and the monitor are objects created with `new()` while the simulation runs (Module 4). The interface, on the other hand, is part of the design hierarchy and is created before the simulation starts.

So there are two worlds:

| | Static world | Dynamic world |
|---|---|---|
| Contains | Modules, interfaces, the DUT, wires | Class objects: transactions, generator, driver, monitor, scoreboard |
| Created | At elaboration, before time 0 | At run time, by calling `new()` |
| Lifetime | The whole simulation | From `new()` until no handle refers to the object |
| Number of copies | Fixed by the source code | Decided while the simulation runs |
| Connected by | Ports | Handles |

The driver class lives in the dynamic world. The DUT pins live in the static world. The driver must wiggle those pins. How does it reach them?

### Three things that do not work

**Attempt 1: instantiate the interface inside the class.**

```systemverilog
class cnt_driver;
  cnt_if cif (clk);          // ILLEGAL: an interface cannot be instantiated in a class
endclass
```

An interface instance is a piece of hierarchy that must exist at elaboration so that it can be wired to the DUT. A class object does not exist at elaboration, and there could be zero or a thousand objects of the class. The language forbids this.

**Attempt 2: give the class ports.**

A module receives an interface through a port. A class has no ports. Its only inputs are the arguments of its methods and constructor, and an interface instance is not a value that can be passed as an ordinary argument.

**Attempt 3: use the hierarchical name from inside the class.**

```systemverilog
class cnt_driver;
  task run();
    tb_vif_basic.cif.en = 1;     // hard-coded path to one particular testbench
  endtask
endclass
```

| Problem with the hierarchical name | Explanation |
|---|---|
| Not allowed in a package | Classes are normally declared in a package, and code in a package may not contain hierarchical references to design instances |
| Not reusable | The class works only in a testbench whose top module and instance have exactly these names. At chip level the path is different |
| One instance only | Two drivers for two buses would need two different classes, identical except for the path |
| The path is fixed when the code is compiled | A test cannot choose at run time which interface a driver should use |

### What is needed

The class needs a **variable** that can be made to refer to an interface instance: set from outside, when the object is built, to whichever instance this object should work with. That variable is a virtual interface.

### Interview questions

**Q1. Why can a class not instantiate an interface?**
An interface instance is a static design element: it is created at elaboration and must be physically connected to the DUT. A class object is dynamic: it is created at run time by `new()`, and any number of objects may exist. A static hierarchy element cannot be created inside a dynamic object, so the language does not allow it.

**Q2. Why not access the interface from the class with a hierarchical path?**
Code inside a package cannot use hierarchical references, and even where it compiles, the class becomes tied to one testbench hierarchy and one interface instance. It cannot be reused at a different level or for a second instance of the bus.

## 3.2 What Is a Virtual Interface?

### In plain English

A virtual interface is a **handle to an interface instance**: a variable that stores "which interface am I talking to". It is not an interface and it contains no signals. Once it has been pointed at a real interface instance, writing `vif.en = 1` changes the `en` signal of that instance.

The interface instance in the top module is often called the **physical interface** (or actual interface), and the handle is the **virtual interface**.

### Technical definition

A virtual interface is a variable, declared with the keyword `virtual` followed by an interface type, that holds a reference to an instance of that interface type. Its default value is `null`. It can be assigned an interface instance or another virtual interface of the same type, compared with `==` and `!=`, passed as an argument to tasks and functions, and stored as a class property. Through it, all signals, clocking blocks, tasks and functions of the referenced instance can be accessed.

### How it works internally

```text
      STATIC  (elaboration)                         DYNAMIC  (run time)

      module tb_vif_basic                           object of class cnt_driver
     +----------------------------+                +----------------------+
     |                            |                |                      |
     |  cnt_if cif (clk);         |    reference   |  virtual cnt_if vif  |
     |  +------------------+ <----+----------------+----o                 |
     |  | rst_n            |      |                |                      |
     |  | en               |      |                |  task count_for();   |
     |  | count            |      |                |    vif.en = 1; ------+--> writes cif.en
     |  +--------+---------+      |                |                      |
     |           |                |                +----------------------+
     |  counter dut (cif);        |
     +----------------------------+

      Step 1 (elaboration): cif and dut are built and wired together.
      Step 2 (run time)   : the object is created; vif is null.
      Step 3 (run time)   : vif = cif;   the handle now refers to the instance.
      Step 4 (run time)   : vif.en = 1;  is exactly the same as  cif.en = 1;
```

- The handle stores only a reference. No signal is copied, and nothing is delayed.
- Several handles may refer to the same instance. A change made through one is seen through all, because there is only one set of signals.
- One handle can be re-pointed to a different instance of the same interface type while the simulation runs.

### Why the word "virtual"?

The word is used in three unrelated places in SystemVerilog. Interviewers like to check that you do not confuse them.

| Construct | Meaning of `virtual` | Module |
|---|---|---|
| `virtual interface` (`virtual cnt_if vif;`) | A handle that refers to an interface instance | 8 |
| `virtual class` | An abstract class: it cannot be constructed, only extended | 4 |
| `virtual function` / `virtual task` | A method that can be overridden, with the call resolved by the type of the object at run time | 4 |

### Physical interface versus virtual interface

| Property | Interface instance (physical) | Virtual interface |
|---|---|---|
| What it is | A design element containing the signals | A variable holding a reference |
| Declared as | `cnt_if cif (clk);` | `virtual cnt_if vif;` |
| Declared where | In a module or in another interface | In a class, or as a variable in a module, program, task or function |
| Created | At elaboration | When its variable or object is created |
| Initial state | Exists, signals are X | `null`: refers to nothing |
| Contains signals | Yes | No |
| Can be changed at run time to refer to something else | No | Yes |
| Can be passed as a task/function argument | No | Yes |
| Can be a class property | No | Yes |
| Can be stored in dynamic arrays, queues, associative arrays | No | Yes |
| Can be a module port | Yes (interface port) | No |
| Synthesizable | Yes | No |

### Interview questions

**Q1. What is a virtual interface?**
A variable that holds a reference (handle) to an instance of an interface. It lets dynamic, class-based code access the signals of a static interface instance.

**Q2. Why is it needed?**
Classes cannot have ports and cannot instantiate interfaces, and hierarchical paths make them non-reusable. A virtual interface is a property of the class that is assigned from outside, so the same driver or monitor class works with any instance of the interface, at any level of hierarchy.

**Q3. Does a virtual interface contain signals?**
No. It is only a reference. The signals exist once, in the interface instance.

**Q4. What is the difference between an interface and a virtual interface?**
An interface instance is a static design element that holds the signals. A virtual interface is a dynamic handle that points to such an instance; it is `null` until assigned and can be re-assigned at run time.

**Q5. What are the three uses of the keyword `virtual`?**
Virtual interface (a handle to an interface instance), virtual class (an abstract class), and virtual method (a method that is overridden polymorphically).

## 3.3 Virtual Interface Declaration

### Syntax

```systemverilog
virtual <interface_type> <handle_name>;                      // the usual form
virtual interface <interface_type> <handle_name>;         // keyword interface is optional
virtual <interface_type>.<modport> <handle_name>;            // restricted to one modport
virtual <interface_type> #(<parameter values>) <handle_name>; // parameterised interface
```

### Examples

```systemverilog
class cnt_driver;
  virtual cnt_if vif;                    // class property (the most common place)
endclass

class alu_driver;
  virtual alu_if.DRV vif;                // only what modport DRV allows is accessible
endclass

class mem_driver;
  virtual mem_if #(.AW(16), .DW(32)) vif; // parameters must match the instance exactly
endclass

module tb;
  virtual cnt_if vif_a;                  // a variable in a module
  virtual cnt_if vifs [4];               // an array of handles
  virtual cnt_if vif_q [$];              // a queue of handles

  task automatic pulse_enable(virtual cnt_if v);   // a task argument
    v.en = 1;
    @(negedge v.clk);
    v.en = 0;
  endtask
endmodule
```

### Where a virtual interface may and may not be used

| Allowed | Not allowed |
|---|---|
| Property of a class | Port of a module or interface |
| Variable in a module, program, task, function or procedural block | Member of a union |
| Argument and return value of tasks and functions | Left-hand side of a continuous assignment |
| Element of fixed, dynamic and associative arrays and queues | Any synthesizable code |
| Member of a struct or of another class (for example a configuration object) | |

The interface type must already be known to the compiler, so the file that declares the interface is compiled before the classes that refer to it.

> **Key point:** By convention the handle is named `vif` in every class of a testbench. This course always uses that name.

### Interview questions

**Q1. How do you declare a virtual interface?**
`virtual <interface_name> <handle>;`, for example `virtual alu_if vif;`. The keyword `interface` may be written after `virtual` but is optional.

**Q2. Can a virtual interface be declared with a modport?**
Yes: `virtual alu_if.DRV vif;`. Access through the handle is then limited to what that modport allows.

**Q3. What is the default value of a virtual interface?**
`null`.

## 3.4 Assigning a Physical Interface to a Virtual Interface

### The legal assignments

```systemverilog
virtual cnt_if vif, vif2;

vif  = cif;          // an interface instance
vif  = cif_arr[1];   // an element of an interface array (constant index)
vif2 = vif;          // another virtual interface of the same type
vif  = null;         // refers to nothing again

if (vif == null) ...     // comparison with null
if (vif == vif2) ...     // do both handles refer to the same instance?
```

| Right-hand side | Result |
|---|---|
| An interface instance of the same type (and same parameter values) | The handle refers to that instance |
| Another virtual interface of the same type | Both handles refer to the same instance |
| `null` | The handle refers to nothing |
| An instance of a different interface type, or with different parameters | Compile error |

### Where the assignment happens

The assignment must be written where the interface instance is **visible by name**: in the module that instantiates it, which is the top-level testbench module. This is the single point at which the static world is handed to the dynamic world.

```text
   tb_top (module)                      classes
   ----------------------------------------------------------------
   alu_if aif (clk);                    
   alu    dut (... aif.a ...);          

   initial begin
     test = new(aif);        ------->   alu_test::new(virtual alu_if vif)
                                           env = new(vif);      ------>  alu_env::new(vif)
                                                                            drv = new(vif);
                                                                            mon = new(vif);
     test.run();
   end
```

The handle is passed down from the top module through the constructors until it reaches the components that need it. Section 3.6 lists the alternatives.

### Modports in the assignment

| Handle declared as | May be assigned |
|---|---|
| `virtual alu_if vif;` | An instance (`aif`) or a handle without a modport |
| `virtual alu_if.DRV vif;` | An instance (`aif`), a handle without a modport, the same modport of an instance (`aif.DRV`), or a handle with the same modport |

A handle that is restricted to a modport cannot be assigned to an unrestricted handle, and cannot be assigned to a handle with a different modport: that would remove or change the restriction.

> **Interview trap:** "Where do you connect the virtual interface to the physical interface?" In the top-level module, because that is the only place where the interface instance exists by name. The class never mentions the instance; it only receives a handle.

### Interview questions

**Q1. How is a physical interface assigned to a virtual interface?**
With an ordinary assignment, `vif = aif;`, made in the module where the instance `aif` is declared, or by passing `aif` as the actual argument for a virtual interface argument of a constructor or method.

**Q2. Can two virtual interfaces refer to the same instance?**
Yes. That is the normal situation: the driver and the monitor each hold a handle to the same interface instance.

**Q3. Can a virtual interface be changed during simulation?**
Yes. It is a variable. It can be assigned another instance of the same interface type, or `null`, at any time.

## 3.5 Accessing Interface Signals from Classes

### Syntax

Once the handle is assigned, everything inside the interface is reached through it with the dot operator:

```systemverilog
vif.en = 1;                    // write a signal
value = vif.count;             // read a signal
@(posedge vif.clk);            // wait for an edge of a signal
@(negedge vif.rst_n);
wait (vif.count == 4'd9);      // wait for a condition on a signal
vif.apply_reset(2);            // call a task of the interface
vif.drv_cb.a <= 8'h10;         // drive through a clocking block (Part 4)
@(vif.drv_cb);                 // wait for a clocking block event (Part 4)
```

### Complete example: a class that drives the counter

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_vif_basic.sv
class cnt_driver;

  virtual cnt_if vif;                       // handle to the counter interface

  function new(virtual cnt_if vif);
    this.vif = vif;                         // store the handle passed in by the creator
  endfunction

  task reset();
    vif.rst_n = 0;
    vif.en    = 0;
    @(negedge vif.clk);
    vif.rst_n = 1;
  endtask

  task count_for(int unsigned cycles);
    vif.en = 1;
    repeat (cycles) @(negedge vif.clk);
    vif.en = 0;
  endtask

endclass

module tb_vif_basic;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);                        // physical interface
  counter dut (cif);

  cnt_driver drv;                           // class handle (null until new)

  initial begin
    drv = new(cif);                         // the physical interface is handed to the class

    drv.reset();
    drv.count_for(3);
    $display("[%0t] count = %0d", $time, cif.count);

    drv.count_for(2);
    $display("[%0t] count = %0d (through the handle: %0d)",
             $time, cif.count, drv.vif.count);
    $finish;
  end

endmodule
```

```output
[40] count = 3
[60] count = 5 (through the handle: 5)
```

**Line by line**

| Line | Explanation |
|---|---|
| `virtual cnt_if vif;` | The class has a property that can refer to any instance of `cnt_if`. The class contains no testbench path and no instance name. |
| `function new(virtual cnt_if vif);` | The constructor takes a virtual interface as its argument. |
| `this.vif = vif;` | The argument and the property have the same name. `this.vif` is the property, plain `vif` is the argument (Module 4). |
| `vif.rst_n = 0;` | A procedural assignment to a signal of whichever instance the handle refers to. |
| `@(negedge vif.clk);` | The class waits for a clock edge through the handle. The clock is reachable because it is a port of the interface. |
| `cnt_driver drv;` | A class handle in the module. It is `null` at this point. |
| `drv = new(cif);` | Creates the object and passes the interface **instance** `cif` where the constructor expects a virtual interface. This is the assignment "physical to virtual". |
| `drv.vif.count` | From the module, the same signal can be read through the object's handle. It is the same variable as `cif.count`. |

**Execution flow**

| Time | Event |
|---|---|
| 0 | The object is created. `reset()` drives `rst_n` = 0 and `en` = 0. |
| 10 | Falling edge: `reset()` releases the reset and returns. `count_for(3)` sets `en` = 1. |
| 15, 25, 35 | Rising edges: `count` = 1, 2, 3. |
| 40 | Third falling edge: `en` = 0, `count_for` returns, the module prints `count = 3`. `count_for(2)` sets `en` = 1 again. |
| 45, 55 | Rising edges: `count` = 4, 5. |
| 60 | Second falling edge: `en` = 0, the module prints `count = 5`. |

Compare this class with the module `cnt_stim` of Part 2. The code inside is nearly the same. The difference is that the class is not wired to anything: it works with whatever interface instance it is given.

### What can be done through a virtual interface

| Operation | Example | Notes |
|---|---|---|
| Read a variable or a net | `x = vif.count;` | |
| Write a variable | `vif.en = 1;` or `vif.en <= 1;` | Blocking or nonblocking procedural assignment |
| Write a net (`wire`) | **Not allowed** | A net cannot be assigned procedurally. Use the pattern of Section 5.3 |
| Wait for an event | `@(posedge vif.clk);` `@(vif.count);` | |
| Call a task or function of the interface | `vif.apply_reset(2);` | |
| Use a clocking block | `@(vif.drv_cb); vif.drv_cb.a <= 1;` | Part 4 |

> **Common mistake:** Writing `vif = new();`. A virtual interface is not a class handle; there is nothing to construct. It can only be assigned an existing interface instance or another virtual interface.

> **Common mistake:** Declaring the handle with the wrong keyword order or without `virtual`: `cnt_if vif;` inside a class is an attempt to instantiate an interface, which is illegal.

### Interview questions

**Q1. How does a class access DUT signals?**
The class has a virtual interface property. The top module assigns the interface instance to it (usually through the constructor). The class then reads and writes the signals as `vif.<signal>`.

**Q2. How does a class wait for a clock edge?**
`@(posedge vif.clk);`, or `@(vif.<clocking_block>);` when a clocking block is used.

**Q3. Can a class assign a `wire` in the interface through a virtual interface?**
No. Procedural assignment to a net is illegal. The class assigns a `logic` variable in the interface, and a continuous assignment in the interface drives the net from that variable.

## 3.6 Passing Interface Handles to Classes

There are several ways to get the handle from the top module into the object that needs it. All of them are in use.

### Method 1: constructor argument (used in this course)

```systemverilog
class alu_driver;
  virtual alu_if.DRV vif;
  function new(virtual alu_if.DRV vif);
    this.vif = vif;
  endfunction
endclass

class alu_env;
  virtual alu_if vif;
  alu_driver     drv;
  alu_monitor    mon;

  function new(virtual alu_if vif);
    this.vif = vif;
    drv = new(vif);          // the environment passes the handle down
    mon = new(vif);
  endfunction
endclass

// in tb_top:
//   alu_env env;
//   initial begin  env = new(aif);  ...  end
```

The object cannot exist without a handle, so it is hard to forget.

### Method 2: assign the property directly after construction

```systemverilog
drv     = new();
drv.vif = aif;              // set from tb_top, or from the environment
```

Simple, but nothing forces the assignment to happen, and the property must be public.

### Method 3: a set method

```systemverilog
class alu_monitor;
  protected virtual alu_if.MON vif;
  function void set_vif(virtual alu_if.MON vif);
    this.vif = vif;
  endfunction
endclass
```

Keeps the property protected and gives one place for checks.

### Method 4: a configuration object

```systemverilog
class alu_config;
  virtual alu_if vif;
  int unsigned   num_txns = 20;
endclass
```

One object carries the handle together with the other settings of the testbench. Every component receives the configuration object and takes `cfg.vif` from it. When a second interface is added, only the configuration class changes, not every constructor.

### Method 5: a central database (UVM, awareness only)

```systemverilog
// in tb_top:
uvm_config_db #(virtual alu_if)::set(null, "*", "vif", aif);

// in the driver's build_phase:
if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
  `uvm_fatal("NOVIF", "virtual interface not set")
```

The top module stores the handle under a name; any component fetches it by that name. No constructor has to pass it along. Module 11 introduces UVM.

### Comparison

| Method | Advantage | Disadvantage |
|---|---|---|
| Constructor argument | The object is never without its handle | Every level between top and component must pass it on |
| Direct assignment | Shortest | Easy to forget; exposes the property |
| Set method | Encapsulation; a place for checks | Easy to forget to call |
| Configuration object | Scales to many interfaces and settings | One more class |
| `uvm_config_db` | No passing through intermediate levels | UVM only; a wrong string name is found only at run time |

### Interview questions

**Q1. How do you pass an interface to a class?**
Declare a virtual interface property in the class and give it a value from outside: most commonly as a constructor argument, otherwise by direct assignment, a set method, a configuration object, or in UVM through `uvm_config_db`.

**Q2. How does the virtual interface travel from the top module to the driver in a layered testbench?**
The top module passes the interface instance to the test (or environment) constructor. The environment stores it and passes it to the constructors of the driver and the monitor. Each component keeps its own copy of the handle; all copies refer to the same instance.

**Q3. Why is a virtual interface not passed through a mailbox like a transaction?**
It could be, since it is a variable, but it is configuration, not data. It is set once when the testbench is built, before any component runs.

## 3.7 The Null Virtual Interface Error

### What happens

A virtual interface that has not been assigned is `null`. Using it to read a signal, write a signal or wait for an event is a fatal **run-time** error: the simulator reports a null virtual interface (null pointer) dereference with the file and line number, and stops. The compiler cannot detect it, because the assignment happens at run time.

```systemverilog
class cnt_driver;
  virtual cnt_if vif;
  task run();
    vif.en = 1;            // run-time error if vif was never assigned
  endtask
endclass

module tb;
  cnt_driver drv;
  initial begin
    drv = new();           // nobody set drv.vif
    drv.run();             // fatal error here
  end
endmodule
```

### Typical causes

| Cause | Fix |
|---|---|
| The handle was never passed in | Pass it through the constructor so that it cannot be forgotten |
| The component started running before the handle was set | Build and connect everything first, then start `run()` |
| The constructor argument has the same name as the property and `this.` was forgotten: `vif = vif;` | Write `this.vif = vif;` |
| The environment received the handle but did not pass it on to a sub-component | Pass it in every `new(...)` call |
| A different object was configured than the one that runs | Check that the handle of the object in use is the one that was set |

### Defensive check

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_vif_null.sv
class cnt_user;

  virtual cnt_if vif;

  function void set_vif(virtual cnt_if vif);
    this.vif = vif;
  endfunction

  function bit is_connected();
    return (vif != null);
  endfunction

  task enable();
    if (vif == null) begin
      $display("[%0t] ERROR: vif is null, cannot drive", $time);
      return;
    end
    vif.en = 1;
    $display("[%0t] en driven to 1", $time);
  endtask

endclass

module tb_vif_null;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);
  counter dut (cif);

  cnt_user u;

  initial begin
    u = new();
    $display("connected = %b", u.is_connected());
    u.enable();

    u.set_vif(cif);
    $display("connected = %b", u.is_connected());
    u.enable();
    $finish;
  end

endmodule
```

```output
connected = 0
[0] ERROR: vif is null, cannot drive
connected = 1
[0] en driven to 1
```

**Line by line**

| Line | Explanation |
|---|---|
| `return (vif != null);` | A virtual interface can be compared with `null`, like a class handle. |
| `if (vif == null) begin ... return; end` | The task checks the handle before using it and reports a clear message instead of letting the simulator crash. In a real testbench this would be `$fatal`. |
| `u = new();` | The object exists but its `vif` is still `null`. |
| `u.set_vif(cif);` | Now the handle refers to `cif`, and the second call to `enable()` drives the signal. |

> **Interview trap:** "Your simulation stops at time 0 with a null object access in the driver. What do you check?" Two handles can be null: the class handle of the driver itself (nobody called `new`), and the virtual interface inside the driver (nobody assigned it). The message normally names the line; if the line is `vif.something`, the virtual interface was not connected. The classic root cause is `vif = vif;` in the constructor, without `this.`.

### Interview questions

**Q1. What happens when a null virtual interface is used?**
A fatal run-time error (null handle dereference) at the statement that uses it. It is not caught at compile time.

**Q2. How do you avoid it?**
Pass the interface through the constructor, connect all handles before starting any component, and check `vif != null` (with `$fatal` on failure) at the beginning of the component's `run()` task.

## 3.8 Arrays of Virtual Interfaces

### In plain English

Section 2.7 showed that an array of interface **instances** cannot be indexed with a variable. A virtual interface is an ordinary variable, so an **array of virtual interfaces** is an ordinary array: it can be indexed with a variable, looped over with `foreach`, and passed to a class. The usual pattern is to copy the instances into such an array once, and use the array from then on.

### Syntax

```systemverilog
cnt_if         cif  [2] (clk);     // array of instances  (static, constant index)
virtual cnt_if vifs [2];           // array of handles    (ordinary variables)

initial begin
  vifs[0] = cif[0];                // constant indices on the right-hand side
  vifs[1] = cif[1];
end
```

For many elements, a generate loop does the copying:

```systemverilog
for (genvar i = 0; i < 2; i++) begin : g_vif
  initial vifs[i] = cif[i];        // i is a constant inside each generated block
end
```

### Complete example

Compile `counter_dut.sv` first, then this file.

```systemverilog file=tb_vif_array.sv
module tb_vif_array;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if cif [2] (clk);

  for (genvar i = 0; i < 2; i++) begin : g_dut
    counter dut (cif[i]);
  end

  virtual cnt_if vifs [2];                 // one handle per interface instance

  initial begin
    vifs[0] = cif[0];
    vifs[1] = cif[1];

    foreach (vifs[i]) begin                // a variable index is fine on the handles
      vifs[i].rst_n = 0;
      vifs[i].en    = 0;
    end
    @(negedge clk);
    foreach (vifs[i]) vifs[i].rst_n = 1;

    vifs[0].en = 1;
    repeat (3) @(negedge clk);
    vifs[1].en = 1;
    repeat (2) @(negedge clk);

    foreach (vifs[i])
      $display("[%0t] counter %0d = %0d", $time, i, vifs[i].count);
    $finish;
  end

endmodule
```

```output
[60] counter 0 = 5
[60] counter 1 = 2
```

**Line by line**

| Line | Explanation |
|---|---|
| `virtual cnt_if vifs [2];` | A fixed-size array of two handles. Both start as `null`. |
| `vifs[0] = cif[0]; vifs[1] = cif[1];` | Each handle is pointed at one instance. The indices on `cif` are constants, as required. |
| `foreach (vifs[i]) vifs[i].rst_n = 0;` | The same statement is applied to every bus. This loop would be illegal on `cif[i]` directly. |
| `vifs[i].count` | Reads the counter of bus `i`. |

**Execution flow**

| Time | Counter 0 | Counter 1 |
|---|---|---|
| 0 to 10 | Reset | Reset |
| 10 | Reset released; `en` = 1 | Reset released; `en` = 0 |
| 15, 25, 35 | 1, 2, 3 | 0 |
| 40 | | `en` = 1 |
| 45, 55 | 4, 5 | 1, 2 |
| 60 | Printed: 5 | Printed: 2 |

> **Verification application:** An environment for a design with N identical ports holds `virtual port_if vifs[N]` and an array of N agents. In a loop it creates agent `i` and gives it `vifs[i]`. Nothing in the agent, driver or monitor classes knows how many ports exist.

### Interview questions

**Q1. How do you drive several instances of an interface from one loop?**
Declare an array of virtual interfaces, assign each element one interface instance (with constant indices or in a generate loop), and loop over the array of handles.

**Q2. Why can an array of virtual interfaces be indexed with a variable when an array of interfaces cannot?**
An array of interfaces is a set of hierarchy instances, and hierarchical names need constant indices. An array of virtual interfaces is an array of variables, like an array of class handles.

## 3.9 Virtual Interfaces with Modports and Parameters

### With a modport

```systemverilog
class alu_monitor;
  virtual alu_if.MON vif;          // this class can only do what modport MON allows
endclass
```

| Declaration | Access through the handle |
|---|---|
| `virtual alu_if vif;` | Everything in the interface, in both directions |
| `virtual alu_if.MON vif;` | Only the items listed in modport `MON`, in the listed directions. Anything else is a compile error |

Using modport-restricted handles in the driver and the monitor gives the class-based testbench the same protection that Part 2 gave to modules.

### With parameters

```systemverilog
mem_if #(.AW(16), .DW(32)) mif (clk);

virtual mem_if #(.AW(16), .DW(32)) vif_ok  = mif;     // types match
// virtual mem_if                  vif_bad = mif;     // ILLEGAL: default parameters differ
```

Each set of parameter values is a separate type, and a handle can only refer to instances of exactly its own type. A class that must work with any width is itself parameterised and passes its parameters to the handle type:

```systemverilog
class mem_driver #(int AW = 4, int DW = 8);
  virtual mem_if #(AW, DW) vif;
endclass

mem_driver #(16, 32) drv;       // works with the 16/32 instance
```

Parameterised classes are covered in Module 11.

### Preview: the shape of the ALU driver

Part 4 completes this class with clocking blocks. The structure is already fixed by what you know:

```systemverilog
class alu_driver;

  virtual alu_if.DRV vif;                      // 1. the handle

  function new(virtual alu_if.DRV vif);        // 2. received from outside
    this.vif = vif;
  endfunction

  task drive(bit [7:0] a, bit [7:0] b, alu_op_e op);
    // 3. pin-level activity, always through vif
  endtask

endclass
```

> **Common mistake:** Declaring the handle without the modport in the class (`virtual alu_if vif;`) "to keep it simple". The code works, but the monitor can then drive signals and the driver can read signals it should not. Use the modport that matches the role.

### Interview questions

**Q1. What is the benefit of `virtual alu_if.DRV vif` over `virtual alu_if vif`?**
The handle is restricted to the driver's modport. The driver cannot write a DUT output or bypass the clocking block; a mistake is reported at compile time.

**Q2. An interface is parameterised. What must be true of the virtual interface declaration?**
It must specify the same parameter values as the instance it will refer to, because differently parameterised interfaces are different types.

## 3.10 Summary of Part 3

| Step | Where | Code |
|---|---|---|
| 1. Declare the interface | A file compiled before the classes | `interface cnt_if (input logic clk); ... endinterface` |
| 2. Instantiate it and connect the DUT | Top module | `cnt_if cif (clk); counter dut (cif);` |
| 3. Declare a handle in the class | Class | `virtual cnt_if vif;` |
| 4. Receive the handle | Class constructor | `function new(virtual cnt_if vif); this.vif = vif; endfunction` |
| 5. Hand the instance to the class | Top module | `drv = new(cif);` |
| 6. Use the signals | Class methods | `vif.en = 1; @(posedge vif.clk); x = vif.count;` |

> **How to say it in an interview:** "A class cannot have ports and cannot instantiate an interface, because classes are dynamic and interfaces are static. So the class holds a virtual interface, which is a handle to an interface instance. The top module creates the real interface, connects it to the DUT, and passes it to the testbench classes, usually through their constructors. Inside the class, signals are accessed as `vif.signal`. If the handle is never assigned it is null, and using it gives a run-time error."
