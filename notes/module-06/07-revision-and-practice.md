# Part 6: Module 6 Revision and Practice

## 6.1 Revision Summary

### Transactions

- A transaction is one complete operation on an interface, described as data: **what**, not **how** or **when**.
- The driver converts transaction → pins. The monitor converts pins → transaction. Nothing else in the testbench touches pins.
- Every component uses the transaction, so it is designed first and kept in a package.
- It is a class, not a struct, because it needs `randomize()`, constraints, methods, inheritance and dynamic creation.

### The fields of `alu_txn`

| Field | Declaration | Kind | Reason for the type |
|---|---|---|---|
| Operands | `rand bit [7:0] a, b;` | Stimulus | Chosen by the testbench; two-state |
| Operation | `rand alu_op_e op;` | Stimulus | Enum: legal values only, readable, automatic coverage bins |
| Result | `logic [8:0] result;` | Response | Sampled from the DUT; four-state so that X is preserved |
| Identifier | `int unsigned id;` | Bookkeeping | Tracks one transaction through the log |

Clock, reset and handshake signals are not fields. A virtual interface is never a field.

### The methods of a transaction

| Method | One-line description | Key point |
|---|---|---|
| `new()` | Put the object in a safe initial state | No return type; all arguments have defaults; no randomization inside |
| `randomize()` | Solve constraints and assign the `rand` fields | Always check the return value |
| `post_randomize()` | Compute derived fields after randomization | Called automatically; not called on failure |
| `convert2string()` | Return the contents as a string | Used by `print` and by error messages |
| `print(tag)` | Display one line in the log | One format for all components |
| `copy()` | Return a new, independent object with the same values | Handles are references; `t2 = t1` copies nothing |
| `compare(rhs)` | Return 1 if the relevant fields are equal | `===` for four-state fields; skip bookkeeping; guard against `null` |

All are functions, all are `virtual`, and every one must be updated when a field is added.

### Constraints in a transaction

- Two purposes: **legality** and **interest** (corner bias, distributions).
- One purpose per named block, so that tests can switch off (`constraint_mode(0)`) or replace (same name in a derived class) exactly one of them.
- Only always-true rules are hard constraints in the base class.
- Tests narrow the stimulus by inline `with { }` or, better, by a derived class.

### Reuse

- Derived class + new constraint name → constraint **added**.
- Derived class + same constraint name → constraint **replaced**.
- Blueprint pattern: the generator randomizes a base-class handle and sends copies; the test decides which object that handle refers to.

### Verification vocabulary

| Term | Meaning |
|---|---|
| Verification | Showing, before tape-out, that the RTL matches the specification |
| Validation | Showing, after silicon, that the chip works in the real system |
| Manufacturing test | Checking each fabricated chip for defects |
| Verification plan | What will be verified and how: features, stimulus, checks, coverage, architecture, exit criteria |
| Test plan | The list of test cases that implements the verification plan |
| Directed test | Hand-written stimulus and expected result for one scenario |
| Constrained-random test | Solver-generated stimulus within constraints, checked automatically, measured by coverage |
| Functional coverage | User-written measure of which planned scenarios occurred |
| Code coverage | Tool-generated measure of which RTL code was exercised |
| Self-checking testbench | Decides pass or fail by itself by comparing actual with expected |
| Reference model | Independent model that produces the expected output |
| Scoreboard | Component that compares actual with expected |
| Regression | Re-running all tests with many seeds, regularly |
| Coverage closure | Analysing and resolving every coverage hole |
| Exit criteria | The measurable conditions for sign-off |

### The three things constrained-random verification needs

```text
        constraints            automatic checking            functional coverage
     (legal, interesting)   (scoreboard, model, assertions)   (what actually happened)
              \                        |                          /
               +-----------------------+-------------------------+
                                       |
                          coverage-driven verification
```

### Coverage in four lines

| | Code coverage | Functional coverage |
|---|---|---|
| Source | RTL | Specification |
| Written by | Tool | Engineer |
| Finds | Unexercised or dead code | Unexercised scenarios |
| Cannot find | Missing features | Scenarios missing from the model |

Neither shows that anything was **checked**. Sign-off needs both, plus passing checks.

### The flow

Specification → features → verification plan → testbench architecture → test plan and coverage plan → bring-up with a sanity test → directed and random tests → debug and bug reports → regression with seeds → coverage closure → sign-off against exit criteria.

## 6.2 Interview Questions and Answers

The questions inside each section of Parts 1 to 5 cover the direct definitions. The questions below are additional.

### Basic level

**Q1. In one sentence, what is the job of a transaction class?**
To hold the data of one operation in a form that can be randomized, passed between testbench components, printed, copied and compared, independently of pins and timing.

**Q2. Name the fields you would put in a transaction for a simple RAM.**
`rand bit write;`, `rand bit [ADDR_W-1:0] addr;`, `rand bit [DATA_W-1:0] wdata;` as stimulus, and `logic [DATA_W-1:0] rdata;` as response.

**Q3. Which of `clk`, `rst_n`, `valid_in`, `a`, `op`, `result` belong in `alu_txn`?**
`a`, `op` and `result`. The others are protocol signals handled by the driver, monitor and interface.

**Q4. What does the monitor do with a transaction?**
It creates a transaction object, fills it with the values it samples from the DUT's pins, and sends it to the scoreboard (and coverage).

