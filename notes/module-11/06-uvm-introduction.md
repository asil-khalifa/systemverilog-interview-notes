# Part 5: Introduction to UVM

This part is an orientation, not a UVM course. Its purpose is to show that UVM contains no new language: it is a library of SystemVerilog classes that standardises the layered testbench you built in Module 9. If you can explain the M9 testbench, you can explain the outline of any UVM testbench, and that is the level expected of a fresher who lists "SystemVerilog" as the main skill.

## 5.1 What UVM Is and Why It Exists

### In plain English

In Module 9 you made a number of design decisions: the generator talks to the driver through a mailbox; every component has a `run()` task; the environment constructs the components and connects them; the test decides how many transactions to send; an event tells the test when to stop. They were reasonable decisions, but they were *yours*. Another engineer would have named things differently, connected them differently, and ended the test differently. Your driver could not be dropped into that engineer's environment.

**UVM (Universal Verification Methodology)** is the industry's agreed set of answers to all of those decisions, delivered as a ready-made class library. Everybody's driver extends the same base class, receives transactions the same way, is constructed and connected at the same moments and reports errors with the same macros. Components written by different people, teams and companies therefore fit together.

### Technical definition

UVM is a standardised verification methodology and an accompanying **SystemVerilog class library**. It was developed by Accellera (first released in 2011, derived mainly from OVM, with ideas from VMM) and is now also an IEEE standard, IEEE 1800.2. The library is delivered as:

- the package `uvm_pkg`, containing several hundred classes;
- the file `uvm_macros.svh`, containing macros that generate repetitive code.

A UVM testbench is ordinary SystemVerilog code that imports the package, includes the macros and extends the base classes.

### What the library provides

| Service | What it gives you | What you did by hand in M9 |
|---|---|---|
| Base classes for every testbench role | `uvm_driver`, `uvm_monitor`, `uvm_sequencer`, `uvm_agent`, `uvm_scoreboard`, `uvm_env`, `uvm_test` | Wrote `alu_driver`, `alu_monitor`... from nothing |
| Phasing | All components are built, connected, run and reported in a fixed, automatic order | `alu_env` called constructors, then `run()` tasks inside a `fork` |
| Factory | Any class can be replaced by a derived class from the test, without editing the environment | Edited the environment or added a handle |
| Configuration database | Values and virtual interfaces are stored centrally and fetched by the components that need them | Passed `vif` through constructor arguments |
| Sequences | Stimulus scenarios are objects, separate from the testbench structure, and can be layered and reused | A loop inside `alu_generator::run()` |
| TLM (transaction-level modelling) ports | Standard connections between components | Mailboxes |
| Objections | A standard way to decide when the test is over | The events `gen_done` and `drv_done`, counters |
| Reporting | Messages with ID, severity and verbosity, filterable and countable | `$display`, `$error` |
| Register layer (RAL) | A model of the DUT's registers with built-in access sequences | Not covered |

### Why the industry uses it

| Benefit | Explanation |
|---|---|
| Reuse across projects (horizontal) | An agent for a standard protocol works unchanged in every testbench that has that protocol |
| Reuse from block to chip (vertical) | A block-level environment is instantiated inside the chip-level environment; its agents become passive monitors |
| Tests without changing the environment | Factory overrides and configuration let a test alter behaviour from outside |
| One vocabulary | Engineers moving between teams and companies recognise the structure immediately |
| Vendor independence | The same library runs on every major simulator |

### What UVM does not change

The DUT, the interface, the clocking blocks, the transaction's `rand` fields and constraints, covergroups, assertions, and the logic inside the driver's and monitor's main loops are all the same SystemVerilog as before. UVM changes the **framework around them**.

### Interview questions

**Q1. What is UVM?**
The Universal Verification Methodology: a standard methodology and SystemVerilog class library for building reusable, constrained-random, coverage-driven testbenches. It provides base classes for testbench components, phasing, a factory, a configuration database, sequences, TLM communication and reporting.

