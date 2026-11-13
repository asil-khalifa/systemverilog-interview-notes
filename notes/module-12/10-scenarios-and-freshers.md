# Industry Scenario Questions

Scenario questions have no single correct answer. The interviewer is listening for a method: you reproduce the problem, narrow it down step by step, name the likely causes in order of probability, and say how you would confirm each one. Answer in numbered steps.

## Debugging Scenarios

**Q292. A test hangs: the simulation never finishes. How do you debug it?**
1. Decide which kind of hang it is. If simulation time keeps increasing, some thread is waiting for something that never happens while the clock keeps running. If time is stuck and the CPU is busy, there is a zero-delay loop.
2. For a zero-delay loop: interrupt the simulator and look at where it is executing. Typical causes are a `forever` or `while` loop with no blocking statement on some path, `wait (e.triggered)` inside a loop, or combinational feedback in the RTL.
3. For a waiting hang: use the log to find the last message from each component (this is why components print with a time and a transaction `id`). The component that went silent first is the starting point.
4. Check the usual suspects: a `get()` on a mailbox nobody fills (two mailbox objects instead of one shared handle), an `@event` that missed its trigger, a `fork`...`join` in which one branch never ends, a semaphore key that was never returned, a driver waiting for a ready signal the DUT never asserts, reset never released, or a wrong end-of-test count.
5. In the waveform, check that the clock is running, reset is released, and whether the DUT is waiting for something from the testbench.
6. Add a watchdog timeout to the testbench so that future hangs end with an error message that says what was being waited for.

**Q293. Functional coverage is stuck at 85% however many seeds are run. What do you do?**
1. Open the coverage report and list the uncovered bins. Do not run more seeds first; if a bin has zero hits after hundreds of runs, more of the same will not help.
2. Classify each hole. (a) Unreachable: the bin describes something the design cannot do or the specification forbids; remove it with `ignore_bins` or `illegal_bins` after confirming with the specification. (b) Blocked by constraints: the stimulus cannot produce it; review the constraints (an over-tight range, a `dist` with weight 0, a conflicting constraint in a base class). (c) Reachable but improbable: for example a cross of two rare conditions, or a FIFO that never fills because reads are as frequent as writes.
3. For (b) and (c), write a targeted test: change the distribution weights, add a constraint in an extended transaction, or shape the timing (many writes with no reads to fill the FIFO).
4. If a few bins remain, write short directed tests for them.
5. Check that the coverage model itself is right: a wrong sampling event or a cross that includes meaningless combinations also shows up as permanent holes.

**Q294. A test passes with one seed and fails with another. What does that tell you and how do you proceed?**
The failing seed generated a scenario the passing seed did not; that is constrained-random testing doing its job. 1. Rerun the failing seed to confirm that it fails every time; a random test must be reproducible with its seed. 2. Find the first error message and the transaction `id` involved, not the last one. 3. Compare that transaction with the specification: is the stimulus legal? If it is illegal, a constraint is missing (testbench bug). If it is legal, compute the expected result by hand to decide whether the reference model or the DUT is wrong. 4. Look for what is special about it: a boundary value, back-to-back operations, an operation during or just after reset. 5. After the fix, rerun the same seed, keep it in the regression, and add a coverage bin for the scenario so that it is tracked from then on.

**Q295. The test passes in RTL simulation but fails in gate-level simulation. Why might that be?**
1. Uninitialised registers. RTL simulation can hide X through X-optimism (`if` and `case` take a definite branch); the netlist propagates X pessimistically. Trace the X back to the first flip-flop that is still X after reset: usually a register without reset that the design reads too early.
2. The testbench hides X in RTL: two-state variables in the monitor or `==` in the scoreboard.
3. Timing. With SDF delays annotated, the testbench may drive inputs too close to the clock edge (setup or hold violations make the flip-flop model output X), or sample outputs before they have settled. Drive and sample with proper skews.
4. Reset and clock sequencing that is too short for the real cells.
5. Differences between RTL and netlist: synthesis interpreted `full_case`/`parallel_case` pragmas or a missing sensitivity-list entry differently from simulation, or the testbench refers to internal signals that were renamed or optimised away.
6. Zero-delay gate simulation races in clock-gating or clock-divider logic.

