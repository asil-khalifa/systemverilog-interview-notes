# Part 5: The Complete Verification Flow, Worked Through for the ALU

Part 4 described the pieces. This part applies them, in order, to one design, so that you can see what each step produces and how one leads to the next. The design is the 8-bit ALU from Module 1. It is small enough to keep every table on one page, and the steps are the same ones used for a design a thousand times larger.

## 5.1 The Flow at a Glance

```text
   1. Understand the specification  ------>  list of requirements, list of questions
            |
            v
   2. Extract the features          ------>  feature list (F1, F2, ...)
            |
            v
   3. Write the verification plan   ------>  per feature: stimulus, check, coverage
            |
            v
   4. Design the testbench          ------>  architecture diagram, component list
            |
            v
   5. Write the test plan           ------>  list of tests (T1, T2, ...)
            |
            v
   6. Write the coverage plan       ------>  coverage items (C1, ...), assertions (A1, ...)
            |
            v
   7. Build, bring up, run, debug   ------>  passing tests, bug reports, fixes
            |
            v
   8. Regression                    ------>  pass rate over all tests and many seeds
            |
            v
   9. Coverage closure              ------>  holes analysed and closed or justified
            |
            v
   10. Sign-off                     ------>  exit criteria met, results reviewed
```

Steps 1 to 6 are planning and are done largely before any testbench code exists. Steps 7 to 9 form a loop that is repeated many times. Step 10 happens once.

| Step | Main deliverable | Who is involved |
|---|---|---|
| 1 | Clarified specification | Verification engineer, designer, architect |
| 2, 3 | Verification plan | Verification engineer writes; designer and architect review |
| 4 | Testbench architecture | Verification engineer or lead |
| 5, 6 | Test plan, coverage plan | Verification engineer; reviewed by designer |
| 7 | Testbench code, tests, bug reports | Verification engineer; designer fixes RTL |
| 8 | Regression reports | Verification engineer; automated infrastructure |
| 9 | Coverage reports, exclusion list | Verification engineer; designer reviews exclusions |
| 10 | Sign-off review | Whole team and management |

## 5.2 Step 1: Understand the Specification

### The specification, as numbered requirements

Rewriting the specification as a numbered list is the first act of verification. Each line can later be traced to a check and a coverage item.

| Req | Requirement |
|---|---|
| R1 | Inputs: `a[7:0]`, `b[7:0]`, `op[2:0]`, `valid_in`. Outputs: `result[8:0]`, `valid_out`. Clock `clk`; reset `rst_n` |
| R2 | An operation is accepted at a rising edge of `clk` at which `valid_in` is 1 |
| R3 | The result of an accepted operation appears on `result` in the following cycle, with `valid_out` = 1 |
| R4 | `valid_out` is 0 in a cycle that does not follow an accepted operation |
| R5 | `ALU_ADD`: `result` = `a + b`; bit 8 is the carry |
| R6 | `ALU_SUB`: `result` = `a - b` computed in nine bits; bit 8 is the borrow |
| R7 | `ALU_AND`, `ALU_OR`, `ALU_XOR`: bitwise operation on `a` and `b`; bit 8 is 0 |
| R8 | `ALU_NOT`: `result[7:0]` = `~a`; bit 8 is 0 |
| R9 | `ALU_SHL`: `a` shifted left by one; the old `a[7]` appears in bit 8; bit 0 is 0 |
| R10 | `ALU_SHR`: `a` shifted right by one; bits 8 and 7 are 0 |
| R11 | `rst_n` is asynchronous and active low. While it is low, `valid_out` = 0 and `result` = 0 |

### Questions raised while reading

A specification this short leaves gaps. Finding them is part of the work, and each answer is added to the specification.

