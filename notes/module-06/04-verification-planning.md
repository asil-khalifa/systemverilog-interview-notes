# Part 4: Verification Planning

Parts 1 to 3 built the object that carries stimulus. This part steps back and asks the larger questions: what are we trying to achieve with that stimulus, how do we decide what to test, and how do we know when to stop?

## 4.1 What Is Verification?

### In plain English

A designer reads the specification and writes RTL. Verification asks one question about that RTL: **does it do what the specification says, in every situation the specification covers?** And it must answer before the design is manufactured, because a chip cannot be patched after it leaves the factory.

Verification is therefore not "running a few tests to see that it works". It is a systematic search for every way in which the design might *not* work.

### Technical definition

**Functional verification** is the process of demonstrating that a design's implementation (RTL) conforms to its specification, before tape-out. The design being checked is the DUT. The work is done mainly by simulation, supported by formal methods, emulation and prototyping.

### Related terms that interviewers ask you to distinguish

| Term | Question it answers | When | Done on |
|---|---|---|---|
| **Verification** (pre-silicon) | Does the RTL match the specification? | Before tape-out | RTL and netlist, in simulators, formal tools, emulators |
| **Validation** (post-silicon) | Does the manufactured chip work in the real system, and is it what the customer needs? | After silicon returns | Real chips on boards |
| **Testing** (manufacturing test, DFT) | Is *this particular chip* free of manufacturing defects? | On every chip produced | Each die, on automatic test equipment |

A short way to remember it: verification asks "did we build it right?" (against the specification); validation asks "did we build the right thing?" (against the real need); manufacturing test asks "was this copy fabricated correctly?".

### Why verification is needed

| Reason | Explanation |
|---|---|
| Cost of a late bug | A bug found in block-level simulation costs minutes to fix. Found in system simulation, days. Found in silicon, it costs a new mask set, months of schedule and possibly the product's market window. Found by a customer, it can mean a recall |
| Complexity | The number of possible input sequences and internal states of even a modest design is far beyond anything that can be tried by hand |
| Human error | Designers misread specifications, forget corner cases and make typing mistakes. A second, independent reading of the specification catches these |
| Ambiguous specifications | Writing checks forces every vague statement to be resolved. Many "bugs" found by verification are in the specification |
| Integration | Blocks that work alone may fail together because of mismatched assumptions about an interface |

For these reasons verification usually takes more effort than design, and verification engineers commonly outnumber designers on a project.

### The main verification techniques

| Technique | How it works | Strength | Limitation |
|---|---|---|---|
| Simulation (dynamic verification) | The RTL is executed with stimulus from a testbench; outputs are checked | Flexible, full visibility, works for any design. The subject of this course | Slow for long scenarios; only checks what is simulated |
| Formal verification | A tool proves mathematically that a property holds for all possible inputs, or finds a counter-example | Exhaustive for the properties written | Limited to smaller blocks; needs skill to write properties and constraints |
| Emulation / FPGA prototyping | The design is mapped onto special hardware and run thousands of times faster | Can boot software and run real workloads | Poor visibility; long compile times; expensive |
| Gate-level simulation | The synthesised netlist is simulated, often with timing | Catches synthesis mismatches, reset and X problems, timing-related issues | Very slow; only a small set of tests is run |
| Static checks (lint, CDC, RDC) | Tools analyse the code without running it | Fast; finds coding errors and clock-domain-crossing problems early | Finds only structural problems, not functional ones |

### Levels of verification

```text
   Block / unit level      one module (the ALU)           full control and visibility,
        |                                                 exhaustive corner cases
        v
   Subsystem / cluster     several blocks together        interfaces between blocks
        |
        v
   Chip / SoC level        the whole design               integration, connectivity,
        |                                                 software-driven scenarios
        v
   System level            chip + software + board model  real use cases
```

Most functional bugs should be found at block level, where simulation is fast and every signal is easy to control. Higher levels concentrate on what cannot be seen lower down: how the blocks interact.

