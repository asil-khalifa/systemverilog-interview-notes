# Part 2: Randomizing and Constraining Transactions

## 2.1 Randomizing Transactions

### In plain English

A directed test fills in the transaction by hand: "add 200 and 100". That tests one case. To test thousands of cases without writing thousands of lines, the testbench asks the simulator to fill in the fields with random values. Because the stimulus fields were declared `rand`, one method call does it:

```systemverilog
t = new();
if (!t.randomize()) $fatal(1, "randomize() failed");
```

After the call, `a`, `b` and `op` hold a new random combination. Call it again and they hold another.

### Technical definition

Every class has a built-in virtual method `randomize()`. When it is called on an object, the constraint solver finds values for all active `rand` and `randc` properties of that object such that every active constraint is satisfied, and writes those values into the object. It returns 1 on success and 0 if no solution exists. Module 5 covers the mechanism in depth; this section applies it to the transaction.

### What happens inside one call

```text
   t.randomize()
        |
        v
   1. pre_randomize() is called (does nothing unless you defined it)
        |
        v
   2. The solver collects: the rand fields that are switched on  (a, b, op)
                           the constraint blocks that are switched on
                           any inline constraints given with "with { ... }"
        |
        v
   3. Is there at least one combination of values that satisfies everything?
        |                                   |
       yes                                  no
        |                                   |
        v                                   v
   4. One solution is chosen at         The object is left unchanged.
      random and written into           randomize() returns 0.
      a, b, op.                         post_randomize() is NOT called.
        |
        v
   5. post_randomize() is called
        |
        v
   6. randomize() returns 1

   Fields that are not rand (result, id) are never modified.
```

### Rules that matter for transactions

| Rule | Consequence in a testbench |
|---|---|
| Only `rand`/`randc` fields are changed | `result` and `id` keep their values across `randomize()` |
| The return value reports failure | It must always be checked. An unchecked failure leaves the previous values in place, and the test silently repeats the same transaction or drives default values |
| An enum field receives only declared members | `op` can never be an illegal encoding |
| Four-state `rand` fields receive only 0 and 1 | Random stimulus never contains X or Z |
| With no constraints, every value is equally likely | `a` and `b` are uniform over 0 to 255, `op` uniform over the eight operations |
| The same seed gives the same sequence of values | A failing test can be re-run with its seed to reproduce the failure exactly |

### Ways to check the return value

```systemverilog
// 1. if + fatal: simple, always active, the form used in this course
if (!t.randomize()) $fatal(1, "randomize() failed");

// 2. immediate assertion: shorter, but see the trap below
assert (t.randomize()) else $fatal(1, "randomize() failed");

// 3. cast to void: compiles without warning but HIDES failures. Do not use.
void'(t.randomize());
```

> **Interview trap:** "What is wrong with `assert(t.randomize());`?" Nothing while assertions are enabled. But assertions can be switched off globally (with `$assertoff` or a simulator option), and some tools then do not evaluate the expression at all, so `randomize()` is never called and the test runs with unrandomized transactions. The `if (!t.randomize())` form has no such risk.

### New object or the same object each time?

A generator can call `randomize()` repeatedly on one object, or create a new object for each transaction. The difference matters as soon as the handle is passed to another component.

| Approach | Code | Safe? |
|---|---|---|
| New object per transaction | `t = new(); t.randomize(); send(t);` | Yes. Every receiver gets its own object |
| One object, send a copy | `bp.randomize(); send(bp.copy());` | Yes. The "blueprint" pattern of Section 3.4 |
| One object, send the handle | `t.randomize(); send(t);` in a loop | **No.** Every receiver holds a handle to the same object, whose fields keep changing. Section 3.2 demonstrates the bug |

### Complete example

```systemverilog file=tb_txn_randomize.sv
module tb_txn_randomize;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    function void print(string tag = "");
      $display("%s: id=%0d op=%s a=0x%h b=0x%h", tag, id, op.name(), a, b);
    endfunction
  endclass

  alu_txn      t;
  int unsigned n_legal_op, n_id_kept;

  initial begin
    // 1. Four random transactions, a new object for each
    for (int i = 0; i < 4; i++) begin
      t    = new();
      t.id = i;
      if (!t.randomize()) $fatal(1, "randomize() failed");
      t.print("RAND");
    end

    // 2. Properties that hold on every run, checked over 500 randomizations
    t    = new();
    t.id = 77;
    repeat (500) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op.name() != "") n_legal_op++;     // op is always a declared member
      if (t.id == 77)        n_id_kept++;      // a non-rand field is never touched
    end
    $display("legal opcode in %0d of 500, id unchanged in %0d of 500",
             n_legal_op, n_id_kept);
  end

endmodule
```

