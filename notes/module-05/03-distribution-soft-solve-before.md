# Part 3: Controlling the Distribution

The constraints of Part 2 decide which values are **legal**. This part is about how **often** each legal value appears (`dist`, `solve`...`before`), and about constraints that give way when they conflict (`soft`).

## 3.1 Distribution Constraints: dist and Weighted Distribution

### In plain English

By default all legal solutions are equally likely. Often that is not what a test needs. Short packets and maximum-length packets find more bugs than the thousands of lengths in between; an error should be injected in 5 percent of the transfers, not 50 percent. A `dist` constraint attaches **weights** to values so that some are chosen more often than others.

### Technical definition

A **distribution constraint** has the form `expression dist { item, item, ... };`. Each item is a value or a range with an optional weight. It does two things:

1. **Membership:** the expression must be equal to one of the listed values or lie in one of the listed ranges (like `inside`).
2. **Weighting:** when nothing else interferes, the probability of each value is proportional to its weight.

### Syntax

```systemverilog
x dist { 0 := 40, [1:3] := 60 };        // := gives the weight to EACH value of the range
x dist { 0 :/ 40, [1:3] :/ 60 };        // :/ DIVIDES the weight among the values of the range
x dist { 0, [1:3] };                    // no weight given: default is := 1
x dist { 0 := w_zero, 255 := w_max, [1:254] :/ w_mid };   // weights may be variables
```

### The two weight operators

| Operator | Name | Meaning for a single value | Meaning for a range of N values |
|---|---|---|---|
| `:=` | "per value" | The value has this weight | **Each** value in the range has this weight (range total = N × weight) |
| `:/` | "per range" | The value has this weight | The range **as a whole** has this weight (each value gets weight / N) |

For a single value the two operators are identical. They differ only for ranges.

### Worked weights

```text
   x dist { 0 := 40, [1:3] := 60 };

      value    weight    probability
        0        40       40/220 = 18.2 %
        1        60       60/220 = 27.3 %
        2        60       60/220 = 27.3 %
        3        60       60/220 = 27.3 %
               -----
      total     220

   x dist { 0 :/ 40, [1:3] :/ 60 };

      value    weight    probability
        0        40       40/100 = 40 %
        1        20       20/100 = 20 %       (60 divided among 3 values)
        2        20       20/100 = 20 %
        3        20       20/100 = 20 %
               -----
      total     100
```

Weights are **relative**. They do not have to add up to 100. `{0 := 1, 1 := 3}` and `{0 := 25, 1 := 75}` describe the same distribution.

### Rules

| Rule | Detail |
|---|---|
| Weights | Any integral expression, including variables. Must not be negative |
| Weight 0 | The value is never chosen |
| Default weight | `:= 1` |
| Values not listed | Illegal: `dist` is also a membership constraint |
| Subject of the `dist` | Must involve at least one `rand` variable. `randc` variables are not allowed |
| Interaction with other constraints | Other constraints may remove some listed values. The remaining values keep their relative weights as far as possible, but the standard only guarantees the exact proportions "absent any other constraints" |
| Negation | A `dist` cannot be negated or used as a sub-expression of `->`, `\|\|` and so on in the way `inside` can. It can be the consequence of an implication or the body of an `if` |

### Complete example

```systemverilog file=tb_dist.sv
module tb_dist;

  class per_value;
    rand bit [1:0] x;
    constraint c { x dist {0 := 40, [1:3] := 60}; }
  endclass

  class per_range;
    rand bit [1:0] x;
    constraint c { x dist {0 :/ 40, [1:3] :/ 60}; }
  endclass

  per_value pv;
  per_range pr;
  int       hist_v[4], hist_r[4];

  initial begin
    pv = new();
    pr = new();
    repeat (2200) begin
      if (!pv.randomize()) $fatal(1, "randomize failed");
      hist_v[pv.x]++;
    end
    repeat (1000) begin
      if (!pr.randomize()) $fatal(1, "randomize failed");
      hist_r[pr.x]++;
    end
    $display(":=  over 2200 calls : %p", hist_v);
    $display(":/  over 1000 calls : %p", hist_r);
  end

endmodule
```

