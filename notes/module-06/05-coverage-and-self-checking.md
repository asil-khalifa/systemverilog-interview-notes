## 4.7 Functional Coverage

This section treats coverage at the planning level: what it is, why it is in the plan, and how its items are derived. The `covergroup` syntax is the subject of Module 10.

### In plain English

After running a thousand random ALU operations you are asked: "Did you test a subtraction that borrows? An addition of `FF` and `FF`? Every opcode with a zero operand?" With random stimulus you cannot answer from memory or by reading the test. Functional coverage is a set of counters, written by the verification engineer, that record whether each scenario of interest actually happened.

### Technical definition

**Functional coverage** is a user-defined metric that measures how much of the design's specified functionality has been exercised by the tests. The engineer describes the values, combinations and sequences that matter (the **coverage model**), and the simulator records which of them occurred. It is derived from the specification and the verification plan, not from the code.

### Why it is needed

| Question | Answered by |
|---|---|
| Is the DUT output correct? | Checkers: scoreboard and assertions |
| Did the test exercise the scenario I care about? | Functional coverage |

The two are independent and both are necessary. A test in which the scoreboard reports no errors and coverage is 20 percent has verified 20 percent of the plan. A test with 100 percent coverage and no checking has verified nothing.

### How a coverage plan is derived

Each feature and scenario in the verification plan is turned into something countable:

| Plan item | Coverage item |
|---|---|
| Every operation is exercised | A coverage point on `op` with one bin per opcode |
| Operand corner values | Coverage points on `a` and `b` with bins: zero, maximum, everything else |
| Every operation with every operand class | A **cross** of the `op` point with the `a` and `b` points |
| ADD with and without carry | A bin for `result[8]` equal to 0 and to 1, sampled only when `op` is ADD |
| Back-to-back operations | A transition or sequence item: `valid_in` high in two consecutive cycles |
| Reset during an operation | A cover property |

A preview of how the first few rows look in code (explained in Module 10):

```systemverilog
covergroup alu_cg with function sample(alu_txn t);
  cp_op : coverpoint t.op;                                   // 8 automatic bins
  cp_a  : coverpoint t.a {
            bins zero = {8'h00};
            bins max  = {8'hFF};
            bins mid  = {[8'h01:8'hFE]};
          }
  cx_op_a : cross cp_op, cp_a;                               // 8 x 3 = 24 bins
endgroup
```

### Properties of functional coverage

| Property | Explanation |
|---|---|
| Written by hand | It is only as good as the coverage model. A scenario nobody thought of has no bin, and 100 percent says nothing about it |
| Derived from the specification | It measures intended behaviour, independent of how the RTL is written |
| Reported as a percentage of bins hit | Merged across all tests and seeds of a regression |
| Meaningful only with checking | A bin may be hit only in a test that failed; results from failing tests are not counted |

## 4.8 Code Coverage

### In plain English

Code coverage answers a simpler, mechanical question: **which parts of the RTL source code were executed by the tests?** If a line of the design never ran, no test can have checked it. The simulator collects this automatically; the engineer writes nothing.

### Technical definition

**Code coverage** is a tool-generated metric that measures how much of the design's implementation (statements, branches, conditions, signal toggles, state-machine states and transitions) has been activated during simulation. It is enabled with a simulator option and is collected on the DUT, not on the testbench.

### The types of code coverage

Using this fragment:

```systemverilog
always_comb begin
  y = '0;                           // statement 1
  if (en && (a > b || c))           // one branch with two outcomes; three conditions
    y = a;                          // statement 2
  else
    y = b;                          // statement 3
end
```