### What a verification engineer actually does

1. Reads the specification and questions it.
2. Writes the verification plan: the list of things to verify and how.
3. Designs and builds the testbench.
4. Writes tests, runs them, and debugs failures (both testbench bugs and design bugs).
5. Reports design bugs and confirms the fixes.
6. Measures coverage, analyses the holes and closes them.
7. Runs regressions and reports status until the sign-off criteria are met.

> **Key point:** The mindset is the opposite of the designer's. The designer tries to make the design work. The verification engineer tries to make it fail, and success is measured by the bugs found before tape-out.

### Interview questions

**Q1. What is verification?**
The process of confirming, before manufacture, that the design implementation behaves as its specification requires, by simulation, formal analysis and related techniques.

**Q2. What is the difference between verification and validation?**
Verification is pre-silicon and checks the design against the specification. Validation is post-silicon and checks that the real chip works in the real system and meets the user's needs.

**Q3. What is the difference between verification and testing?**
In semiconductor usage, "testing" normally means manufacturing test: checking every fabricated chip for physical defects. Verification checks the design itself for functional errors, once, before fabrication.

**Q4. Why is verification done at block level if the whole chip will be verified anyway?**
At block level the design is small, simulations are fast, and every input can be controlled directly, so corner cases can be reached and bugs are cheap to find and debug. At chip level the same corner may be impossible to reach or take hours of simulation.

**Q5. Can verification prove that a design has no bugs?**
No. Simulation can only show the presence of bugs, never their absence. Verification reduces the risk to an acceptable level, and coverage metrics measure how thoroughly the planned behaviour has been exercised.

## 4.2 What Is a Verification Plan?

### In plain English

Before building anything, write down what "verified" will mean for this design: which behaviours must be checked, how each will be stimulated, how each will be checked, and how you will know it has happened. That document is the verification plan. It is the contract between the verification team, the design team and management.

### Technical definition

The **verification plan** (also called *vplan*, and in some companies loosely called the test plan) is a document, derived from the design specification, that lists every feature to be verified and, for each, the verification method, the stimulus strategy, the checking mechanism and the coverage metric, together with the testbench architecture, resources, schedule and completion criteria.

### Why it is needed

| Without a plan | With a plan |
|---|---|
| Tests are written as ideas occur; features are forgotten | Every feature of the specification is listed and tracked |
| "Are we done?" is answered by opinion | "Done" is defined by measurable criteria agreed in advance |
| The testbench is built for the first test and patched afterwards | The testbench architecture is designed for all the planned tests |
| Design and verification interpret the specification separately | The plan review exposes different interpretations early |
| Progress cannot be reported | Progress is the fraction of plan items passing and covered |

### What a verification plan contains

| Section | Contents |
|---|---|
| 1. Introduction and scope | The DUT, the specification version it is based on, what is and is not verified at this level |
| 2. Feature list | Every feature extracted from the specification, each with an identifier and a priority |
| 3. Verification strategy | For each feature: simulation, formal, or both; directed or constrained-random; block or chip level |
| 4. Testbench architecture | Block diagram, components, interfaces, reference model, reuse from other projects |
| 5. Stimulus plan | Transactions, constraints, sequences and scenarios needed |
| 6. Checking plan | Scoreboard, reference model, assertions, protocol checkers, end-of-test checks |
| 7. Coverage plan | Functional coverage points and crosses mapped to the features; code coverage goals |
| 8. Test list (the test plan) | The individual tests, see Section 4.3 |
| 9. Completion (exit) criteria | The measurable conditions for sign-off |
| 10. Resources and schedule | People, tools, licences, compute, milestones |
| 11. Risks and assumptions | Late specification changes, unavailable models, known limitations |

The core of the plan is a table with one row per feature. A shortened example for the ALU (the complete one is in Part 5):