**What to expect.** The first histogram is close to 400, 600, 600, 600 (weights 40, 60, 60, 60 out of 220, times 2200 calls). The second is close to 400, 200, 200, 200 (weights 40, 20, 20, 20 out of 100, times 1000 calls). The numbers fluctuate by a few percent from run to run. Sample output; actual values differ per seed and simulator:

```text
:=  over 2200 calls : '{391, 607, 598, 604}
:/  over 1000 calls : '{412, 195, 188, 205}
```

**Line by line**

| Line | Explanation |
|---|---|
| `x dist {0 := 40, [1:3] := 60};` | Each of 1, 2, 3 gets weight 60. The range is "three times as heavy" as its written weight. |
| `x dist {0 :/ 40, [1:3] :/ 60};` | The range gets 60 in total, 20 per value. Here the written numbers are directly the percentages for the two items. |
| `hist_v[pv.x]++;` | Builds a histogram. Measuring a distribution always needs many samples; a handful of calls proves nothing. |

### A realistic use: packet length and opcode mix

This example needs `alu_pkg.sv` from Module 1.

```systemverilog file=tb_dist_knobs.sv
module tb_dist_knobs;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;

    // weights are ordinary variables: a test can change them at run time
    int unsigned w_arith = 6;
    int unsigned w_logic = 3;
    int unsigned w_shift = 1;

    constraint op_dist_c {
      op dist { ALU_ADD := w_arith, ALU_SUB := w_arith,
                ALU_AND := w_logic, ALU_OR  := w_logic, ALU_XOR := w_logic, ALU_NOT := w_logic,
                ALU_SHL := w_shift, ALU_SHR := w_shift };
    }
    constraint corner_c {
      a dist { 8'h00 := 10, 8'hFF := 10, [8'h01:8'hFE] :/ 80 };   // 10% / 10% / 80%
    }
  endclass

  alu_txn txn;
  int     n_shift, n_a_min, n_a_max;

  initial begin
    txn = new();
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (txn.op inside {ALU_SHL, ALU_SHR}) n_shift++;
      if (txn.a == 8'h00) n_a_min++;
      if (txn.a == 8'hFF) n_a_max++;
    end
    $display("default weights : shifts=%0d a_min=%0d a_max=%0d", n_shift, n_a_min, n_a_max);

    txn.w_arith = 0;                  // a "shift only" test: remove the other opcodes
    txn.w_logic = 0;
    n_shift = 0;
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (txn.op inside {ALU_SHL, ALU_SHR}) n_shift++;
    end
    $display("shift-only test : shifts=%0d", n_shift);
  end

endmodule
```

**What to expect.** With the default weights the total opcode weight is 6+6+3+3+3+3+1+1 = 26, of which the shifts have 2, so `shifts` is about 77 of 1000. `a_min` and `a_max` are each about 100. Without the `dist`, `a` would be `00` only about 4 times in 1000 calls; the `dist` is what makes the corner values common. In the second loop every other weight is 0, so the result is exactly `shifts=1000`.

| Line | Explanation |
|---|---|
| `int unsigned w_arith = 6;` | A state variable used as a weight: a "knob". |
| `op dist {...}` | One weight per opcode. Equal weights within a group. |
| `[8'h01:8'hFE] :/ 80` | 254 values share a weight of 80. With `:=` the range would have a total weight of 254 × 80 and the corners would almost never appear. |
| `txn.w_arith = 0;` | Zero weight removes those opcodes. If **all** weights were set to 0, no value would be legal and `randomize()` would fail. |

### Constraint expressions versus distribution constraints

