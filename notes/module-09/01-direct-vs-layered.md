# Module 9 Overview

Modules 1 to 8 taught the individual pieces of a class-based testbench: data types, arrays, tasks and functions, classes, randomization, transaction classes, mailboxes and events, interfaces and clocking blocks. This module puts all of them together. By the end of it you will have a complete, working **layered testbench** for the 8-bit ALU from Module 1, and you will be able to explain every file, every connection and every design decision in it.

This is the module interviewers draw on most for "architecture" questions: "Draw a testbench.", "What does the monitor do?", "How does your test end?", "Why does the scoreboard not take its expected values from the generator?". Each of these has a definite answer, and each answer is in this module.

**What this module contains**

| Part | Content |
|---|---|
| 1 | Direct testbench versus layered testbench: what each is, advantages, disadvantages, why industry uses the layered form |
| 2 | The project at a glance, and its foundation files: DUT, interface with modports and clocking blocks, transaction class |
| 3 | The stimulus side: generator and driver |
| 4 | The checking side: monitor and scoreboard |
| 5 | Environment, test, testbench package and testbench top; how to compile and run |
| 6 | Execution from start to finish: communication flow, cycle-by-cycle timeline, logs, end of test, new tests without touching components, a seeded bug, and the same structure applied to a FIFO |
| 7 | Revision summary, interview questions, output prediction, debugging, coding exercises, checklist |

**What you need from earlier modules**

| Topic | Module |
|---|---|
| `logic` versus `bit`, enums, `!==`, expression width | 1 |
| Queues | 2 |
| Tasks, functions, `automatic` | 3 |
| Classes, handles, `new`, inheritance, virtual methods, shallow and deep copy | 4 |
| `rand`, constraints, `randomize()` | 5 |
| Transaction class with `print`, `copy`, `compare` | 6 |
| Mailboxes, events, `fork`...`join_any`, `disable fork` | 7 |
| Interfaces, modports, virtual interfaces, clocking blocks | 8 |

Each of these is recalled in one or two sentences at the point where it is used, so that the module can be read on its own.

**The project files**

| File | Kind | Contents |
|---|---|---|
| `alu_pkg.sv` | Package | The opcode enum `alu_op_e` (from Module 1) |
| `alu.sv` | Module | The DUT (from Module 1, unchanged) |
| `alu_if.sv` | Interface | DUT signals, clocking blocks `drv_cb` and `mon_cb`, modports |
| `alu_txn.sv` | Class | The transaction |
| `alu_generator.sv` | Class | Creates and randomizes transactions |
| `alu_driver.sv` | Class | Turns transactions into pin activity |
| `alu_monitor.sv` | Class | Turns pin activity back into transactions |
| `alu_scoreboard.sv` | Class | Predicts the expected result and compares |
| `alu_env.sv` | Class | Creates and connects the four components |
| `alu_test.sv` | Class | Base test: configures and runs the environment |
| `alu_arith_test.sv` | Classes | A derived test that only generates ADD and SUB |
| `alu_directed_test.sv` | Classes | A derived test with eight hand-written transactions |
| `alu_tb_pkg.sv` | Package | Includes all the class files |
| `tb_top.sv` | Module | Clock, reset, interface instance, DUT instance, starts the test |

All of these are also saved in the `examples/module-09/` folder of the repository.

> **Note:** As in the other modules, the logs in this module were worked out by hand from the IEEE 1800 scheduling rules, because no simulator was available while writing. The directed test has a fully determined log, given in Section 6.4. The random tests print different operand values with every seed and simulator; their logs are labelled as samples. Run the project yourself and compare.

# Part 1: Direct Testbench Versus Layered Testbench

## 1.1 What Every Testbench Must Do

### In plain English

Whatever its style, a testbench has five jobs. Keep this list in mind, because the whole of this module is about *where* each job is done.