**Q5. What is the difference between stimulus fields and response fields?**
Stimulus fields are chosen by the testbench and are `rand`. Response fields are produced by the DUT, captured by the monitor, and are not `rand`.

**Q6. What is a testcase?**
One test from the test plan: a specific configuration and stimulus scenario with defined pass criteria, run on the common testbench.

**Q7. What is a DUT?**
The Design Under Test: the RTL block being verified.

**Q8. What is a bug?**
A difference between what the design does and what the specification requires.

**Q9. What is a seed?**
The starting value of the random number generator. The same seed with the same code reproduces the same random stimulus.

**Q10. What does PASS mean for a test?**
That, for the stimulus applied in that run, no checker reported an error and the expected number of checks was performed. It does not mean the feature is free of bugs.

**Q11. What is a coverage hole?**
A coverage item (bin, line, branch, condition) that no test has hit.

**Q12. What is a watchdog or timeout in a testbench?**
A process that ends the simulation with an error if the test has not finished within a maximum time, so that a deadlock does not run forever.

### Intermediate level

**Q13. The driver needs to wait a random number of cycles between transactions. Where does that number live?**
In the transaction, as a `rand` field such as `rand int unsigned delay;` with a constraint. The transaction carries the *intent*; the driver implements it with clock edges. Tests can then control timing by constraining the field.

**Q14. Why should `copy()` not simply be `return this;`?**
That returns a handle to the same object, so nothing has been copied; sender and receiver still share one object.

**Q15. Your transaction has a dynamic array of bytes and a handle to a header object. Write the copy logic for both.**
`c.payload = payload;` copies the array elements. `c.hdr = hdr.copy();` creates a separate header object. Writing `c.hdr = hdr;` would make both transactions share one header.

**Q16. Should `compare()` print an error message when the objects differ?**
Usually not. It should return the verdict; the scoreboard decides whether a difference is an error and how to report it. A separate variant may return a description of the differences for debug.

**Q17. Why are response fields not included in constraints?**
They are not `rand`; the solver treats a non-`rand` variable in a constraint as a constant with its current value. A response field is typically X before the DUT responds, and an X or Z value in a constraint expression is an error.

**Q18. What is the difference between a reference model and a scoreboard?**
The reference model computes the expected output. The scoreboard holds expected and actual values, matches them up and compares them. A scoreboard often contains or calls a reference model.

**Q19. Give two reasons to keep directed tests in a constrained-random project.**
A fast sanity check that the environment works, and deterministic coverage of specific corners (reset values, named boundary cases, reproductions of past bugs).

**Q20. Why must coverage from failing tests be discarded?**
A failing test did not demonstrate correct behaviour; its stimulus may even have been produced by a broken testbench. Counting its coverage would claim that scenarios were verified when they were not.

**Q21. What is the difference between a feature and a test?**
A feature is something the design must do, from the specification. A test is a piece of stimulus that exercises one or more features. One feature may need several tests, and one random test may cover many features.

**Q22. How do you decide the priority of the items in a verification plan?**
By risk: how likely the feature is to be wrong (new logic, complex logic, late changes) and how severe a failure would be (basic function, cannot be worked around in software). High-risk, high-impact items are verified first.

**Q23. What is toggle coverage good for?**
It shows whether every bit of every signal has taken both values. It is particularly useful for connectivity (a bit of a bus tied off or never driven) and at chip level.

**Q24. The same test passes with one seed and fails with another. Is the test unstable?**
No. Different seeds produce different stimulus; one of them reached a scenario that exposes a bug in the design or the testbench. That is exactly what multiple seeds are for.

### Advanced and scenario-based

**Q25. The scoreboard reports "0 errors" and the test passes, but the designer later finds that the block does nothing at all in that test. What went wrong in the testbench?**
Nothing was compared. Possible causes: the monitor never detected a valid output; the scoreboard's process was not started or the mailbox was not connected; the test ended before any response arrived. The pass decision must require a non-zero number of comparisons equal to the number of transactions sent, and an empty expected queue at the end.

**Q26. Every transaction the driver receives has the same values, although the generator log shows different values. Explain.**
The generator created one object and sent its handle repeatedly while re-randomizing it. The print in the generator shows each new value at the time, but by the time the driver processes the handles they all refer to the single object with the latest values. The generator must send a new object or a copy each time.

**Q27. After adding a `parity` field to the transaction, the scoreboard never reports parity errors even when you force one. Where do you look?**
At `compare()` (and `copy()`). The new field was probably not added to the comparison, or not copied, so the scoreboard compares default values. All three methods must be updated with every new field.

**Q28. You have 100 percent functional coverage in the first week. What do you conclude?**
That the coverage model is too weak: too few points, bins that are too coarse, no crosses, or coverage sampled without regard to whether the scenario was meaningful. The model is reviewed against the verification plan before the figure is believed.

**Q29. A cross-coverage bin has not been hit after 500 seeds. What are your options?**
Determine whether it is reachable. If it is illegal or impossible, mark it as ignored or illegal with justification. If it is reachable, raise its probability with a `dist` or a derived transaction with tighter constraints, or write a directed test for it. Also ask why it is so hard to reach; sometimes the answer is a design bug that prevents the scenario.

