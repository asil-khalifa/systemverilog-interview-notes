# Part 6: Module 5 Revision and Practice

## 6.1 Revision Summary

### The mechanism in one page

| Item | Summary |
|---|---|
| `rand` | Random; uniform over the legal values; values may repeat |
| `randc` | Random-cyclic; no repeat until all legal values are used; history is per object; solved first; integral types only |
| `randomize()` | Built-in virtual method; returns 1 on success, 0 on failure; on failure nothing changes |
| State variable | Any non-random variable in a constraint; its current value is a constant for the solver |
| Constraint block | Named class member; a set of expressions that must all be true |
| Solver | Considers all active constraints together; picks one solution; all solutions equally likely unless `dist` or `solve before` says otherwise |
| `pre_randomize()` | Runs before the solver, also when the call later fails |
| `post_randomize()` | Runs after a successful solve only; constraints are not re-checked afterwards |

### Constraint constructs

| Construct | Meaning | Remember |
|---|---|---|
| `a < b;` | Relational | Bidirectional. No chained comparisons (`1 < x < 5` is wrong) |
| `a + b == 10;` | Arithmetic | Normal width and sign rules apply: overflow, unsigned subtraction |
| `x inside {[1:5], 9};` | Set membership | Uniform over the values, not over the items |
| `A -> B;` | Implication | Same as `!A \|\| B`. Also means "not B implies not A" |
| `if (A) B; else C;` | Conditional | Same as `(A -> B) && (!A -> C)`. Braces, not `begin`...`end` |
| `A <-> B;` or `A == B;` | Equivalence | Both directions |
| `foreach (a[i]) ...` | Per-element | Unrolled after the size is known. Guard neighbour indices |
| `a.sum() with (int'(item))` | Reduction | The sum has the element's width unless cast |
| `unique {a, b, arr};` | All different | Within one call only |
| `x dist {v := w, [r] :/ w};` | Weighted distribution | `:=` weight per value; `:/` weight shared by the range |
| `soft x == 5;` | Default | Dropped silently on conflict; inline > derived > base; later > earlier |
| `solve a before b;` | Ordering | Changes probabilities only, never the legal set |
| `f(x)` in a constraint | Function call | Arguments are solved first; not bidirectional |

### Controls

| Control | Syntax | Effect |
|---|---|---|
| Disable a constraint | `obj.c.constraint_mode(0);` | The block is ignored |
| Freeze a variable | `obj.v.rand_mode(0);` | The variable becomes state; constraints on it still apply |
| Inline constraint | `obj.randomize() with { ... };` | Added to the class constraints for this call |
| Outer-scope name | `local::name` | Resolves a name in the calling scope inside `with` |
| Partial randomization | `obj.randomize(a, b);` | Only `a` and `b` are random in this call |
| Check only | `obj.randomize(null);` | Returns 1 if the current values are legal |
| Scope randomization | `std::randomize(v) with { ... };` | Randomizes ordinary variables |
| Seed an object | `obj.srandom(seed);` | Sets that object's random generator |

### The six comparisons

| Compare | In one sentence |
|---|---|
| `rand` vs `randc` | `rand` picks independently each time and can repeat; `randc` cycles through every legal value once before repeating |
| Constraint expression vs `dist` | An expression says what is legal, with equal probability; `dist` says what is legal and how often |
| Implication vs `if`-`else` | Same logic and both bidirectional; `if`-`else` has a built-in "otherwise" branch, `->` is a compact expression |
| Soft vs hard | A hard constraint must hold or the call fails; a soft constraint is a default that is dropped when it conflicts |
| `rand_mode()` vs `constraint_mode()` | `rand_mode` switches variables, and the frozen value must still be legal; `constraint_mode` switches rules and can never cause a failure |
| `pre_randomize()` vs `post_randomize()` | `pre` prepares the solve and always runs; `post` completes the object and runs only on success |

### Implicit orderings (the only places where the solver "decides first")

1. `randc` variables before `rand` variables.
2. The size of a dynamic array or queue before its elements.
3. The arguments of a function called in a constraint before the function's result.

All three can make a solvable problem fail. Explicit `solve`...`before` cannot.

### The traps, in one list