| Job | Question it answers |
|---|---|
| 1. Generate stimulus | What values and operations should be applied to the DUT? |
| 2. Drive the stimulus | How are those values put onto the DUT pins, and when, relative to the clock? |
| 3. Observe the DUT | What actually happened on the pins? |
| 4. Check the response | Was the DUT output correct for the input it received? |
| 5. Measure progress | Which scenarios have been exercised (coverage), and did the test pass? |

A **direct testbench** does all five jobs in one place, usually one module with a few tasks. A **layered testbench** gives each job to a separate component and connects the components through well-defined channels.

### The two levels of abstraction

Jobs 1 and 4 are about *what* is being done: "add 200 and 100; the answer must be 300". Jobs 2 and 3 are about *how* it appears on wires: "at the rising edge, `valid_in` is 1, `a` is `C8`, `b` is `64`, `op` is `000`; one cycle later `valid_out` is 1 and `result` is `12C`".

| Level | Unit of work | Who works at this level |
|---|---|---|
| Transaction level | A transaction object: operands, opcode, result | Generator, scoreboard, test |
| Signal (pin) level | Values of individual signals at clock edges | Driver, monitor, interface, DUT |

The driver converts from transaction level down to signal level. The monitor converts from signal level back up to transaction level. Everything else in the testbench never touches a signal. This separation is the central idea of a layered testbench.

## 1.2 The Direct Testbench

### Definition

A direct (also called flat, linear or module-based) testbench is a single module that instantiates the DUT, generates the clock, and contains procedural code that assigns values straight to the DUT inputs and compares the DUT outputs against values the engineer worked out by hand. It is the Verilog style of verification.

### Structure

```text
  +--------------------------- module tb_alu_direct ---------------------------+
  |                                                                            |
  |   clock generator        initial block                                     |
  |   always #5 clk=~clk     - reset                                           |
  |                          - apply(200, 100, ADD, 300)   stimulus AND        |
  |                          - apply(5, 10, SUB, 507)      expected value      |
  |                          - ...                         written by hand     |
  |                                 |                 ^                        |
  |                         drive   v                 |  compare               |
  |                          +-------------------------------+                 |
  |                          |              DUT              |                 |
  |                          +-------------------------------+                 |
  +----------------------------------------------------------------------------+
```

### Complete example

This is a slightly improved version of the directed testbench from Module 1. A task removes the repetition, and an error counter gives a final verdict. Compile it together with `alu_pkg.sv` and `alu.sv`.

```systemverilog file=tb_alu_direct.sv
module tb_alu_direct;
  import alu_pkg::*;

  logic        clk = 0;
  logic        rst_n;
  logic        valid_in;
  logic [7:0]  a, b;
  alu_op_e     op;
  logic        valid_out;
  logic [8:0]  result;
  int unsigned errors;

  alu dut (.*);

  always #5 clk = ~clk;

  task automatic apply(input logic [7:0] a_i,
                       input logic [7:0] b_i,
                       input alu_op_e    op_i,
                       input logic [8:0] exp_i);
    @(negedge clk);
    a        = a_i;
    b        = b_i;
    op       = op_i;
    valid_in = 1'b1;
    @(negedge clk);
    valid_in = 1'b0;
    if (valid_out !== 1'b1 || result !== exp_i) begin
      errors++;
      $display("[%0t] FAIL %s a=%0d b=%0d result=%0d expected=%0d",
               $time, op_i.name(), a_i, b_i, result, exp_i);
    end
    else
      $display("[%0t] PASS %s a=%0d b=%0d result=%0d",
               $time, op_i.name(), a_i, b_i, result);
  endtask

  initial begin
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    apply(8'd200, 8'd100, ALU_ADD, 9'd300);
    apply(8'd5,   8'd10,  ALU_SUB, 9'd507);
    apply(8'hF0,  8'h3C,  ALU_AND, 9'h030);
    apply(8'h81,  8'h00,  ALU_SHL, 9'h102);

    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED with %0d errors", errors);
    $finish;
  end

endmodule
```