**Q30. The reference model and the RTL were written by the same person from the same understanding. What is the risk and how do you reduce it?**
A common misunderstanding of the specification appears in both, so they agree and the bug is invisible. Reduce it by having a different person write the model from the specification, writing it at a different abstraction level and in a different style, reviewing it against the specification, and adding directed tests whose expected values are worked out by hand.

**Q31. A bug is found at chip level that should have been found at block level. What follow-up do you do in the block-level environment?**
Reproduce it at block level, find out why it was missed (missing feature in the plan, missing coverage point, an over-constraint, a wrong assumption about the inputs, a weak checker), and fix that gap, not just the single case. Then check whether the same gap exists for similar features.

**Q32. How would you verify the ALU's requirement that `b` has no effect on NOT, SHL and SHR?**
Stimulus: leave `b` fully random for those opcodes, never constrain it to 0. Checking: the reference model ignores `b`, so any dependence in the DUT appears as a scoreboard mismatch. Coverage: a cross showing that each unary opcode was seen with zero and with non-zero `b`.

**Q33. The specification changes halfway through the project. What do you update, and in what order?**
The verification plan first (features, checks, coverage), then the transaction and constraints if the interface or legal stimulus changed, the reference model and assertions, the tests and the coverage model; then the regression is re-run and coverage is re-collected from zero for the affected features, because old coverage was measured against old behaviour.

**Q34. Why might a team deliberately keep a constraint out of the base transaction even though all current tests need it?**
Because a hard constraint in the base class applies to every future test. If any later test needs to violate it (an error test, a corner case), it would have to switch it off by name. Keeping test-level intent in the test, or making it `soft`, keeps the base class open.

**Q35. In an interview you are given a 2-to-1 round-robin arbiter and five minutes. What do you say?**
Interfaces: two requests, two grants, clock, reset. Features: no grant without request; at most one grant at a time; a single requester is granted; with both requesting, grants alternate; no requester waits more than one turn (fairness); reset state. Stimulus: random request patterns, including both held continuously, both dropped together, and requests changing every cycle. Checks: assertions for one-hot-or-zero grant and grant-implies-request; a small model for the alternation. Coverage: all four request combinations, each with each previous grant; long continuous contention.

**Q36. What would make you refuse to sign off even though every metric is at 100 percent?**
Bugs still being found at a steady rate; checkers or the coverage model not reviewed; exclusions without justification; a regression that has only been clean once; RTL changed after the last full regression; or features in the specification with no trace to any test, check or coverage item.

## 6.3 Output-Prediction Questions

Work out the output on paper first, then read the answer, then run the code. These examples are self-contained and do not need `alu_pkg`.

**P1.**

```systemverilog
module p1;
  class txn;
    int a;
    function txn copy();
      txn c = new();
      c.a = a;
      return c;
    endfunction
  endclass

  txn t1, t2, t3;

  initial begin
    t1   = new();
    t1.a = 5;
    t2   = t1;
    t3   = t1.copy();
    t1.a = 9;
    $display("%0d %0d %0d %0d %0d", t1.a, t2.a, t3.a, t1 == t2, t1 == t3);
  end
endmodule
```

Answer: `9 9 5 1 0`. `t2` is a second handle to the same object, so it sees the change to 9. `t3` is a separate object created before the change, so it still holds 5. Handle equality is 1 for `t1`/`t2` and 0 for `t1`/`t3`.

**P2.**

```systemverilog
module p2;
  class txn;
    int a;
  endclass

  txn t;
  txn q[$];

  initial begin
    for (int i = 0; i < 3; i++) begin
      if (i != 1) t = new();
      t.a = i;
      q.push_back(t);
    end
    $display("%0d %0d %0d", q[0].a, q[1].a, q[2].a);
  end
endmodule
```

Answer: `1 1 2`. In iteration 0 a new object is created and stored. In iteration 1 no object is created, so the **same** object is modified (`a` becomes 1) and its handle is stored again. In iteration 2 a new object is created. Entries 0 and 1 are one object, which now holds 1.

**P3.**

```systemverilog
module p3;
  class txn;
    logic [3:0] r;
    function bit cmp_loose (txn rhs);  return (r ==  rhs.r);  endfunction
    function bit cmp_strict(txn rhs);  return (r === rhs.r);  endfunction
  endclass

  txn t1, t2;

  initial begin
    t1 = new();  t1.r = 4'b1010;
    t2 = new();  t2.r = 4'b10x0;
    $display("%0d %0d", t1.cmp_loose(t2), t1.cmp_strict(t2));
    if (t1.r != t2.r) $display("MISMATCH");
    else              $display("no mismatch reported");
  end
endmodule
```

Answer: `0 0`, then `no mismatch reported`. `1010 == 10x0` is X; returned through a `bit` it becomes 0, so the loose function happens to say "not equal". `===` gives a definite 0. But the inline `if (t1.r != t2.r)` evaluates to X, which is treated as false, so the `else` branch runs and the mismatch is missed. This is why `!==` is used.

**P4.**

```systemverilog
module p4;
  class txn;
    rand bit [3:0] a;
    bit      [3:0] b;
    constraint c { a == b + 1; }
  endclass

  txn t;
  int ok;

  initial begin
    t   = new();
    t.b = 4;
    ok  = t.randomize();
    $display("%0d %0d", ok, t.a);
    t.b = 15;
    ok  = t.randomize();
    $display("%0d %0d", ok, t.a);
  end
endmodule
```