- `rand` forgotten: the variable is a constant.
- Return value of `randomize()` not checked.
- `assert(obj.randomize())` with assertions disabled.
- A new object per iteration destroys `randc`.
- Dynamic array without a size constraint stays empty; without an upper bound it may become huge.
- `1 < x < 5`; `a - b > 0` on unsigned values; `x < 10` on a signed variable.
- `a + b == 8'd10` wraps; `arr.sum()` wraps; `sum() with (item == 5)` is one bit wide.
- `!x inside {...}` needs parentheses; `x & (x - 1) == 0` needs parentheses.
- `d[i+1]` or `d[i-1]` without a guard.
- `x inside {[1:100], 200}` does not give 200 half the probability.
- A soft constraint is not a probability; inline constraints do not override hard class constraints.
- `rand_mode(0)` does not remove the constraints on the variable.
- `with { addr == addr; }` constrains nothing.
- A derived-class constraint with a new name is added, not substituted.
- `post_randomize()` is skipped on failure and can break constraints unnoticed.

## 6.2 Interview Questions and Answers

The questions at the end of each section cover the direct definitions. The questions below are additional.

### Basic level

**Q1. What are the three things needed for class-based randomization?**
Properties declared `rand` or `randc`, constraint blocks that restrict them, and a call to `randomize()` on a constructed object.

**Q2. Where can `rand` be used?**
On class properties. Ordinary module variables and local variables cannot be declared `rand`; they are randomized with `std::randomize()`.

**Q3. What is the return type of `randomize()`?**
`int`: 1 for success, 0 for failure.

**Q4. Write a constraint that keeps an 8-bit value between 10 and 50, excluding 25.**
`constraint c { x inside {[10:50]}; x != 25; }`

**Q5. How do you randomize a variable without declaring a class?**
`std::randomize(var) with { ... };` or, for a simple range, `var = $urandom_range(max, min);`.

**Q6. What is the default distribution of a `rand` variable?**
Uniform over its legal values when no other variable is involved. In general, all solutions (combinations of all variables) are equally likely.

**Q7. What is the difference between `$urandom_range(10)` and `$urandom % 10`?**
The first returns 0 to 10 inclusive; the second returns 0 to 9.

**Q8. Can constraints be written outside the class?**
Yes, as an external constraint: declare `constraint c;` in the class and define `constraint cls::c { ... }` outside.

**Q9. Can a constraint block be empty?**
Yes. It restricts nothing. An empty block is also used in a derived class to cancel an inherited block of the same name.

**Q10. What happens to non-`rand` properties when `randomize()` is called?**
They are not changed. If they appear in constraints their current values are used as constants.

### Intermediate level

**Q11. How many solutions does `rand bit [2:0] a, b; constraint c { a + b == 3'd7; }` have, and how many does `a + b == 7` have?**
With the 3-bit literal the sum is computed in 3 bits: for each of the 8 values of `a` exactly one `b` works, so 8 solutions. With the 32-bit literal `7` the sum is computed in 32 bits: also 8 solutions (0+7, 1+6, ..., 7+0). They coincide for 7. For a target of 3 they differ: `== 3'd3` has 8 solutions (including 4+7 = 11, which is 3 in 3 bits), while `== 3` has only 4.

**Q12. Why is a `rand bit` field preferred to a `rand logic` field?**
The solver produces two-state values in both cases. `bit` is faster, uses less memory, and cannot be accidentally left at X when used as a state variable in a constraint.

**Q13. Can you constrain a non-random variable?**
You can write the constraint, and it will be **checked**: the call fails if the variable's value violates it. But the solver cannot change the variable.

**Q14. How do you make sure a `dist` is exact?**
You cannot guarantee exact proportions over a finite number of calls; weights are probabilities. They are also only exact when no other constraint interferes with the variable. Measure with coverage.

**Q15. How do you randomize a variable to any value except those in a queue?**
`constraint c { !(x inside {used_q}); }`

**Q16. What is the difference between `foreach` in a constraint and `foreach` in procedural code?**
In a constraint it is unrolled into a set of simultaneous constraints, one per element; nothing is executed in sequence. In procedural code it is a loop that executes its body repeatedly.

**Q17. Can you call `randomize()` inside `post_randomize()`?**
On other objects, yes, and it is sometimes done to randomize sub-items in a second stage. Calling `this.randomize()` there would recurse endlessly.