| # | Question | Agreed answer |
|---|---|---|
| Q-1 | What is the value of `result` in a cycle where `valid_out` is 0? | Not specified; `result` is only meaningful when `valid_out` is 1. The testbench shall not check it otherwise |
| Q-2 | May `valid_in` be high in consecutive cycles (back-to-back operations)? | Yes. There is no back-pressure; one operation can be accepted every cycle |
| Q-3 | Is `b` used by the single-operand operations (NOT, SHL, SHR)? | No. `b` must have no effect on the result |
| Q-4 | What happens if `rst_n` goes low while an operation is in progress? | The operation is discarded; outputs go to 0 immediately and stay 0 until a new operation is accepted after reset is released |
| Q-5 | May `a`, `b` and `op` change while `valid_in` is 0? | Yes; they are ignored |
| Q-6 | Are all eight values of `op` legal? | Yes; there are no reserved encodings |

The answers Q-2, Q-3 and Q-4 each produce a new feature that was not in the original text.

> **Key point:** A question such as Q-1 must be settled by the specification owner, not by reading the RTL. The RTL happens to hold the previous `result` when `valid_in` is 0, but if the testbench checked for that, it would be verifying an implementation detail and would fail on a perfectly valid redesign.

## 5.3 Step 2: Extract the Features

| ID | Feature | From | Priority |
|---|---|---|---|
| F1 | Reset: outputs are 0 while `rst_n` is low | R11 | High |
| F2 | Handshake: `valid_out` follows `valid_in` by exactly one cycle | R2, R3, R4 | High |
| F3 | ADD, including carry | R5 | High |
| F4 | SUB, including borrow | R6 | High |
| F5 | AND | R7 | High |
| F6 | OR | R7 | High |
| F7 | XOR | R7 | High |
| F8 | NOT | R8 | High |
| F9 | SHL, including the bit shifted into bit 8 | R9 | High |
| F10 | SHR, including the bit shifted out | R10 | High |
| F11 | Operand corner values with every operation: 0, `FF`, `a == b`, single bit set | R5 to R10 | High |
| F12 | Back-to-back operations with no idle cycle | Q-2 | Medium |
| F13 | Idle gaps of varying length; inputs changing while `valid_in` is 0 | R2, Q-5 | Medium |
| F14 | `b` has no effect on NOT, SHL, SHR | Q-3 | Medium |
| F15 | Reset in the middle of an operation, and operation immediately after reset | Q-4 | High |
| F16 | Outputs are never X or Z after reset | General | High |

## 5.4 Step 3: The Verification Plan

One row per feature: how it will be stimulated, how it will be checked, and what will show that it was exercised. Identifiers beginning with T, C and A refer to the test plan, coverage plan and assertion list in the following sections.

| ID | Stimulus | Check | Coverage | Tests |
|---|---|---|---|---|
| F1 | Reset at time 0 | A1 | C8 | T1, T2 |
| F2 | Any valid operation; varied gaps | A2, A3 | C6 | All |
| F3 | `alu_txn` with `op == ALU_ADD`; `alu_carry_txn` | Scoreboard with `alu_predict` | C1, C4, C5 | T3, T4, T5 |
| F4 | `alu_txn` with `op == ALU_SUB`; constraint `a < b` for borrow | Scoreboard | C1, C4, C5 | T3, T4, T5 |
| F5 to F7 | `alu_txn` with the logic opcodes | Scoreboard | C1, C4 | T3, T4, T6 |
| F8 | `alu_txn` with `op == ALU_NOT` | Scoreboard | C1, C4 | T3, T4, T6 |
| F9, F10 | `alu_shift_txn` | Scoreboard | C1, C4, C5 | T3, T4, T7 |
| F11 | `corner_c` bias in `alu_txn`; directed corners | Scoreboard | C2, C3, C4 | T3, T4 |
| F12 | Driver with zero idle cycles between transactions | Scoreboard; A2 | C6 | T8 |
| F13 | Random idle gaps of 0 to 5 cycles; random pin values while idle | Scoreboard; A3 | C6 | T9 |
| F14 | Unary opcodes with unconstrained random `b` | Scoreboard (the model ignores `b`) | C7 | T4, T7 |
| F15 | Reset asserted at a random time during the test | A1; scoreboard flushed on reset | C8 | T10 |
| F16 | All tests | A4 | n/a | All |

**Strategy.** Block-level simulation with a layered, class-based, constrained-random testbench, plus a small number of directed tests for sanity, reset and named corners. The design is small enough for formal verification as well, which would be listed here as an additional method on a real project.

