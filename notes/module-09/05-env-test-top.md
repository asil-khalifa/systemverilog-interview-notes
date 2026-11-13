# Part 5: Environment, Test, Package and Testbench Top

## 5.1 The Environment

### In plain English

The four components do not know about each other. Something has to create them, create the mailboxes and events they share, hand each component the right handles, start them all running at the same time, and decide when they have finished. That container is the environment.

### Technical definition

The environment is a class that encapsulates the verification components for a DUT. It constructs the components and their communication channels, connects them by passing shared handles, passes down the virtual interface, starts every component's `run()` task as a parallel thread, and detects the end of the test. It contains no test-specific stimulus, so the same environment is used by every test.

### Why it is a separate class

| Without an environment | With an environment |
|---|---|
| Every test repeats the code that creates and connects four components | Tests construct one object |
| Adding a component (say a coverage collector) means editing every test | One file changes |
| The block's testbench cannot be instantiated inside a larger testbench | A subsystem environment contains several block environments |

### The file

```systemverilog file=alu_env.sv
class alu_env;

  virtual alu_if     vif;

  mailbox #(alu_txn) gen2drv_mbx;
  mailbox #(alu_txn) mon2scb_mbx;
  event              drv_done;
  event              gen_done;

  alu_generator      gen;
  alu_driver         drv;
  alu_monitor        mon;
  alu_scoreboard     scb;

  int unsigned       drain_timeout = 100;    // clock cycles

  function new(virtual alu_if vif);
    this.vif    = vif;
    gen2drv_mbx = new();
    mon2scb_mbx = new();
    gen = new(gen2drv_mbx, drv_done, gen_done);
    drv = new(vif, gen2drv_mbx, drv_done);
    mon = new(vif, mon2scb_mbx);
    scb = new(mon2scb_mbx);
  endfunction

  task run();
    // Start all components. Only gen.run() ever returns.
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
    join_any
    $display("[%0t] ENV: stimulus done, waiting for %0d results", $time, gen.num_sent);

    // Drain: wait until every transaction that was sent has been checked
    fork
      wait (scb.num_checked == gen.num_sent);
      begin
        repeat (drain_timeout) @(posedge vif.clk);
        $error("[%0t] ENV: timeout, %0d of %0d results checked",
               $time, scb.num_checked, gen.num_sent);
      end
    join_any

    disable fork;                           // stop driver, monitor, scoreboard, watchdog
  endtask

endclass
```

### Line by line: construction and connection

| Code | Explanation |
|---|---|
| `virtual alu_if vif;` | The environment keeps the interface handle so that it can pass it on, and so that `run()` can count clock cycles. |
| `mailbox #(alu_txn) gen2drv_mbx;` etc. | Handles for the two mailboxes. They are `null` until `new()`. |
| `event drv_done; event gen_done;` | Event variables. Unlike class handles, an event variable is created with an event object already attached; no `new()` is needed. |
| `alu_generator gen;` ... | Handles for the four components. Public, so that a test can reach into them (`env.gen.num_txns = 20;`). |
| `function new(virtual alu_if vif);` | The only thing the environment needs from outside is the interface. |
| `gen2drv_mbx = new();` | Creates an **unbounded** mailbox. `new(1)` would create a bounded mailbox of size 1. |
| `gen = new(gen2drv_mbx, drv_done, gen_done);` | Creates the generator and gives it one end of the first mailbox and the two events. |
| `drv = new(vif, gen2drv_mbx, drv_done);` | The driver receives the **same** mailbox handle and the **same** `drv_done` event. This single line is the connection Generator → Mailbox → Driver. |
| `mon = new(vif, mon2scb_mbx);` | The monitor receives the same `vif` as the driver, and one end of the second mailbox. |
| `scb = new(mon2scb_mbx);` | The other end: Monitor → Mailbox → Scoreboard. |