**Q296. Every scoreboard comparison fails, and the actual value always equals the expected value of the previous (or next) transaction. What is wrong?**
The data is right but the pairing is off by one. Causes, in order: (1) the monitor samples the output in the wrong cycle relative to the inputs, ignoring the DUT's one-cycle latency; (2) the monitor samples on the raw clock edge instead of the clocking block and catches the value from before or after the edge; (3) the scoreboard pushes an expected value for a cycle in which `valid_in` was not really accepted, or the DUT produced an extra output after reset, shifting the queue by one; (4) the first transaction was driven during reset and ignored by the DUT. Confirm by lining up one transaction in the waveform: the cycle the inputs were accepted, the cycle the output appeared, and the cycles in which the monitor captured each.

**Q297. The nightly regression suddenly takes three times as long. How do you find out why?**
1. Find out when it changed and what was checked in on that day (RTL, testbench, scripts, tool version, machine pool).
2. Compare a single test before and after: is the simulated time the same and the wall-clock time longer, or does the test now simulate longer? Longer simulated time means an end-of-test condition changed, for example tests now end on a timeout instead of on completion.
3. If the wall-clock time per simulated cycle went up, use the simulator's profiler. Typical causes: waveform dumping or full debug access switched on for all tests, verbose logging, an assertion or covergroup sampled on every clock on a wide signal, a scoreboard queue or associative array that is never emptied, a polling loop that wakes every time unit, or a `#1` clock where the period used to be larger.
4. Check the infrastructure: fewer machines, licences queuing, compilation no longer shared between tests.

**Q298. `randomize()` fails in one test only. How do you debug it?**
1. Read the solver's message: simulators print the set of conflicting constraints and the values of the state variables involved.
2. List everything that applies in that test: the class constraints, constraints inherited from base classes, constraints added by the extended transaction of this test, the inline `with` block, and any variable whose `rand_mode` is off (it now acts as a constant) or that is non-random by declaration.
3. Look for the contradiction: usually an inline constraint against a class constraint, or a state variable holding a value the constraints do not allow (for example a size left at 0).
4. Isolate by switching constraint blocks off one at a time with `constraint_mode(0)` until the call succeeds; the last one switched off is part of the conflict.
5. Fix by removing the contradiction, making the default constraint `soft`, or disabling it in this test. Check for width or sign problems in the expressions.
6. Make sure every `randomize()` call is checked, so that such a failure stops the test at the point of failure.

**Q299. The DUT outputs are X at the start of every test. Is that a bug?**
Not necessarily. Before reset is applied, flip-flops are X, and that is expected. It is a bug if (1) outputs are still X after reset has been applied and released for the specified time: then a register feeding the output has no reset or reset is not connected; (2) an input of the DUT is undriven (Z) or X because the testbench did not initialise it, which is a testbench bug; (3) there is contention on a net. The testbench should hold all inputs at known idle values during reset, start checking only after reset, and have an assertion that control outputs are not unknown once reset is released.

**Q300. A test fails in the regression but passes when you run it alone. What could be different?**
The seed (the regression uses a random seed; rerun with the seed from the regression log), the command-line arguments and plusargs, the compile options (coverage, assertions or optimisation switched on), the version of the code that was checked out, or files shared between tests (two tests writing to the same output or memory-image file). Reproduce by running the exact command line from the regression log, then remove differences one at a time.

**Q301. Simulations of a long test run out of memory. What do you check in the testbench?**
Objects that are never released: a scoreboard queue or associative array from which matched entries are not deleted, a monitor that stores every transaction "for debug", a mailbox whose consumer is slower than its producer (an unbounded mailbox grows without limit), or threads created with `fork`...`join_none` in a loop that never end. Also check waveform dumping of the whole design and large arrays that are declared as fixed-size where an associative array would store only the used entries.