Answer: `1 5`, then `0 5`. `b` is not `rand`, so it is a constant for the solver. With `b` = 4, `a` must be 5. With `b` = 15, `b + 1` is evaluated in 32 bits (the literal `1` is 32 bits wide) and equals 16, which a 4-bit `a` can never be. `randomize()` returns 0 and leaves `a` at its previous value. The simulator also prints a constraint-failure message.

**P5.**

```systemverilog
module p5;
  class base;
    rand bit [3:0] v;
    constraint range_c { v inside {[0:3]}; }
  endclass

  class d1 extends base;
    constraint range_c { v == 9; }
  endclass

  class d2 extends base;
    constraint other_c { v == 9; }
  endclass

  base b;
  d1   x;
  d2   y;
  int  ok;

  initial begin
    x  = new();
    y  = new();
    b  = x;
    ok = b.randomize();
    $display("%0d %0d", ok, b.v);
    b  = y;
    ok = b.randomize();
    $display("%0d %0d", ok, b.v);
  end
endmodule
```

Answer: `1 9`, then `0 0`. In `d1` the block has the same name as the base block and **replaces** it, so only `v == 9` applies. In `d2` the block has a different name and is **added**: `v` must be in 0 to 3 and also equal 9, which is impossible, so `randomize()` fails and `v` keeps its default of 0. In both cases the call is made through a base-class handle and the constraints of the actual object are used.

**P6.**

```systemverilog
module p6;
  class base;
    virtual function string str();   return "base";  endfunction
    function string         label(); return "base";  endfunction
    function void print();
      $display("%s %s", str(), label());
    endfunction
  endclass

  class der extends base;
    virtual function string str();   return {super.str(), "+der"};  endfunction
    function string         label(); return "der";                  endfunction
  endclass

  base b;
  der  d;

  initial begin
    d = new();
    b = d;
    b.print();
    $display("%s %s", b.label(), d.label());
  end
endmodule
```

Answer: `base+der base`, then `base der`. `str()` is virtual, so the derived version runs even though it is called from a base-class method. `label()` is not virtual: inside `base::print` and through the base handle `b`, the base version runs; only through the derived handle `d` does the derived version run. This is why the methods of a transaction are declared `virtual`.

**P7.**

```systemverilog
module p7;
  bit   [7:0] a = 8'd5, b = 8'd10;
  logic [8:0] r1, r2;
  initial begin
    r1 = a - b;
    r2 = {1'b0, a - b};
    $display("%h %h", r1, r2);
  end
endmodule
```

Answer: `1fb 0fb`. In `r1 = a - b` the operands are extended to the nine bits of the left-hand side before subtracting, so the borrow appears in bit 8. Inside a concatenation each operand is self-determined: `a - b` is computed in eight bits (`FB`) and the zero is then placed in front. A reference model written the second way would disagree with the DUT on every subtraction that borrows.

## 6.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
class alu_txn;
  rand bit [7:0] a;
  function void new();
    a = 0;
  endfunction
endclass
```

A constructor has no return type. Write `function new();`.

**E2.**

```systemverilog
if (!t.randomize() with (a < b)) $fatal(1, "failed");
```

Inline constraints are written in braces, each ending with a semicolon: `t.randomize() with { a < b; }`.

**E3.**

```systemverilog
alu_txn t;
initial t = new alu_txn();
```

The class name is not repeated after `new`. Write `t = new();`. (`new t2` with a handle is the shallow-copy syntax, which is something else.)

**E4.**

```systemverilog
class alu_txn;
  rand real gain;
endclass
```

In IEEE 1800-2017, `rand` may be applied only to integral types (and to arrays, structs and handles built from them). A real cannot be randomized this way. Randomize an integer and scale it in `post_randomize()`.

**E5.**

```systemverilog
class alu_txn;
  rand bit [7:0] a;
  constraint a_c { a inside [1:10]; }
endclass
```

The set after `inside` must be in braces: `a inside {[1:10]};`.

### Run-time errors and logic bugs (the code compiles)

**D1.**

```systemverilog
class alu_txn;
  rand bit [7:0] a;
  function new(bit [7:0] a = 0);
    a = a;
  endfunction
endclass
```

The argument hides the property, so the statement assigns the argument to itself. The property is never set. Write `this.a = a;`.

**D2.**

```systemverilog
alu_txn t;
initial begin
  t.a = 8'd5;
end
```

`t` is `null`; no object was created. The simulation stops with a null-handle error. Add `t = new();`.

**D3.**

```systemverilog
function alu_txn copy();
  copy.a  = a;
  copy.b  = b;
  copy.op = op;
endfunction
```

The implicit return variable `copy` is a handle and starts as `null`; accessing `copy.a` is a null-handle error. An object must be constructed first: `alu_txn c = new(); ... return c;`.

**D4.**

```systemverilog
function bit compare(alu_txn rhs);
  return (this == rhs);
endfunction
```

This compares handles, so it returns 1 only when both refer to the very same object. Compare the fields.

**D5.**

```systemverilog
alu_txn t = new();
repeat (10) begin
  void'(t.randomize());
  gen2drv_mbx.put(t);