| Type | Measures | In the fragment |
|---|---|---|
| Statement (line) | Was each executable statement executed? | All three assignments must run. Two tests suffice: one taking the `if`, one taking the `else` |
| Branch (decision) | Was each branch of every `if`, `case` and `?:` taken, both true and false? | The `if` must evaluate true at least once and false at least once. An `if` with no `else` still has an implicit false branch |
| Condition | Did each sub-condition of a decision take both values? | `en`, `a > b` and `c` must each be seen true and false |
| Expression | Did each operand of an expression on the right-hand side control the result? | Same idea, applied to assignments such as `y = p & (q \| r)` |
| Toggle | Did each bit of each signal change 0→1 and 1→0? | Every bit of `a`, `b`, `y`, and `en`, `c` |
| FSM state | Was each state of each state machine entered? | Not applicable here |
| FSM transition (arc) | Was each possible state-to-state transition taken? | Not applicable here |

Why the stricter types matter: with `en=1, a>b=1, c=0` and `en=0`, statement and branch coverage are both 100 percent, yet `c` has never been 1. If the designer wrote `||` where `&&` was intended, these two tests would not show it. Condition coverage reports that `c` was never exercised.

### Code coverage versus functional coverage

| Aspect | Code coverage | Functional coverage |
|---|---|---|
| Measures | How much of the implementation was executed | How much of the specified functionality was exercised |
| Derived from | The RTL source | The specification and verification plan |
| Written by | Nobody; generated by the tool | The verification engineer |
| Effort | A simulator switch | Design, coding and review of the coverage model |
| Can detect a missing feature | No. Code that was never written cannot be uncovered | Yes, if the plan lists the feature |
| Can detect unexercised code | Yes | No |
| Can detect unreachable (dead) code | Yes | No |
| Knows about combinations and sequences | No | Yes, through crosses and transitions |
| 100 percent means | Every line, branch and so on was activated | Every scenario in the model occurred |
| 100 percent does **not** mean | That the outputs were checked, or that every feature exists | That the model was complete |

### Reading the two together

| Functional coverage | Code coverage | Interpretation | Action |
|---|---|---|---|
| High | High | The plan has been exercised and so has the code | Check the remaining criteria and sign off |
| High | Low | The planned scenarios occurred but part of the RTL never ran | The coverage model is missing features, or there is dead or unreachable code, or an undocumented feature exists. Review the uncovered code with the designer |
| Low | High | The code was executed but the planned scenarios did not occur | Stimulus is too shallow: lines were touched without the interesting values, combinations or sequences. Improve constraints, add tests. (Or the model contains unreachable bins) |
| Low | Low | Early in the project, or the tests are ineffective | More tests, more seeds, better constraints |

> **Interview trap:** "We have 100 percent code coverage. Are we done?" No. Code coverage shows that the code was executed, not that its results were checked, and it cannot reveal a feature the designer forgot to implement. It is a necessary condition for sign-off, not a sufficient one.

> **Interview trap:** "We have 100 percent functional coverage. Are we done?" No. The coverage model was written by people and may be incomplete; code coverage is used to find what it missed. Sign-off needs both, plus all tests passing and no open critical bugs.

### Coverage holes, exclusions and waivers

A **coverage hole** is an item that has not been hit. Each one is analysed:

| Cause | Response |
|---|---|
| The stimulus never produced the condition | More seeds, new constraints, or a directed test |
| A constraint prevents the condition | Relax the constraint if the condition is legal |
| The condition is illegal or cannot happen by design | Mark the bin as illegal or ignored; exclude the code with a written justification, reviewed by the designer |
| The code is dead or left over | Remove it from the RTL |
| The feature is not implemented | A design bug: report it |

An exclusion without a reviewed justification is a way of hiding a problem. Exclusion files are part of what is audited at sign-off.

### Interview questions

**Q1. What is code coverage?**
A tool-generated measure of how much of the RTL (statements, branches, conditions, toggles, FSM states and transitions) was exercised during simulation.

**Q2. What is functional coverage?**
A user-defined measure of how many of the scenarios, values and combinations listed in the verification plan actually occurred during simulation.

**Q3. What are the types of code coverage?**
Statement (line), branch, condition, expression, toggle, and FSM state and transition coverage.

**Q4. What is the difference between branch and condition coverage?**
Branch coverage checks that each decision as a whole evaluated both true and false. Condition coverage checks that each individual sub-expression inside the decision took both values.