## Verification-Planning Scenarios

**Q302. How would you verify a synchronous FIFO? Give the plan.**
*Features from the specification*: write when not full, read when not empty, data comes out in the order written, `full` and `empty` flags, behaviour on write-when-full and read-when-empty, simultaneous read and write, reset.

*Stimulus*: a transaction with random `wr_en`, `rd_en`, `din` and idle cycles; constraints or weights to bias towards filling (more writes), draining (more reads) and balanced traffic.

*Checking*: a scoreboard with a queue as reference model: push `din` on every accepted write, pop and compare with `dout` on every accepted read (with `!==`). Assertions: never `full` and `empty` together; `empty` after reset; no change of the pointer on write-when-full or read-when-empty; `full` asserted exactly when the count equals the depth.

*Coverage*: FIFO empty, full, and levels in between; full→not full and empty→not empty transitions; write when full; read when empty; simultaneous read and write at empty, at full and in between; the pointers wrapping around; data values 0x00 and 0xFF.

*Tests*: reset test, fill then drain, alternating write and read, random traffic with several weightings, overflow and underflow attempts, reset in the middle of traffic.

*Exit criteria*: all tests pass, 100% functional coverage, code coverage reviewed with justified exclusions.

**Q303. How would you verify a round-robin arbiter with four requesters?**
*Checks*: at most one grant at a time (`$onehot0(gnt)`), a grant only to a requester that is requesting, a grant within one cycle (or the specified latency) whenever any request is present, and fairness: after requester *i* is served, the next grant goes to the next requesting index in circular order, and no requester waits for more than three other grants. *Reference model*: a small function that keeps the index of the last grant and computes the next expected one. *Stimulus*: random request vectors, with directed patterns for all requesting at once, a single requester, a requester that drops its request, and requests arriving in the same cycle. *Coverage*: each requester granted; each ordered pair "grant to i followed by grant to j"; all sixteen request patterns; reset during a grant.

**Q304. How would you verify a 4-bit up/down counter with load and enable?**
*Features*: reset value, count up, count down, hold when not enabled, load a value, priority between load and count, wrap-around from 15 to 0 and from 0 to 15. *Checking*: a reference model in the scoreboard with one `case` on the control inputs evaluated each clock, compared with the DUT output; assertions such as "when enabled, counting up and not loading, the next value is the current value plus one". *Coverage*: every count value; the transitions 15→0 and 0→15; load of the boundary values 0 and 15; load while counting; each control combination; reset at a non-zero count. *Stimulus*: random control signals with the enable weighted high so that the counter actually moves, plus a directed test that counts through the full range in both directions.

**Q305. All tests pass, but you suspect the testbench is not really checking anything. How do you gain confidence?**
1. Inject a bug on purpose: change one operation in the DUT (or force a signal) and confirm that a test fails. If nothing fails, the checker is not working.
2. Look at the scoreboard counters: the number of comparisons must equal the number of transactions sent. "0 errors out of 0 comparisons" is a classic false pass.
3. Check that the comparison uses `!==`, that the monitor uses four-state types, and that the scoreboard reports an error for leftover expected items.
4. Check assertion coverage: assertions whose antecedent never fired have checked nothing.
5. Review the reference model against the specification, not against the RTL.

**Q306. Functional coverage and code coverage are both 100%, yet a bug is found later. How is that possible?**
Coverage shows that scenarios were exercised, not that the results were checked. Possible reasons: the scoreboard did not check the affected output or field; the feature was missing from the verification plan, so no coverpoint existed for it (functional coverage is only as complete as the plan); the bug needs a combination or sequence that was not crossed; the reference model had the same misunderstanding of the specification as the RTL; or the bug is outside functional simulation (timing, clock-domain crossing, power sequencing). The lesson is that coverage must be paired with checking and with reviews of the plan.