| ID | Feature | How stimulated | How checked | How measured |
|---|---|---|---|---|
| F3 | ADD produces `a + b` with carry in bit 8 | Random `alu_txn` with `op == ALU_ADD`; corner bias on operands | Scoreboard compares with `alu_predict` | Coverpoint on `op`; cross of operand corners with ADD; carry bin |
| F11 | Outputs are 0 after reset | Reset applied at start and in mid-operation | Assertion on `valid_out` and `result` during reset | Cover property: reset while `valid_in` is high |

### How it is created and used

```text
   Specification
        |
        v
   Feature extraction  ---->  review with designers and architects
        |
        v
   Verification plan (features, strategy, checks, coverage, tests, exit criteria)
        |
        +---->  Testbench is built to implement the plan
        |
        +---->  Tests and coverage are written from the plan
        |
        +---->  Regression results and coverage are mapped back onto the plan
        |
        v
   Sign-off: every plan item is covered and passing
```

The plan is a **living document**. It is updated when the specification changes, when a bug reveals a missing scenario, and when coverage analysis shows a hole that the plan did not anticipate. Verification-management tools can link each plan item to a coverage item and show the percentage achieved against each feature; this is called plan-driven or metric-driven verification.

> **How to say it in an interview:** "The verification plan is the document that defines what will be verified and how. I derive it from the specification by listing every feature, and for each one I state how it will be stimulated, how it will be checked and which coverage item proves it was exercised. It also describes the testbench architecture and the exit criteria. It is reviewed with the designers and it is updated throughout the project."

### Interview questions

**Q1. What is a verification plan?**
A document derived from the specification that lists the features to verify and, for each one, the stimulus, checking and coverage, plus the testbench architecture and the completion criteria.

**Q2. Who writes and who reviews the verification plan?**
The verification engineer or lead writes it. It is reviewed by the designers, the architects or specification owners, and often by software or system engineers who will use the block.

**Q3. When is the verification plan written?**
At the start, in parallel with the RTL design, as soon as the specification is stable enough. It is then maintained for the life of the project.

**Q4. Why is the plan derived from the specification and not from the RTL?**
The RTL may be wrong; that is what verification is trying to find out. A plan derived from the RTL would describe what the design does, not what it should do.

**Q5. What are exit criteria?**
The measurable conditions under which verification is declared complete: for example all planned tests passing, 100 percent functional coverage, code coverage above an agreed threshold with reviewed exclusions, and no open high-priority bugs.

## 4.3 What Is a Test Plan?

### In plain English

The verification plan says *what* must be verified. The test plan says *which tests* will do it: a concrete list, each test with a name, a purpose, the stimulus it uses, what it expects, and which features it covers.

### Technical definition

A **test plan** is the list of test cases (testcases) to be written and run, each described by its objective, the configuration and stimulus it applies, its pass/fail criteria, and the features and coverage items it targets, along with its priority and current status.

### Verification plan versus test plan

Usage varies between companies, and many use the two names for one combined document. When they are distinguished, the difference is:

| Aspect | Verification plan | Test plan |
|---|---|---|
| Answers | What will be verified and how do we know it is done? | Which tests will be run? |
| Level | Strategy | Execution |
| Organised by | Feature | Test case |
| Contains | Features, methods, testbench architecture, checkers, coverage model, exit criteria, schedule | Test names, objectives, stimulus, expected results, priority, status |
| Relationship | The parent document | A section of, or a companion to, the verification plan |
| Changes | When the specification or strategy changes | Frequently, as tests are added and results come in |

> **Interview trap:** If asked "what is the difference between a verification plan and a test plan?", do not answer that they are completely different documents, and do not answer that they are the same. Say that the verification plan is the overall strategy (features, methodology, checking, coverage, exit criteria) and the test plan is the list of test cases that implements it, and add that many teams keep both in one document.

### What one test-plan entry contains