**Q5. Code coverage is 100 percent but functional coverage is 60 percent. What does that mean?**
All the code was executed, but 40 percent of the planned scenarios did not occur: the tests touched the code without producing the interesting combinations or sequences. Stimulus needs to be improved, or some bins are unreachable and need review.

**Q6. Functional coverage is 100 percent but code coverage is 80 percent. What does that mean?**
A fifth of the RTL was never executed even though every planned scenario occurred. Either the coverage model omits some features, or the RTL contains dead, unreachable or undocumented logic. The uncovered code is reviewed with the designer.

**Q7. Can 100 percent code coverage and 100 percent functional coverage guarantee a bug-free design?**
No. Coverage shows what was exercised, not that it was checked correctly, and a scenario missing from both the plan and the code is invisible to both. They give confidence, not proof.

**Q8. Who writes functional coverage, and from what?**
The verification engineer, from the specification and the verification plan, never from the RTL.

## 4.9 The Self-Checking Testbench

### In plain English

A testbench that only applies stimulus leaves the real work to a person: looking at waveforms or log files and deciding whether the outputs are right. That is slow, cannot be repeated nightly, and is unreliable; nobody inspects ten thousand random results accurately.

A **self-checking testbench** decides by itself. It knows, for every stimulus, what the DUT should produce; it compares that with what the DUT did produce; and at the end it prints a single verdict: PASSED or FAILED.

### Technical definition

A self-checking testbench is one that automatically determines the correctness of the DUT's responses during simulation, by comparing them with expected values obtained from a reference model, a predictor or assertions, and that reports pass or fail without manual inspection.

### Why it is needed

| Need | Why self-checking is the only answer |
|---|---|
| Constrained-random stimulus | Expected values cannot be written by hand for stimulus that is not known in advance |
| Regressions | Hundreds of tests run unattended every night; a script must be able to read the result |
| Repeatability | The same checks are applied every time, with no human judgement |
| Speed of debug | A failure is reported at the time and transaction where it occurs, not discovered later in a waveform |

### The ingredients

| Ingredient | Role |
|---|---|
| Stimulus generator | Produces the transactions |
| Driver | Applies them to the DUT |
| Monitor | Observes the DUT's inputs and outputs and rebuilds transactions |
| Predictor / reference model | Computes the expected response from the observed inputs |
| Comparator (scoreboard) | Compares actual with expected and counts matches and mismatches |
| Assertions | Check protocol and timing rules continuously |
| End-of-test report | Prints the totals and the final verdict |

### Ways of obtaining a self-check

| Method | How | Suitable for |
|---|---|---|
| Reference model + scoreboard | A model computes the expected output for each transaction | Data-transforming designs: ALU, filter, encoder, processor |
| Data integrity scoreboard | Whatever goes in must come out, unchanged and in order | FIFOs, memories, bridges, routers |
| Assertions | Properties checked every cycle | Protocol and control: handshakes, flags, one-hot, timing |
| Inverse operation | Apply the operation and its inverse; expect the original | Encrypt/decrypt, encode/decode, write then read back |
| Golden file | Outputs compared with a stored file from a trusted earlier run | Legacy flows. Fragile, and only valid for fixed stimulus |
| Hand-written expected values | The test states the expected result | Directed tests only |

### Complete example: a self-checking ALU testbench

This testbench uses the final `alu_txn` class and the `alu_predict` reference model from Section 3.5. It is deliberately flat: one module, no interface, no mailbox. Its purpose is to show the *idea* of self-checking with both directed and constrained-random stimulus. Module 9 restructures the same ideas into separate generator, driver, monitor and scoreboard classes.

The design is the ALU from Module 1, repeated here so that the example folder is complete.

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