Sample output; actual values in the first four lines differ per seed and simulator. The last line is the same on every run.

```output
RAND: id=0 op=ALU_XOR a=0x3d b=0xb1
RAND: id=1 op=ALU_ADD a=0xe6 b=0x07
RAND: id=2 op=ALU_SHR a=0x58 b=0xfa
RAND: id=3 op=ALU_SUB a=0x91 b=0x2c
legal opcode in 500 of 500, id unchanged in 500 of 500
```

**Line by line**

| Line | Explanation |
|---|---|
| `t = new(); t.id = i;` | A new object for each transaction; the creator assigns the serial number. |
| `if (!t.randomize()) $fatal(...)` | Randomize and check. `$fatal` stops the simulation: continuing after a randomization failure produces meaningless results. |
| `t.print("RAND");` | One log line per transaction. `op.name()` prints the opcode by name. |
| `if (t.op.name() != "")` | `name()` returns an empty string for a value that is not a member. It never does here, because the solver only chooses declared members of an enum. |
| `if (t.id == 77)` | `id` is not `rand`, so 500 calls to `randomize()` leave it alone. |

### Interview questions

**Q1. How do you randomize a transaction?**
Declare the stimulus fields `rand`, create the object, and call its built-in `randomize()` method, checking that it returns 1.

**Q2. What does `randomize()` return, and what happens to the object if it fails?**
1 on success, 0 on failure. On failure the `rand` fields keep their previous values and `post_randomize()` is not called.

**Q3. Does `randomize()` change non-`rand` fields?**
No. Only active `rand` and `randc` properties are assigned.

**Q4. Can `randomize()` give an enum field an illegal value?**
No. The solver restricts an enum variable to its declared members.

**Q5. A test fails in the nightly regression. How do you reproduce it?**
Re-run the same test with the same random seed, which the simulator prints in the log. SystemVerilog guarantees the same sequence of random values for the same seed and the same code (random stability), so the failure repeats exactly.

**Q6. Why should the return value of `randomize()` not be discarded with `void'()`?**
Because a failure then goes unnoticed: the transaction keeps its old or default values and the test continues with stimulus that nobody intended, often passing while testing nothing.

## 2.2 Constraint-Based Transactions

### In plain English

Unconstrained random values are legal for the ALU, because it accepts any operands and any opcode. But "legal" is not the same as "useful". With `a` uniform over 256 values, the value `8'hFF` appears about once in 256 transactions, and the pair `a = FF, b = FF` about once in 65,536. Yet the corners (zero, all ones, carry, borrow) are exactly where arithmetic bugs live.

Constraints put the designer's knowledge into the transaction. They do two jobs:

1. **Legality:** rule out stimulus the DUT is specified not to receive. (For many designs this is essential: an address must be inside the memory, a length must match the payload, a reserved opcode must not be sent.)
2. **Interest:** steer the random values toward the cases most likely to expose bugs.

### Technical definition

A constraint block is a named, declarative member of a class that states relationships which the `rand` properties must satisfy after `randomize()`. All active constraints are solved simultaneously. A transaction whose legal and interesting values are defined by constraint blocks inside the class is called a constraint-based (or constrained-random) transaction.

### Kinds of constraints found in a transaction class

| Kind | Purpose | Example | Where it lives |
|---|---|---|---|
| Validity (legal range) | Never generate what the specification forbids | `addr inside {[0:1023]};` | Base transaction, always on |
| Relationship between fields | Keep fields consistent | `len == payload.size();` | Base transaction, always on |
| Distribution | Make some values more frequent | `op dist {ALU_ADD := 2, ...};` | Base transaction, may be switched off |
| Corner bias | Hit boundary values often | `a dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};` | Base transaction, may be switched off |
| Default that tests may override | A sensible value unless a test says otherwise | `soft delay inside {[0:3]};` | Base transaction |
| Test-specific | Focus one test on one feature | `op == ALU_ADD; a + b > 255;` | Derived class, or inline `with { }` |
| Error injection | Deliberately generate illegal stimulus | Validity constraint switched off with `constraint_mode(0)` | Error test |

> **Key point:** Keep validity constraints and distribution constraints in **separate, named blocks**. A test that wants a different distribution can then switch off or replace one block without accidentally permitting illegal stimulus.

### Constraints for the ALU transaction

```systemverilog
// Arithmetic is the most complex logic, so ADD and SUB get double weight.
constraint op_dist_c {
  op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
            ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
}

// Operands: 10 percent zero, 10 percent all ones, 80 percent anything in between.
constraint corner_c {
  a dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
  b dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
}
```