The order inside the constructor matters in one respect: the mailboxes must be created **before** they are passed to the components. If `gen = new(gen2drv_mbx, ...)` came before `gen2drv_mbx = new();`, the generator would receive `null`, the environment would then create a mailbox that only the environment knows about, and the first `put()` would fail with a null object access.

### Line by line: running

| Code | Explanation |
|---|---|
| `fork gen.run(); drv.run(); mon.run(); scb.run(); join_any` | Each statement in the `fork` becomes its own thread, and all four start at the same simulation time. `join_any` lets the parent continue as soon as **one** of them finishes. Driver, monitor and scoreboard are `forever` loops, so the one that finishes is always the generator. The other three keep running in the background. |
| `$display("... stimulus done ...")` | Printed when the generator has sent its last transaction. |
| second `fork` ... `join_any` | A race between two threads: "everything has been checked" and "too much time has passed". |
| `wait (scb.num_checked == gen.num_sent);` | Level-sensitive wait. It is re-evaluated whenever either counter changes and unblocks when the scoreboard has checked as many transactions as the generator sent. |
| `repeat (drain_timeout) @(posedge vif.clk);` then `$error` | The watchdog. If the DUT never produces a result, or a transaction is lost, the first thread would wait forever and the simulation would hang. The watchdog turns a hang into a clear error. |
| `disable fork;` | Kills every thread that this process started with `fork` and that is still running: the driver, the monitor, the scoreboard, and whichever of the two drain threads did not finish. After this the environment is quiet and `run()` returns. |

### Why join_any, and not join or join_none

| Construct | Parent continues when | Effect if used for the four components |
|---|---|---|
| `fork`...`join` | **All** threads have finished | Never: three of the four are `forever` loops. The simulation runs until someone kills it |
| `fork`...`join_any` | **Any one** thread has finished | When the generator has finished. This is what is wanted |
| `fork`...`join_none` | Immediately | The parent continues at once and must wait for the end of the test some other way, for example `@(gen_done);` (see below) |

### How the test ends

"How does your testbench know when to stop?" has several acceptable answers; a good answer names the mechanism and its weakness.

| Method | How | Weakness |
|---|---|---|
| Fixed delay: `#10000; $finish;` | Wait a fixed time | Too short: results are cut off. Too long: wasted simulation. Breaks when the number of transactions changes |
| Stop when the generator finishes | `join_any`, then `$finish` | The last transactions are still in the driver, the DUT and the monitor. They are never checked |
| Generator finished **and** scoreboard has checked everything | `join_any` (or `@(gen_done)`), then `wait (scb.num_checked == gen.num_sent)` | Hangs if a transaction is lost, so it needs a timeout |
| The above plus a watchdog timeout | As in `alu_env::run` | None of the above; this is the robust form |