| Field | Example |
|---|---|
| Test name | `alu_add_carry_test` |
| Objective | Verify ADD when the sum exceeds 255 |
| Features covered | F3, F12 |
| Type | Constrained-random |
| Stimulus | 500 transactions of `alu_carry_txn` |
| Expected result / checks | Scoreboard reports 0 mismatches; bit 8 of every result is 1 |
| Coverage targeted | Carry bin of the ADD coverpoint |
| Priority | High |
| Status | Written / passing / failing / blocked |

### Kinds of tests found in a test plan

| Kind | Purpose |
|---|---|
| Sanity (smoke) test | A short test that checks the design is alive: reset, one or two basic operations. Run first, and after every code change |
| Feature (directed) test | One specific feature or scenario with chosen values |
| Constrained-random test | Many random transactions within constraints; the main source of coverage |
| Corner-case test | Boundary values and rare conditions: maximum, minimum, overflow, full, empty |
| Error (negative) test | Illegal or erroneous stimulus, to check that the design detects it or recovers |
| Reset test | Reset at start, in the middle of an operation, repeated resets |
| Stress test | Maximum rate, back-to-back transactions, long duration |
| Register test | Read and write every register; reset values; access types |
| Regression | Not a single test: the complete collection, re-run regularly with many seeds |

### Interview questions

**Q1. What is a test plan?**
The list of test cases needed to carry out the verification plan, each with its objective, stimulus, expected outcome, the features it covers and its status.

**Q2. What is the difference between a verification plan and a test plan?**
The verification plan is the strategy document organised by feature: what to verify, how to stimulate, check and measure it, the testbench architecture and the exit criteria. The test plan is the list of concrete tests, organised by test case. In many teams the test plan is a section of the verification plan.

**Q3. What is a sanity test?**
A short, basic test (reset plus a few simple operations) that shows the DUT and testbench are functional. It is run before anything else and after every change, so that a broken build is detected in minutes.

**Q4. What is a negative test?**
A test that deliberately applies illegal or erroneous stimulus to confirm that the design handles it as specified, for example by flagging an error and continuing to operate.

**Q5. What is a regression?**
The repeated running of the whole test suite, with different random seeds, to confirm that changes to the design or testbench have not broken anything that previously passed.

## 4.4 How to Derive Test Scenarios from a Specification

### In plain English

Interviewers like to hand a candidate a small specification (a FIFO, a counter, an arbiter, a traffic-light controller) and ask "how would you verify this?". They are not looking for code. They want to see a method: a repeatable way of turning a page of specification into a list of scenarios, without missing the unusual ones.

### The method

**Step 1. Read the specification and mark every requirement.** Each sentence that says what the design *shall*, *must* or *will* do is one or more features. So is each row of a table and each waveform.

**Step 2. List the interfaces.** For every port: direction, width, protocol, timing, legal values, reset value.

**Step 3. List the features by category.** Going through a fixed set of categories prevents omissions:

| Category | Questions to ask |
|---|---|
| Reset and initialisation | What are the outputs during and after reset? What happens if reset arrives in the middle of an operation? Synchronous or asynchronous? |
| Basic function | What does each operation or mode do in the normal case? |
| Configuration and modes | What parameters, registers or mode pins change the behaviour? All combinations? |
| Data values | Minimum, maximum, zero, all ones, alternating patterns, a single bit set |
| Boundaries | Full, empty, overflow, underflow, wrap-around, the last address |
| Protocol and timing | Back-to-back operations, idle gaps, the shortest and longest allowed timing, signals asserted simultaneously |
| Sequences | Does the result depend on what came before? Which orders of operations are interesting? |
| Concurrency | What if two things happen in the same cycle (read and write, request and reset)? |
| Errors and illegal input | What is illegal? What must the design do when it happens? |
| Performance | Latency, throughput, anything with a number in the specification |

**Step 4. Apply systematic test-design techniques to each feature.**