**Q18. How do you constrain a queue to hold between 3 and 6 elements, all different, in descending order?**
`constraint c { q.size() inside {[3:6]}; foreach (q[i]) if (i > 0) q[i] < q[i-1]; }`. Strict descending order already makes the elements different.

**Q19. Is `constraint c { a == b; }` the same as assigning `a = b` in `post_randomize()`?**
No. The constraint is bidirectional: other constraints on `a` also restrict `b`, and the solver chooses both consistently. The assignment overwrites `a` after solving, without checking any constraint on `a`.

**Q20. How do you get 70 percent reads and 30 percent writes?**
`constraint c { write dist {0 := 70, 1 := 30}; }`

**Q21. What does `constraint c { x inside {a_queue}; }` do when the queue is empty?**
The set is empty, so the constraint cannot be satisfied and `randomize()` fails.

**Q22. How do `static` random variables behave?**
`static rand` properties are shared by all objects of the class. Each `randomize()` call on any object assigns the shared copy a new value.

### Advanced and scenario-based

**Q23. A regression shows that a configuration bit `fast_mode` is 1 in fewer than 1 percent of tests although nothing constrains it directly. Explain and fix.**
Some constraint of the form `fast_mode -> (something restrictive)` gives `fast_mode` = 1 far fewer solutions than `fast_mode` = 0, and solutions are equally likely. Fix with `solve fast_mode before <the dependent variables>;` or with an explicit `dist` on `fast_mode`.

**Q24. Your generator uses `randc` for a channel number, but coverage shows repeated channels before all are used. Why?**
The generator creates a new transaction object per item, so each object's cyclic history starts empty. Keep the `randc` variable in the generator (or in one long-lived blueprint object) and copy its value into each transaction.

**Q25. A test adds `randomize() with { len == 2000; }` and the call fails although the test writer disabled `len_c`. What do you check?**
Whether another block, possibly in a base class, also restricts `len`; whether `len` is wide enough to hold 2000; whether the array whose size is tied to `len` has its own size limit; whether the `constraint_mode(0)` call was made on the same object that is randomized (a generator may construct a new object after the call).

**Q26. How would you generate a transaction that depends on the previous one, for example an address that is the previous address plus 4?**
Keep the previous value in a non-random property and refer to it: `constraint c { addr == prev_addr + 4; }`, updating `prev_addr = addr;` in `post_randomize()`. The object must be reused, or the value must be passed to each new object by the generator.

**Q27. When would you not use constraints at all?**
For fully determined values (fixed patterns, checksums, derived fields), which belong in procedural code or `post_randomize()`; and for very large problems where a procedural algorithm is far cheaper than solving, such as shuffling a large array or picking a random subset.

**Q28. The same seed gives different stimulus on two simulators. Is that a bug?**
No. The standard defines the constraint semantics and the stability rules, not the random number algorithm or the solver. Reproducibility holds for the same seed on the same simulator version with the same code.

**Q29. A constraint solver takes minutes per call. What do you look for?**
Wide variables in multiplications, divisions or modulus; large arrays with pairwise (`foreach` in `foreach`) constraints or `unique`; unbounded array sizes; many variables coupled into one large problem that could be split into stages (randomize the header first, then the payload); bit-level functions of wide vectors.