**Q2. Is UVM a language?**
No. It is a library written in SystemVerilog. Using it requires only a SystemVerilog simulator plus the UVM package and macros.

**Q3. Why is UVM used instead of a plain SystemVerilog layered testbench?**
For standardisation and reuse. A hand-written layered testbench works but follows private conventions. UVM fixes the conventions (structure, construction order, communication, end of test, reporting) so that components from different sources interoperate and tests can modify an environment without editing it.

## 5.2 How SystemVerilog Features Map to UVM

Every mechanism in UVM is built from a language feature covered in this course. This table is the core of the chapter: read each row as "UVM uses *this* to do *that*".

| SystemVerilog feature (module) | How UVM uses it |
|---|---|
| Classes and objects (M4) | Everything in a UVM testbench is a class object: transactions, sequences, components, the test |
| Inheritance (M4) | User classes extend library base classes: `class alu_uvm_driver extends uvm_driver #(alu_seq_item);` |
| Virtual methods and polymorphism (M4) | The library calls methods such as `build_phase()` and `run_phase()` through base-class handles; your overriding versions execute. The factory returns a derived object through a base handle |
| `$cast` (M1, M4) | Used inside the factory and in `clone()`, which return base-type handles that are cast to the real type |
| Static properties and methods (M4) | The factory, the configuration database and the root of the component tree are reached through static methods: `uvm_config_db #(T)::set(...)`, `type_id::create(...)` |
| Parameterized classes (Section 2.1) | `uvm_driver #(REQ)`, `uvm_sequencer #(REQ)`, `uvm_sequence #(REQ)`, `uvm_analysis_port #(T)`, `uvm_config_db #(T)` |
| `typedef` (M1) | `typedef uvm_sequencer #(alu_seq_item) alu_sequencer;` |
| Packages and `::` (Part 1) | The whole library is `uvm_pkg`; `alu_seq_item::type_id::create()` is two scope resolutions and a static call |
| `rand`, constraints, `randomize()` (M5) | Sequence items are randomized by sequences; inline constraints shape scenarios |
| Transaction class with copy/compare/print (M6) | `uvm_sequence_item` provides `copy`, `clone`, `compare`, `print`, `convert2string` as standard methods to override or automate |
| Mailboxes (M7) | Replaced by TLM ports, exports and FIFOs, which are classes built on the same blocking `put`/`get` ideas |
| Events (M7) | `uvm_event`, and more importantly the objection mechanism for end of test |
| `fork`...`join` and process control (M7, Part 3) | The library forks every component's `run_phase` task in parallel and kills them when the phase ends; sequences run as processes that can be killed |
| Interfaces, virtual interfaces, clocking blocks (M8) | Used unchanged. The virtual interface is delivered through the configuration database |
| Layered testbench (M9) | Generator becomes sequence + sequencer; driver, monitor, scoreboard, environment and test keep their roles |
| Covergroups and assertions (M10) | Used unchanged. Covergroups usually live in a subscriber component connected to the monitor |
| Macros (`` `define ``) | `` `uvm_component_utils ``, `` `uvm_object_utils ``, `` `uvm_info ``, `` `uvm_error ``, `` `uvm_fatal `` generate boilerplate |
| Plusargs (Section 4.4) | `+UVM_TESTNAME=alu_base_test` selects the test; `+UVM_VERBOSITY=UVM_HIGH` sets message verbosity |

> **How to say it in an interview:** "UVM is a SystemVerilog class library. Components are classes derived from `uvm_component`; transactions are classes derived from `uvm_sequence_item`. It relies on inheritance and virtual methods for phases and overrides, on parameterized classes for type-safe drivers, sequencers and ports, on static methods for the factory and the config database, and on virtual interfaces to reach the DUT. So the OOP features of SystemVerilog are the foundation that UVM is built on."

### Interview questions

**Q1. Which OOP concepts does UVM depend on?**
Inheritance (user classes extend UVM base classes), polymorphism through virtual methods (phase methods, factory overrides), parameterized classes (drivers, sequencers, ports, config database), static members (factory and config database access), and encapsulation.

**Q2. Why must phase methods such as `run_phase` be virtual?**
The library holds every component through a `uvm_component` handle and calls `run_phase` on it. Only because the method is virtual does the call reach the overriding version in the user's derived class.

## 5.3 The Class Hierarchy: uvm_object and uvm_component

All UVM classes descend from a small tree. Knowing the two main branches is enough to place any class.

```text
   uvm_void
     |
   uvm_object ------------------------------------------- data, things that come and go
     |
     +-- uvm_transaction
     |      +-- uvm_sequence_item ..................... alu_seq_item      (the transaction)
     |             +-- uvm_sequence #(REQ) ............ alu_sequence      (stream of items)
     |
     +-- uvm_report_object
            +-- uvm_component ---------------------------- structure, things that stay
                   |
                   +-- uvm_test ....................... alu_base_test
                   +-- uvm_env ........................ alu_uvm_env
                   +-- uvm_agent ...................... alu_agent
                   +-- uvm_driver #(REQ) .............. alu_uvm_driver
                   +-- uvm_monitor .................... alu_uvm_monitor
                   +-- uvm_sequencer #(REQ) ........... alu_sequencer
                   +-- uvm_scoreboard ................. alu_uvm_scoreboard
                   +-- uvm_subscriber #(T) ............ a coverage collector
```

(Intermediate library classes are omitted from the sketch.)

### uvm_object versus uvm_component

| Property | `uvm_object` | `uvm_component` |
|---|---|---|
| Represents | Data and behaviour that is created and discarded during the run: transactions, sequences, configuration objects | The static structure of the testbench: driver, monitor, agent, environment, test |
| Lifetime | Created whenever needed, at any time; garbage-collected when no longer referenced | Created once in the build phase at time 0; exists until the end of simulation |
| Place in a hierarchy | None | Has a parent and a full hierarchical name, for example `uvm_test_top.env.agent.drv` |
| Phases | None | `build_phase`, `connect_phase`, `run_phase` and the others are called automatically |
| Constructor | `function new(string name = "alu_seq_item");` | `function new(string name, uvm_component parent);` |
| Registration macro | `` `uvm_object_utils(alu_seq_item) `` | `` `uvm_component_utils(alu_uvm_driver) `` |
| Created with | `alu_seq_item::type_id::create("req")` | `alu_uvm_driver::type_id::create("drv", this)` |
| In the M9 testbench | `alu_txn` | `alu_generator`, `alu_driver`, `alu_monitor`, `alu_scoreboard`, `alu_env`, `alu_test` |

The two constructor signatures are worth memorising; a wrong one is the most common beginner compile error in UVM. A component's constructor takes its parent, which is how the component tree is formed.

### Interview questions

**Q1. What is the difference between `uvm_object` and `uvm_component`?**
`uvm_component` classes form the static testbench hierarchy: they are created once during the build phase, have a parent and a hierarchical name, and take part in phases. `uvm_object` classes are transient data such as transactions and sequences: they have no parent, no phases, and are created and destroyed throughout the simulation. `uvm_component` itself is derived from `uvm_object`.

**Q2. From which class is a transaction derived? A driver?**
A transaction from `uvm_sequence_item`. A driver from `uvm_driver #(REQ)`, which is a `uvm_component`.

## 5.4 Phases

### The problem phases solve

In M9 the environment's constructor created the components, then connected the mailboxes, then `run()` forked the components' tasks, and the test printed a report at the end. That order was coded by hand in `alu_env` and `alu_test`. In UVM the order is built into the library: every component implements the phase methods it needs, and the library calls them on **all** components at the right time.

### The common phases

| Phase | Kind | Order through the hierarchy | What you put in it | M9 equivalent |
|---|---|---|---|---|
| `build_phase` | function | Top-down (parent before children) | Create child components; fetch configuration and the virtual interface | Constructors: `gen = new(...)`, `drv = new(...)` in `alu_env::new` |
| `connect_phase` | function | Bottom-up | Connect TLM ports between components | Passing `gen2drv_mbx` and `mon2scb_mbx` to both ends |
| `end_of_elaboration_phase` | function | Bottom-up | Final adjustments; print the topology | |
| `start_of_simulation_phase` | function | Bottom-up | Print banners and configuration | |
| `run_phase` | **task** | All components in parallel | Everything that consumes time: driving, monitoring, starting sequences | Each component's `task run()` inside the `fork` of `alu_env::run()` |
| `extract_phase` | function | Bottom-up | Collect final values from components | |
| `check_phase` | function | Bottom-up | Check that nothing is left over (empty queues, all responses seen) | End-of-test checks in the scoreboard |
| `report_phase` | function | Bottom-up | Print the summary and pass/fail result | `alu_scoreboard::report()` |
| `final_phase` | function | Top-down | Close files | |

```text
   time 0 (no time passes)           time advances            end of test (no time passes)

   build -> connect -> end_of_elaboration -> start_of_simulation
                                    |
                                    v
                    run_phase  (every component's task, forked in parallel)
                                    |
                                    v
                    extract -> check -> report -> final

   function phases                  the only task phase                function phases
```

Points to know:

- Only `run_phase` is a task. All other phases are functions and therefore take no simulation time (M3).
- `build_phase` is top-down because a parent must exist, and must have decided its configuration, before its children are created. `connect_phase` runs after the whole tree has been built, so every port that needs connecting already exists.
- The `run_phase` is internally divided into optional finer run-time phases (reset, configure, main, shutdown, each with pre- and post- phases) that run in parallel with it. Most testbenches use only `run_phase`.
- The phases start when the top module calls `run_test()`.

### Interview questions

**Q1. What are UVM phases and why are they needed?**
Phases are predefined steps that the library executes on every component in a fixed order: build, connect, end of elaboration, start of simulation, run, extract, check, report, final. They synchronise the construction, connection, execution and reporting of all components without the user coding that order.

**Q2. Which phase is a task?**
`run_phase` (and its run-time sub-phases). All the others are functions.

**Q3. Why is `build_phase` top-down and `connect_phase` bottom-up?**
Building is top-down because a parent creates its children and may configure them first. Connecting happens after everything exists; proceeding bottom-up ensures lower-level connections are made before the levels above them rely on them.

## 5.5 The Factory

In M9 the environment contained `drv = new(...)`, which fixes the class of the driver at that line. To run one test with an error-injecting driver you would have to edit the environment. The **factory** removes the need. It is a central table of all registered classes, plus a list of *overrides*. Components and objects are not constructed with `new` directly but by asking the factory: `alu_uvm_driver::type_id::create("drv", this)`. The factory normally returns an `alu_uvm_driver`. If a test has registered an override, it returns an object of the overriding **derived** class instead, through the same base-type handle. The environment's source code does not change.

Three language features make this work, all from earlier modules: the registration macro (`` `uvm_component_utils `` or `` `uvm_object_utils ``) adds a nested proxy type called `type_id` with a **static** `create` method; the object returned is a derived class assigned to a base-class handle (**upcasting**); and because the methods are **virtual**, the derived behaviour runs. Typical uses are replacing a transaction with a version that has extra constraints, or a driver with one that injects protocol errors, for one test only.

```systemverilog
// In the environment (never changes):
drv = alu_uvm_driver::type_id::create("drv", this);

// In one particular test's build_phase: use the error-injecting driver everywhere
alu_uvm_driver::type_id::set_type_override(alu_err_driver::get_type());
```

## 5.6 The Configuration Database

In M9 the virtual interface travelled from `tb_top` to the driver through a chain of constructor arguments: top to test, test to environment, environment to driver. Every level had to know about it. The **configuration database**, `uvm_config_db`, is a central store that replaces the chain. One piece of code deposits a value under a name and says which components may see it; any of those components fetches it by the same name.

`uvm_config_db #(T)` is a parameterized class (Section 2.1) used only through two static methods. `set(context, instance_path, field_name, value)` stores a value; `get(context, instance_path, field_name, variable)` retrieves it and returns 1 if it was found. The type parameter `T` must be the same in the `set` and the `get`, and so must the field name string. Its most common use is passing the virtual interface from the top module to the driver and the monitor; it is also used for configuration objects (number of transactions, active or passive agent, and similar settings).

```systemverilog
// In tb_top, before run_test(): visible to every component ("*")
uvm_config_db #(virtual alu_if)::set(null, "*", "vif", alu_vif);

// In the driver's build_phase
if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
  `uvm_fatal("NOVIF", "virtual interface was not set for the driver")
```

> **Interview trap:** "The driver's `get` from the config database fails although `set` was called. Why?" The usual causes are a mismatch in the type parameter (for example `virtual alu_if` in one place and `virtual alu_if.DRV` in the other), a different field name string, an instance path in `set` that does not cover the driver, or calling `set` after `run_test()` has already started the build phase.

## 5.7 UVM Components at a High Level

### The structure of a UVM testbench

```text
  tb_top (module)
  |   clock, reset, alu_if alu_vif, DUT instance
  |   uvm_config_db::set(vif);  run_test("alu_base_test");
  |
  +-- alu_base_test (uvm_test) ....................... starts sequences, raises objections
        |
        +-- alu_uvm_env (uvm_env)
              |
              +-- alu_agent (uvm_agent) ------------------------------------------+
              |     |                                                             |
              |     |   alu_sequence (object)                                     |
              |     |        | items                                              |
              |     |        v                                                    |
              |     +-- alu_sequencer --seq_item_port/export--> alu_uvm_driver -> vif -> DUT
              |     |                                                             |
              |     +-- alu_uvm_monitor <----------------------------- vif <------ DUT
              |               | analysis port (ap)                                |
              |     ----------|-----------------------------------------------------+
              |               v
              +-- alu_uvm_scoreboard (uvm_scoreboard)     (and coverage subscribers)
```

### Each element in one paragraph

**Sequence item** (`alu_seq_item`, extends `uvm_sequence_item`). The transaction: the same `rand` fields and constraints as `alu_txn`, plus the standard object methods. It is what flows from the sequence to the driver and from the monitor to the scoreboard.

**Sequence** (`alu_sequence`, extends `uvm_sequence #(alu_seq_item)`). An object whose `body()` task creates items, randomizes them and sends them. It is the stimulus *scenario*. It replaces the loop inside `alu_generator::run()`, but being a separate object it can be swapped per test, layered inside other sequences, and reused. Sequences are not components: they are created and started by the test and disappear when finished.

**Sequencer** (`alu_sequencer`, a `uvm_sequencer #(alu_seq_item)`). A component that sits between sequences and the driver. It hands the driver one item at a time when the driver asks, and arbitrates if several sequences run at once. In M9 the mailbox `gen2drv_mbx` did the simple version of this job. Most sequencers are just a `typedef` of the library class.

**Driver** (`alu_uvm_driver`, extends `uvm_driver #(alu_seq_item)`). Converts items into pin activity through the virtual interface, exactly like `alu_driver`. The loop is: `seq_item_port.get_next_item(req);` drive the item; `seq_item_port.item_done();`. `get_next_item` blocks until a sequence supplies an item (compare with `gen2drv_mbx.get(txn)`); `item_done` tells the sequence that the item has been driven, which unblocks it (the handshake that `drv_done` provided in M9).

**Monitor** (`alu_uvm_monitor`, extends `uvm_monitor`). Passive. Samples the interface through `mon_cb`, rebuilds items, and publishes each one by calling `ap.write(item)` on its **analysis port**. It does not know or care who is listening.

**Agent** (`alu_agent`, extends `uvm_agent`). A container for one interface's sequencer, driver and monitor. It has a mode: **active** (all three; it drives the DUT) or **passive** (monitor only; it just observes). The same agent is active at block level and passive at chip level where real logic drives that interface. The M9 testbench had no agent level because it had only one interface.

**Scoreboard** (`alu_uvm_scoreboard`, extends `uvm_scoreboard`). Receives items from the monitor through an analysis connection, computes the expected result, compares, counts, and reports in `report_phase`. The checking logic is the same as in `alu_scoreboard`.

**Environment** (`alu_uvm_env`, extends `uvm_env`). Creates the agent(s), the scoreboard and coverage collectors in `build_phase` and connects them in `connect_phase`. Same role as `alu_env`.

**Test** (`alu_base_test`, extends `uvm_test`). The top-level component. Creates the environment, applies configuration and factory overrides, starts the sequences in `run_phase`, and controls the end of test with objections. A project has many tests, usually derived from one base test, all using the same environment. The test to run is chosen by name with `run_test("alu_base_test")` or `+UVM_TESTNAME=...`.

**Top module** (`tb_top`). Still a module: it instantiates the DUT and the interface, generates clock and reset, puts the virtual interface into the configuration database and calls `run_test()`.

### Side-by-side: the M9 layered testbench and UVM

| Role | M9 layered testbench | UVM equivalent | What changed |
|---|---|---|---|
| Transaction | `alu_txn` | `alu_seq_item` extends `uvm_sequence_item` | Inherits standard copy/compare/print; created by the factory |
| Stimulus scenario | Loop in `alu_generator::run()` | `alu_sequence::body()` | Separated from structure; selectable per test |
| Passing stimulus to the driver | `gen2drv_mbx` (`mailbox #(alu_txn)`) | `alu_sequencer` with `seq_item_port` / `seq_item_export` | A pull model with a built-in handshake |
| Driver | `alu_driver` with `task run()` | `alu_uvm_driver` with `run_phase` | `get_next_item` / `item_done` instead of `mailbox.get` |
| Monitor | `alu_monitor` puts into `mon2scb_mbx` | `alu_uvm_monitor` calls `ap.write(item)` | Broadcast to any number of subscribers |
| Grouping per interface | (none) | `alu_agent` | New level, enabling active/passive reuse |
| Checker | `alu_scoreboard` gets from `mon2scb_mbx` | `alu_uvm_scoreboard` with `write()` | Receives through an analysis connection |
| Container | `alu_env` | `alu_uvm_env` | Build and connect split into phases |
| Test | `alu_test` | `alu_base_test` extends `uvm_test` | Chosen by name at run time |
| Top | `tb_top` creates `alu_test` and calls `run()` | `tb_top` calls `run_test()` | The library creates the test |
| Getting `vif` | Constructor arguments | `uvm_config_db #(virtual alu_if)` | No chain of arguments |
| Construction | `new()` | `type_id::create()` | Overridable through the factory |
| Starting threads | `fork gen.run(); drv.run(); ... join_any` | All `run_phase` tasks forked by the library | Automatic |
| End of test | Events `gen_done`, `drv_done`, counters | Objections | Standard, component-independent |
| Messages | `$display`, `$error` | `` `uvm_info ``, `` `uvm_error ``, `` `uvm_fatal `` | Verbosity control, counts, IDs |

### TLM ports versus mailboxes

TLM stands for transaction-level modelling: components exchange whole transactions through method calls instead of signals.

| Property | Mailbox (M7, M9) | UVM TLM connection |
|---|---|---|
| What the component holds | A handle to a shared mailbox object | A **port** object of its own |
| Who knows about the other end | Both ends share the same mailbox, created by the environment | Neither component knows the other; the environment connects port to export in `connect_phase` |
| Blocking transfer | `mbx.put(t)`, `mbx.get(t)` | `port.put(t)`, `port.get(t)`; for sequences, `get_next_item` / `item_done` |
| One-to-many broadcast | Not possible: one `get` removes the item; you need one mailbox per receiver | **Analysis port**: `ap.write(t)` delivers the same item to every connected subscriber (scoreboard, coverage, logger) |
| Does `write` block? | `put` blocks on a full bounded mailbox | `write` is a function: never blocks, takes no time |
| Buffering | The mailbox is the buffer | None in a port; add a `uvm_tlm_analysis_fifo #(T)` when the receiver needs to `get` at its own pace |
| Type safety | `mailbox #(alu_txn)` | `uvm_analysis_port #(alu_seq_item)` |

The idea is the same: a typed channel that decouples the sender from the receiver. The TLM port adds that the two ends are developed without sharing an object, and the analysis port adds broadcast. Internally a `uvm_tlm_fifo` is itself implemented with a mailbox.

### Objections versus the hand-written end of test

`run_phase` tasks such as a driver's `forever` loop never return, so the library needs to be told when the test is over. A component that still has work to do **raises an objection**; when it is done it **drops** it. The run phase ends when every raised objection has been dropped, and the library then kills the remaining `run_phase` processes and moves on to the reporting phases.

| | M9 layered testbench | UVM |
|---|---|---|
| "I have work to do" | Implicit: the test waits for specific events | `phase.raise_objection(this);` |
| "I am done" | `-> gen_done;`, a transaction counter reaching its target | `phase.drop_objection(this);` |
| Who decides the test is over | Code in `alu_test` or `alu_env` that knows every component's event | The library: all objections dropped |
| Extra time for the last transaction to be checked | A fixed delay or waiting on the scoreboard count | A drain time on the objection, or a delay before dropping |
| Adding a new component that also has work | Edit the end-of-test code | The new component raises its own objection |

Normally only the test (or the top sequence) raises an objection, around the sequences it starts. If no one ever raises an objection, the run phase ends at time 0 and nothing is simulated, which is a classic first-day mistake.

### Interview questions

**Q1. Name the components of a UVM testbench.**
Sequence item, sequence, sequencer, driver, monitor, agent, scoreboard, environment and test, with a top module that holds the DUT and interface. Coverage collectors (subscribers) are usually present too.

**Q2. What is the difference between a sequence and a sequencer?**
A sequence is an object that generates a stream of items in its `body()` task. A sequencer is a component that routes items from sequences to the driver, one at a time, on request.

**Q3. What is an agent? What is the difference between active and passive?**
An agent packages the sequencer, driver and monitor of one interface. An active agent contains all three and drives the DUT. A passive agent contains only the monitor and just observes; it is used when the interface is driven by real design logic, for example at chip level.

**Q4. How does the driver get a transaction in UVM?**
Through its `seq_item_port`, which is connected to the sequencer's `seq_item_export`. The driver calls `get_next_item(req)`, drives the item, and calls `item_done()`.

**Q5. What is an analysis port?**
A TLM port with a single non-blocking function `write(item)` that broadcasts the item to all connected subscribers. Monitors use it to send observed transactions to scoreboards and coverage collectors.

**Q6. How does a UVM test end?**
By the objection mechanism. The run phase ends when all raised objections have been dropped.

**Q7. How does the M9 mailbox between generator and driver relate to UVM?**
It corresponds to the sequencer-driver connection. The generator's role is taken by a sequence; the mailbox's role by the sequencer and the `seq_item_port`; the `get` becomes `get_next_item`, and the done-event becomes `item_done`.