**Q307. You find a mismatch that you believe is an RTL bug. What do you do before and after reporting it?**
Before: make sure it is not a testbench problem by checking the stimulus against the specification and computing the expected value by hand; reduce the failure to the smallest test and a fixed seed; identify the first wrong signal in the waveform. Report with the test name, seed, command line, simulation time of the failure, expected and actual values, the specification section, and the waveform location. After the designer's fix: rerun the failing seed, run the full regression to make sure nothing else broke, keep the test and seed in the regression, and add a coverage bin or assertion for the scenario.

**Q308. The schedule allows two more days and verification is not complete. How do you prioritise?**
By risk. First make sure every feature has at least a basic passing test and that the regression is clean. Then spend the time where a bug would be most damaging or most likely: the main data path, new or recently changed logic, complex control such as corner cases of flags and counters, and anything that failed recently. Close the largest coverage holes with targeted tests. List what remains unverified, with the risk of each item, and tell the lead clearly. Do not report a block as done by quietly excluding the unfinished parts.

# Frequently Asked Fresher Questions

Fresher interviews mix language questions with questions about fundamentals and about how you work. Short, honest, structured answers do best.

**Q309. Explain your project.**
Prepare a two-minute answer with this structure. (1) What the DUT does, in two sentences: "an 8-bit ALU with eight operations; inputs are registered with a valid signal and the 9-bit result appears one clock later". (2) The testbench architecture: generator, driver, monitor, scoreboard, environment, connected with mailboxes and a virtual interface; draw it if a board is available. (3) Your own contribution: which parts you wrote. (4) How it checks: reference model in the scoreboard, assertions, functional coverage and the coverage you reached. (5) One bug you found and how you debugged it; this is the part interviewers remember. Be ready for follow-ups on anything you mention: if you say "mailbox", expect "why not a queue?".

**Q310. What is the difference between verification, validation and testing?**
Verification is done before manufacturing, on the design description (RTL or gates), by simulation, formal methods and emulation: "did we build the design correctly, according to the specification?". Validation is done on the real silicon or a prototype, in the real system with real software: "does the product do what the customer needs?". Testing (manufacturing test) checks every manufactured chip for fabrication defects using scan patterns and built-in self-test; it assumes the design is correct.

**Q311. What is the difference between simulation and synthesis?**
Simulation executes the RTL and the testbench in software to observe behaviour over time; it supports the whole language, including delays, classes and system tasks. Synthesis translates the synthesizable subset of the RTL into a netlist of gates from a technology library, under timing, area and power constraints. Code that simulates is not necessarily synthesizable, and synthesizable code can simulate differently from the gates if it is written badly (incomplete sensitivity lists, mixed blocking and nonblocking assignments), which is called a simulation-synthesis mismatch.

**Q312. Why do you want to work in verification rather than design?**
Give a truthful answer in your own words. Points that are true of the job and worth mentioning: verification takes the majority of the effort on a chip project; it requires understanding the whole design and its specification, not one block; it combines hardware knowledge with software skills (OOP, randomization, debugging); and finding a bug before tape-out has a direct, visible value. Avoid saying that verification is easier or that it is a way into design.

**Q313. What is your approach to debugging a failing test?**
1. Reproduce it with the same seed and options. 2. Read the log from the top and find the first error, not the last. 3. Decide whether the stimulus was legal. 4. Follow the failing transaction through the testbench layers by its ID to find where expected and actual first differ. 5. Open the waveform at that time and trace the wrong signal backwards to its cause. 6. Form one hypothesis and test it; do not change several things at once. 7. Decide whether it is a testbench, reference-model, specification or RTL problem and fix or report it. 8. Rerun the seed and then the regression.

**Q314. What is a self-checking testbench?**
A testbench that decides by itself whether the DUT's outputs are correct, using a scoreboard with a reference model and assertions, and prints a clear PASS or FAIL. Nobody has to inspect waveforms. This is essential for regressions of thousands of random tests.