end
```

Two bugs. The return value of `randomize()` is discarded, so a failure is invisible. And the same handle is put into the mailbox ten times, so the driver sees ten references to one object. Check the return value, and create a new object (or put `t.copy()`) for each transaction.

**D6.**

```systemverilog
class alu_txn;
  rand bit [7:0] a, b;
  logic [8:0]    result;
  constraint sum_c { result == a + b; }
endclass
```

`result` is not `rand`, so the solver treats it as a constant with its current value, which is X. An X in a constraint is an error and `randomize()` fails. The expected result is computed after randomization, by the reference model, not by a constraint.

**D7.**

```systemverilog
$display("op = %s", t.op);
```

`%s` with an enum variable prints the numeric value interpreted as characters, not the name. Use `t.op.name()`.

**D8.**

```systemverilog
class alu_txn;
  rand alu_op_e op;
  constraint op_c { op dist {ALU_ADD := 1, ALU_SUB := 1}; }
endclass
...
if (!t.randomize() with { op == ALU_XOR; }) $fatal(1, "failed");
```

The `dist` allows only ADD and SUB; XOR is not in the list, so the combined constraints have no solution and the test stops. Give every legal opcode a non-zero weight in the base class, or switch `op_c` off for this test.

**D9.**

```systemverilog
if (n_err == 0) $display("TEST PASSED");
```

A test in which no comparison was ever made also has zero errors. Require that checks were performed: `if (n_err == 0 && n_checked > 0 && n_checked == n_sent)`.

**D10.**

```systemverilog
class alu_txn;
  virtual alu_if vif;
  rand bit [7:0] a, b;
  task drive();
    @(vif.drv_cb);
    vif.drv_cb.a <= a;
  endtask
endclass
```

Not a language error but a design error. The transaction now depends on the interface and contains timing, so it cannot be created by a monitor, stored by a scoreboard or reused elsewhere without dragging the interface along. Driving belongs in the driver.

**D11.**

```systemverilog
class alu_delay_txn extends alu_txn;
  rand int unsigned delay;
  function string convert2string();
    return $sformatf("delay=%0d", delay);
  endfunction