The **drain time** is the interval between the last stimulus being generated and the last result being checked. Here it is one clock cycle (the DUT's latency); in a real design it can be thousands of cycles.

### The role of gen_done

The generator triggers `gen_done` just before its `run()` returns. With `join_any`, the return itself tells the environment that stimulus is finished, so `alu_env::run` does not need to wait for the event. The event matters in the other common arrangement, where the components are started with `join_none`:

```systemverilog
// Alternative start-up, equivalent in effect
fork
  gen.run();
  drv.run();
  mon.run();
  scb.run();
join_none
@(gen_done);                  // wait until the generator announces it has finished
```

This form is needed when the thread that finishes first is not necessarily the generator: several generators running in parallel, for instance, where the environment must wait for *all* of their done events. There is no missed-trigger race in the fragment above: threads started with `join_none` do not begin executing until the parent blocks, and the parent blocks at `@(gen_done)`, so the parent is already waiting when the generator starts.

### What disable fork kills

`disable fork` terminates all the active threads that were spawned by the **calling process**. A task does not create a new process: `alu_env::run()` executes inside the `initial` block of `tb_top` that called `test.run()`. So "the calling process" is that `initial` block, and its children are the four component threads and the two drain threads. All of those that are still alive are killed. Threads belonging to other processes, such as the clock generator and the reset block in `tb_top`, are not affected.

> **Common mistake:** Putting `$finish` in the generator or the driver "when the last transaction is done". The simulation ends before the monitor and scoreboard have seen the last result, and the final transactions are never checked. A component should never end the simulation; the test (or top) does, after the environment reports that everything has drained.

> **Common mistake:** Creating two mailboxes where one is meant: `gen = new(mbx_a, ...); drv = new(mbx_b, ...);`. Both components work perfectly on their own, the generator's transactions pile up in one mailbox, and the driver waits forever on the other. Symptom: the test hangs at time 0 with only one `GEN` line printed, and (with a watchdog) ends in a timeout.

### Interview questions

**Q1. What is an environment?**
A class that contains the generator, driver, monitor and scoreboard, creates the mailboxes and events that connect them, passes the virtual interface to the driver and monitor, starts all components in parallel and controls the end of the run.

**Q2. How are the generator and driver connected?**
The environment creates one mailbox and passes the same handle to both constructors. The generator puts transactions in; the driver gets them out.

**Q3. Why are the components started with `fork`...`join_any`?**
The components must run concurrently, so they are forked. Driver, monitor and scoreboard never terminate, so `join` would block forever. `join_any` returns when the generator, the only thread that ends, has finished.

**Q4. After `join_any` returns, is the test over?**
No. The last transactions are still on their way through the driver, DUT, monitor and scoreboard. The environment waits until the scoreboard has checked as many transactions as were sent, with a timeout.

**Q5. What does `disable fork` do here?**
It kills the still-running child threads of the current process: the three endless component threads and the unfinished drain thread. Without it they would keep running while the test prints its report.

**Q6. Why does the environment need a timeout?**
If a transaction is lost or the DUT never responds, the condition "all checked" never becomes true and the simulation would hang. The watchdog converts the hang into an error message that names how many results were missing.

**Q7. In what order must objects be created in the environment's constructor?**
Shared objects (mailboxes) first, then the components that receive them. Otherwise a component is given a null handle.

**Q8. What is drain time?**
The time allowed after the last stimulus for transactions still inside the DUT and testbench to reach the scoreboard.

## 5.2 The Test

### In plain English

The environment is the machinery; the test decides what to do with it. A test creates the environment, adjusts a few settings (how many transactions, which constraints, which generator), runs it and prints the verdict. A project has one environment and many tests.

### Technical definition

A test is the top-level class of the testbench. It instantiates the environment, configures it for one scenario, starts it and reports the result. New scenarios are created by **extending** the base test and overriding its configuration, not by editing the environment or its components.

### Environment versus test

| | Environment | Test |
|---|---|---|
| Contains | Components and their connections | One environment plus scenario settings |
| How many per project | One per DUT | Many: one per scenario |
| Changes when | The testbench structure changes | A new scenario is added |
| Reused at higher levels | Yes | No, tests are specific to a level |
| Knows about constraints and counts | No (it provides defaults) | Yes |

### The file

```systemverilog file=alu_test.sv
class alu_test;

  alu_env env;
  string  name = "alu_test";

  function new(virtual alu_if vif);
    env = new(vif);
  endfunction

  // Scenario settings. Derived tests override this.
  virtual function void configure();
    env.gen.num_txns = 10;
  endfunction

  task run();
    configure();
    $display("[%0t] TEST: %s started", $time, name);
    env.run();
    env.scb.report();
  endtask

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `alu_env env;` | Handle to the environment. |
| `string name = "alu_test";` | Used in the log. Derived tests set their own name. |
| `function new(virtual alu_if vif);` | The test receives the interface from `tb_top`... |
| `env = new(vif);` | ...and passes it down. This one call builds and connects the whole component tree (Section 2.2). |
| `virtual function void configure();` | The hook for scenario-specific settings. `virtual` is essential: `run()` calls `configure()` through a base-class handle, and the override of the object's actual class must be the one that executes (Module 4, virtual methods). |
| `env.gen.num_txns = 10;` | The base test: ten random transactions. |
| `task run();` | The execution flow of every test is the same four steps. |
| `configure();` | Step 1: apply the settings, after the components exist and before they run. |
| `env.run();` | Step 3: run until everything has been checked. This is the only statement that consumes simulation time. |
| `env.scb.report();` | Step 4: print the summary and verdict. |

`run()` is not virtual and is not overridden: every test has the same flow, and only `configure()` differs. That keeps derived tests to a few lines (Section 6.6).

### Execution flow of a test

```text
   tb_top:  test = new(aif)          ->  env, gen, drv, mon, scb, mailboxes built, connected
   tb_top:  test.run()
               configure()           ->  scenario settings (zero time)
               env.run()
                  fork ... join_any  ->  four threads start; reset; transactions flow
                  drain              ->  wait for the scoreboard to catch up
                  disable fork       ->  stop the endless threads
               env.scb.report()      ->  summary and verdict
   tb_top:  $finish
```

### Interview questions

**Q1. What is the difference between a test and an environment?**
The environment holds the reusable structure: components and connections. The test holds what is specific to one scenario: configuration, constraints, counts. There is one environment and many tests.

**Q2. How do you write a new test?**
Extend the base test class and override its configuration method to change counts, replace the blueprint transaction with a constrained derived transaction, or replace the generator. The environment and components are not modified.

**Q3. Why is `configure()` declared virtual?**
The top module holds a base-class handle that may point to an object of any derived test. `run()` calls `configure()`; with a virtual method, the version belonging to the object's actual class executes. Without `virtual` the base version would always run and every test would behave like the base test.

**Q4. Where is the test object created?**
In an `initial` block of the top module, which also passes it the interface instance.

## 5.3 The Testbench Package

### Why a package

Classes must be declared somewhere. Declaring them at file level puts them in the compilation unit scope, whose contents depend on how the tool was invoked. Putting them in a **package** gives them a definite home: any module that needs them writes `import alu_tb_pkg::*;` and gets exactly one definition of each class. Module 11 covers packages in general.

### The file

```systemverilog file=alu_tb_pkg.sv
package alu_tb_pkg;

  import alu_pkg::*;

  `include "alu_txn.sv"
  `include "alu_generator.sv"
  `include "alu_driver.sv"
  `include "alu_monitor.sv"
  `include "alu_scoreboard.sv"
  `include "alu_env.sv"
  `include "alu_test.sv"
  `include "alu_arith_test.sv"
  `include "alu_directed_test.sv"

endpackage
```

### Line by line

| Code | Explanation |
|---|---|
| `package alu_tb_pkg;` | Everything up to `endpackage` belongs to this package. |
| `import alu_pkg::*;` | The classes use `alu_op_e` and the opcode names. Importing here makes them visible to all the included class files. |
| `` `include "alu_txn.sv" `` | The preprocessor pastes the contents of the file at this point. The class is therefore declared *inside* the package, although its text lives in a separate file. |
| The order of the includes | A class must be declared before it is used. The transaction comes first, because every component uses it; the components come before the environment that contains them; the environment before the base test; the base test before the tests derived from it. |

The last two includes are the derived tests of Sections 6.4 and 6.6.

> **Key point:** The class files are **not** listed on the compiler command line. Only `alu_tb_pkg.sv` is, and it pulls the class files in. If a class file were also compiled directly, the class would be declared twice, once outside the package and once inside, and the two would be different types. (Many teams give included class files the extension `.svh` to make this obvious. They are named `.sv` here to match the file list in the syllabus.)

If the order cannot be arranged (two classes that refer to each other), a forward declaration `typedef class alu_env;` at the top of the package tells the compiler that the name is a class that will be defined later (Module 1, Section 3.6).

### A virtual interface inside a package

The classes contain `virtual alu_if vif;`, and `alu_if` is not declared in the package (an interface cannot be). This is legal: a virtual interface declaration only names the interface type, which is resolved when the design is elaborated. `alu_if.sv` must be part of the compilation, and compiling it before the package avoids warnings in some tools.

## 5.4 The Testbench Top: tb_top.sv

### In plain English

Everything so far has been classes, which do not exist until someone calls `new()`. The testbench top is the static, module-based part: the place where the real signals live. It makes the clock, applies reset, creates one interface instance, plugs the DUT into it, and then creates the test object and tells it to run.

### What belongs in the top module

| Item | Why it is in the top module |
|---|---|
| Clock generation | The clock is a free-running signal needed by both the DUT and the interface before any class runs |
| Reset generation | Reset must be active from time 0, before the class-based components start |
| Interface instance | Interfaces are static design elements; a class can only *point to* one |
| DUT instance | The DUT is a module |
| DUT-to-interface connections | The only place where both are visible |
| Creating the test and passing it the interface | The bridge from the static world to the dynamic world |
| Starting the test and ending the simulation | Top-level control |

What does **not** belong there: stimulus, checking, or any knowledge of what the test does.

### The file

```systemverilog file=tb_top.sv
module tb_top;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  // ---------------- clock ----------------
  logic clk = 0;
  always #5 clk = ~clk;

  // ---------------- interface and DUT ----------------
  alu_if aif (clk);

  alu dut (
    .clk       (clk),
    .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),
    .a         (aif.a),
    .b         (aif.b),
    .op        (aif.op),
    .valid_out (aif.valid_out),
    .result    (aif.result)
  );

  // ---------------- reset ----------------
  initial begin
    aif.rst_n = 1'b0;
    repeat (2) @(negedge clk);
    aif.rst_n = 1'b1;
  end

  // ---------------- test ----------------
  initial begin
    alu_test          test;
    alu_arith_test    arith_test;
    alu_directed_test directed_test;
    string            test_name;

    if (!$value$plusargs("TEST=%s", test_name)) test_name = "alu_test";

    case (test_name)
      "alu_test"          : test = new(aif);
      "alu_arith_test"    : begin arith_test = new(aif);    test = arith_test;    end
      "alu_directed_test" : begin directed_test = new(aif); test = directed_test; end
      default             : $fatal(1, "Unknown test name '%s'", test_name);
    endcase

    test.run();
    $finish;
  end