| Property | Constraint expression (`<`, `==`, `inside`, ...) | Distribution constraint (`dist`) |
|---|---|---|
| Purpose | Define what is **legal** | Define what is legal **and how often** |
| Probability | All solutions equally likely | Proportional to the weights |
| Negation `!( ... )` | Allowed | Not allowed |
| Usable inside larger expressions | Yes | No, only as a constraint item |
| On `randc` variables | Allowed | Not allowed |
| Bidirectional | Yes | The membership part is; the weights are a preference of the solver |
| Guarantee | Always satisfied (hard) | Membership always satisfied; proportions exact only without interfering constraints |
| Typical use | Protocol legality | Steering toward corners; mixing traffic types |

### dist versus inside

| | `x inside {0, [1:3]}` | `x dist {0 := 1, [1:3] := 1}` | `x dist {0 :/ 1, [1:3] :/ 1}` |
|---|---|---|---|
| Legal values | 0, 1, 2, 3 | 0, 1, 2, 3 | 0, 1, 2, 3 |
| P(x = 0) | 1/4 | 1/4 | 1/2 |
| P(x = 1) | 1/4 | 1/4 | 1/6 |

> **Interview trap:** "`x dist {[1:100] := 1, 200 := 50}`: is 200 chosen 50 percent of the time?" No. The range has 100 values of weight 1 each, total 100. 200 has weight 50. P(200) = 50/150 = 33 percent. With `[1:100] :/ 1` the answer would be 50/51.

> **Interview trap:** "What is the difference between `:=` and `:/`?" For a single value, none. For a range, `:=` gives the weight to each value, `:/` splits the weight across the values.

> **Common mistake:** Combining a `dist` on a variable with another constraint that removes most of the listed values, and then expecting the written percentages. Once other constraints interfere, the observed ratio can differ from the written one.

> **Common mistake:** Expecting exact counts. Weights are probabilities. In 100 calls a 10 percent item appears "about 10" times, sometimes 5, sometimes 16.

> **Verification application:** Coverage closure. When the coverage report shows holes at the boundaries, the engineer adds or adjusts `dist` weights (or sets weight knobs from the test) to push stimulus toward the uncovered bins.

### Interview questions

**Q1. What is a `dist` constraint?**
A constraint that restricts an expression to a set of values and ranges and assigns each a weight, so that the values are chosen with probabilities proportional to the weights.

**Q2. Explain `:=` and `:/` with an example.**
`x dist {[1:4] := 20, 5 := 20}`: each of 1 to 4 has weight 20 and 5 has weight 20, so 5 is chosen 20/100 = 20 percent of the time. `x dist {[1:4] :/ 20, 5 :/ 20}`: the range shares 20 (5 each) and 5 has 20, so 5 is chosen 20/40 = 50 percent of the time.

**Q3. Do the weights have to add up to 100?**
No. They are relative. Only the ratios matter.

**Q4. What happens to values that are not listed in the `dist`?**
They are never generated. A `dist` restricts the variable to its listed values.

**Q5. Can a `dist` be applied to a `randc` variable?**
No. A weighted distribution conflicts with the cyclic "each value once" behaviour.

**Q6. Can weights be variables?**
Yes. Weights can be any integral expressions, including class properties set by the test. A weight of 0 disables that value.

**Q7. How do you generate a signal that is 1 about 5 percent of the time?**
`err dist {1 := 5, 0 := 95};`

## 3.2 Soft Constraints

### In plain English

A normal constraint is a law: if it cannot be obeyed, randomization fails. A **soft** constraint is a default: "use this unless someone asks for something else". If a soft constraint conflicts with a normal constraint, the soft one is quietly dropped and randomization still succeeds.

### Technical definition

A constraint expression preceded by the keyword `soft` is a **soft constraint**. All other constraints are **hard constraints**. The solver must satisfy every hard constraint. It satisfies each soft constraint **if doing so is possible** given the hard constraints and the soft constraints of higher priority; otherwise that soft constraint is discarded for this call. Discarding a soft constraint is not an error and produces no message.

### Why it is needed