```output
[40] PASS ALU_ADD a=200 b=100 result=300
[60] PASS ALU_SUB a=5 b=10 result=507
[80] PASS ALU_AND a=240 b=60 result=48
[100] PASS ALU_SHL a=129 b=0 result=258
TEST PASSED
```

**Line by line**

| Code | Explanation |
|---|---|
| `alu dut (.*);` | Instantiates the DUT and connects each port to the testbench signal of the same name. |
| `always #5 clk = ~clk;` | Clock with a period of 10 time units. Rising edges at 5, 15, 25...; falling edges at 10, 20, 30... |
| `task automatic apply(...)` | One task does three of the five jobs: it drives the pins, waits, and checks. `automatic` gives each call its own copy of the arguments (Module 3). |
| `@(negedge clk);` then the four assignments | Stimulus is applied on the falling edge, half a cycle away from the rising edge at which the DUT samples. That avoids a race between testbench and DUT. |
| Second `@(negedge clk);` | By now one rising edge has passed, so the DUT has registered the result. |
| `valid_out !== 1'b1 \|\| result !== exp_i` | The check, with `!==` so that X on an output is a failure (Module 1, Section 4.5). |
| `apply(8'd5, 8'd10, ALU_SUB, 9'd507);` | The engineer calculated the expected value by hand: 5 - 10 = -5, which in 9 bits is 512 - 5 = 507. |
| `if (errors == 0) ...` | Final verdict. |

**Execution flow**

| Time | What happens |
|---|---|
| 0 | Inputs get known values and reset is asserted. |
| 20 | Second falling edge: reset released. First `apply` call starts and waits for the next falling edge. |
| 30 | `apply` drives 200, 100, `ALU_ADD`, `valid_in` = 1. |
| 35 | Rising edge: the DUT stores 300 and sets `valid_out`. |
| 40 | `apply` removes `valid_in`, checks, prints. The second call starts. |
| 50, 55, 60 | The same three steps for the subtraction. And so on every 20 time units. |

### Advantages of a direct testbench

| Advantage | Explanation |
|---|---|
| Quick to write | A few dozen lines; no classes, no interface, no mailboxes |
| Easy to read for a small DUT | The stimulus and the expected value sit on the same line |
| Easy to debug | One thread of execution, strictly sequential |
| Exactly repeatable | The same vectors every run |
| No knowledge of OOP needed | Usable by a designer for a quick sanity check of a block |

### Disadvantages of a direct testbench

| Disadvantage | What it means in practice |
|---|---|
| Expected values are worked out by hand | The ALU has 8 operations and 65,536 operand pairs each: 524,288 cases. Nobody writes 524,288 `apply` lines, and a hand calculation can itself be wrong |
| Only the scenarios you thought of are tested | Bugs live in the cases nobody thought of |
| Stimulus, pin timing and checking are tangled together | The task `apply` knows the protocol (drive on negedge, wait one cycle) *and* the data *and* the check. A change to any one of them means editing the same code |
| A protocol change breaks every test | If the ALU gains a second pipeline stage, every place that assumes "result after one cycle" must be edited |
| No reuse | The code cannot be reused for another test, at the next level of integration (block inside a subsystem), or on the next project |
| Checking happens only where the test looks | Between two `apply` calls nobody watches the outputs. A spurious `valid_out` during idle cycles goes unnoticed |
| One sequential thread | Real designs have several interfaces active at the same time; a single thread cannot drive and watch them all |
| No measurement of what was covered | "Are we done?" has no objective answer |
| Does not scale to a team | One file, one author |

> **Key point:** The direct testbench is not wrong. It is the right tool for a 20-line module, for bring-up of a new block ("does it do anything at all?"), and for reproducing one specific failure. It stops being the right tool when the number of scenarios is too large to write by hand.

## 1.3 The Layered Testbench

### Definition

A layered testbench is a testbench built from separate class-based components, each with one responsibility, arranged in layers of abstraction. The components exchange **transaction objects** through mailboxes, and only two of them (driver and monitor) touch the DUT signals, through a virtual interface. Stimulus is usually constrained-random, and checking is automatic.