```systemverilog file=tb_alu_selfcheck.sv
// Compile order: alu_pkg.sv, alu.sv, alu_tb_pkg.sv (includes alu_txn.sv), this file
module tb_alu_selfcheck;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  // ---------------- DUT connections ----------------
  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  always #5 clk = ~clk;

  // ---------------- bookkeeping ----------------
  int unsigned n_txn;         // transactions checked
  int unsigned n_err;         // mismatches found
  bit [7:0]    op_seen;       // one bit per opcode: a hand-made coverage record
  alu_txn      t;

  // ---------------- drive one transaction and check the response ----------------
  task automatic drive_and_check(alu_txn txn);
    logic [8:0] expected;

    @(negedge clk);                       // drive away from the sampling edge
    a        = txn.a;
    b        = txn.b;
    op       = txn.op;
    valid_in = 1'b1;

    @(negedge clk);                       // the DUT sampled at the posedge in between
    valid_in   = 1'b0;
    txn.result = result;                  // ACTUAL  : captured from the DUT
    expected   = alu_predict(txn);        // EXPECTED: from the reference model

    n_txn++;
    op_seen[txn.op] = 1'b1;

    if (valid_out !== 1'b1 || txn.result !== expected) begin
      n_err++;
      $error("[%0t] MISMATCH {%s} expected=0x%h valid_out=%b",
             $time, txn.convert2string(), expected, valid_out);
    end
  endtask

  // ---------------- a directed transaction: every value chosen by hand ----------------
  task automatic directed(alu_op_e op_i, bit [7:0] a_i, bit [7:0] b_i);
    alu_txn d = new();
    d.id = n_txn;
    d.op = op_i;
    d.a  = a_i;
    d.b  = b_i;
    drive_and_check(d);
  endtask

  // ---------------- the test ----------------
  initial begin
    // reset
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(posedge clk);
    if (valid_out !== 1'b0 || result !== 9'd0) begin
      n_err++;
      $error("[%0t] outputs not zero during reset", $time);
    end
    rst_n = 1'b1;

    // directed corner cases
    directed(ALU_ADD, 8'hFF, 8'hFF);
    directed(ALU_ADD, 8'h00, 8'h00);
    directed(ALU_SUB, 8'h00, 8'hFF);
    directed(ALU_SUB, 8'h7F, 8'h7F);
    directed(ALU_SHL, 8'h80, 8'h00);
    directed(ALU_SHR, 8'h01, 8'h00);

    // constrained-random
    repeat (200) begin
      t    = new();
      t.id = n_txn;
      if (!t.randomize()) $fatal(1, "randomize() failed");
      drive_and_check(t);
    end

    // end-of-test report
    $display("transactions : %0d", n_txn);
    $display("opcodes seen : %0d of 8", $countones(op_seen));
    $display("errors       : %0d", n_err);
    if (n_err == 0 && n_txn > 0 && $countones(op_seen) == 8) $display("TEST PASSED");
    else                                                     $display("TEST FAILED");
    $finish;
  end

endmodule
```

```output
transactions : 206
opcodes seen : 8 of 8
errors       : 0
TEST PASSED
```

The output is the same for every seed as long as the design is correct. (With 200 random transactions, the chance that one of the eight opcodes never appears is negligible.)

**Line by line**

| Code | Explanation |
|---|---|
| `import alu_tb_pkg::*;` | Brings in `alu_txn` and `alu_predict`. |
| `alu dut (.*);` | The DUT is connected to module-level signals of the same names. |
| `int unsigned n_txn, n_err;` | The counters on which the final verdict is based. |
| `bit [7:0] op_seen;` | A hand-made stand-in for functional coverage: bit *n* is set when opcode *n* has been driven. Module 10 replaces it with a covergroup. |
| `@(negedge clk);` then the assignments | Stimulus changes on the falling edge, half a cycle before the DUT samples, so there is no race at the rising edge. (Module 8 replaces this with a clocking block.) |
| Second `@(negedge clk);` | Between the two falling edges there was one rising edge, at which the DUT sampled `valid_in` = 1 and registered the result. |
| `txn.result = result;` | The **actual** value is stored in the transaction, in a four-state field. |
| `expected = alu_predict(txn);` | The **expected** value is computed from the transaction's inputs, independently of the DUT. |
| `if (valid_out !== 1'b1 \|\| txn.result !== expected)` | The comparison. `!==` is used so that an X or Z on either DUT output is a mismatch. |
| `$error(...)` | Reports the failure at the moment it happens, with the time and the whole transaction. The simulation continues, so that one run can reveal several problems. |
| `task automatic directed(...)` | Builds a transaction from hand-chosen values and sends it down the **same** drive-and-check path as the random ones. Directed and random stimulus share one checker. |
| Reset check | The outputs are checked while reset is active. |
| `directed(ALU_ADD, 8'hFF, 8'hFF);` and the others | The corners from the plan: largest sum, zero sum, largest borrow, `a == b`, the bit shifted out to the left, the bit shifted out to the right. |
| `t = new();` inside the loop | A new object per transaction. `t` is declared at module level and `new()` is a separate statement, for the reason given at the end of Section 3.5. |
| End-of-test report | Totals, then one unambiguous line. |
| `n_err == 0 && n_txn > 0 && ...` | A test passes only if there were no errors **and** something was actually checked **and** the intended stimulus occurred. |