Before soft constraints existed, a transaction class with a default such as `len == 8` forced every test that wanted a different length to switch the block off with `constraint_mode(0)` or to override it in a derived class. With `soft len == 8`, a test simply writes `txn.randomize() with { len == 20; }`. The default disappears by itself. This makes base classes reusable: the class author supplies sensible defaults, and the test writer overrides them without knowing the names of the constraint blocks.

### Syntax

```systemverilog
class pkt;
  rand bit [7:0] len;
  rand bit [7:0] gap;

  constraint range_c { len inside {[1:64]}; }          // hard: the protocol limit
  constraint dflt_c  { soft len == 8; }                // soft: the default
  constraint gap_c   { soft gap inside {[1:3]}; }      // soft constraints can be any expression
endclass

p.randomize() with { soft len == 3; };                 // soft constraints can also be inline
p.randomize() with { disable soft len; };              // drop the soft constraints on len
```

### Priority between soft constraints

When two soft constraints conflict with each other, the one with the **higher priority** wins. Priority follows a simple idea: **the more specific or later the declaration, the higher the priority.**

| Priority | Where the soft constraint is written |
|---|---|
| Highest | Inline, in `randomize() with { ... }` |
| | In a derived class |
| | In the base class |
| Lowest | In the class of a `rand` member object (the container's constraints outrank the contained object's) |

Within one class, a soft constraint written **later** (in a later block, or later in the same block) has higher priority than one written earlier.

`disable soft x;` discards all soft constraints of lower priority that refer to `x`. It is used when a test wants `x` fully random again without specifying a replacement value.

### How it works internally

```text
   randomize()
      1. Collect hard constraints H and soft constraints S1 (highest priority) ... Sn (lowest)
      2. If H alone has no solution                -> return 0 (failure)
      3. For each soft constraint, highest priority first:
             if H + (softs kept so far) + this one still has a solution  -> keep it
             else                                                        -> drop it
      4. Pick a solution of H + the kept soft constraints
```

A soft constraint is **all or nothing**. It is not a probability or a weight. If it can be honoured it is always honoured in full.

### Complete example

```systemverilog file=tb_soft.sv
module tb_soft;

  class pkt;
    rand bit [7:0] len;
    rand bit [7:0] gap;

    constraint range_c { len inside {[1:64]}; }             // hard
    constraint dflt_c  { soft len == 8; }                   // soft default
    constraint gap_c   { soft gap == 1; soft gap == 2; }    // two soft constraints in conflict
  endclass

  pkt p;
  int status;

  initial begin
    p = new();

    status = p.randomize();
    $display("1. no override          : status=%0d len=%0d gap=%0d", status, p.len, p.gap);

    status = p.randomize() with { len == 20; };
    $display("2. hard inline len==20  : status=%0d len=%0d", status, p.len);

    status = p.randomize() with { soft len == 3; };
    $display("3. soft inline len==3   : status=%0d len=%0d", status, p.len);

    status = p.randomize() with { len > 60; };
    $display("4. hard inline len>60   : status=%0d len in 61..64: %s",
             status, (p.len inside {[61:64]}) ? "yes" : "NO");

    status = p.randomize() with { len == 100; };
    $display("5. hard inline len==100 : status=%0d", status);
  end

endmodule
```

```output
1. no override          : status=1 len=8 gap=2
2. hard inline len==20  : status=1 len=20
3. soft inline len==3   : status=1 len=3
4. hard inline len>60   : status=1 len in 61..64: yes
5. hard inline len==100 : status=0
```

Most simulators print an additional constraint-failure message for call 5.

**Line by line**

| Call | Explanation |
|---|---|
| 1 | Nothing conflicts with `soft len == 8`, so it is honoured: `len` is 8. For `gap`, the two soft constraints contradict each other. The later one (`gap == 2`) has higher priority and is kept; `gap == 1` is dropped. |
| 2 | The hard inline constraint `len == 20` conflicts with `soft len == 8`. The soft constraint is dropped. No failure. |
| 3 | Two soft constraints on `len`: the class default (8) and the inline one (3). Inline has the highest priority, so `len` is 3. |
| 4 | `len > 60` conflicts with the soft default, which is dropped. The hard range constraint still applies, so `len` is 61 to 64. |
| 5 | `len == 100` conflicts with the **hard** constraint `len inside {[1:64]}`. Hard against hard cannot be resolved: `randomize()` returns 0. Soft constraints never rescue a conflict between hard constraints. |