endmodule
```

### Line by line

| Code | Explanation |
|---|---|
| `import alu_pkg::*;` | For the type of the `op` connection. |
| `import alu_tb_pkg::*;` | Makes the test classes visible. |
| `logic clk = 0;` | The clock starts at a known value. Initialising in the declaration creates no event at time 0, so there is no spurious edge. |
| `always #5 clk = ~clk;` | Period 10 time units. Rising edges at 5, 15, 25...; falling edges at 10, 20, 30... |
| `alu_if aif (clk);` | **The** interface instance. All testbench access to DUT signals goes through this one instance. |
| `alu dut (...)` | The DUT instance. Its `clk` comes straight from the clock; every other port is connected to the interface signal of the same name. |
| `.valid_out (aif.valid_out)` | A DUT output drives the interface variable. Each interface variable has exactly one driver: the DUT for the outputs, the clocking block `drv_cb` for the DUT inputs, the reset block for `rst_n`. |
| `aif.rst_n = 1'b0;` | Reset is asserted at time 0. The X → 0 transition is a negative edge, so the DUT's asynchronous reset takes effect immediately. |
| `repeat (2) @(negedge clk);` | Wait for two falling edges (times 10 and 20). |
| `aif.rst_n = 1'b1;` | Reset is released at time 20, on a falling edge, half a cycle away from the rising edges at which the DUT, driver and monitor work. That keeps the release free of races. |
| `alu_test test;` | A **base-class** handle. Whatever test is selected, it is run through this handle. |
| `alu_arith_test arith_test;` etc. | One handle per derived test, used only to construct the object. |
| `$value$plusargs("TEST=%s", test_name)` | Reads the command-line argument `+TEST=<name>`. It returns 0 if the argument is absent, in which case the base test is selected. |
| `"alu_test" : test = new(aif);` | Creates the test object. `aif`, an interface instance, is passed to a constructor argument of type `virtual alu_if`: this is the moment the physical interface is assigned to a virtual interface. |
| `begin arith_test = new(aif); test = arith_test; end` | Creates a derived test and stores its handle in the base handle (an upcast, always legal). |
| `default : $fatal(...)` | A misspelt test name must stop the run, not silently run something else. |
| `test.run();` | Runs the selected test. `run()` calls the virtual `configure()`, so the derived test's settings apply. Returns when everything has been checked and reported. |
| `$finish;` | Ends the simulation. Without it the clock generator would keep the simulation running forever. |