## 5.5 Step 4: Testbench Architecture

```text
+------------------------------------- tb_top (module) ------------------------------------+
|                                                                                          |
|   clock and reset generation                                                             |
|                                                                                          |
|   +------------------------------- alu_test ----------------------------------------+    |
|   |   chooses the transaction type, the number of transactions, the idle-gap policy |    |
|   |                                                                                 |    |
|   |   +---------------------------- alu_env -------------------------------------+  |    |
|   |   |                                                                          |  |    |
|   |   |   alu_generator --gen2drv_mbx--> alu_driver         alu_scoreboard       |  |    |
|   |   |   (randomizes                    (txn -> pins)      (alu_predict,        |  |    |
|   |   |    alu_txn)                           |              compare, report)    |  |    |
|   |   |                                       |                    ^             |  |    |
|   |   |                                       |               mon2scb_mbx        |  |    |
|   |   |                                       |                    |             |  |    |
|   |   |                                       |              alu_monitor         |  |    |
|   |   |                                       |              (pins -> txn)       |  |    |
|   |   +---------------------------------------|--------------------^-------------+  |    |
|   +-------------------------------------------|--------------------|----------------+    |
|                                               v  vif               |  vif                |
|                              +----------------------------------------------+            |
|                              |     alu_if  (signals, drv_cb, mon_cb,        |            |
|                              |              modports, assertions)           |            |
|                              +----------------------------------------------+            |
|                                               |                    ^                     |
|                                               v                    |                     |
|                                        +-----------------------------+                   |
|                                        |          alu  (DUT)         |                   |
|                                        +-----------------------------+                   |
+------------------------------------------------------------------------------------------+
```

| Component | Responsibility | Uses from `alu_txn` |
|---|---|---|
| `alu_generator` | Creates and randomizes transactions; sends them to the driver; signals `gen_done` | `new`, `randomize`, `copy`, `print` |
| `alu_driver` | Takes a transaction from `gen2drv_mbx` and drives `valid_in`, `a`, `b`, `op` through `vif` | Fields `a`, `b`, `op`; `print` |
| `alu_monitor` | Samples the pins through `vif`; builds a transaction containing the observed inputs and `result`; sends it to the scoreboard | `new`, fields, `print` |
| `alu_scoreboard` | Predicts with `alu_predict`, compares, counts, reports | `compare` or field compare, `convert2string` |
| `alu_env` | Creates the components and mailboxes, connects them, starts them | |
| `alu_test` | Configures the environment for one scenario | Derived transaction classes |
| `alu_if` | Bundles the signals; clocking blocks give race-free driving and sampling; holds the assertions | |
| `tb_top` | Instantiates the DUT and the interface, generates clock and reset, starts the test | |

The transaction class of Part 3 is the first piece of this architecture, and the flat testbench of Section 4.9 already contains every function in miniature. Modules 7 and 8 supply the two missing mechanisms (mailboxes and virtual interfaces), and Module 9 builds the complete structure.

## 5.6 Step 5: The Test Plan

| ID | Test name | Objective | Type | Stimulus | Features |
|---|---|---|---|---|---|
| T1 | `alu_sanity_test` | Design and testbench are alive | Directed | Reset, then one operation of each opcode with simple operands | F1 to F10 |
| T2 | `alu_reset_test` | Reset values; first operation after reset | Directed | Reset; check outputs; one operation in the first cycle after release | F1, F15 |
| T3 | `alu_corner_test` | Named corner cases | Directed | `FF + FF`, `00 + 00`, `FF + 01`, `00 - 01`, `00 - FF`, `7F - 7F`, `SHL 80`, `SHR 01`, `NOT 00`, `NOT FF`, logic operations with `00`, `FF`, `55`, `AA` | F3 to F11 |
| T4 | `alu_random_test` | Broad coverage of all operations and operands | Constrained-random | 5,000 `alu_txn` with default constraints | F2 to F14 |
| T5 | `alu_arith_test` | Carry and borrow | Constrained-random | 1,000 `alu_carry_txn`; 1,000 SUB with `a < b` | F3, F4 |
| T6 | `alu_logic_test` | Logic operations with varied bit patterns | Constrained-random | 1,000 transactions with `op inside {ALU_AND, ALU_OR, ALU_XOR, ALU_NOT}`, corner bias off | F5 to F8 |
| T7 | `alu_shift_test` | Shifts, with `b` random | Constrained-random | 1,000 `alu_shift_txn` | F9, F10, F14 |
| T8 | `alu_back_to_back_test` | Maximum throughput | Constrained-random | 2,000 transactions, zero idle cycles | F12 |
| T9 | `alu_idle_gap_test` | Idle behaviour | Constrained-random | 1,000 transactions, 0 to 5 idle cycles between them, pins randomized while idle | F13 |
| T10 | `alu_reset_mid_test` | Reset during operation | Random with directed event | Random traffic; `rst_n` pulsed low at random times, several times | F15 |