| Technique | Idea | Example |
|---|---|---|
| Equivalence partitioning | Divide the input space into classes that the design should treat alike; test at least one member of each | Operands: zero, small, large, maximum |
| Boundary value analysis | Bugs cluster at the edges of each class; test just below, at, and just above each boundary | 254, 255, and the sum that first produces a carry (256) |
| Cross combinations | Features that work alone may fail together | Every operation with every operand class |
| State and transition coverage | Visit every state and every transition, including those that should be impossible | Empty → not empty → full → not full → empty |
| Negative testing | Do what the specification forbids | Write when full; read when empty |
| "What if?" questions | Ask about every pair of events: what if they coincide, or come in the opposite order? | What if reset is released in the same cycle as a request? |

**Step 5. For each scenario, decide how it is stimulated, how it is checked and how its occurrence is measured.** This gives one row of the verification plan.

**Step 6. Review the list with the designer.** Ask "what are you worried about in this block?". The answers become high-priority scenarios.

### Worked example: a synchronous FIFO

**The specification (one paragraph).** A synchronous FIFO, 8 bits wide and 16 entries deep. Ports: `clk`, `rst_n`, `wr_en`, `din[7:0]`, `rd_en`, `dout[7:0]`, `full`, `empty`. Data written while `wr_en` is high and the FIFO is not full is stored. Data is read in the order written, while `rd_en` is high and the FIFO is not empty. `full` is high when 16 entries are stored; `empty` is high when none are. A write when full and a read when empty are ignored. Reset empties the FIFO.

**Scenarios derived by the method**

| # | Category | Scenario | Check |
|---|---|---|---|
| 1 | Reset | After reset, `empty` = 1, `full` = 0 | Assertion |
| 2 | Reset | Reset while the FIFO holds data: it becomes empty | Assertion; scoreboard is flushed |
| 3 | Basic | Write one item, read it back | Scoreboard: data read equals data written |
| 4 | Basic | Write N items, read N items: order is preserved | Scoreboard models a queue |
| 5 | Boundary | Fill completely: `full` rises exactly on the 16th write | Assertion on `full` versus a model count |
| 6 | Boundary | Empty completely: `empty` rises exactly on the last read | Assertion |
| 7 | Boundary | Pointer wrap-around: write and read more than 16 items in total | Scoreboard |
| 8 | Error | Write when full: the item is dropped, stored data is not corrupted | Scoreboard does not expect the dropped item |
| 9 | Error | Read when empty: `dout` and the state do not change | Scoreboard; assertion that `empty` stays high |
| 10 | Concurrency | Read and write in the same cycle when partly full: count unchanged | Scoreboard; cover the event |
| 11 | Concurrency | Read and write in the same cycle when full | Specification must say what happens; check accordingly |
| 12 | Concurrency | Read and write in the same cycle when empty | As above |
| 13 | Data | All zeros, all ones, alternating `55`/`AA`, walking one | Scoreboard |
| 14 | Timing | Back-to-back writes; back-to-back reads; alternating write/read | Scoreboard |
| 15 | Stress | Long random mix of reads and writes with varying rates, so that the FIFO repeatedly reaches full and empty | Scoreboard; coverage on fill level |
| 16 | Flags | `full` and `empty` are never high together | Assertion |

Scenarios 11 and 12 are valuable even before a single test runs: the specification paragraph does not say what happens, so the verification engineer goes back to the specification owner. Finding such gaps is part of the job.

> **How to say it in an interview:** "I start from the specification and list the interfaces and features. I go through fixed categories so I do not miss anything: reset, normal operation, modes, data values, boundaries, timing, sequences, simultaneous events, and illegal inputs. For each feature I apply boundary-value analysis and consider combinations. Then for each scenario I say how I would stimulate it, how I would check it, and which coverage point shows that it happened."

### Interview questions

**Q1. Given a specification, how do you come up with test scenarios?**
Use the method above: extract features category by category, apply equivalence partitioning, boundary analysis, combinations, sequences and negative cases, and for each scenario define stimulus, check and coverage.