### Seeing it catch a bug

Change one line of `alu.sv` to model a designer's mistake, for example `ALU_SUB: result_nxt = b - a;`, and run again. The testbench now prints one `$error` line for each subtraction in which `a` and `b` differ, such as

```text
[70] MISMATCH {id=2 op=ALU_SUB a=0x00 b=0xff result=0x0ff} expected=0x101 valid_out=1
```

and finishes with a non-zero error count and `TEST FAILED`. (The exact wording and prefix of an `$error` message depend on the simulator.) Notice that the directed test with `a == b` (`7F - 7F`) does **not** detect this bug, because both orders give zero. A test passing does not mean a feature is correct; it means that particular stimulus did not expose a problem. This is the argument for many random transactions.

Deliberately inserting a bug to confirm that the testbench reports it is a standard practice. A testbench that has never been seen to fail has not been shown to check anything.

### Requirements for a trustworthy self-checking testbench

| Requirement | Reason |
|---|---|
| The expected value comes from an independent source | A model copied from the RTL agrees with the RTL's bugs |
| Comparisons use `===` / `!==` | X and Z on DUT outputs must fail |
| Every transaction is checked | A checker that silently skips transactions produces false passes |
| The end-of-test report states how many checks were performed | "0 errors" with 0 checks must be a failure |
| Nothing is left over at the end | Expected items never matched, or DUT outputs never expected, are errors |
| The verdict is a single, fixed, searchable line | Regression scripts search the log for it |
| The absence of the PASS line counts as failure | A test that crashed or timed out prints nothing |
| A timeout (watchdog) ends a hung simulation | Otherwise a deadlock looks like a long-running test |

> **Common mistake:** A testbench whose end-of-test code prints "TEST PASSED" unconditionally, or only when `n_err == 0`, without confirming that any comparison took place. If the monitor never sees a transaction (wrong clock edge, `valid_out` never high), the error count is zero and the test passes while checking nothing.

> **Interview trap:** "What is the difference between a self-checking testbench and a testbench with a `$display` of the outputs?" Printing outputs is not checking. A self-checking testbench contains the expected values (or a way to compute them) and makes the pass/fail decision itself.

### Interview questions

**Q1. What is a self-checking testbench?**
A testbench that determines automatically whether the DUT's outputs are correct, by comparing them with expected values from a reference model or with assertions, and that reports pass or fail without anyone examining waveforms.

**Q2. Why is it necessary for constrained-random verification?**
The stimulus is generated at run time and differs for every seed, so expected results cannot be prepared by hand. They must be computed and compared automatically.

**Q3. What are the components of a self-checking testbench?**
A stimulus generator, a driver, a monitor, a predictor or reference model, a scoreboard that compares, assertions for protocol checks, and an end-of-test report.