### The layers

```text
   +---------------------------------------------------------------------------+
   |  Test layer        alu_test, alu_arith_test, alu_directed_test            |
   |                    chooses WHAT to run: number of transactions,           |
   |                    constraints, which generator                           |
   +---------------------------------------------------------------------------+
   |  Scenario layer    alu_generator                                          |
   |                    creates the stream of transactions                     |
   +---------------------------------------------------------------------------+
   |  Functional layer  alu_scoreboard (with the reference model alu_predict)  |
   |                    decides whether the DUT behaved correctly              |
   +---------------------------------------------------------------------------+
   |  Command layer     alu_driver, alu_monitor                                |
   |                    translate between transactions and pin activity        |
   +---------------------------------------------------------------------------+
   |  Signal layer      alu_if (interface, clocking blocks), clock, reset,     |
   |                    and the DUT itself                                     |
   +---------------------------------------------------------------------------+
```

Reading from the top: each layer uses only the layer directly below it and knows nothing about the layers further down. The test does not know which clock edge the driver uses. The generator does not know that a signal called `valid_in` exists. The scoreboard does not know how the result reached it.

| Layer | Works with | Knows about the protocol timing? | Changes when... |
|---|---|---|---|
| Test | Configuration, constraints | No | A new scenario is wanted |
| Scenario | Transactions | No | The kind or order of stimulus changes |
| Functional | Transactions | No | The DUT's intended function changes |
| Command | Transactions on one side, signals on the other | Yes | The pin-level protocol changes |
| Signal | Signals | It *is* the protocol | The DUT ports change |

### The components and the data flow

```text
                 +----------------------------- alu_test ------------------------------+
                 |  +--------------------------- alu_env ---------------------------+  |
                 |  |                                                               |  |
                 |  |  +---------------+   gen2drv_mbx   +---------------+          |  |
                 |  |  | alu_generator |---------------->|  alu_driver   |          |  |
                 |  |  +---------------+   (alu_txn)     +-------+-------+          |  |
                 |  |          ^                                 |                  |  |
                 |  |          +---------- drv_done -------------+  vif.drv_cb      |  |
                 |  |                                            |                  |  |
                 |  |  +----------------+  mon2scb_mbx   +-------+-------+          |  |
                 |  |  | alu_scoreboard |<---------------|  alu_monitor  |          |  |
                 |  |  | (alu_predict)  |   (alu_txn)    +-------+-------+          |  |
                 |  |  +----------------+                        ^  vif.mon_cb      |  |
                 |  +--------------------------------------------|------------------+  |
                 +-----------------------------------------------|---------------------+
                                                                 |
   module tb_top                                    virtual interface (vif)
   +-------------------------------------------------------------|---------------------+
   |                                                             |                     |
   |   clock, reset        +-------------------------------------+------+              |
   |   -------------------> |                 alu_if aif                |              |
   |                        +---------+----------------------+----------+              |
   |                                  | inputs               ^ outputs                 |
   |                                  v                      |                         |
   |                        +---------------------------------------+                  |
   |                        |               alu  dut                |                  |
   |                        +---------------------------------------+                  |
   +-----------------------------------------------------------------------------------+
```

The two paths to remember, in the form interviewers ask for them:

```text
   Stimulus path :  Generator -> Mailbox -> Driver -> Interface -> DUT

   Checking path :  DUT -> Interface -> Monitor -> Mailbox -> Scoreboard
```

| Component | One-sentence job | Section |
|---|---|---|
| Transaction (`alu_txn`) | The unit of data that travels between components | 2.5 |
| Generator | Creates and randomizes transactions and sends them to the driver | 3.1 |
| Driver | Receives transactions and drives the DUT input pins at the right clock edges | 3.2 |
| Interface | Bundles the DUT signals and defines sampling and driving timing | 2.4 |
| Monitor | Watches the pins and rebuilds transactions from what it sees | 4.1 |
| Scoreboard | Predicts the expected result and compares it with the observed result | 4.2 |
| Environment | Creates the components, the mailboxes and the events, and connects them | 5.1 |
| Test | Configures the environment for one scenario and starts it | 5.2 |
| Testbench top | Static module: clock, reset, interface instance, DUT instance, starts the test | 5.4 |