**Q2. What is boundary value analysis?**
Selecting test values at and around the edges of each input or state range, such as 0, 1, maximum minus 1, maximum, and the transition into overflow, because design errors concentrate at boundaries.

**Q3. What is equivalence partitioning?**
Dividing the possible inputs into groups whose members the design is expected to treat in the same way, and testing representative values from each group instead of every value.

**Q4. List the corner cases for a FIFO.**
Full, empty, write when full, read when empty, simultaneous read and write at full, at empty and in between, pointer wrap-around, reset while not empty, and the exact cycle at which `full` and `empty` change.

**Q5. What do you do when the specification does not say what should happen in a scenario?**
Raise it with the specification owner or designer, get the intended behaviour agreed and written into the specification, and then add the scenario to the plan. It must not be decided by looking at what the RTL does.

## 4.5 Directed Testing

### Definition

In **directed testing** the engineer writes each test for one specific scenario, choosing every stimulus value and stating the expected result explicitly.

```systemverilog
// A directed test for the ALU: every value is chosen by hand
directed(ALU_ADD, 8'hFF, 8'h01);     // carry out of bit 7
directed(ALU_ADD, 8'hFF, 8'hFF);     // largest possible sum
directed(ALU_SUB, 8'h00, 8'h01);     // borrow
directed(ALU_SHL, 8'h80, 8'h00);     // the bit shifted out must appear in result[8]
```

### How it works

```text
   for each scenario in the test plan:
        write a test  ->  run it  ->  it passes  ->  that scenario is verified
                                                     (and nothing else is)
```

### Advantages and disadvantages

| Advantages | Disadvantages |
|---|---|
| Simple to write for a small design; no complex testbench needed | One test verifies one scenario; effort grows in step with the number of scenarios |
| The scenario tested is exactly known and reproducible | Only scenarios the engineer thought of are tested; unexpected bugs are missed |
| Quick to reach a specific corner | Tests are tied to particular values and timing, and break when the design changes |
| Easy to debug: short, and the intent is obvious | Many tests to maintain |
| Useful from the first day, before the random environment is ready | Coverage rises slowly and levels off below 100 percent |

### Where directed tests are still used

- Sanity tests at the start of a project.
- Reset behaviour and register reset values.
- Specific corner cases that random stimulus is unlikely to reach.
- Re-creating a reported bug, and keeping that test so the bug cannot return.
- Closing the last coverage holes at the end of a project.

## 4.6 Constrained-Random Testing

### Definition

In **constrained-random testing** (CRT, also called constrained-random verification, CRV) the testbench generates stimulus automatically by randomizing transactions within constraints that keep it legal and steer it toward interesting cases. Results are checked automatically, and functional coverage records which scenarios have occurred.

```systemverilog
// A constrained-random test for the ALU: the values are chosen by the solver
repeat (1000) begin
  t = new();
  if (!t.randomize()) $fatal(1, "randomize() failed");
  drive_and_check(t);
end
```

### What it requires

Random stimulus alone is not enough. Three things must be present together:

| Requirement | Why | Module |
|---|---|---|
| Constraints | Unconstrained values are mostly illegal or uninteresting | 5, and Part 2 here |
| Automatic checking (a self-checking testbench) | Nobody can work out by hand the expected results of ten thousand random operations | Sections 4.9, 4.10 |
| Functional coverage | With random stimulus you do not know what was tested unless you measure it | 10, and Section 4.7 |

### How it works: the coverage-driven loop