**Q30. Explain how a test can change the behaviour of a transaction class without editing it. Give four mechanisms.**
Inline constraints (`randomize() with`), `constraint_mode()` and `rand_mode()`, knob properties used as state variables or `dist` weights, and a derived class that overrides or adds constraint blocks (installed through the generator's blueprint handle or the UVM factory).

**Q31. `randomize()` succeeds, but the DUT receives an illegal value. List possible causes.**
`post_randomize()` modified the value; the field is not `rand` and was set elsewhere; the constraint was disabled or overridden; the legal-value constraint is `soft` and was dropped; a width or sign effect makes the constraint accept wrapped values; the driver, not the generator, corrupts the value.

**Q32. Why are helper random variables useful? Give an example.**
They name a property of the stimulus so that it can be constrained, weighted and covered directly. Example: `rand bit ovf;` with `ovf == (a + b > 255)` lets the test set the overflow rate with a `dist` on `ovf`.

## 6.3 Output-Prediction Questions

All of these have exact answers that do not depend on the seed. Work them out before reading the answer.

**P1.**

```systemverilog
class A;
  rand bit [3:0] x;
  constraint c { x > 12; x < 14; }
endclass
// A a = new();  void'(a.randomize());  $display("%0d", a.x);
```

Answer: `13`. Only one value satisfies both conditions.

**P2.**

```systemverilog
class B;
  rand bit [2:0] x;
  int y = 9;
  constraint c { x == y; }
endclass
// B b = new();  $display("%0d %0d", b.randomize(), b.x);
```

Answer: `0 0`. A 3-bit variable cannot equal 9 (the comparison is done in 32 bits, so there is no truncation of 9). The call fails and `x` keeps its initial value 0. (The arguments are evaluated left to right in practice; either order gives the same result here because `x` never changes.)

**P3.**

```systemverilog
class C;
  rand int x;
  constraint a { soft x == 1; }
  constraint b { soft x == 2; }
endclass
// C c = new();
// void'(c.randomize());                         $display("%0d", c.x);
// void'(c.randomize() with { soft x == 3; });   $display("%0d", c.x);
// void'(c.randomize() with { x < 2; });         $display("%0d", c.x);
```

Answer: `2`, `3`, `1`. First call: the two soft constraints conflict and the later block has priority. Second call: the inline soft constraint has the highest priority. Third call: the hard `x < 2` removes `soft x == 2`; `soft x == 1` does not conflict and is honoured.

**P4.**

```systemverilog
class D;
  rand bit [7:0] a, b;
  constraint c1 { a == 10; }
  constraint c2 { b == a + 1; }
endclass
// D d = new();  int s;
// s = d.randomize();                              $display("%0d %0d %0d", s, d.a, d.b);
// d.a.rand_mode(0);  d.a = 20;  s = d.randomize(); $display("%0d %0d %0d", s, d.a, d.b);
// d.c1.constraint_mode(0);      s = d.randomize(); $display("%0d %0d %0d", s, d.a, d.b);
```

Answer: `1 10 11`, then `0 20 11`, then `1 20 21`. In the second call `a` is frozen at 20, which violates `c1`, so the call fails and `b` keeps 11. In the third call `c1` is off; `c2` uses the frozen `a`.

**P5.**

```systemverilog
class E;
  rand bit [3:0] v;
  constraint c { v == 7; }
  function void pre_randomize();  $display("pre  v=%0d", v);          endfunction
  function void post_randomize(); $display("post v=%0d", v); v = 15;  endfunction
endclass
// E e = new();
// void'(e.randomize());  $display("after v=%0d", e.v);
// void'(e.randomize());
```

Answer:

```output
pre  v=0
post v=7
after v=15
pre  v=15
post v=7
```

`pre_randomize()` sees the old value, `post_randomize()` sees the solved value and then overwrites it. The overwritten value 15 violates the constraint, and nothing complains.

**P6.**

```systemverilog
class P;
  rand bit [3:0] x;
  constraint c { x < 4; }
  constraint d { x > 1; }
endclass
class Q extends P;
  constraint c { x > 12; }
  constraint e { x % 2 == 0; }
endclass
// P h;  Q q = new();  h = q;  void'(h.randomize());  $display("%0d", h.x);
```

Answer: `14`. The object is a `Q`. Its constraints are the overriding `c` (`x > 12`), the inherited `d` (`x > 1`) and the added `e` (even). Of 13, 14, 15 only 14 is even.

**P7.**

```systemverilog
class F;
  rand bit [3:0] x;
  constraint c { x inside {[2:5]}; }
endclass
// module scope:  F f = new();  int x = 9;
// f.x = 3;  $display("%0d", f.randomize(null));
// f.x = 9;  $display("%0d", f.randomize(null));
// $display("%0d", f.randomize() with { x == local::x; });
// $display("%0d", f.randomize() with { x == x; });
```

Answer: `1`, `0`, `0`, `1`. The first two are checks of the current value. The third requires `f.x == 9`, which conflicts with the class constraint. In the fourth both names mean `f.x`, so the inline constraint is always true.

**P8.** Probabilities.

```systemverilog
rand bit       a;
rand bit [2:0] b;
constraint c { a -> b < 2; }
```

Give P(a = 1) and P(b = 0), first without ordering and then with `solve a before b`.

Answer: Solutions: `a` = 0 with eight values of `b`; `a` = 1 with `b` = 0 or 1. Ten solutions. Without ordering: P(a = 1) = 2/10 = 1/5, and P(b = 0) = 2/10 = 1/5. With `solve a before b`: P(a = 1) = 1/2, and P(b = 0) = 1/2 × 1/8 + 1/2 × 1/2 = 5/16.

**P9.** Weights.

```systemverilog
x dist { [1:3] := 2, 4 :/ 2, [5:6] :/ 2 };
```

Give the probability of 1, of 4 and of 5.

Answer: Weights: 1, 2, 3 have 2 each; 4 has 2; 5 and 6 share 2, so 1 each. Total 10. P(1) = 0.2, P(4) = 0.2, P(5) = 0.1.

**P10.**

```systemverilog
class G;
  rand int q[$];
  rand int d[];
  constraint c { foreach (q[i]) q[i] == i * 2; }
endclass
// G g = new();  g.q = '{5, 5, 5};
// void'(g.randomize());
// $display("%0d %0d %0d %0d | %0d", g.q.size(), g.q[0], g.q[1], g.q[2], g.d.size());
```

Answer: `3 0 2 4 | 0`. Neither size is constrained, so both arrays keep their sizes: the queue keeps three elements, which are then constrained to 0, 2, 4, and the dynamic array stays empty.

## 6.4 Find-the-Error and Debugging Questions

### Errors the compiler or solver reports

**E1.** `constraint c { a = 5; }`
Assignment in a constraint. Use `a == 5;`.

**E2.** `randc bit [3:0] id; constraint c { id dist {0 := 1, [1:15] := 2}; }`
A `dist` cannot be applied to a `randc` variable. Make it `rand`, or drop the `dist`.

**E3.** `constraint c { solve a before b; solve b before a; }`
Circular ordering.

**E4.** `constraint c { for (int i = 0; i < 4; i++) d[i] > 0; }`
`for` is not allowed in a constraint. Use `foreach (d[i]) d[i] > 0;`.

**E5.** `constraint c { if (mode) begin len == 4; addr == 0; end }`
Constraint sets are grouped with braces: `if (mode) { len == 4; addr == 0; }`.

**E6.** `int tag;` ... `obj.tag.rand_mode(0);`
`rand_mode()` on a property that is not `rand` is a compile error.

**E7.** `rand string name;`
Strings cannot be random variables. Randomize an index or an enum and map it to a string.

**E8.** `rand bit [1:0] v[5]; constraint c { unique {v}; }`
Compiles, but always fails at run time: five distinct values do not exist in 2 bits.

**E9.** `function void post_randomize(); #10; crc = calc(); endfunction`
A delay inside a function. The hooks cannot consume time.

**E10.** `constraint c { foreach (d[i]) d[i] < d[i+1]; }`
Index out of range for the last element. Guard it: `if (i < d.size() - 1)`.

**E11.** `constraint c { soft id == 3; }` with `randc bit [3:0] id;`
Soft constraints are not allowed on `randc` variables.

**E12.** `class T; rand bit [7:0] a; endclass` ... `T t; void'(t.randomize());`
Null handle: `t = new();` is missing. Run-time error.

### Bugs that compile and run

**D1.** Channels repeat although `ch` is `randc`.

```systemverilog
repeat (8) begin
  cfg c = new();
  void'(c.randomize());
  drive(c.ch);
end
```

A new object each time. Construct `c` once, outside the loop.

**D2.** The payload is always empty.

```systemverilog
rand bit [7:0] payload[];
constraint c { foreach (payload[i]) payload[i] != 0; }
```

No size constraint, so the size stays 0. Add `payload.size() inside {[1:64]};`.

**D3.** Randomization always fails.

```systemverilog
rand bit [7:0] w[4];
constraint c { w.sum() == 300; }
```

The sum is 8 bits wide and can never be 300. Use `w.sum() with (int'(item)) == 300`.

**D4.** With one simulator option the test sends all-zero transactions.

```systemverilog
assert (txn.randomize());
```

With assertions disabled the call is not executed. Use `if (!txn.randomize()) $fatal(1, "...");`.

**D5.** The requested address is ignored.

```systemverilog
task send(bit [15:0] addr);
  void'(txn.randomize() with { addr == addr; });
endtask
```

Both names resolve to `txn.addr`. Write `addr == local::addr`.

**D6.** Delays are sometimes enormous.

```systemverilog
rand int delay;
constraint c { delay < 20; }
// ...  repeat (txn.delay) @(posedge clk);
```

`delay` is signed, so almost every value is negative; `repeat` with a negative count executes zero times, and other uses treat it as a huge unsigned number. Use `rand int unsigned delay;` with `delay inside {[0:19]};`.

**D7.** The error test fails to randomize.

```systemverilog
class err_txn extends base_txn;          // base has: constraint len_c { len <= 64; }
  constraint long_c { len > 64; }
endclass
```

The new block is added to the inherited one. Name it `len_c` to override.

**D8.** Every tenth transaction is a duplicate of the previous one.

```systemverilog
void'(txn.randomize() with { a > b; });
gen2drv_mbx.put(txn.copy());
```

The return value is discarded. When the call occasionally fails (here because another constraint sometimes conflicts with `a > b`), the old values are sent again. Check the status.

**D9.** `fast` is practically never 1.

```systemverilog
rand bit        fast;
rand bit [31:0] timeout;
constraint c { fast -> timeout == 0; }
```

One solution with `fast` = 1 against four billion with `fast` = 0. Add `solve fast before timeout;`.

**D10.** The sum check passes in simulation but the values look wrong.

```systemverilog
rand bit [7:0] a, b;
constraint c { a + b == 8'd200; }
```

The 8-bit literal makes the addition 8 bits wide, so `a` = 250, `b` = 206 is accepted (456 modulo 256 is 200). Write `a + b == 200`.

## 6.5 Coding Exercises with Solutions

### Exercise 1: the ALU transaction class

Write the course transaction class `alu_txn` with random operands and opcode, a weighted opcode mix, the rule that `b` is 0 for `ALU_NOT`, and the methods `print`, `copy` and `compare`. Randomize it five times, and show that a copy compares equal. This example needs `alu_pkg.sv` from Module 1.

```systemverilog file=ex01_alu_txn.sv
module ex01_alu_txn;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 3, ALU_SUB := 3,
                ALU_AND := 2, ALU_OR := 2, ALU_XOR := 2, ALU_NOT := 2,
                ALU_SHL := 1, ALU_SHR := 1 };
    }
    constraint not_b_c { (op == ALU_NOT) -> (b == 0); }

    function void print(string tag = "");
      $display("%s id=%0d op=%-7s a=%3d b=%3d result=%h", tag, id, op.name(), a, b, result);
    endfunction

    function alu_txn copy();
      alu_txn t = new();
      t.a = a;  t.b = b;  t.op = op;  t.result = result;  t.id = id;
      return t;
    endfunction

    function bit compare(alu_txn rhs);
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction
  endclass

  alu_txn txn, cpy;
  int     errors;

  initial begin
    txn = new();
    for (int i = 0; i < 5; i++) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      txn.id = i;
      txn.print("[gen]");
      if (txn.op == ALU_NOT && txn.b != 0) errors++;
    end
    cpy = txn.copy();
    $display("copy equals original : %0d", txn.compare(cpy));
    cpy.a = ~cpy.a;
    $display("after changing copy  : %0d", txn.compare(cpy));
    $display("ex01: errors=%0d", errors);
  end

endmodule
```

**What to expect.** Five `[gen]` lines with `id` 0 to 4, random operands and opcodes, and `result=xxx` (it is a four-state field that nothing has assigned). The last three lines are exact:

```output
copy equals original : 1
after changing copy  : 0
ex01: errors=0
```

`compare` uses `===` for `result`, so two unassigned (X) results compare equal instead of producing an unknown.

### Exercise 2: measure a distribution

Write a small reusable way to print a histogram of a random variable, and use it to verify `len dist {1 := 30, [2:9] :/ 40, 10 := 30}`.

```systemverilog file=ex02_histogram.sv
module ex02_histogram;

  class len_gen;
    rand bit [3:0] len;
    constraint c { len dist {1 := 30, [2:9] :/ 40, 10 := 30}; }
  endclass

  len_gen g;
  int     hist[int];           // associative array: value -> count
  int     n = 2000;
  int     errors;

  initial begin
    g = new();
    repeat (n) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      hist[g.len]++;
      if (!(g.len inside {[1:10]})) errors++;
    end
    foreach (hist[v])
      $display("len=%2d : %4d  (%0.1f%%)", v, hist[v], 100.0 * hist[v] / n);
    $display("ex02: errors=%0d", errors);
  end

endmodule
```

**What to expect.** Ten lines for `len` 1 to 10. `len=1` and `len=10` are each near 30 percent (about 600 of 2000). Each of 2 to 9 is near 5 percent (40 percent shared by eight values, about 100 each). The last line is exactly `ex02: errors=0`. An associative array is used so that only values that actually occur are stored and printed.

### Exercise 3: a packet with a checksum and error injection

Write a packet class with a random payload of 1 to 16 bytes, a checksum equal to the XOR of all payload bytes, and a random `bad_csum` flag (10 percent) that corrupts the checksum.

```systemverilog file=ex03_packet.sv
module ex03_packet;

  class packet;
    rand bit [7:0] payload[];
    rand bit       bad_csum;
    bit [7:0]      csum;

    constraint size_c { payload.size() inside {[1:16]}; }
    constraint err_c  { bad_csum dist {1 := 10, 0 := 90}; }

    function bit [7:0] calc_csum();
      bit [7:0] c = 0;
      foreach (payload[i]) c ^= payload[i];
      return c;
    endfunction

    function void post_randomize();
      csum = calc_csum();
      if (bad_csum) csum = ~csum;
    endfunction
  endclass

  packet p;
  int    errors, n_bad;

  initial begin
    p = new();
    repeat (1000) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      if (p.payload.size() < 1 || p.payload.size() > 16)            errors++;
      if (!p.bad_csum && p.csum != p.calc_csum())                    errors++;
      if ( p.bad_csum && p.csum == p.calc_csum())                    errors++;
      if (p.bad_csum) n_bad++;
    end
    $display("corrupted packets: %0d of 1000", n_bad);
    $display("ex03: errors=%0d", errors);
  end

endmodule
```

**What to expect.** About 100 corrupted packets, then exactly `ex03: errors=0`. The checksum is not `rand`: it is computed in `post_randomize()` from the final payload, and the error is injected after the correct value has been calculated.

### Exercise 4: a burst that must not cross a 4 KB boundary

A bus burst has a start address, a number of beats (1 to 16) and a beat size of 1, 2, 4 or 8 bytes. Rules: the start address is aligned to the beat size, and the whole burst lies within one 4096-byte page.

```systemverilog file=ex04_burst_4k.sv
module ex04_burst_4k;

  class burst;
    rand bit [31:0] addr;
    rand bit [4:0]  beats;         // number of beats
    rand bit [1:0]  size_log2;     // bytes per beat = 1 << size_log2

    constraint beats_c { beats inside {[1:16]}; }
    constraint align_c { (addr & ((32'd1 << size_log2) - 1)) == 0; }
    constraint page_c  { int'(addr[11:0]) + int'(beats) * (1 << size_log2) <= 4096; }
  endclass

  burst b;
  int   errors, nbytes;

  initial begin
    b = new();
    repeat (500) begin
      if (!b.randomize()) $fatal(1, "randomize failed");
      nbytes = 1 << b.size_log2;
      if (b.beats < 1 || b.beats > 16)                          errors++;
      if (b.addr % nbytes != 0)                                 errors++;
      if ((b.addr / 4096) != ((b.addr + b.beats * nbytes - 1) / 4096)) errors++;
    end
    $display("ex04: sample addr=%h beats=%0d bytes/beat=%0d", b.addr, b.beats, nbytes);
    $display("ex04: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample burst, then exactly `ex04: errors=0`. The page rule uses only the offset inside the page (`addr[11:0]`) and widens everything to `int`, so no intermediate result can wrap. The checker states the same rule differently: the first and the last byte of the burst are in the same page.

### Exercise 5: a random subset in random order

Given a fixed list of eight legal register addresses, choose four different ones in random order.

```systemverilog file=ex05_subset.sv
module ex05_subset;

  class pick;
    bit [7:0]      legal[8] = '{8'h00, 8'h04, 8'h08, 8'h10, 8'h14, 8'h20, 8'h40, 8'h80};
    rand bit [7:0] chosen[4];

    constraint member_c { foreach (chosen[i]) chosen[i] inside {legal}; }
    constraint uniq_c   { unique {chosen}; }
  endclass

  pick p;
  int  errors;

  initial begin
    p = new();
    repeat (200) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      foreach (p.chosen[i]) begin
        if (!(p.chosen[i] inside {p.legal})) errors++;
        for (int j = i + 1; j < 4; j++)
          if (p.chosen[i] == p.chosen[j]) errors++;
      end
    end
    $display("ex05: sample chosen=%p", p.chosen);
    $display("ex05: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample of four different addresses from the list, then exactly `ex05: errors=0`. `legal` is a state array; `inside {legal}` restricts each choice to it and `unique` makes the choices different.

### Further practice (no solutions given)

1. Constrain a 16-bit value so that its upper byte is the bitwise inverse of its lower byte.
2. Generate an array of ten elements in which the first half is ascending and the second half is descending.
3. Generate three 8-bit values that are the side lengths of a valid triangle (each side shorter than the sum of the other two). Watch the widths.
4. Generate a 10-element array where every element is either 0 or greater than its index.
5. Write a class that produces a different one-hot 8-bit value on each of eight successive calls, in random order, without `randc`.
6. Generate a random 32-bit value in which exactly one byte is `0xFF` and no other byte is `0xFF`.
7. Write a constraint for a 3 × 3 matrix in which every row and every column sums to 15 and all nine elements are different (a magic square). Measure how long your simulator takes.
8. Add a knob to the ALU transaction of Exercise 1 that lets a test select "boundary operands only" (each operand is one of 0, 1, 127, 128, 254, 255) without editing the class.
9. Take Problem 22 and add: the FIFO must become full at least twice, and the sequence must end with an empty FIFO. Is 20 operations still enough?
10. For `rand bit [3:0] a, b; constraint c { a < b; }`, compute by hand the probability of each value of `a`, then confirm it with a histogram over 12,000 calls.

## 6.6 Concepts You Must Understand Before Moving Forward

**Basics**

- [ ] I can explain why constrained-random verification is used and what it needs besides random stimulus.
- [ ] I can state the difference between `rand` and `randc` and explain why `randc` fails with a new object per item.
- [ ] I know what `randomize()` returns, and what happens to the variables and to `post_randomize()` on failure.
- [ ] I can explain what a state variable is.
- [ ] I know when a `rand` dynamic array is resized and when it is not.

**Constraints**

- [ ] I can explain "declarative", "bidirectional" and "solved simultaneously" with an example.
- [ ] I can explain why a variable may be non-uniform although all solutions are equally likely.
- [ ] I can spot the chained comparison, overflow, unsigned subtraction and signed-variable traps.
- [ ] I can write `inside`, implication, `if`-`else`, `foreach`, `sum()` and `unique` constraints from memory.
- [ ] I can explain why `a -> b` also restricts `a`.
- [ ] I know why `sum()` needs `with (int'(item))`.

**Distribution**

- [ ] I can compute probabilities for `:=` and `:/`.
- [ ] I can explain soft-constraint priority and predict which soft constraint survives.
- [ ] I can work out a probability table with and without `solve`...`before`.
- [ ] I can explain why a function call in a constraint is not bidirectional.

**Control and debug**

- [ ] I know the task and function forms of `constraint_mode()` and `rand_mode()` and the difference between the two.
- [ ] I can explain inline constraints, `local::`, `randomize(args)` and `randomize(null)`.
- [ ] I know what `std::randomize()` is for.
- [ ] I can explain seeds, random stability and how to reproduce a failure.
- [ ] I can list the causes of a randomization failure and describe a debugging procedure.
- [ ] I can explain overriding versus extending a constraint in a derived class.

**Problem solving**

- [ ] I can solve at least fifteen of the twenty-two problems of Part 5 without looking, and write a checker for each.

## 6.7 What Comes Next

Module 6 uses everything in this module to build the transaction class properly: properties, constructor, constraints, and the `print`, `copy` and `compare` methods of `alu_txn`. It then steps back to verification planning: how a specification becomes a list of test scenarios, how directed and constrained-random tests are combined, and how functional coverage and a self-checking testbench close the loop.