Pass criteria for every test: the scoreboard reports zero mismatches and a non-zero number of comparisons equal to the number of transactions accepted by the DUT; no assertion fails; no `$error` or `$fatal`; the test ends by itself before the timeout.

Notice how few of these need new code. T4 to T9 use one environment; each differs only in which transaction class is given to the generator, how many transactions are requested and one driver setting. That is the pay-off of the reuse built into the transaction in Section 3.4.

## 5.7 Step 6: The Coverage Plan and the Assertion List

### Functional coverage items

| ID | Item | Bins | Goal |
|---|---|---|---|
| C1 | `op` | One per opcode (8) | All hit |
| C2 | `a` | `00`, `FF`, `01`, `80`, others | All hit |
| C3 | `b` | `00`, `FF`, `01`, `80`, others | All hit |
| C4 | Cross of C1 with C2 and with C3 | 8 × 5 each | All hit |
| C5 | `result[8]` for ADD, SUB and SHL | 0 and 1 for each of the three | All hit |
| C6 | Idle cycles between consecutive operations | 0, 1, 2 to 5 | All hit |
| C7 | For NOT, SHL, SHR: `b` | `00`, non-zero | All hit |
| C8 | Reset while `valid_in` or `valid_out` is high | Occurred | Hit at least once |
| C9 | `a` compared with `b`, for SUB | `a < b`, `a == b`, `a > b` | All hit |

### Code coverage goals

| Type | Goal |
|---|---|
| Statement, branch, condition | 100 percent; any exclusion needs a written, reviewed justification |
| Toggle | 100 percent on all ports and registers |
| FSM | Not applicable (no state machine) |

### Assertions

A preview; the syntax is explained in Module 10. They are placed in `alu_if` so that they are active in every test.

| ID | Rule | Property |
|---|---|---|
| A1 | Outputs are 0 while reset is active | Checked whenever `rst_n` is low |
| A2 | An accepted operation produces `valid_out` in the next cycle | `valid_in \|=> valid_out` |
| A3 | No `valid_out` without a preceding `valid_in` | `!valid_in \|=> !valid_out` |
| A4 | Outputs are known | `valid_out` is never X or Z; `result` is not X or Z when `valid_out` is 1 |

```systemverilog
// A2 and A3, as they will appear in the interface (Module 10)
assert property (@(posedge clk) disable iff (!rst_n)  valid_in |=>  valid_out);
assert property (@(posedge clk) disable iff (!rst_n) !valid_in |=> !valid_out);
```

### Division of labour between the checkers

| What is checked | By |
|---|---|
| Data: is `result` the right value? | Scoreboard and reference model |
| Timing and protocol: does `valid_out` appear in the right cycle? | Assertions |
| Was it exercised? | Functional coverage |

## 5.8 Step 7: Build, Bring Up, Run and Debug

### Order of work

| Stage | Activity | Typical first failures |
|---|---|---|
| 1 | Compile the RTL and the testbench together | Port mismatches, missing imports |
| 2 | Run T1, the sanity test | Clock or reset not toggling; driver on the wrong edge; monitor never sees `valid_out` |
| 3 | Run the remaining directed tests T2, T3 | Reference model errors; real design bugs in corner cases |
| 4 | Run T4 with one seed, then with several | Constraint failures; scoreboard out of step; design bugs |
| 5 | Run the focused random tests T5 to T10 | Design bugs in handshake and reset behaviour |
| 6 | Switch on coverage collection and look at the first report | Bins that can never be hit; missing bins |