**Q4. How does a regression script know whether a test passed?**
It searches the log for a fixed pass message and for error or fatal messages (or reads the simulator's error count). A test passes only if the pass message is present and no errors are reported.

**Q5. What is a false pass and how can it happen?**
A test that reports PASS although the design is wrong or was not checked. Causes: comparison with `!=` when the output is X; the monitor or scoreboard never receiving transactions; a reference model that shares the RTL's bug; a pass message printed unconditionally.

**Q6. How do you gain confidence in the testbench itself?**
Insert known bugs into the design (or corrupt a transaction in the testbench) and confirm that the checkers report them; review the checkers against the specification; and confirm that the number of checks performed is what the test intended.

## 4.10 Expected Versus Actual Output Comparison

### In plain English

Every check in verification has the same shape: obtain the value the DUT **should** produce, obtain the value it **did** produce, compare. This section looks at where each of the two values comes from and at the ways the comparison can go wrong.

### Definitions

| Term | Meaning | Source |
|---|---|---|
| **Actual** output | What the DUT really produced | Sampled from the DUT's output pins by the monitor |
| **Expected** output | What the specification says it must produce for the given input | Computed by a reference model or predictor from the inputs, or stated by the test |
| **Scoreboard** | The component that receives both and compares them | Module 9 |

### The flow of data

```text
                       +---------+     pins      +---------+     pins     +---------+
     alu_txn --------> | driver  | ------------> |   DUT   | -----------> | monitor |
     (a, b, op)        +---------+               +---------+              +---------+
                                                                               |
                                              observed alu_txn (a, b, op, result = ACTUAL)
                                                                               |
                                                                               v
                         +---------------------------------------------------------------+
                         |  scoreboard                                                   |
                         |                                                               |
                         |    a, b, op  --->  alu_predict()  --->  EXPECTED result       |
                         |                                              |                |
                         |    result (ACTUAL) ----------------------->  compare          |
                         |                                              |                |
                         |                              match: pass++   |  mismatch:     |
                         |                                              |  $error, fail++|
                         +---------------------------------------------------------------+
```

A point that surprises beginners: the scoreboard takes the **inputs** from the monitor too, not from the generator. The monitor reports what was really on the DUT's pins. If the driver has a bug and drives something different from what the generator asked for, the prediction is still made from what the DUT actually received, and the comparison stays valid.

### Where the expected value comes from

| Source | Description | Example |
|---|---|---|
| Reference model (golden model) | An independent model of the function, in SystemVerilog or in C/C++ through DPI | `alu_predict`; an instruction-set simulator for a processor |
| Predictor | A simplified model that transforms an input transaction into the expected output transaction | Expected FIFO output = the oldest input not yet read |
| The stimulus itself | For designs that only transport data, expected output equals input | FIFO, bridge, switch |
| The test | A hand-written value | Directed tests |
| Assertions | The expected behaviour is expressed as a property over time | "`valid_out` is high exactly one cycle after `valid_in`" |

### Kinds of comparison

| Kind | Used when | Data structure in the scoreboard |
|---|---|---|
| Immediate, one-to-one | Each output corresponds to exactly one input and arrives in order with fixed latency | None; compare as each transaction arrives. The ALU is this case |
| In-order | Outputs come in the same order as inputs but after a variable delay | A queue of expected transactions; each actual is compared with the front of the queue |
| Out-of-order | Outputs may overtake each other | An associative array of expected transactions, indexed by an ID carried in the transaction |
| Transaction-level (untimed) | Only values matter | Compare fields |
| Cycle-accurate | The exact cycle of each output matters | Compare values and times; usually done with assertions |

An in-order scoreboard, in outline:

```systemverilog
alu_txn      exp_q[$];          // expected transactions waiting for their actual
int unsigned n_pass, n_fail;

function void write_expected(alu_txn t);
  exp_q.push_back(t.copy());
endfunction

function void write_actual(alu_txn act);
  alu_txn exp;
  if (exp_q.size() == 0) begin
    n_fail++;
    $error("unexpected output: {%s}", act.convert2string());
    return;
  end
  exp = exp_q.pop_front();
  if (exp.compare(act)) n_pass++;
  else begin
    n_fail++;
    $error("MISMATCH expected {%s} actual {%s}",
           exp.convert2string(), act.convert2string());
  end
endfunction

function void report();
  if (exp_q.size() != 0) begin
    n_fail++;
    $error("%0d expected transactions were never observed", exp_q.size());
  end
  $display("scoreboard: %0d passed, %0d failed", n_pass, n_fail);
endfunction
```

All three transaction methods from Part 3 appear here: `copy()` so that the stored object cannot be changed by its sender, `compare()` for the verdict, and `convert2string()` for the message.

### What a good mismatch message contains

| Item | Why |
|---|---|
| Simulation time | To find the place in the waveform |
| Transaction ID | To find the related generator, driver and monitor lines in the log |
| The full input | To reproduce the case |
| Expected and actual values, in hex | To see which bits differ |
| The name of the check | To know which rule was violated |

### The ways a comparison can be wrong

| Problem | Effect | Prevention |
|---|---|---|
| `!=` instead of `!==` | X on the output is not reported (false pass) | Always `!==` for DUT data |
| Handles compared instead of contents | Always a mismatch (false fail) | `compare()` |
| Monitor samples on the wrong clock edge or in a race with the DUT | Old or unstable values captured; intermittent false fails | Clocking blocks (Module 8) |
| Actual stored in a two-state variable | X becomes 0 (false pass) | Four-state fields for DUT outputs |
| Reference model has the same bug as the RTL | Bug not detected | Independent model, written from the specification |
| Reference model wrong, RTL right | False fail | Debug decides; the specification is the judge |
| Expected and actual out of step by one transaction | Every comparison after the first slip fails | End-of-test check on the queue; IDs in transactions |
| Nothing compared at all | Zero errors (false pass) | Require a non-zero number of checks |
| Width or signedness of the model differs from the DUT | Mismatches only on overflow or when the MSB is set | Model at the DUT's exact widths (Module 1) |

> **Key point:** When expected and actual differ, there are always three suspects: the design, the testbench (stimulus, monitor, reference model), and the specification. Do not report a design bug until you have checked that the testbench is right and that the specification really requires what the testbench expects.

> **Verification application:** Debugging a mismatch follows a fixed routine. (1) Read the scoreboard message: time, ID, expected, actual. (2) Find the same ID in the generator and driver lines to confirm what was sent. (3) Open the waveform at that time and confirm that the pins match what the monitor reported. (4) Work out by hand, from the specification, what the result should be. (5) Whichever of expected or actual disagrees with the specification identifies the faulty party.

### Interview questions

**Q1. Where do the expected and the actual values come from?**
The actual value is sampled from the DUT outputs by the monitor. The expected value is computed by a reference model or predictor from the inputs that the DUT received, or is written explicitly in a directed test.

**Q2. Why does the scoreboard use the inputs observed by the monitor and not the transaction created by the generator?**
The monitor reports what was really applied to the DUT. If the driver modifies, delays or corrupts a transaction, a prediction based on the generator's copy would be wrong. It also lets the same scoreboard be reused when the stimulus comes from another block instead of a generator.

**Q3. How does a scoreboard handle a DUT with variable latency?**
It stores expected transactions in a queue as inputs are observed, and compares each observed output with the front of the queue. For out-of-order responses it uses an associative array keyed by a transaction ID.

**Q4. What checks should a scoreboard make at the end of the test?**
That the queue of expected transactions is empty (nothing was lost by the DUT), that no unexpected outputs were received, and that the number of comparisons performed is greater than zero and matches the number of transactions sent.

**Q5. A mismatch is reported. How do you decide whether it is a design bug or a testbench bug?**
Compute the correct result by hand from the specification for the reported input. If the DUT's actual value agrees with the specification, the reference model or monitor is wrong. If the expected value agrees with the specification and the waveform confirms the actual value, it is a design bug. If the specification is unclear, it is a specification issue to be resolved with its owner.

**Q6. What is a golden reference model?**
A trusted, independent implementation of the design's intended function, often written at a higher level of abstraction (untimed SystemVerilog, C or C++), whose outputs are taken as the expected values.