endclass
```

The override discards the base fields; the log now shows only the delay. Call the base version: `return {super.convert2string(), $sformatf(" delay=%0d", delay)};`. (If the base method is `virtual`, the override is virtual too, even without the keyword; writing `virtual` again is good practice.)

**D12.** A regression log shows this for a failing test, and the engineer files a design bug immediately:

```text
MISMATCH {id=41 op=ALU_NOT a=0x0f b=0x33 result=0x0f0} expected=0x1f0
```

Work it out by hand first. `~0F` is `F0` and bit 8 must be 0, so the correct result is `0F0`. The DUT is right and the **reference model** is wrong: it inverted a nine-bit value (`~{1'b0, a}`) instead of placing a zero in front of the eight-bit inversion. Always check both sides against the specification before filing.

## 6.5 Coding Exercises with Solutions

Try each exercise before reading the solution. Exercises 2 to 5 use the final `alu_txn` class; compile `alu_pkg.sv` and `alu_tb_pkg.sv` (with `alu_txn.sv` in the include path) first.

### Exercise 1: a transaction class for a FIFO

Write a complete transaction class for the synchronous FIFO of Section 4.4. One transaction is one clock cycle of activity: idle, write, read, or simultaneous write and read. Include constraints, helper methods, and `convert2string`, `print`, `copy` and `compare`.

```systemverilog file=ex01_fifo_txn.sv
module ex01_fifo_txn;

  typedef enum bit [1:0] {FIFO_IDLE, FIFO_WRITE, FIFO_READ, FIFO_WRITE_READ} fifo_kind_e;

  class fifo_txn;
    // stimulus
    rand fifo_kind_e kind;
    rand bit [7:0]   din;
    // response
    logic [7:0]      dout;
    logic            full;
    logic            empty;
    // bookkeeping
    int unsigned     id;

    constraint kind_dist_c {
      kind dist { FIFO_IDLE := 1, FIFO_WRITE := 4, FIFO_READ := 4, FIFO_WRITE_READ := 1 };
    }

    function bit is_write();
      return kind inside {FIFO_WRITE, FIFO_WRITE_READ};
    endfunction

    function bit is_read();
      return kind inside {FIFO_READ, FIFO_WRITE_READ};
    endfunction

    virtual function string convert2string();
      return $sformatf("id=%0d kind=%s din=0x%h dout=0x%h full=%b empty=%b",
                       id, kind.name(), din, dout, full, empty);
    endfunction

    virtual function void print(string tag = "");
      $display("%s: %s", tag, convert2string());
    endfunction

    virtual function fifo_txn copy();
      fifo_txn c = new();
      c.kind  = kind;
      c.din   = din;
      c.dout  = dout;
      c.full  = full;
      c.empty = empty;
      c.id    = id;
      return c;
    endfunction

    virtual function bit compare(fifo_txn rhs);
      if (rhs == null) return 0;
      return (kind  ==  rhs.kind)  &&
             (din   ==  rhs.din)   &&
             (dout  === rhs.dout)  &&
             (full  === rhs.full)  &&
             (empty === rhs.empty);
    endfunction
  endclass

  fifo_txn t, c;

  initial begin
    t       = new();
    t.id    = 3;
    t.kind  = FIFO_WRITE;
    t.din   = 8'hA5;
    t.dout  = 8'h00;
    t.full  = 1'b0;
    t.empty = 1'b1;
    t.print("WR");

    c = t.copy();
    $display("copy equal: %0d   is_write=%0d is_read=%0d",
             t.compare(c), t.is_write(), t.is_read());

    c.full = 1'bx;
    $display("after corrupting full: %0d", t.compare(c));
  end

endmodule
```

```output
WR: id=3 kind=FIFO_WRITE din=0xa5 dout=0x00 full=0 empty=1
copy equal: 1   is_write=1 is_read=0
after corrupting full: 0
```

The structure is the same as `alu_txn`: stimulus fields `rand` and two-state, response fields four-state, `id` not compared, `===` on everything sampled from the DUT. `kind` has a two-state base type here, so `==` is sufficient for it.

### Exercise 2: extend the transaction with a delay field

Create `alu_delay_txn`, which adds a random idle-cycle count of 0 to 5. Make `print` and `copy` handle the new field correctly when the object is used through an `alu_txn` handle.

```systemverilog file=ex02_delay_txn.sv
module ex02_delay_txn;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  class alu_delay_txn extends alu_txn;
    rand int unsigned delay;

    constraint delay_c { delay inside {[0:5]}; }

    virtual function string convert2string();
      return {super.convert2string(), $sformatf(" delay=%0d", delay)};
    endfunction

    virtual function alu_txn copy();
      alu_delay_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      c.delay  = delay;
      return c;
    endfunction
  endclass

  alu_delay_txn d, d2;
  alu_txn       base_h, base_copy;

  initial begin
    d       = new();
    d.id    = 7;
    d.op    = ALU_OR;
    d.a     = 8'h0F;
    d.b     = 8'hF0;
    d.delay = 3;

    base_h    = d;                    // base-class handle to the derived object
    base_copy = base_h.copy();        // virtual: the derived copy() runs
    base_copy.print("COPY");          // virtual: the derived convert2string() runs

    if ($cast(d2, base_copy))
      $display("the copy is an alu_delay_txn, delay=%0d", d2.delay);

    base_copy = new();                // a plain alu_txn
    if (!$cast(d2, base_copy))
      $display("a plain alu_txn cannot be cast to alu_delay_txn");
  end

endmodule
```

```output
[0] COPY: id=7 op=ALU_OR a=0x0f b=0xf0 result=0xxxx delay=3
the copy is an alu_delay_txn, delay=3
a plain alu_txn cannot be cast to alu_delay_txn
```

`print()` is inherited unchanged; it calls `convert2string()`, which is virtual, so the derived text is used. `copy()` creates a derived object and returns it through the base return type. `$cast` recovers a derived handle when the object really is of the derived type, and fails cleanly when it is not.

### Exercise 3: pack and unpack

A serial version of the ALU receives its stimulus as one 19-bit word `{op, a, b}`. Write functions that pack an `alu_txn` into that word and rebuild a transaction from it.

```systemverilog file=ex03_pack_unpack.sv
module ex03_pack_unpack;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  typedef bit [18:0] alu_bits_t;

  function automatic alu_bits_t pack_txn(alu_txn t);
    return {t.op, t.a, t.b};
  endfunction

  function automatic alu_txn unpack_txn(alu_bits_t bits);
    alu_txn t = new();
    if (!$cast(t.op, bits[18:16])) $error("illegal opcode %b", bits[18:16]);
    t.a = bits[15:8];
    t.b = bits[7:0];
    return t;
  endfunction

  alu_txn    t, u;
  alu_bits_t w;

  initial begin
    t    = new();
    t.op = ALU_XOR;
    t.a  = 8'hAA;
    t.b  = 8'h0F;

    w = pack_txn(t);
    $display("packed           : %h", w);

    u = unpack_txn(w);
    $display("unpacked         : %s", u.convert2string());
    $display("round trip equal : %0d", t.compare(u));
  end

endmodule
```

```output
packed           : 4aa0f
unpacked         : id=0 op=ALU_XOR a=0xaa b=0x0f result=0xxxx
round trip equal : 1
```

`ALU_XOR` is `100`, so the word is `100_1010_1010_0000_1111`, which is `4AA0F` when written as five hex digits. `$cast` is used for the opcode so that an illegal encoding would be reported instead of silently stored. The two objects compare equal because `compare()` uses `===` and both results are X.

### Exercise 4: an in-order scoreboard

Write the checking part of a scoreboard as functions: one receives each stimulus transaction and stores the expected result, one receives each observed transaction and compares, one reports at the end. Exercise it with a correct result, a wrong result, an X result, an unexpected output and a missing output.

```systemverilog file=ex04_scoreboard.sv
module ex04_scoreboard;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  alu_txn      exp_q[$];
  int unsigned n_pass, n_fail;

  function automatic void write_expected(alu_txn t);
    alu_txn e = t.copy();
    e.result = alu_predict(e);
    exp_q.push_back(e);
  endfunction

  function automatic void write_actual(alu_txn act);
    alu_txn e;
    if (exp_q.size() == 0) begin
      n_fail++;
      $display("FAIL unexpected {%s}", act.convert2string());
      return;
    end
    e = exp_q.pop_front();
    if (e.compare(act)) begin
      n_pass++;
      $display("PASS {%s}", act.convert2string());
    end
    else begin
      n_fail++;
      $display("FAIL expected {%s}", e.convert2string());
      $display("     actual   {%s}", act.convert2string());
    end
  endfunction

  function automatic void report();
    if (exp_q.size() != 0) begin
      n_fail++;
      $display("FAIL %0d expected transaction(s) never observed", exp_q.size());
    end
    $display("scoreboard: %0d passed, %0d failed", n_pass, n_fail);
    if (n_fail == 0 && n_pass > 0) $display("TEST PASSED");
    else                           $display("TEST FAILED");
  endfunction

  function automatic alu_txn make(int unsigned id, alu_op_e op, bit [7:0] a, bit [7:0] b);
    alu_txn t = new();
    t.id = id;
    t.op = op;
    t.a  = a;
    t.b  = b;
    return t;
  endfunction

  alu_txn s, d;

  initial begin
    s = make(0, ALU_ADD, 8'd200, 8'd100);  write_expected(s);
    d = s.copy();  d.result = 9'h12C;      write_actual(d);     // correct

    s = make(1, ALU_SUB, 8'd5, 8'd10);     write_expected(s);
    d = s.copy();  d.result = 9'h0FB;      write_actual(d);     // borrow bit lost

    s = make(2, ALU_SHL, 8'h81, 8'h00);    write_expected(s);
    d = s.copy();  d.result = 'x;          write_actual(d);     // output is X

    d = make(3, ALU_OR, 8'h01, 8'h02);
    d.result = 9'h003;                     write_actual(d);     // nothing was expected

    s = make(4, ALU_AND, 8'hFF, 8'h0F);    write_expected(s);   // never observed

    report();
  end

endmodule
```

```output
PASS {id=0 op=ALU_ADD a=0xc8 b=0x64 result=0x12c}
FAIL expected {id=1 op=ALU_SUB a=0x05 b=0x0a result=0x1fb}
     actual   {id=1 op=ALU_SUB a=0x05 b=0x0a result=0x0fb}
FAIL expected {id=2 op=ALU_SHL a=0x81 b=0x00 result=0x102}
     actual   {id=2 op=ALU_SHL a=0x81 b=0x00 result=0xxxx}
FAIL unexpected {id=3 op=ALU_OR a=0x01 b=0x02 result=0x003}
FAIL 1 expected transaction(s) never observed
scoreboard: 1 passed, 4 failed
TEST FAILED
```

Five different situations, five correct verdicts. The last two are the ones most often forgotten: an output that nobody expected, and an expected output that never came. `$display` is used instead of `$error` only so that the output is identical on every simulator.

### Exercise 5: a test-specific transaction that checks itself

The coverage plan needs subtractions with `a == b`. Write a derived transaction for it, generate 100, and confirm that every one is a subtraction of equal operands whose predicted result is zero.

```systemverilog file=ex05_equal_txn.sv
module ex05_equal_txn;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  class alu_equal_txn extends alu_txn;
    constraint equal_c { op == ALU_SUB; a == b; }
  endclass

  alu_equal_txn t;
  int unsigned  n_ok;

  initial begin
    t = new();
    repeat (100) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op == ALU_SUB && t.a == t.b && alu_predict(t) === 9'h000) n_ok++;
    end
    $display("%0d of 100: SUB with a == b and predicted result 0", n_ok);
  end

endmodule
```

```output
100 of 100: SUB with a == b and predicted result 0
```

`equal_c` is added to the inherited `op_dist_c` and `corner_c`; all three can be satisfied together. One object is randomized repeatedly here, which is safe because its handle is not passed to anything else.

### Exercise 6 (paper exercise): plan the verification of a counter

**Specification.** A 4-bit up/down counter. Ports: `clk`, `rst_n` (asynchronous, active low), `en`, `up`, `load`, `din[3:0]`, `count[3:0]`. On a rising clock edge: if `load` is 1, `count` takes `din`; otherwise, if `en` is 1, `count` increments when `up` is 1 and decrements when `up` is 0; otherwise it holds. The counter wraps in both directions. Reset sets `count` to 0. `load` has priority over `en`.

Write the feature list, the transaction, the checks, the coverage items and the test list. A model answer:

**Features**

| ID | Feature |
|---|---|
| F1 | Reset sets `count` to 0 |
| F2 | Count up when `en` = 1, `up` = 1 |
| F3 | Count down when `en` = 1, `up` = 0 |
| F4 | Hold when `en` = 0 and `load` = 0 |
| F5 | Load `din` when `load` = 1 |
| F6 | `load` has priority over `en` |
| F7 | Wrap from 15 to 0 when counting up |
| F8 | Wrap from 0 to 15 when counting down |
| F9 | Change of direction at any value, including 0 and 15 |
| F10 | Reset during counting |

**Transaction.** One transaction is one clock cycle: `rand bit en, up, load; rand bit [3:0] din; logic [3:0] count;`. Constraints: `load` asserted about 10 percent of the time; `din` biased toward 0 and 15; a derived transaction with `en == 1` and `up` held for long runs, so that the wraps are reached.

**Checks.** A reference model in the scoreboard: a 4-bit variable updated every cycle by the same rules (`if (load) m = din; else if (en) m = up ? m + 1 : m - 1;`), compared with `count` using `!==` on every clock edge. Assertions: `count` is 0 while `rst_n` is low; `count` is never X after reset; `count` is stable when `en` and `load` are both 0.

**Coverage**

| Item | Bins |
|---|---|
| `count` | All 16 values |
| Operation | up, down, hold, load |
| Cross operation × `count` at 0 and 15 | Includes both wraps and loads at the limits |
| `load` and `en` both 1 | Occurred |
| `din` on load | 0, 15, others |
| Direction change | up→down and down→up, at 0, at 15, elsewhere |
| Reset while counting | Occurred |

**Tests**

| Test | Type | Purpose |
|---|---|---|
| `cnt_sanity_test` | Directed | Reset, count up five, count down five |
| `cnt_wrap_test` | Directed | Up through 15 → 0; down through 0 → 15 |
| `cnt_load_test` | Directed | Load 0, 15 and a middle value; load with `en` = 1 |
| `cnt_random_test` | Constrained-random | All controls random, many cycles, many seeds |
| `cnt_long_run_test` | Constrained-random | Long runs in one direction to reach the wraps repeatedly |
| `cnt_reset_test` | Random with directed reset | Reset at random times |

**Exit criteria.** All tests passing over many seeds; all coverage items at 100 percent; statement, branch, condition and toggle coverage at 100 percent; no open bugs.

### Further practice (no solutions given)

1. Add a `rand bit inject_x;` field to `alu_txn` meaning "the driver shall drive X on `b` for this transaction". Which methods must change? Which component acts on it? What must the scoreboard do for unary and for binary operations?
2. Write `compare_report()` from Section 3.3 into `alu_txn` and use it in the Exercise 4 scoreboard so that only the differing fields are printed.
3. Write a transaction class for an APB-like bus: `write`, `addr[7:0]`, `wdata[31:0]`, `rdata[31:0]`, `slverr`. Constrain the address to be word-aligned and add a derived class that generates only writes to addresses `0x00` to `0x1C`.
4. Change `tb_alu_selfcheck.sv` so that a second directed call follows the first with no idle cycle between them (back-to-back). What must change in `drive_and_check`?
5. Insert each of these bugs into `alu.sv`, one at a time, and record which tests of `tb_alu_selfcheck.sv` (directed, random, or both) detect it: `ALU_ADD` result truncated to eight bits; `ALU_SHR` shifting left; `valid_out` permanently 1; `ALU_NOT` inverting `b` instead of `a`.
6. Write the verification plan tables (features, checks, coverage, tests) for a 2-to-1 round-robin arbiter, using the outline in Q35.
7. For the FIFO scenarios of Section 4.4, decide for each one whether a scoreboard, an assertion or both should check it, and write one sentence of justification.

## 6.6 Concepts You Must Understand Before Moving Forward

Do not start Module 7 until you can answer each of these without looking at the notes.

**Transactions**

- [ ] I can explain what a transaction is and why the testbench works at transaction level.
- [ ] I can sort the ports of a DUT into stimulus fields, response fields and protocol signals.
- [ ] I can explain why `a` and `b` are `rand bit` and `result` is a non-`rand` `logic`.
- [ ] I can write `new`, `convert2string`, `print`, `copy` and `compare` for a transaction from memory.
- [ ] I can explain the shared-handle bug and two ways to avoid it.
- [ ] I can explain why `compare` uses `===`, skips `id`, and checks for `null`.
- [ ] I can explain why the transaction methods are `virtual`.

**Randomization and reuse**

- [ ] I always check the return value of `randomize()` and can say what happens when it fails.
- [ ] I can explain the two purposes of constraints and why they are split into named blocks.
- [ ] I can create a test-specific transaction by extension, and I know when a derived constraint adds and when it replaces.
- [ ] I can describe the blueprint pattern.

**Verification planning**

- [ ] I can define verification, validation and manufacturing test.
- [ ] I can list the contents of a verification plan and explain how it differs from a test plan.
- [ ] I can take a small specification and derive scenarios category by category.
- [ ] I can compare directed and constrained-random testing and say when each is used.
- [ ] I can compare code coverage and functional coverage and interpret the four combinations of high and low.
- [ ] I can list what makes a testbench self-checking and four ways a test can falsely pass.
- [ ] I can explain where the expected value comes from and why the scoreboard uses the monitor's view of the inputs.
- [ ] I can describe the complete flow from specification to sign-off, the bug life cycle, and the exit criteria.

## 6.7 What Comes Next

The transaction now exists, and you know what the testbench around it has to achieve. Two mechanisms are still missing before the layered testbench can be built.

- **Module 7** covers inter-process communication: events, `fork`...`join`, mailboxes and semaphores. It answers "how does the generator hand an `alu_txn` to the driver while both are running in parallel?" with `gen2drv_mbx`, and "how does the test know the generator has finished?" with `gen_done`.
- **Module 8** covers interfaces, clocking blocks and virtual interfaces. It answers "how does a class reach the DUT's pins?" with `vif`.
- **Module 9** puts everything together: `alu_generator`, `alu_driver`, `alu_monitor`, `alu_scoreboard`, `alu_env` and `alu_test`, built around the `alu_txn` class and the verification plan from this module.