### Soft versus hard constraints

| Property | Hard constraint | Soft constraint |
|---|---|---|
| Keyword | None (the default) | `soft` |
| Must be satisfied | Always | Only if possible |
| Conflict with a hard constraint | `randomize()` fails | The soft constraint is dropped silently |
| Conflict with another soft constraint | Not applicable | The higher-priority one wins |
| Priority | None: all are equal and all must hold | Inline > derived class > base class; later > earlier |
| Can be removed with | `constraint_mode(0)` on the block | `constraint_mode(0)` on the block, or `disable soft var;` |
| Allowed on | `rand` and `randc` variables | `rand` variables only |
| Typical use | Protocol rules that must never be broken | Default values and typical-case preferences that tests may override |

> **Interview trap:** "If a soft constraint conflicts with a hard constraint, does `randomize()` fail?" No. The soft constraint is ignored and the call succeeds.

> **Interview trap:** "Is a soft constraint satisfied with some probability?" No. It is satisfied whenever it does not conflict; otherwise it is dropped entirely.

> **Common mistake:** Making protocol rules soft. If `soft addr[1:0] == 0` is the alignment rule, any test constraint that happens to conflict with it silently produces misaligned addresses. Rules are hard; defaults are soft.

> **Common mistake:** Expecting a soft constraint to be dropped only "as much as necessary". With `soft len inside {[1:10]}` and a hard `len > 8`, there is no conflict: `len` is 9 or 10. With a hard `len > 20`, the entire soft constraint is dropped and `len` can be anything above 20.

> **Verification application:** A reusable transaction ships with soft defaults: `soft delay == 0;`, `soft kind == NORMAL;`, `soft err_inject == 0;`. A directed error test overrides one of them inline: `randomize() with { err_inject == 1; }`, and inherits the remaining defaults unchanged.

### Interview questions

**Q1. What is a soft constraint?**
A constraint marked `soft` that the solver satisfies when possible and silently discards when it conflicts with a hard constraint or with a higher-priority soft constraint.

**Q2. Why were soft constraints introduced?**
To let a class provide default values and behaviours that tests can override with inline or derived constraints, without switching constraint blocks off and without randomization failures.

**Q3. Two soft constraints conflict. Which one is used?**
The one with higher priority: inline `with` constraints over class constraints, derived-class over base-class, and within a class the later-declared over the earlier-declared.

**Q4. What does `disable soft x;` do?**
It removes all lower-priority soft constraints that involve the variable `x`, so that `x` is restricted only by hard constraints and by soft constraints of higher priority.

**Q5. `constraint c1 { soft x == 5; }` and inline `with { x inside {[10:20]}; }`. What is `x`?**
A value from 10 to 20. The soft constraint conflicts with the hard inline constraint and is dropped.

**Q6. `constraint c1 { x == 5; }` and inline `with { soft x == 10; }`. What is `x`?**
5. The inline constraint is soft and conflicts with the hard class constraint, so the inline one is dropped. Being inline gives priority only among soft constraints.

**Q7. Can `randc` variables have soft constraints?**
No. Soft constraints may be specified only for `rand` variables.

## 3.3 solve...before: Variable Ordering

### In plain English

Section 2.4 showed a surprise: with `(mode == 1) -> (len == 3)`, the one-bit variable `mode` was 1 only one time in five, because four of the five legal combinations have `mode` = 0. `solve mode before len` tells the solver: "choose `mode` first, giving each of its legal values an equal chance, and only then choose `len`". The set of legal combinations stays exactly the same. Only the probabilities change.

### Technical definition