The handles are declared at the top of the `initial` block without initialisers and assigned in the `case` branches. A variable declared in a module's `initial` block is static, and an initialiser on a static variable is executed once before simulation starts, whichever branch is later taken; writing `alu_arith_test t = new(aif);` inside a branch would therefore construct that test in every run.

### One design choice: selecting the test at run time

Because the test is chosen by a plusarg, the project is compiled once and any test is run by changing the command line: `+TEST=alu_directed_test`. The `case` statement is a minimal "factory". UVM generalises it: `run_test()` reads `+UVM_TESTNAME` and creates the named test class through the UVM factory, with no `case` statement to maintain.

> **Common mistake:** Generating the clock inside a class or inside the driver. The DUT and interface need the clock from time 0 as a static signal; classes run later and may be killed with `disable fork`.

> **Common mistake:** Forgetting to pass the interface, or passing it to only part of the hierarchy. The handle that was missed remains `null`, and the first `@(vif.drv_cb)` produces a null-dereference run-time error at time 0.

> **Common mistake:** Releasing reset at the active clock edge. Whether the DUT (and the monitor's reset check) see reset as asserted or released at that edge then depends on process ordering.

> **Note:** From time 0 until the driver's first idle drive takes effect at time 6, the DUT inputs are X. The DUT is in reset, so nothing is registered. The DUT's `unique case (op)` may, in some simulators, print a "no matching case item" warning at time 0 because `op` is X. It is harmless here; it stops as soon as the driver has driven the idle opcode.

### Interview questions

**Q1. What does the testbench top contain?**
Clock generation, reset generation, the interface instance, the DUT instance connected to the interface, and an `initial` block that creates the test object, passes it the interface, runs it and finishes the simulation.

**Q2. Why is the top a module and not a class?**
The DUT and the interface are static design elements that must be instantiated in the design hierarchy, and clock and reset must exist from time 0. Classes are dynamic and cannot instantiate modules or interfaces.

**Q3. How does the physical interface reach the driver?**
The top module passes the interface instance to the test's constructor, whose argument is a virtual interface. The test passes it to the environment, and the environment passes it to the driver and the monitor.

**Q4. How do you select which test to run without recompiling?**
With a plusarg read by `$value$plusargs`, and code that constructs the matching test class and assigns it to a base-class handle.

**Q5. Why is the test run through a base-class handle?**
So that `tb_top` contains one `test.run()` call that works for every test. Polymorphism (the virtual `configure()` method) makes the selected test's behaviour execute.

**Q6. Why is reset released on the falling clock edge?**
All sampling and driving happens around the rising edge. Changing reset half a cycle away means no component can see it change at the instant it samples.

**Q7. Who calls `$finish`?**
The top module, after `test.run()` has returned, which happens only after the environment has drained and the scoreboard has reported.

## 5.5 Compiling and Running the Project

### File list and compile order

| Order | File | Why it comes here |
|---|---|---|
| 1 | `alu_pkg.sv` | Everything else imports it |
| 2 | `alu_if.sv` | Imports `alu_pkg`; referred to by the classes as a virtual interface |
| 3 | `alu.sv` | The DUT; imports `alu_pkg` |
| 4 | `alu_tb_pkg.sv` | Imports `alu_pkg`; includes all the class files |
| 5 | `tb_top.sv` | Imports both packages; instantiates interface and DUT |

Not on the command line: `alu_txn.sv`, `alu_generator.sv`, `alu_driver.sv`, `alu_monitor.sv`, `alu_scoreboard.sv`, `alu_env.sv`, `alu_test.sv`, `alu_arith_test.sv`, `alu_directed_test.sv`. They are included by `alu_tb_pkg.sv` and only need to be in a directory where the compiler looks for include files (the current directory, or one given with `+incdir+`).

`tb_alu_direct.sv` from Part 1 is a separate testbench; do not compile it together with `tb_top.sv` unless you name the top module explicitly.

### Command lines

The exact options differ between tool versions; treat these as starting points.

```text
Synopsys VCS
  vcs -sverilog -full64 alu_pkg.sv alu_if.sv alu.sv alu_tb_pkg.sv tb_top.sv -o simv
  ./simv +TEST=alu_directed_test
  ./simv +TEST=alu_test +ntb_random_seed=7

Cadence Xcelium
  xrun -sv alu_pkg.sv alu_if.sv alu.sv alu_tb_pkg.sv tb_top.sv +TEST=alu_directed_test
  xrun -sv alu_pkg.sv alu_if.sv alu.sv alu_tb_pkg.sv tb_top.sv +TEST=alu_test -svseed 7

Siemens Questa
  vlog -sv alu_pkg.sv alu_if.sv alu.sv alu_tb_pkg.sv tb_top.sv
  vsim -c tb_top +TEST=alu_directed_test -do "run -all; quit"
  vsim -c tb_top +TEST=alu_test -sv_seed 7 -do "run -all; quit"
```

| Option | Meaning |
|---|---|
| `+TEST=<name>` | Read by `tb_top`; selects `alu_test` (default), `alu_arith_test` or `alu_directed_test` |
| Seed option | Changes the random stimulus. The same seed with the same tool reproduces the same run |

### Running on EDA Playground

1. Choose a SystemVerilog simulator in the left panel (a commercial one; the project uses classes, clocking blocks and randomization).
2. Use the "+" next to the file tabs to create one tab for each of the fourteen project files, with exactly the file names used in this module, and paste the contents.
3. The site compiles `design.sv` first and then `testbench.sv`. Put only include lines in them:

```systemverilog
// design.sv
`include "alu_pkg.sv"
`include "alu_if.sv"
`include "alu.sv"
```

```systemverilog
// testbench.sv
`include "alu_tb_pkg.sv"
`include "tb_top.sv"
```

4. In the "Run Options" field enter `+TEST=alu_directed_test`, then run.

### If it does not compile or run

| Symptom | Likely cause |
|---|---|
| "Undefined type `alu_txn`" in a component file | A class file was compiled directly instead of through the package, or the include order in the package is wrong |
| "Cannot find include file" | The class files are not in the include search path; add `+incdir+<directory>` |
| "Undefined type `alu_op_e`" | `alu_pkg.sv` was not compiled first, or an `import alu_pkg::*;` is missing |
| "Null object access" at time 0 | A handle was used before `new()`: usually a mailbox not created, or created after being passed on |
| "Null virtual interface" at time 0 | The interface was not passed down to the driver or monitor |
| Simulation never ends | `$finish` missing, or the components were started with `join` |
| `ENV: timeout` error | A transaction was lost: wrong mailbox connection, monitor not seeing `valid_in` or `valid_out`, or the DUT never answering |
| "Unknown test name" fatal | Typing error in `+TEST=` |