In the first days most failures are testbench bugs. That is normal. The sanity test exists so that these are found with a ten-line stimulus instead of a five-thousand-transaction one.

### Debugging a failure

1. Read the first error in the log, not the last. Later errors are often consequences.
2. Note the time, the transaction ID and the seed.
3. Re-run with the same seed, with waveform dumping and more verbose printing.
4. Decide which of the three suspects is at fault (Section 4.10): design, testbench or specification.
5. If it is the design, reduce the case to the smallest stimulus that shows it, and file a bug.

### The bug life cycle

```text
                         +-------+
   failure analysed -->  |  NEW  |   reported with test name, seed, time, expected, actual
                         +-------+
                             |
                             v
                        +----------+        not a design bug: testbench error, duplicate,
                        | ASSIGNED | -----> or behaviour is as specified
                        +----------+                    |
                             |                          v
                 designer finds root cause         +----------+
                 and changes the RTL               | REJECTED |
                             |                     +----------+
                             v
                         +-------+
                         | FIXED |
                         +-------+
                             |
          verification re-runs the failing test with the same seed,
          then the regression
                             |
               +-------------+--------------+
               |                            |
          still fails                     passes
               |                            |
               v                            v
          +----------+                 +----------+       +--------+
          | REOPENED | --> ASSIGNED    | VERIFIED | ----> | CLOSED |
          +----------+                 +----------+       +--------+
```

The exact state names depend on the tracking tool; the sequence does not.

**What a good bug report contains**

| Field | Example |
|---|---|
| Title | "ALU_SUB gives `b - a` instead of `a - b` when `a != b`" |
| Design and version | `alu`, RTL revision identifier |
| Test and seed | `alu_random_test`, seed 1234567 |
| How to reproduce | The exact simulation command |
| Time of failure | 70 ns |
| Observed | `a=00 b=FF op=ALU_SUB`, `result=0FF` |
| Expected | `result=101` |
| Specification reference | R6 |
| Severity / priority | High: wrong functional result |
| Attachments | Log excerpt, waveform location |

**After the fix**

- Re-run the failing test with the failing seed: it must pass.
- Run the full regression: the fix must not have broken anything else.
- Ask why the bug was not found earlier, and whether a coverage item or a test should be added so that this class of bug cannot return unnoticed.
- Only then close the bug.

> **Interview trap:** "Who closes a bug?" The verification engineer who reported it, after confirming the fix by re-running the failing test and the regression. The designer marks it fixed; they do not close it.

## 5.9 Step 8: Regression

### Definition

A **regression** is the re-running of the complete set of tests, usually automatically and usually every night, to confirm that everything that passed before still passes after the latest changes to the RTL or the testbench. For constrained-random tests, each test is run many times with different **seeds**, so that every run exercises different stimulus.

### How a regression is organised

| Tier | Contents | Run | Purpose |
|---|---|---|---|
| Sanity / smoke | A handful of short tests, fixed seeds | Before every check-in; minutes | Stop a broken change from entering the repository |
| Nightly | All tests, several random seeds each | Every night; hours | Detect regressions quickly; accumulate coverage |
| Weekly / full | All tests, many seeds, coverage merged, sometimes gate-level | Weekly and before milestones | Coverage closure and sign-off data |

### Seeds

A random test is identified by its name **and** its seed. The regression script chooses new seeds for every run and records them. A failing (test, seed) pair is re-run with the same seed to reproduce the failure. The seed is passed on the simulator command line; the option differs per tool.

| Simulator | Fixed seed | Random seed |
|---|---|---|
| Synopsys VCS | `+ntb_random_seed=1234` | `+ntb_random_seed_automatic` |
| Siemens Questa | `-sv_seed 1234` | `-sv_seed random` |
| Cadence Xcelium | `-svseed 1234` | `-svseed random` |

Reproduction requires the same seed, the same simulator version and the same source code. Editing the testbench can change the stimulus a seed produces, which is why a failing seed is debugged before unrelated changes are merged.

### A regression report