**Q315. What is a verification plan and what does it contain?**
The document, written from the specification before the testbench, that defines what will be verified and how. It contains the list of features to verify, the testbench architecture, the stimulus strategy (random and directed tests), the checkers and assertions for each feature, the functional coverage model that proves each feature was exercised, the list of tests, the exit criteria (coverage targets, no open bugs) and the schedule. It is the reference for answering "are we done?".

**Q316. What is a regression?**
The complete set of tests for a design, run automatically (usually nightly) with many random seeds, whenever the RTL or the testbench changes. Its purposes are to detect that a change broke something that used to work, and to accumulate coverage. Results are tracked as pass rate and coverage trends.

**Q317. What is a corner case? Give examples for a FIFO.**
A legal but unusual situation at the boundary of the design's behaviour, where bugs are more likely because several conditions meet. For a FIFO: a write when it is full; a read when it is empty; a simultaneous read and write when exactly full or exactly empty; the pointers wrapping from the last location to the first; a single entry written and read back immediately; reset while it is not empty.

**Q318. Give one example each of a compile-time, an elaboration-time and a run-time error in a class-based testbench.**
Compile time: assigning a base-class handle to a derived-class handle without `$cast`, or calling a method that the class does not have. Elaboration time: a module instance whose port list does not match the module, or an interface passed to a port of a different interface type. Run time: using a null handle, a failed `$cast` called as a task, a `randomize()` failure, an out-of-range array index, or an assertion failure.

**Q319. When do you debug with the log and when with the waveform?**
The log is the first tool for a class-based testbench: transactions, comparisons and errors are printed with times and IDs, and classes do not appear in waveforms the way signals do. The waveform is used once the log has pointed to a time and a signal: to see exact cycle timing on the interface, to trace a wrong DUT output back through the RTL, and for X propagation. Start with the log to find *when*, then the waveform to find *why*.

**Q320. What is the difference between `$finish` and `$stop`, and between `$fatal`, `$error`, `$warning` and `$info`?**
`$finish` ends the simulation. `$stop` pauses it and returns control to the interactive simulator prompt, from which it can be continued. The severity tasks all print a message with the time and scope: `$info` is informational, `$warning` flags something suspicious, `$error` reports a failure and lets the simulation continue (the simulator counts errors), and `$fatal` reports a failure and ends the simulation immediately. A scoreboard mismatch is an `$error`; a null virtual interface or a failed randomization is a `$fatal`.

**Q321. What does `` `timescale 1ns/1ps `` mean?**
The first value is the time unit: a delay written as `#1` means 1 ns. The second is the time precision: delays are rounded to the nearest 1 ps, so `#1.2345` becomes 1.235 ns. The precision cannot be larger than the unit. Inside a module, `timeunit 1ns; timeprecision 1ps;` is the SystemVerilog way to say the same without depending on the order in which files are compiled.

**Q322. What are setup time and hold time? Does functional simulation check them?**
Setup time is how long the data input of a flip-flop must be stable before the active clock edge; hold time is how long it must stay stable after the edge. A violation can make the flip-flop metastable. RTL functional simulation has no gate delays and does not check them. They are verified by static timing analysis, and by gate-level simulation with back-annotated SDF delays, where the timing checks in the cell models report violations.

**Q323. What is the difference between a Moore and a Mealy state machine?**
In a Moore machine the outputs depend only on the current state, so they change only after a clock edge and are glitch-free with respect to inputs. In a Mealy machine the outputs depend on the current state and the current inputs, so they can respond in the same cycle as the input, usually with fewer states, but a change on an input passes straight to the output. In the sequence detector of Q209, `det = (state == S101) && din` is a Mealy output.

**Q324. What is the difference between synchronous and asynchronous reset, and how do you verify reset?**
A synchronous reset takes effect only at a clock edge: `always_ff @(posedge clk) if (!rst_n) ...`. An asynchronous reset takes effect as soon as it is asserted, without a clock: `always_ff @(posedge clk or negedge rst_n)`; its release must still be synchronised to the clock. To verify reset: check that every output and important register has its specified value after reset, with no X; apply reset in the middle of activity, not only at time 0, and check that the DUT recovers and works afterwards; for asynchronous reset, assert it away from the clock edge and check that the outputs respond immediately.