`solve a before b;` is a **variable-ordering** constraint. It instructs the solver to pick the value of `a` before the value of `b`. `a` is chosen with a uniform distribution over the values of `a` **that occur in at least one solution**; then `b` is chosen uniformly among the values that complete a solution with that `a`.

Two statements define `solve`...`before` completely:

1. It **does not change the solution space.** Every combination that was legal is still legal, and none that was illegal becomes legal.
2. It **does change the probability** of each solution.

### Syntax

```systemverilog
constraint order_c {
  solve mode before len;                 // one before one
  solve kind, burst before addr, len;    // several before several
}
```

### Worked probability tables

The class used in all three cases:

```systemverilog
rand bit       mode;
rand bit [1:0] len;
constraint imp_c { (mode == 1) -> (len == 3); }
```

The five solutions are (0,0), (0,1), (0,2), (0,3) and (1,3).

```text
   Case A: no ordering                each solution is equally likely

      (mode,len)    probability
        (0,0)          1/5
        (0,1)          1/5
        (0,2)          1/5
        (0,3)          1/5
        (1,3)          1/5           P(mode=1) = 1/5       P(len=3) = 2/5

   Case B: solve mode before len      mode first: 0 or 1, each 1/2

      (mode,len)    probability
        (0,0)       1/2 x 1/4 = 1/8
        (0,1)       1/2 x 1/4 = 1/8
        (0,2)       1/2 x 1/4 = 1/8
        (0,3)       1/2 x 1/4 = 1/8
        (1,3)       1/2 x 1   = 1/2  P(mode=1) = 1/2       P(len=3) = 5/8

   Case C: solve len before mode      len first: 0, 1, 2 or 3, each 1/4

      (mode,len)    probability
        (0,0)       1/4 x 1   = 1/4
        (0,1)       1/4 x 1   = 1/4
        (0,2)       1/4 x 1   = 1/4
        (0,3)       1/4 x 1/2 = 1/8
        (1,3)       1/4 x 1/2 = 1/8  P(mode=1) = 1/8       P(len=3) = 1/4
```

The same five solutions appear in all three tables. The ordering only moves probability between them.

### Complete example

```systemverilog file=tb_solve_before.sv
module tb_solve_before;

  class no_order;
    rand bit       mode;
    rand bit [1:0] len;
    constraint imp_c { (mode == 1) -> (len == 3); }
  endclass

  class mode_first extends no_order;
    constraint order_c { solve mode before len; }
  endclass

  class len_first extends no_order;
    constraint order_c { solve len before mode; }
  endclass

  function automatic int count_mode_one(no_order h);
    int n = 0;
    repeat (1000) begin
      if (!h.randomize()) $fatal(1, "randomize failed");
      if (h.mode == 1) begin
        n++;
        if (h.len != 3) $error("illegal solution mode=1 len=%0d", h.len);
      end
    end
    return n;
  endfunction

  no_order   a;
  mode_first b;
  len_first  c;

  initial begin
    a = new();  b = new();  c = new();
    $display("no ordering           : mode=1 in %0d of 1000", count_mode_one(a));
    $display("solve mode before len : mode=1 in %0d of 1000", count_mode_one(b));
    $display("solve len before mode : mode=1 in %0d of 1000", count_mode_one(c));
  end

endmodule
```

**What to expect.** The three counts are close to 200, 500 and 125 (probabilities 1/5, 1/2 and 1/8). No `$error` message appears in any case, because the legal set is the same for all three classes. Exact counts vary per seed and simulator.

**Line by line**

| Line | Explanation |
|---|---|
| `class mode_first extends no_order;` | Inherits the variables and the implication, and adds only the ordering. |
| `solve mode before len;` | `mode` is picked first. Both 0 and 1 are part of at least one solution, so each gets probability 1/2. |
| `count_mode_one(no_order h)` | The argument is a base-class handle. Because `randomize()` is virtual, the constraints of the actual object (including `order_c`) are used. |
| `if (h.len != 3) $error(...)` | Checks that the ordering has not created an illegal solution. |

### Restrictions and implicit orderings