### How the five jobs map onto components

| Job | Direct testbench | Layered testbench |
|---|---|---|
| Generate stimulus | Literal values in the `initial` block | Generator plus constraints in the transaction class |
| Drive | Assignments inside the same task | Driver |
| Observe | Reading DUT outputs inside the same task | Monitor |
| Check | `if` with a hand-computed value | Scoreboard with a reference model |
| Measure | Error counter | Scoreboard counters; functional coverage (Module 10) |

### Advantages of a layered testbench

| Advantage | Explanation |
|---|---|
| Automatic checking of any stimulus | The reference model computes the expected value for whatever the generator produced, so thousands of random transactions are checked with no extra code |
| Finds unexpected bugs | Constrained-random stimulus reaches combinations nobody listed |
| Separation of concerns | A change in pin timing touches only the driver and monitor. A change in function touches only the reference model. A new scenario touches only a test |
| New tests are small | A test is a few lines that change constraints or counts (Section 6.6); the components are not edited |
| Reuse | The monitor and scoreboard can be reused unchanged when the ALU is embedded in a larger design, where the driver is replaced by real logic |
| Continuous observation | The monitor watches every clock edge, not only the moments when a test chooses to look |
| Parallelism | Each component runs as its own thread, which matches the concurrency of hardware |
| Team scalability | Different engineers own different components behind agreed interfaces (the transaction class and the mailboxes) |
| Path to UVM | UVM is this same architecture with standard base classes (Module 11) |

### Disadvantages of a layered testbench

| Disadvantage | Explanation |
|---|---|
| Higher initial cost | Ten or more files have to exist before the first transaction runs |
| Needs more knowledge | OOP, randomization, IPC and virtual interfaces are all prerequisites |
| Harder to debug | Several threads, zero-time handshakes, handles and mailboxes; the cause of a failure can be in the testbench itself |
| The reference model is extra code that can be wrong | A bug in the model gives false failures, or, worse, the same misunderstanding in model and DUT gives a false pass |
| Random tests are not repeatable unless the seed is recorded | Every failure report must include the seed |
| Overkill for trivial blocks | For a 20-line module the testbench would be ten times the size of the design |

## 1.4 Direct Versus Layered: Comparison

| Aspect | Direct testbench | Layered testbench |
|---|---|---|
| Built from | One module, tasks, `initial` blocks | Classes inside a package, plus one small top module |
| Level of abstraction | Signal level throughout | Transaction level above the driver and monitor |
| Stimulus | Hand-written vectors | Constrained-random transactions (plus directed tests when needed) |
| Expected values | Calculated by the engineer for each vector | Calculated by a reference model for every transaction |
| Checking | At the points the test chooses | Continuous, for every transaction the monitor sees |
| Access to DUT pins | Any code in the module | Only driver and monitor, through a virtual interface |
| Timing control | Scattered through the test | Concentrated in driver, monitor and clocking blocks |
| Adding a test | Copy and edit the vectors | Extend the test class and change constraints |
| Effect of a protocol change | Every test is edited | Driver and monitor are edited |
| Reuse across tests, levels and projects | Almost none | High |
| Coverage | Not measured | Functional coverage on the monitored transactions |
| Threads | One | One per component |
| Effort for the first test | Minutes to hours | Days |
| Effort for the hundredth test | The same as the first | Minutes |
| Scales to large designs | No | Yes |
| Typical use | Small blocks, bring-up, reproducing one bug | Block-level and system-level verification in industry |