**Q325. How does a synchronous FIFO generate `full` and `empty`?**
With a write pointer, a read pointer and a way to tell full from empty when the pointers are equal. One method keeps a counter of the number of entries: increment on write, decrement on read, unchanged on both; `empty` is count == 0 and `full` is count == DEPTH. The other makes the pointers one bit wider than the address: `empty` when the pointers are identical, `full` when they differ only in the extra top bit. A write when full and a read when empty must not change the pointers.

**Q326. How much UVM should a fresher know?**
Know what UVM is and why it exists (Q55), the main components and how they correspond to the plain SystemVerilog layered testbench (sequence item = transaction, sequence = generator, sequencer and driver, monitor, agent, scoreboard, environment, test), the idea of phases, the factory and the configuration database, and how the driver gets items (`get_next_item`, `item_done`). Be honest about the depth: "I have built the layered testbench in plain SystemVerilog and understand how each part maps to UVM" is a strong fresher answer; claiming UVM experience you do not have is quickly exposed.

## Last-Day Revision Checklist

Read each line and answer it aloud in two sentences. If you cannot, go back to the question or module in brackets.

**Language basics**

- Two-state and four-state types; default values; `logic` vs `wire` (Q3, M1).
- `==` vs `===` vs `==?`; which one in a scoreboard (M1, Q177).
- Blocking vs nonblocking assignment (Q56, Q168).
- Fixed, dynamic, associative arrays and queues; their methods (Q57, Q9, Q61).
- Task vs function; `automatic`; `ref` (Q13, Q15, Q65).

**OOP**

- Class, object, handle, `null`, `new` (Q18 to Q20).
- Shallow vs deep copy (Q69, Q156).
- Inheritance, `super`, constructor order (Q71, Q158).
- Virtual methods and polymorphism; `$cast` (Q72, Q73, Q157).
- Abstract class, pure virtual; static members; `local`/`protected` (Q28, Q23, Q24).

**Randomization**

- `rand` vs `randc`; checking `randomize()` (Q29, Q30).
- `inside`, `dist`, implication, `solve before`, `soft`, `unique` (Q78 to Q82).
- `constraint_mode` vs `rand_mode`; `pre_randomize`/`post_randomize` (Q35, Q36, Q170).
- Array constraints with `foreach`, `size()`, `sum()` (Q84, Q236 to Q243).
- Width, sign and chained-comparison traps in constraints (Q182, Q233).

**IPC**

- `join`, `join_any`, `join_none`; `disable fork`; `wait fork` (Q44, Q89, Q162).
- The loop-variable trap with `join_none` (Q92, Q163).
- Mailbox methods; bounded vs unbounded (Q41, Q91, Q165).
- Event: `->`, `->>`, `@`, `wait(triggered)` (Q88, Q90, Q166).
- Semaphore; deadlock; race condition (Q42, Q267, Q268).

**Testbench**

- Interface, modport, clocking block, virtual interface (Q45 to Q48, Q94).
- Why the clocking block removes races; event regions (Q111, Q113).
- Role of each component and the flow of one transaction (Q49, Q276).
- Why the scoreboard listens to the monitor; how the test ends (Q279, Q282).
- One object per transaction in generator and monitor (Q172, Q183).

**Coverage and assertions**

- Code vs functional coverage; bins, cross, `ignore_bins`, `illegal_bins` (Q39, Q99, Q101).
- Immediate vs concurrent; `|->` vs `|=>`; `disable iff`; `$past`, `$rose` (Q50, Q51, Q104, Q105).
- Vacuous success (Q142).

**Yourself**

- Your project in two minutes, with one bug you found (Q309).
- Your debugging method in numbered steps (Q313).
- Verification plan for a FIFO (Q302).