| Rule | Detail |
|---|---|
| Variables | Must be `rand` integral variables. `randc` variables are not allowed (they are always solved first anyway) |
| Circular ordering | `solve a before b; solve b before a;` is an error |
| Cannot fix a failure | If the constraints have no solution, no ordering will create one |
| Cannot cause a failure | The solver only picks values of the first variable that are part of a complete solution |
| Not needed when | The relation between the variables is one-to-one (for example `b == a + 1`), because then every value already has the same number of solutions |

Besides explicit `solve`...`before`, the language has **implicit** orderings:

| Implicit ordering | Can it cause a failure? |
|---|---|
| `randc` variables are solved before `rand` variables | Yes: the cyclic value is fixed first and the rest must fit around it |
| The size of a dynamic array or queue is solved before its elements | Yes, if the chosen size makes the element constraints impossible |
| Arguments of a function called in a constraint are solved before the function's result is used (Section 3.4) | Yes |

> **Key point:** Explicit `solve`...`before` is a pure probability control and is always safe. The three implicit orderings are real "decide this first" steps and can turn a solvable problem into a failure.

> **Interview trap:** "Does `solve a before b` change which values are legal?" No. It changes only how often each legal combination is selected.

> **Interview trap:** "My `randomize()` fails. Will `solve before` fix it?" No. If the solution space is empty, nothing is left to order.

> **Common mistake:** Reading `solve a before b` as "apply the constraints on `a` first and ignore `b`". The solver still considers all constraints together when deciding which values of `a` are possible.

> **Verification application:** The usual pattern is a "kind" or "type" variable that determines the range of a data variable: `solve kind before len;`. Without it, kinds with large length ranges dominate and kinds with a single legal length (for example a zero-length control packet) almost never occur. An alternative that needs no ordering is to put a `dist` on `kind`.

### Interview questions

**Q1. What does `solve`...`before` do?**
It sets the order in which the solver assigns the variables, which changes the probability distribution of the solutions. It does not change the set of legal solutions.

**Q2. `rand bit a; rand bit [1:0] b; constraint c { a -> b == 0; }` Give P(a=1) without ordering, with `solve a before b`, and with `solve b before a`.**
Solutions: (0,0), (0,1), (0,2), (0,3), (1,0). Without ordering: 1/5. With `solve a before b`: 1/2. With `solve b before a`: `b` is 0 with probability 1/4, and then `a` is 1 with probability 1/2, so 1/8.

**Q3. Can `solve`...`before` be used with `randc`?**
No. `randc` variables are not permitted in `solve`...`before`; they are always solved first.

**Q4. When is `solve`...`before` needed?**
When one variable's value determines how many values another variable can take, typically through an implication or `if`-`else`, and the first variable should have a balanced (or at least non-negligible) distribution.

**Q5. Is there a way to get the same effect without `solve`...`before`?**
Yes: put an explicit `dist` on the controlling variable, or randomize in two steps (randomize the controlling variable first, then the rest with it as a state variable). The two-step approach, unlike `solve`...`before`, is a real ordering and can fail if the first choice leaves no solution.

**Q6. Does the order in which constraints are written have the same effect as `solve`...`before`?**
No. Textual order has no effect at all.

## 3.4 Functions in Constraints

### In plain English

Some relationships are awkward or impossible to write as a single expression: a lookup in a table, a checksum, a calculation with a loop. A constraint may call a **function** to compute such a value. There is a price: the solver cannot see inside the function, so it cannot solve "backwards" through it.

### Rules

| Rule | Detail |
|---|---|
| What can be called | Functions only (no tasks). Usually a class method or a package function |
| Lifetime | The function must be `automatic` (class methods are automatic by default) |
| Arguments | `input` or `const ref` only. No `output`, `inout` or non-const `ref` |
| Side effects | None. The function must not modify class properties, and must not call `rand_mode()` or `constraint_mode()` |
| Number of calls | Unspecified. The solver may call the function any number of times, in any order |

### How it works internally: an implicit ordering