> **Interview trap:** "So a layered testbench cannot run directed tests?" It can. A directed test in a layered testbench is a test that supplies fixed transactions instead of random ones (Section 6.4 does exactly this). The stimulus is directed, but it still flows through the same driver, monitor and scoreboard, so it is still checked automatically. "Layered" describes the structure, not the randomness.

## 1.5 Why Industry Uses the Layered Architecture

1. **The state space is too large for hand-written tests.** Even this toy ALU has more than half a million input combinations per cycle. A real block has sequences, modes and configurations on top of that. Only automatic generation plus automatic checking can cover it.
2. **Verification takes most of the project effort**, so anything reused saves a lot. Components are written once and reused by hundreds of tests, by the subsystem and chip-level testbenches, and by the next generation of the design.
3. **Specifications change during the project.** With separation of concerns, a change is made in one place.
4. **Teams are large.** A fixed architecture with agreed component roles lets several people work on one testbench and lets a new engineer find their way around any testbench in the company.
5. **Sign-off needs numbers.** Coverage collected at the monitor answers "what has been tested?" objectively.
6. **It is the basis of UVM.** UVM standardises exactly this structure (sequence, sequencer, driver, monitor, agent, scoreboard, environment, test). Understanding the plain SystemVerilog version makes UVM easy to learn, and interviewers for fresher roles test the plain version to check that understanding.

> **How to say it in an interview:** "A direct testbench drives hand-written vectors at pin level and checks them against hand-computed values, all in one module. It is fine for small blocks but does not scale: the tests are not reusable and only cover what the engineer thought of. A layered testbench splits the work into components: a generator creates random transactions, a driver converts them to pin activity through a virtual interface, a monitor converts pin activity back into transactions, and a scoreboard checks them against a reference model. The components communicate through mailboxes at transaction level, so stimulus, protocol timing and checking are independent of each other. That gives reuse, automatic checking of random stimulus, and small tests, which is why industry, and UVM, use this structure."

### Interview questions

**Q1. What is a layered testbench?**
A testbench organised as separate components at different levels of abstraction, typically generator, driver, monitor, scoreboard, environment and test, which exchange transaction objects through mailboxes. Only the driver and the monitor access DUT signals, through a virtual interface.

**Q2. Name the layers.**
From the bottom: signal layer (interface, DUT), command layer (driver, monitor), functional layer (scoreboard, reference model), scenario layer (generator), and test layer.

**Q3. Give three disadvantages of a direct testbench.**
Expected values are hand-computed for every vector; only scenarios the author thought of are tested; stimulus, timing and checking are mixed, so any protocol change breaks every test and nothing is reusable.

**Q4. Give two disadvantages of a layered testbench.**
It costs much more to set up before the first test runs, and it is harder to debug because of multiple threads and because the testbench itself (especially the reference model) can contain bugs.

**Q5. Which components know about the pin-level protocol?**
Only the driver and the monitor (and the interface they use). The generator, scoreboard and test work purely with transactions.

**Q6. What is meant by "separation of concerns" in a testbench?**
Each component has one responsibility and hides how it does it. What to send (generator), how to send it (driver), what was observed (monitor) and whether it was right (scoreboard) can each be changed without touching the others.

**Q7. When would you still write a direct testbench?**
For a very small block, for first bring-up of new RTL, or to reproduce one specific failing scenario quickly.

**Q8. What is the difference between transaction level and signal level?**
At transaction level one object describes a complete operation (operands, opcode, result) with no notion of clock edges. At signal level the same operation is a set of individual signal values at specific clock edges. The driver and monitor convert between the two.

**Q9. Is a layered testbench always constrained-random?**
No. The architecture is independent of the kind of stimulus. Directed transactions can be sent through the same components and are still checked automatically.

**Q10. How does this architecture relate to UVM?**
UVM is a standard class library that implements the same architecture. The generator becomes a sequence and sequencer, driver and monitor keep their names and are grouped in an agent, the mailboxes become TLM ports, and the environment and test become `uvm_env` and `uvm_test`.