Reading the `dist` weights (Module 5):

- `:=` gives the weight to **each** value. `ALU_ADD := 2` gives ADD a weight of 2. The weights of `op` sum to 10, so ADD is chosen about 2 times in 10.
- `:/` shares the weight across the **whole range**. `[8'h01:8'hFE] :/ 8` gives the 254 middle values a total weight of 8 between them. So `a` is `00` about 1 time in 10, `FF` about 1 time in 10, and somewhere in between 8 times in 10.

The effect on corner coverage is large:

| Event | Unconstrained probability | With `corner_c` |
|---|---|---|
| `a == 8'hFF` | 1 in 256 | 1 in 10 |
| `a == 8'hFF` and `b == 8'hFF` | 1 in 65,536 | 1 in 100 |
| `a == 0` and `b == 0` | 1 in 65,536 | 1 in 100 |

### Controlling constraints from a test

| Mechanism | Syntax | Effect | Typical use |
|---|---|---|---|
| Inline constraint | `t.randomize() with { op == ALU_SUB; a < b; }` | Adds constraints for this one call | A quick, local restriction |
| Switch a block off or on | `t.corner_c.constraint_mode(0);` | The block is ignored until switched back on | Remove a bias; error injection |
| Fix a field | `t.op.rand_mode(0);` | The field keeps its current value and is treated as a constant by the solver | Hold one field while the others vary |
| Derived class | `class alu_carry_txn extends alu_txn; constraint carry_c {...} endclass` | Adds constraints, or replaces a base block of the same name | A reusable, named test scenario (Section 3.4) |
| `soft` constraint | `constraint d_c { soft delay == 0; }` | Applies unless a harder constraint contradicts it | Defaults that a test may override without switching anything off |

### pre_randomize() and post_randomize() in a transaction

These two built-in methods are called automatically by `randomize()`. They are empty unless the class defines them.

| Hook | Runs | Typical use in a transaction |
|---|---|---|
| `pre_randomize()` | Before the solver | Switch constraints or `rand_mode` according to a configuration field; set non-random fields that constraints depend on |
| `post_randomize()` | After a successful solve | Compute fields that are a function of the random ones (CRC, parity, checksum, length); clear a stale response field; print the transaction for debug |

```systemverilog
function void post_randomize();
  result = 'x;      // a newly randomized stimulus has no response yet
endfunction
```

A packet class would compute its checksum here: the payload is random, and the checksum is not random but derived from the payload, so it cannot be a `rand` field with a simple constraint.

### Complete example

```systemverilog file=tb_txn_constraints.sv
module tb_txn_constraints;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
                ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
    }

    constraint corner_c {
      a dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
      b dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
    }

    function void post_randomize();
      result = 'x;
    endfunction
  endclass

  alu_txn      t;
  int unsigned n_add, n_zero, n_max, n_ok;

  initial begin
    t = new();

    // 1. Default constraints: count how often the biased values appear
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op == ALU_ADD) n_add++;
      if (t.a  == 8'h00)   n_zero++;
      if (t.a  == 8'hFF)   n_max++;
    end
    $display("1. bias on  : ADD=%0d  a==00: %0d  a==FF: %0d  (of 1000)",
             n_add, n_zero, n_max);

    // 2. Switch the corner bias off: a becomes uniform again
    t.corner_c.constraint_mode(0);
    n_zero = 0;
    n_max  = 0;
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.a == 8'h00) n_zero++;
      if (t.a == 8'hFF) n_max++;
    end
    $display("2. bias off : a==00: %0d  a==FF: %0d  (of 1000)", n_zero, n_max);
    t.corner_c.constraint_mode(1);

    // 3. Inline constraint: only subtractions that borrow
    repeat (100) begin
      if (!t.randomize() with { op == ALU_SUB; a < b; }) $fatal(1, "randomize() failed");
      if (t.op == ALU_SUB && t.a < t.b) n_ok++;
    end
    $display("3. inline constraint satisfied in %0d of 100", n_ok);

    // 4. Contradictory constraints: no solution exists
    if (!t.randomize() with { a == 8'h00; a > b; })
      $display("4. randomize() returned 0: no value of b is less than 0");
  end

endmodule
```

Sample output; the counts in lines 1 and 2 differ per seed and simulator but stay close to the values shown. Lines 3 and 4 are the same on every run. Before line 4 the simulator also prints its own message about the constraint conflict.