When a random variable is used as an **argument** of a function in a constraint, the solver:

1. solves the argument variables **first**, using only the constraints that involve those variables and no lower-priority ones,
2. calls the function with the chosen values,
3. treats the returned value as a **constant** while solving the remaining variables.

```text
   constraint c { y == twice(x);  y < 6; }

   Step 1:  x is solved on its own. No constraint mentions only x -> x is any value 0..15.
   Step 2:  twice(x) is evaluated, say x = 9 -> 18.
   Step 3:  solve y with  y == 18  and  y < 6   -> impossible -> randomize() returns 0.

   The solver does NOT go back and choose a smaller x.
```

The function call has broken the bidirectional link between `x` and `y`. Information flows only from the arguments to the result.

### Complete example

```systemverilog file=tb_func_constraint.sv
module tb_func_constraint;

  class with_function;
    rand bit [3:0] x;
    rand bit [4:0] y;

    function automatic bit [4:0] twice(bit [3:0] v);
      return 2 * v;
    endfunction

    constraint c { y == twice(x); y < 6; }
  endclass

  class with_expression;
    rand bit [3:0] x;
    rand bit [4:0] y;
    constraint c { y == 2 * x; y < 6; }
  endclass

  with_function   f;
  with_expression e;
  int             f_fail, e_fail;

  initial begin
    f = new();
    e = new();
    repeat (1000) begin
      if (!f.randomize()) f_fail++;
      if (!e.randomize()) e_fail++;
    end
    $display("with function   : %0d failures in 1000 calls", f_fail);
    $display("with expression : %0d failures in 1000 calls", e_fail);
  end

endmodule
```

**What to expect.** The expression version never fails: the line reads exactly `with expression : 0 failures in 1000 calls`, because the solver restricts `x` to 0, 1 or 2 so that `y` is 0, 2 or 4. The function version fails whenever the independently chosen `x` is 3 or more, which is 13 of its 16 values, so it reports about 810 failures (the simulator will also print a failure message for each one unless such messages are switched off).

**Line by line**

| Line | Explanation |
|---|---|
| `function automatic bit [4:0] twice(...)` | A side-effect-free function with an `input` argument. |
| `y == twice(x); y < 6;` | `x` is a function argument and is solved first, alone. `y < 6` cannot influence it. |
| `y == 2 * x; y < 6;` | The same relation as an expression. The solver sees the whole relation and restricts `x` accordingly. |

### When to use a function, and what to use instead

| Situation | Recommendation |
|---|---|
| The relation can be written as an expression | Write the expression. It stays bidirectional |
| A derived value (CRC, parity, checksum, length field) that nothing else depends on | Compute it in `post_randomize()` (Section 4.1), not in a constraint |
| A value computed from **state** variables only | A function is fine: nothing random flows through it |
| A complex mapping from one random variable to a bound for another (for example "maximum length allowed for this kind") | A function is acceptable; remember that the argument is solved first and is not influenced by the other variable |

> **Interview trap:** "Are constraints with function calls bidirectional?" No. The arguments are solved first and the return value is then a constant. This is the main exception to the "all constraints are solved together" rule.

> **Common mistake:** A function in a constraint that modifies a class property, prints, or counts calls. The solver may call it many times or not at all.

### Interview questions

**Q1. Can you call a function inside a constraint?**
Yes, if the function is automatic, has only input (or const ref) arguments and has no side effects.

**Q2. How does the solver treat a function call in a constraint?**
It first solves the random variables used as arguments, then evaluates the function, and then uses the result as a constant when solving the remaining variables. This creates an implicit ordering and removes bidirectionality across the call.

**Q3. Why can a constraint with a function fail where the equivalent expression would succeed?**
Because the argument variables are chosen without regard to the constraints on the function's result. If the chosen arguments produce a result that violates another constraint, the solver cannot go back.

**Q4. Where should a CRC or checksum field be computed?**
In `post_randomize()`, after all random fields have their final values. It is a derived value, not a random one.