```text
        +--------------------------------------------------------------+
        |                                                              |
        v                                                              |
   Run the random tests with many seeds                                |
        |                                                              |
        v                                                              |
   Any failures?  -- yes -->  debug: testbench bug or design bug?      |
        |                     fix, re-run                              |
        no                                                             |
        v                                                              |
   Collect functional and code coverage                                |
        |                                                              |
        v                                                              |
   Coverage goals met?  -- yes -->  done (subject to the exit criteria)|
        |                                                              |
        no                                                             |
        v                                                              |
   Analyse the holes:                                                  |
     - more seeds                                                      |
     - adjust or add constraints / a new derived transaction           |
     - a directed test for the unreachable corner                      |
     - or: the hole is illegal or unreachable -> exclude, with review  |
        |                                                              |
        +--------------------------------------------------------------+
```

This loop is called **coverage-driven verification**.

### Directed versus constrained-random

| Aspect | Directed testing | Constrained-random testing |
|---|---|---|
| Who chooses the stimulus | The engineer, value by value | The constraint solver, within rules set by the engineer |
| One test covers | One scenario | Thousands of scenarios; a different set for each seed |
| Bugs found | Those the engineer anticipated | Also those nobody anticipated |
| Checking | Often a hand-written expected value | Must be automatic: scoreboard, reference model, assertions |
| Knowing what was tested | By reading the test | Only through functional coverage |
| Initial effort | Low: the first test runs on day one | High: an environment must be built first |
| Effort per additional scenario | High | Low: a new constraint or a new seed |
| Reproducing a failure | Trivial | Requires the seed |
| Maintenance when the design changes | Many tests to edit | Mostly the transaction, driver and monitor |
| Best suited to | Small designs, sanity checks, specific corners | Medium and large designs |

### Progress over time

```text
coverage
100% |                                        ...........***********  constrained-random
     |                               ......***                        + a few directed tests
     |                         ...***                                   for the last holes
     |                     ..**                    __________--------  directed only
     |                  .**            _____-------
     |                .*      ____-----
     |               *   __---
     |              * _--
     |          __--*
     |      _--     *
     |  _--        *
     |_-___________*___________________________________________  time
        ^          ^
        |          first random test runs
        first directed test runs
        |<-------->|
         time spent building the
         random environment
```

Directed testing shows progress immediately but slows down, because each new scenario costs a new test. Constrained-random testing shows nothing while the environment is built, then covers the bulk of the plan quickly, and levels off near the end, where the last few holes are closed with tighter constraints or directed tests. Real projects use both.

> **Interview trap:** "Is constrained-random testing always better than directed testing?" No. For a very small block the environment costs more than it returns. Random stimulus may take a very long time to hit a narrow corner that one directed test reaches at once. And without functional coverage, random testing gives a false sense of security. The correct answer is that the two are complementary.

> **Common mistake:** Saying "random testing" when you mean constrained-random. Purely random stimulus is rarely useful; the constraints, the automatic checking and the coverage are what make it a methodology.

### Interview questions

**Q1. What is directed testing?**
A method in which each test is written by hand for one specific scenario, with chosen stimulus values and a known expected result.

**Q2. What is constrained-random testing?**
A method in which the testbench generates stimulus by randomizing transactions under constraints, checks the results automatically, and measures with functional coverage which scenarios were exercised.

**Q3. What are the advantages of constrained-random over directed testing?**
Far more scenarios per unit of effort, discovery of bugs nobody anticipated, and low cost for each additional scenario once the environment exists.

**Q4. What are its disadvantages?**
A larger initial investment in the environment, the need for automatic checking and coverage, failures that are harder to debug because the stimulus was not written by a person, and difficulty reaching some narrow corner cases.

**Q5. Why is functional coverage essential with constrained-random testing?**
Because the stimulus is not written explicitly, there is no other way to know which scenarios actually occurred. Coverage turns "we ran a lot of random tests" into "these planned scenarios were exercised and these were not".

**Q6. Do projects still write directed tests?**
Yes: for sanity checks, reset and register tests, bug reproductions, and for the last coverage holes that random stimulus does not reach.

**Q7. What is coverage-driven verification?**
The iterative flow of running constrained-random tests, measuring coverage, analysing the holes and adjusting constraints or adding tests until the coverage goals in the verification plan are met.