```text
   Regression 2026-11-13   RTL rev 41   TB rev 97

   test                      seeds   pass   fail
   -----------------------   -----   ----   ----
   alu_sanity_test               1      1      0
   alu_reset_test                1      1      0
   alu_corner_test               1      1      0
   alu_random_test              50     49      1     seed 88213704: scoreboard mismatch
   alu_arith_test               20     20      0
   alu_logic_test               20     20      0
   alu_shift_test               20     20      0
   alu_back_to_back_test        20     20      0
   alu_idle_gap_test            20     20      0
   alu_reset_mid_test           20     18      2     seeds 5512, 90417: assertion A3
   -----------------------   -----   ----   ----
   total                       173    170      3     pass rate 98.3 %

   functional coverage 94.2 %    code coverage: stmt 100, branch 100, cond 97.5, toggle 99.1
```

**Triage.** Each failure is examined and grouped by signature (the first error message). The two `alu_reset_mid_test` failures have the same signature and are almost certainly one bug. Three failing runs here mean two problems to debug.

### Interview questions on regression

**Q. What is a regression and why is it run?**
The periodic re-running of all tests, with many seeds, to check that recent changes have not broken previously working behaviour and to accumulate coverage.

**Q. Why run the same random test with different seeds?**
Each seed produces a different sequence of random stimulus. More seeds mean more scenarios explored and more coverage, at no additional coding cost.

**Q. A test fails in the regression but passes when you run it. What do you check?**
Whether you used the same seed, the same code revision, the same simulator version and the same compile and run-time options. A random test with a different seed is a different test.

## 5.10 Step 9: Coverage Closure

Coverage closure is the process of taking the merged coverage of the regression from "most" to the goal, by analysing every remaining hole.

### The procedure

1. Merge the coverage databases of all **passing** runs.
2. List the uncovered functional bins and the uncovered code.
3. For each hole, find the cause and choose the action:

| Hole (ALU example) | Cause | Action |
|---|---|---|
| Cross bin `ALU_SHR` × `a == 80` never hit | Rare: needs one specific value with one opcode | More seeds, or add `8'h80` and `8'h01` to the `dist` in `corner_c` |
| C9 bin `a == b` for SUB never hit | Probability 1 in 256 per subtraction, and only a few subtractions per test | Add a derived transaction with `op == ALU_SUB; a == b;`, or a directed test |
| C8, reset while `valid_out` is high | Reset pulses in T10 landed only in idle cycles | Constrain the reset time relative to the traffic |
| Condition coverage: one sub-expression of the reset logic never false | Can only happen if `rst_n` is X | Exclude, with justification, reviewed by the designer |
| A coverage bin for an illegal `op` value | All eight encodings are legal; the bin can never exist | The coverage model is wrong: remove the bin |

4. Re-run and re-merge. Repeat until the goals are met.

### Typical progress

```text
   bugs found                            coverage
   per week                              100% |                       ............
        |      **                             |                ......
        |    **  **                           |           ....
        |   *      **                         |        ...
        |  *         ***                      |     ..
        | *             ****                  |   ..
        |*                  ******            |  .
        +--------------------------- time     +---------------------------------- time
          bring-up   main     closure           bring-up    main        closure
```

Early in the project bugs are found quickly and coverage rises fast. Toward the end the bug rate falls and coverage levels off. A bug rate that has fallen to near zero while coverage is at its goal is one of the signals that verification is nearing completion. A bug rate that is still high means it is not, whatever the coverage figure says.

> **Common mistake:** Treating coverage closure as "making the number reach 100". The number is a means. Each hole is a question: "why has this not happened?" The answer is sometimes a weak test, sometimes an error in the coverage model, and sometimes a design bug that makes the scenario impossible. Excluding holes without understanding them defeats the purpose.

## 5.11 Step 10: Sign-Off, or What "Done" Means

Verification can never prove the absence of bugs, so "done" cannot mean "no bugs remain". It means that a set of **exit criteria**, agreed in the verification plan at the start, has been met, and that the remaining risk has been judged acceptable.

### Typical exit criteria