```output
1. bias on  : ADD=204  a==00: 97  a==FF: 105  (of 1000)
2. bias off : a==00: 5  a==FF: 3  (of 1000)
3. inline constraint satisfied in 100 of 100
4. randomize() returned 0: no value of b is less than 0
```

**Line by line**

| Line | Explanation |
|---|---|
| `constraint op_dist_c {...}` | The weights sum to 10; ADD has 2 of them, so about 200 of 1000 transactions are ADD (unweighted it would be about 125). |
| `constraint corner_c {...}` | Two independent `dist` expressions in one block, one per operand. About 100 of 1000 values of `a` are `00` and about 100 are `FF`. |
| `function void post_randomize();` | Runs after every successful randomization and marks the response as "not captured yet". |
| `t.corner_c.constraint_mode(0);` | Switches off that one block in that one object. `a` is now uniform, so each specific value appears about 4 times in 1000. |
| `t.corner_c.constraint_mode(1);` | Switches it back on. A constraint that is switched off stays off until this call. |
| `randomize() with { op == ALU_SUB; a < b; }` | The inline constraints are solved **together with** the class constraints. `op == ALU_SUB` is compatible with `op_dist_c` because SUB has a non-zero weight. |
| `if (t.op == ALU_SUB && t.a < t.b) n_ok++;` | The testbench checks its own stimulus. Every one of the 100 satisfies the constraint. |
| `with { a == 8'h00; a > b; }` | `a` must be 0 and also greater than the unsigned `b`. Impossible, so `randomize()` returns 0 and leaves the object unchanged. |

> **Common mistake:** Giving a value a `dist` weight of zero, or leaving it out of the `dist` list, and then asking for it inline. `op dist {ALU_ADD := 1, ALU_SUB := 1}` makes the other six opcodes impossible; `randomize() with { op == ALU_XOR; }` then fails. A `dist` is also a constraint on the set of allowed values.

> **Common mistake:** Over-constraining the base transaction. If the base class contains `a < b`, no test can ever generate `a >= b` without switching the constraint off, and the engineer who writes the next test may not know it exists. The base class should contain what is **always** true; narrowing belongs in tests.

> **Verification application:** In the Module 9 testbench the generator never mentions `ALU_ADD` or `8'hFF`. It only calls `randomize()`. What the stimulus looks like is decided entirely by the constraints in `alu_txn` and its test-specific extensions. That division is what lets one environment run many different tests.

### Constraints compared with procedural code

A beginner often asks why constraints are needed when the same effect seems achievable with `$urandom` and `if` statements.

| Aspect | Procedural (`$urandom_range`, `if`) | Constraints |
|---|---|---|
| Style | Step by step: "how to compute a value" | Declarative: "what must be true" |
| Related fields | The order of assignments decides which field is chosen first; hard to keep relations correct | All fields are solved together |
| Changing behaviour in a test | Edit the code | Add, replace or switch off a constraint; the original code is untouched |
| Combining requirements from several places | Manual | Automatic: base class + derived class + inline are solved as one set |
| Impossible requirements | Silent wrong values | `randomize()` returns 0 |

### Interview questions

**Q1. What is a constraint-based transaction?**
A transaction class whose `rand` fields are restricted and shaped by constraint blocks, so that each `randomize()` call produces a legal and useful operation.

**Q2. What are the two purposes of constraints in a transaction?**
Legality (never generate stimulus the specification forbids) and interest (bias the stimulus toward corner cases and important scenarios).

**Q3. Why split constraints into several named blocks?**
So that each can be switched off with `constraint_mode(0)` or replaced in a derived class independently. A test can change the distribution without disturbing the validity rules.

**Q4. How do you make corner values such as 0 and all ones appear frequently?**
With a `dist` constraint that gives those values explicit weights, for example `a dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};`.

**Q5. What is the difference between `:=` and `:/` in `dist`?**
`:=` assigns the weight to every value in the item; `:/` divides the weight equally among the values of the item.

**Q6. What is `post_randomize()` used for in a transaction?**
For fields that depend on the randomized ones but cannot be expressed as simple constraints, such as a CRC or checksum, and for clean-up such as clearing the response field.

**Q7. A test needs only ADD operations that produce a carry. Give two ways to get them.**
Inline: `t.randomize() with { op == ALU_ADD; a + b > 255; }`. Or a derived class `alu_carry_txn` with a constraint block containing the same expressions, which the test supplies to the generator.

**Q8. How would you generate an illegal transaction on purpose?**
Switch off the validity constraint with `constraint_mode(0)` (and usually add a constraint that forces the illegal value), in a test dedicated to error handling. The scoreboard must know that an error is expected.