| Criterion | ALU example |
|---|---|
| Every feature in the verification plan is implemented in tests, checks and coverage | F1 to F16 each map to at least one test, one check and one coverage item |
| All tests pass | 100 percent pass rate over the full regression with many seeds, for an agreed number of consecutive runs |
| Functional coverage goal met | C1 to C9 at 100 percent |
| Code coverage goal met | Statement, branch, condition and toggle at 100 percent, with every exclusion justified and reviewed |
| All assertions pass and have been exercised | A1 to A4 never failed, and each was triggered (a property that was never triggered has checked nothing) |
| No open high-priority bugs | All critical and major bugs closed; any remaining minor ones documented and accepted |
| Bug discovery rate has levelled off | No new bugs for an agreed period of regressions |
| Reviews completed | Testbench, checkers, coverage model and exclusions reviewed by the designer and a second verification engineer |
| The RTL is frozen | The sign-off regression was run on the final version of the code |
| Results are documented | A report recording all of the above |

### The sign-off review

At the review the verification engineer presents: the plan and its traceability (requirement → feature → test, check, coverage); regression history; coverage reports with the exclusion list; the bug history; known limitations and anything deliberately not verified at this level. The team decides whether the criteria are met.

> **How to say it in an interview:** "Verification is done when the exit criteria in the plan are met: every planned feature has tests, checks and coverage; the regression passes cleanly over many seeds; functional and code coverage are at their goals with reviewed exclusions; there are no open critical bugs; and the bug rate has flattened. It is a judgement about risk backed by metrics, not a proof that no bugs exist."

### Interview questions

**Q1. Walk me through how you would verify a block from start to finish.**
Read the specification and resolve open questions; extract the features; write the verification plan with stimulus, checking and coverage per feature; design the testbench architecture; write the test plan and coverage plan; build the testbench and bring it up with a sanity test; run directed and constrained-random tests, debug failures and file bugs; run regressions with many seeds; analyse and close coverage holes; and sign off against the exit criteria.

**Q2. How do you know when verification is complete?**
When the agreed exit criteria are met: all planned tests implemented and passing in regression, functional and code coverage goals reached with reviewed exclusions, assertions passing and exercised, no open high-priority bugs, and a bug discovery rate that has levelled off.

**Q3. What is traceability in a verification plan?**
The ability to follow each requirement of the specification to the feature that represents it, and from there to the tests that stimulate it, the checkers that verify it and the coverage items that show it was exercised, and back again.

**Q4. Describe the life cycle of a bug.**
The verification engineer reports it (new) with the test, seed and expected versus actual values. It is assigned to the designer, who either rejects it with a reason or fixes it. Verification re-runs the failing test with the same seed and then the regression; if it passes the bug is verified and closed, otherwise it is reopened.

**Q5. What information do you include in a bug report?**
A precise title, design version, test name and seed, the command to reproduce it, the time of failure, the observed and expected behaviour with a reference to the specification, severity, and the location of logs and waveforms.

**Q6. What is coverage closure?**
The work of analysing every uncovered item in the merged coverage results and resolving it, by more seeds, better constraints, directed tests, correcting the coverage model, or a justified exclusion, until the coverage goals are met.

**Q7. The designer says "that scenario can never happen, exclude it". What do you do?**
Ask why it cannot happen and confirm it independently, ideally with an assertion that would fail if it ever did. Record the justification with the exclusion and have it reviewed. If the reasoning depends on how the block is used in the larger system, that assumption must be documented and checked at the level above.

**Q8. During verification you find that the specification is ambiguous. What do you do?**
Raise it with the specification owner, get the intended behaviour decided and recorded in the specification, and update the plan, the reference model and the tests to match. The RTL's current behaviour is not the authority.

**Q9. Which checks belong in the scoreboard and which in assertions?**
Data correctness, which needs a model of the function, belongs in the scoreboard. Timing and protocol rules about signals over clock cycles, such as handshakes and reset behaviour, are best written as assertions, which run in every test and point to the exact cycle of failure.

**Q10. Why is the sanity test run first after every change?**
It is short and exercises the basic path through the DUT and the whole testbench. If it fails, something fundamental is broken, and there is no point in spending hours of compute on the rest of the regression.
