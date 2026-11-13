# Part 2: Constraint Blocks and Constraint Expressions

## 2.1 Constraint Blocks and How the Solver Thinks

### In plain English

A constraint is a rule that the random values must obey: "the length is less than 64", "the address is word-aligned", "if the packet is a read, there is no payload". You write the rules; the simulator finds values that obey **all of them at once**.

The most important idea in this whole module is that constraints are **rules, not instructions**. They are not executed from top to bottom like statements. A constraint does not "assign" anything. The solver looks at the complete set of rules and picks one combination of values for which every rule is true.

### Technical definition

A **constraint block** is a named class member introduced by the keyword `constraint`. It contains a list of **constraint expressions**. Each expression is a Boolean condition over random variables, state variables and constants. A `randomize()` call succeeds only if values exist that make every expression of every active constraint block true.

Constraints are:

- **Declarative.** They state what must be true, not how to compute it.
- **Unordered.** The order of expressions in a block, and of blocks in a class, has no effect on which solutions are legal.
- **Bidirectional.** A relation between two variables restricts both of them. `a < b` limits `a` as much as it limits `b`.
- **Solved simultaneously.** All active constraints, from all blocks, base classes and inline `with` clauses, form one problem.

### Syntax

```systemverilog
class bus_txn;
  rand bit [15:0] addr;
  rand bit [7:0]  len;
  rand bit        write;

  // constraint <name> { <expression>; <expression>; ... }
  constraint addr_c {
    addr[1:0] == 2'b00;            // each expression ends with a semicolon
    addr inside {[16'h1000:16'h1FFF]};
  }
  constraint len_c { len > 0; len <= 64; }

  constraint empty_c { }           // legal: an empty block restricts nothing

  constraint ext_c;                // prototype: body is written outside the class
  static constraint shared_c { len != 13; }
endclass

constraint bus_txn::ext_c { write == 1 -> len < 16; }   // external body
```

### What may appear inside a constraint block

| Item | Example | Section |
|---|---|---|
| Relational or arithmetic expression | `len <= 64;` `a + b == 100;` | 2.2 |
| Set membership | `addr inside {[0:15], 32};` | 2.3 |
| Implication | `write -> len < 16;` | 2.4 |
| `if`...`else` | `if (write) len < 16; else len == 0;` | 2.4 |
| Iteration | `foreach (d[i]) d[i] > 0;` | 2.5 |
| Uniqueness | `unique {a, b, c};` | 2.6 |
| Distribution | `len dist {1 := 5, [2:10] := 1};` | 3.1 |
| Soft constraint | `soft len == 4;` | 3.2 |
| Ordering | `solve write before len;` | 3.3 |
| Function call | `len == count_ones(mask);` | 3.4 |

What may **not** appear: assignments (`a = 5;`), procedural statements (`for`, `while`, `case`, `begin`...`end`), delays, tasks, and operators with side effects (`++`, `+=`). Expressions must be integral: real numbers and strings are not allowed in standard constraints.

> **Interview trap:** `constraint c { a = 5; }` is a syntax error. Inside a constraint, "equal to" is always `==`.

### How the solver works

Think of every possible combination of values of the random variables as a point. Each constraint removes the points that violate it. What remains is the **solution space**. The solver picks one point from it. The standard requires that, in the absence of `dist` and `solve`...`before`, **every solution is equally likely**.

```text
   rand bit [1:0] x, y;
   constraint c { x < y; }

   All 16 combinations (x across, y down); "S" = solution, "." = removed by the constraint

              x=0   x=1   x=2   x=3
       y=0     .     .     .     .
       y=1     S     .     .     .
       y=2     S     S     .     .
       y=3     S     S     S     .

   6 solutions, each chosen with probability 1/6.

   Per-variable probabilities that result:
       x = 0 : 3/6      y = 0 : 0
       x = 1 : 2/6      y = 1 : 1/6
       x = 2 : 1/6      y = 2 : 2/6
       x = 3 : 0        y = 3 : 3/6
```

Two lessons from this small picture:

1. The constraint mentions `x` and `y` symmetrically, and it restricts both. `x` can never be 3 and `y` can never be 0, although neither is said explicitly.
2. **Uniform over solutions does not mean uniform per variable.** `x` is 0 half of the time. When a variable looks "skewed" in a regression, the cause is usually this: some of its values simply appear in more solutions than others. `solve`...`before` (Section 3.3) exists to change this.

### Complete example: bidirectionality

```systemverilog file=tb_constraint_bidir.sv
module tb_constraint_bidir;

  class pair;
    rand bit [3:0] x, y, z;

    constraint rel_c  { y == x + 2; }      // looks like "compute y from x"
    constraint pin_c  { y == 7; }          // but this fixes y, which forces x
    constraint z_lo_c { z > y; }
    constraint z_hi_c { z < 9; }
  endclass

  pair p;

  initial begin
    p = new();
    repeat (3) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      $display("x=%0d y=%0d z=%0d", p.x, p.y, p.z);
    end
  end

endmodule
```

```output
x=5 y=7 z=8
x=5 y=7 z=8
x=5 y=7 z=8
```

**Line by line**

| Line | Explanation |
|---|---|
| `y == x + 2;` | A relation between `x` and `y`. It is not an assignment and has no direction. |
| `y == 7;` | Fixes `y`. Because the relation must also hold, `x` must be 5. The solver worked "backwards" from `y` to `x`. |
| `z > y;` and `z < 9;` | Two separate blocks. All blocks are combined: `z` must be greater than 7 and less than 9, so `z` is 8. |
| Output | There is exactly one solution, so every call returns it. This is one of the few random examples with a fully predictable output. |

### Constraint block details

| Feature | Behaviour |
|---|---|
| Several blocks in one class | All are ANDed together. Splitting constraints into small named blocks is good practice because each can be switched off separately with `constraint_mode()` |
| Block names | Must be unique within the class. A derived class may reuse a base-class name to override it (Section 4.7) |
| External constraint | A prototype `constraint name;` (or `extern constraint name;`) inside the class, and a body `constraint class_name::name { ... }` outside. If no body is ever provided, the prototype form without `extern` is treated as an empty constraint (tools warn) |
| `static constraint` | The constraint itself is not different, but its on/off state is shared: `constraint_mode()` on one object changes it for all objects of the class |
| State variables | Read once, when `randomize()` is called |
| Four-state values | Constraints are solved in two-state. A state variable that contains X or Z when it is used in a constraint is an error |

### Common mistakes

> **Common mistake:** Reading constraints as a program. In `constraint c { a < 10; b == a + 1; a > 5; }` the solver does not "first choose `a` below 10, then compute `b`". It finds any `(a, b)` pair for which all three conditions are true.

> **Common mistake:** Expecting each variable to be uniformly distributed because there is "only one small constraint". See the `x < y` picture above.

> **Common mistake:** Putting two contradictory constraints in different blocks (or in a base and a derived class) and wondering why randomization fails. Blocks are not alternatives; all active blocks must hold together.

### Interview questions

**Q1. What is a constraint block?**
A named member of a class, declared with the keyword `constraint`, that contains Boolean expressions which the random variables of the object must satisfy after `randomize()`.

**Q2. Are constraints executed in order?**
No. Constraints are declarative and are solved simultaneously. The textual order of expressions and blocks does not affect the set of legal solutions.

**Q3. What does "constraints are bidirectional" mean?**
A constraint relating several variables restricts all of them, regardless of how it is written. `y == x + 2` together with `y == 7` forces `x` to 5. Likewise `a -> b` also means "if `b` is false then `a` must be false".

**Q4. If there are no `dist` or `solve before` constraints, how are solutions chosen?**
Every legal combination of values (every solution) has the same probability. Individual variables are therefore not necessarily uniformly distributed.

**Q5. What is an external constraint?**
A constraint whose prototype is declared in the class and whose body is defined outside it with the scope operator, `constraint cls::name { ... }`. It allows the body to be placed in a different file, for example one file per test.

**Q6. What is a static constraint?**
A constraint declared `static`. Calling `constraint_mode()` on it through any object switches it on or off for every object of that class.

**Q7. Can a constraint contain a non-random variable?**
Yes. It is a state variable: its current value is used as a constant. This is how a test "steers" a transaction: it sets a non-random knob and constraints refer to it.

## 2.2 Relational and Arithmetic Constraint Expressions

### Definition

A constraint expression is any integral expression. The solver requires it to be **true** (non-zero). The usual forms are:

- **Relational constraints:** comparisons using `<`, `<=`, `>`, `>=`, `==`, `!=`.
- **Arithmetic constraints:** comparisons whose operands contain `+`, `-`, `*`, `/`, `%`, `<<`, `>>`.
- **Logical combinations:** using `&&`, `||`, `!`.
- **Bit-level constraints:** using bit-selects, part-selects, concatenation, bitwise and reduction operators, and system functions such as `$countones`, `$onehot`, `$clog2`.

### Syntax and examples

```systemverilog
class expr_demo;
  rand bit [7:0]  a, b, c;
  rand bit [15:0] addr;
  rand int        delay;

  constraint relational_c {
    a > 10;
    a <= 100;
    b != a;
    c >= a && c <= b || c == 0;        // && binds tighter than ||
  }
  constraint arithmetic_c {
    a + b < 200;
    a % 4 == 0;                        // multiple of 4
    b == 2 * c + 1;
    delay inside {[0:20]};
  }
  constraint bit_level_c {
    addr[1:0] == 2'b00;                // word aligned
    addr[15:12] != 4'hF;               // not in the top 4K region
    $countones(a) == 3;                // exactly three bits set
    (addr & 16'h00FF) != 0;            // low byte not zero
  }
endclass
```

### Operators in constraints

| Operator group | Allowed | Notes |
|---|---|---|
| `== != < <= > >=` | Yes | The basic building blocks |
| `&& \|\| !` | Yes | `a && b` in a constraint is the same as writing `a;` and `b;` as two expressions |
| `+ - *` | Yes | Watch widths and overflow (below) |
| `/ %` | Yes | Slower to solve. Division by a random variable must never have a zero divisor |
| `<< >> >>> <<<` | Yes | |
| `& \| ^ ~`, reduction operators | Yes | |
| `?:` | Yes | `len == (write ? 8 : 0);` |
| `inside`, `dist`, `->`, `<->` | Yes | Dedicated sections |
| `**` | Tool-dependent | Often restricted to constant operands. Prefer a shift for powers of two |
| `===`, `!==`, `==?` with X/Z | No | Constraints are two-state |
| `++`, `--`, assignment operators | No | No side effects are allowed |

### The traps: these are what interviewers test

Constraint expressions follow exactly the same width and sign rules as any other SystemVerilog expression (Module 1, Sections 2.6 and 4.4). The solver does not "know what you meant". Six traps cover most questions.

#### Trap 1: chained comparison

```systemverilog
rand bit [7:0] x;
constraint wrong_c { 10 < x < 20; }          // does NOT mean "x between 10 and 20"
constraint right_c { x > 10; x < 20; }       // or: x inside {[11:19]};
```

`10 < x < 20` is parsed as `(10 < x) < 20`. `(10 < x)` is 0 or 1, and both are less than 20. The constraint is always true, so `x` is unconstrained.

#### Trap 2: overflow in a narrow expression

```systemverilog
rand bit [7:0] a, b;
constraint narrow_c { a + b == 8'd10; }      // evaluated in 8 bits
constraint wide_c   { a + b == 10; }         // evaluated in 32 bits
```

In `narrow_c` every operand is 8 bits wide, so the sum is computed in 8 bits and wraps around. `a` = 200, `b` = 66 is a legal solution because 266 modulo 256 is 10. In `wide_c` the literal `10` is a 32-bit integer, the operands are extended to 32 bits first, and only true sums of 10 are accepted. When the mathematical value matters, make sure something in the expression is wide enough, or cast: `int'(a) + int'(b) == 10`.

#### Trap 3: unsigned subtraction

```systemverilog
rand bit [3:0] a, b;
constraint wrong_c { a - b > 0; }            // intended: a greater than b
constraint right_c { a > b; }
```

`a` and `b` are unsigned, so the whole expression is unsigned (one unsigned operand makes everything unsigned). For `a` = 2, `b` = 5 the result is not -3 but a huge positive 32-bit number, which is greater than 0. The constraint `a - b > 0` only excludes `a == b`. Never express an ordering through a subtraction of unsigned values.

#### Trap 4: signed random variables

```systemverilog
rand int  delay;
rand byte offset;
constraint c1 { delay < 100; }               // also allows -2,147,483,648 to -1
constraint c2 { offset < 50; }               // also allows -128 to -1
```

`int`, `byte`, `shortint` and `longint` are signed. A constraint with only an upper bound leaves all negative values legal, and there are far more of those. Either use unsigned types (`int unsigned`, `bit [7:0]`) or always give both bounds: `delay inside {[0:99]};`.

#### Trap 5: a non-random variable

```systemverilog
bit [7:0] len;                               // "rand" forgotten
constraint c { len inside {[1:10]}; }
```

`len` is a state variable with value 0. The constraint is false, and nothing can be changed to make it true: `randomize()` fails. If `len` happened to hold a legal value, the call would succeed and `len` would silently never change.

#### Trap 6: operator precedence and `!`

```systemverilog
constraint wrong_c { !x inside {[1:5]}; }    // parsed as (!x) inside {[1:5]}
constraint right_c { !(x inside {[1:5]}); }
```

Unary `!` binds tighter than `inside`. `!x` is 0 or 1, so the wrong version means "x is zero".

### Complete example

```systemverilog file=tb_constraint_traps.sv
module tb_constraint_traps;

  class traps;
    rand bit [7:0] a, b;        // for the overflow trap
    rand bit [3:0] p, q;        // for the subtraction trap
    rand bit [7:0] x;           // for the chained comparison

    constraint narrow_c { a + b == 8'd10; }
    constraint sub_c    { p - q > 0; }
    constraint chain_c  { 10 < x < 20; }
  endclass

  traps t;
  int   wrapped, p_less, x_outside;

  initial begin
    t = new();
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize failed");
      if (int'(t.a) + int'(t.b) != 10) wrapped++;
      if (t.p < t.q)                   p_less++;
      if (!(t.x inside {[11:19]}))     x_outside++;
    end
    $display("a + b was not really 10 : %0d of 1000", wrapped);
    $display("p was less than q       : %0d of 1000", p_less);
    $display("x was outside 11..19    : %0d of 1000", x_outside);
  end

endmodule
```

**What to expect.** All three counts are large, which proves that none of the three constraints does what it appears to say. There are 256 solutions of `a + b == 8'd10` in 8-bit arithmetic and only 11 of them have a true sum of 10, so the first count is about 957. `p - q > 0` excludes only `p == q`; of the 240 remaining pairs half have `p < q`, so the second count is about 500. `x` is unconstrained and only 9 of 256 values lie in 11 to 19, so the third count is about 965. Exact counts vary per seed and simulator.

### Tips for writing solvable constraints

| Guideline | Reason |
|---|---|
| Prefer `inside` and simple comparisons to arithmetic | Easier for the solver and for the reader |
| Avoid `/` and `%` on wide variables; use bit-selects for powers of two (`addr[1:0] == 0` instead of `addr % 4 == 0`) | Division and modulus are expensive |
| Avoid multiplying two wide random variables | The solver may be slow or give up |
| Use unsigned types for quantities that cannot be negative | Removes the signed traps |
| Give every variable both a lower and an upper bound | Keeps values legal and solving fast |
| Keep constraint blocks small and named by purpose | They can then be disabled or overridden individually |

### Interview questions

**Q1. What is wrong with `constraint c { 0 < x < 10; }`?**
It is parsed as `(0 < x) < 10`. The inner comparison is 0 or 1, which is always less than 10, so the constraint restricts nothing. Write `x > 0; x < 10;` or `x inside {[1:9]};`.

**Q2. `rand bit [7:0] a, b; constraint c { a + b == 8'd255; }` versus `{ a + b == 255; }`: is there a difference?**
For 255 there is no difference in the solutions, because an 8-bit wrapped sum equal to 255 needs a true sum of 255 or 511, and 511 cannot be reached by two 8-bit values (maximum 510). For most other targets there is a difference: with an 8-bit literal the sum wraps, so true sums of target + 256 are also accepted. The general rule is to make the expression at least as wide as the largest possible sum.

**Q3. `rand int x; constraint c { x < 5; }` What values can `x` take?**
Any value from -2,147,483,648 to 4. `int` is signed. Nearly every result will be a large negative number.

**Q4. How do you constrain a 32-bit address to be 4-byte aligned?**
`addr[1:0] == 2'b00;`. `addr % 4 == 0` is equivalent but more expensive to solve.

**Q5. Can you use `$countones` in a constraint?**
Yes. `$countones(x) == 1` generates one-hot values; `$onehot(x)` does the same. These bit-vector system functions are understood by the solver and remain bidirectional.

**Q6. Why does `constraint c { a - b > 0; }` not guarantee `a > b` for unsigned `a` and `b`?**
The subtraction is performed in unsigned arithmetic and wraps to a large positive value when `a < b`. Only `a == b` gives 0. The correct constraint is `a > b`.

## 2.3 The inside Operator

### In plain English

`inside` asks "is this value one of the following?". The list can contain single values, ranges and whole arrays. In a constraint it means "choose the value from this set".

### Syntax

```systemverilog
x inside {1, 2, 5};                     // a list of values
x inside {[10:20]};                     // a range, both ends included
x inside {[0:9], 50, [100:199]};        // a mixture
x inside {[lo:hi]};                     // bounds may be variables or expressions
x inside {[$:10]};                      // $ = lowest value of x's type
x inside {[250:$]};                     // $ = highest value of x's type
x inside {legal_q};                     // every element of an array or queue
x inside {legal_q, 255, [16:31]};       // arrays can be mixed with values and ranges
!(x inside {[10:20]});                  // exclusion: note the parentheses
```

### Behaviour

| Point | Explanation |
|---|---|
| Probability | Every value **in the resulting set** is equally likely. A range does not count as "one item": in `{0, [10:19]}` the value 0 has probability 1/11, not 1/2 |
| Duplicates | Listing a value twice, or overlapping ranges, does not increase its probability. `inside` describes a set |
| Empty range | `[hi:lo]` with the low bound greater than the high bound contributes no values |
| Bounds | May be random variables. `x inside {[lo:hi]}` then also restricts `lo` and `hi` (bidirectional) |
| Arrays | `x inside {arr}` means `x` equals at least one element. If `arr` is itself `rand`, this relates `x` to the array elements |
| Negation | `!(x inside {...})` excludes the set |
| Matching | Uses `==?`, so X/Z/`?` in a set value are wildcards (Module 1, Section 4.6) |

### Complete example

```systemverilog file=tb_inside.sv
module tb_inside;

  class sel;
    rand bit [7:0] x, y, z;
    bit [7:0] legal_q[$] = '{8'd3, 8'd7, 8'd42};   // state variable: a list of legal values
    bit [7:0] used_q[$]  = '{8'd100, 8'd101};

    constraint x_c { x inside {0, [10:19], 255}; }
    constraint y_c { y inside {legal_q}; }
    constraint z_c { z inside {[100:103]}; !(z inside {used_q}); }
  endclass

  sel s;
  int x_zero;

  initial begin
    s = new();
    repeat (1200) begin
      if (!s.randomize()) $fatal(1, "randomize failed");
      if (s.x == 0) x_zero++;
      if (!(s.y inside {3, 7, 42}))  $error("y illegal: %0d", s.y);
      if (!(s.z inside {102, 103}))  $error("z illegal: %0d", s.z);
    end
    $display("last: x=%0d y=%0d z=%0d", s.x, s.y, s.z);
    $display("x was 0 in %0d of 1200 calls", x_zero);
  end

endmodule
```

**What to expect.** No `$error` messages. In the `last` line `x` is 0, 255 or between 10 and 19; `y` is 3, 7 or 42; `z` is 102 or 103. The set for `x` has 12 members (0, the ten values 10 to 19, and 255), each equally likely, so `x` is 0 in about 100 of the 1200 calls, not in 400.

**Line by line**

| Line | Explanation |
|---|---|
| `bit [7:0] legal_q[$] = '{...};` | A non-random queue. It can be filled or changed by the test at run time. |
| `x inside {0, [10:19], 255};` | Twelve legal values, uniformly distributed. |
| `y inside {legal_q};` | The value must be one of the queue's elements. Changing the queue changes the legal set without touching the class. |
| `!(z inside {used_q});` | Excludes values already used. Combined with `[100:103]`, only 102 and 103 remain. |

### inside compared with other ways of writing a set

| Form | Meaning | Distribution |
|---|---|---|
| `x inside {[1:3], 9};` | x is 1, 2, 3 or 9 | Uniform over the 4 values |
| `x == 1 \|\| x == 2 \|\| x == 3 \|\| x == 9;` | Same set | Same |
| `x >= 1; x <= 3;` | Range only | Uniform |
| `x dist {[1:3] := 1, 9 := 1};` | Same set | Weighted; here also uniform over the 4 values (Section 3.1) |
| `x dist {[1:3] :/ 1, 9 :/ 1};` | Same set | 9 has probability 1/2; 1, 2, 3 share the other half |

> **Interview trap:** `x inside {[1:100], 200}` does **not** give 200 a 50 percent chance. Each of the 101 values has probability 1/101. To weight ranges against single values, `dist` is required.

> **Common mistake:** `x inside {[10:1]}`. The range is empty, so if this is the only item the constraint can never be satisfied and randomization fails. Ranges are always written `[low:high]`.

> **Verification application:** A test keeps a queue of valid register addresses read from the register map and constrains `addr inside {valid_addr_q};`. An error test inverts it with `!(addr inside {valid_addr_q});` to generate accesses to unmapped addresses.

### Interview questions

**Q1. How do you constrain a variable to a set of values and ranges?**
With `inside`: `x inside {1, [5:10], 20};`.

**Q2. How do you exclude a set of values?**
`!(x inside {[5:10]});`. The parentheses are required because `!` has higher precedence than `inside`.

**Q3. What is the probability of 200 in `x inside {[1:99], 200}`?**
1/100. All 100 values of the set are equally likely.

**Q4. Can the bounds of an `inside` range be random variables?**
Yes: `x inside {[lo:hi]};` with `rand` `lo` and `hi`. The solver then chooses all three so that `lo <= x <= hi`.

**Q5. What is the difference between `inside` and `dist`?**
`inside` only restricts the value to a set, with a uniform distribution over the set. `dist` restricts to a set and also assigns weights that control how often each value or range is chosen.

## 2.4 Conditional Constraints: Implication, if-else and Equivalence

### In plain English

Many rules only apply in certain situations: "**if** the transfer is a read, the payload is empty", "**if** the packet is long, the length is at least 1000". Conditional constraints express this. SystemVerilog offers two notations with the same meaning, the implication operator `->` and `if`...`else`.

### The implication operator ->

`A -> B` reads "A implies B": **if A is true, B must be true. If A is false, B is unrestricted.** It is exactly equivalent to `!A || B`.

| A | B | `A -> B` | Allowed by the constraint? |
|---|---|---|---|
| 0 | 0 | 1 | Yes |
| 0 | 1 | 1 | Yes |
| 1 | 0 | 0 | **No** |
| 1 | 1 | 1 | Yes |

Only one combination is forbidden: A true and B false. Read the table again from B's side: if B is false, A cannot be true. So `A -> B` also means "**not B implies not A**". This is the bidirectional behaviour of implication, and it is the point interviewers probe.

```systemverilog
constraint c1 { write -> len < 16; }                 // single consequence
constraint c2 { (kind == LONG) -> { len > 1000; len < 1500; } }   // a set of consequences
constraint c3 { (a > 5 && b == 0) -> c inside {[1:3]}; }
```

### if-else constraints

```systemverilog
constraint len_c {
  if (kind == SHORT)       len inside {[1:63]};
  else if (kind == MEDIUM) len inside {[64:1023]};
  else                     len inside {[1024:1500]};
}

constraint multi_c {
  if (write) {
    len > 0;
    addr[1:0] == 0;
  } else {
    len == 0;
  }
}
```

- Braces `{ }` group several constraint expressions, not `begin`...`end`.
- `if (A) X; else Y;` is exactly equivalent to `(A -> X) && (!A -> Y)`.
- An `if` without `else` is exactly `A -> X`.
- An `else` belongs to the nearest unmatched `if`, as in procedural code.

Despite looking like procedural code, `if`-`else` in a constraint is still declarative and bidirectional. The solver does not "evaluate the condition first". It finds values for the condition and the branches together.

### Equivalence

Sometimes the relation must hold in both directions: "the length is over 1000 **if and only if** the packet kind is LONG". Implication alone is one-way: `(kind == LONG) -> (len > 1000)` still allows a SHORT packet with length 1200.

```systemverilog
// Three ways to say "A if and only if B"
constraint eq1_c { (kind == LONG) -> (len > 1000);  (len > 1000) -> (kind == LONG); }
constraint eq2_c { (kind == LONG) == (len > 1000); }      // both sides are 1-bit results
constraint eq3_c { (kind == LONG) <-> (len > 1000); }     // equivalence operator
```

The `<->` operator was added to the language in IEEE 1800-2009; if an older tool does not accept it inside a constraint, forms 1 and 2 always work.

### How conditional constraints affect the distribution

```text
   rand bit       mode;
   rand bit [1:0] len;
   constraint imp_c { (mode == 1) -> (len == 3); }

   Solutions (mode, len):
       (0,0) (0,1) (0,2) (0,3)        mode = 0 : len is free      -> 4 solutions
       (1,3)                          mode = 1 : len must be 3    -> 1 solution

   5 solutions, each with probability 1/5:
       P(mode = 1) = 1/5       P(mode = 0) = 4/5
       P(len = 3)  = 2/5       P(len = 0)  = P(len = 1) = P(len = 2) = 1/5
```

Although `mode` is a single bit with "no constraint of its own", it is 1 only 20 percent of the time. With a 32-bit `len`, `mode` would be 1 about once in four billion calls: effectively never. This is the standard motivation for `solve mode before len` (Section 3.3).

### Complete example

```systemverilog file=tb_implication.sv
module tb_implication;

  class cfg;
    rand bit       mode;
    rand bit [1:0] len;
    constraint imp_c { (mode == 1) -> (len == 3); }
  endclass

  cfg c;
  int mode_one;

  initial begin
    c = new();

    // Forward direction: force the condition
    if (!c.randomize() with { mode == 1; }) $fatal(1, "randomize failed");
    $display("forced mode=1 : mode=%0d len=%0d", c.mode, c.len);

    // Backward direction: force the consequence to be false
    if (!c.randomize() with { len == 2; }) $fatal(1, "randomize failed");
    $display("forced len=2  : mode=%0d len=%0d", c.mode, c.len);

    // Distribution
    repeat (1000) begin
      if (!c.randomize()) $fatal(1, "randomize failed");
      if (c.mode == 1) mode_one++;
    end
    $display("mode was 1 in %0d of 1000 calls", mode_one);
  end

endmodule
```

**What to expect.** The first two lines are fully determined by the constraints:

```output
forced mode=1 : mode=1 len=3
forced len=2  : mode=0 len=2
```

The third line reports a count of about 200 (one fifth of 1000), not 500. The exact count varies per seed and simulator.

**Line by line**

| Line | Explanation |
|---|---|
| `(mode == 1) -> (len == 3);` | Forbids exactly one situation: `mode` = 1 with `len` not equal to 3. |
| `randomize() with { mode == 1; }` | An inline constraint (Section 4.4) added for this call only. With `mode` = 1 the implication forces `len` = 3. |
| `randomize() with { len == 2; }` | Now the consequence is false. The only way to keep the implication true is `mode` = 0. The constraint has worked from right to left. |
| The loop | Shows that `mode` is not 50/50. Four of the five solutions have `mode` = 0. |

### Implication versus if-else

| Property | Implication `A -> B` | `if (A) B; else C;` |
|---|---|---|
| Meaning | `!A \|\| B` | `(A -> B) && (!A -> C)` |
| "Otherwise" branch | None. Needs a second implication `!A -> C` | Built in |
| Several consequences | `A -> { B1; B2; }` | `if (A) { B1; B2; }` |
| Chains of cases | One implication per case | `else if` chain; conditions are prioritised, so later branches implicitly include "and none of the earlier conditions" |
| Bidirectional | Yes | Yes |
| Effect on distribution | Identical for equivalent constraints | Identical |
| Is an expression | Yes: can be combined, for example `(a -> b) && c` | No: it is a statement-like constraint item |
| Typical use | Short one-line dependencies | Multi-way selection that reads like a specification table |

> **Interview trap:** "Does `a -> b` restrict `a`?" Yes. If other constraints make `b` false, `a` must be false. And even without that, `a` becomes less likely when few values of the other variables satisfy `b`.

> **Interview trap:** "In `if (x == 0) y == 0;`, is `x` chosen first?" No. There is no order. If another constraint says `y == 5`, then `x` can never be 0.

> **Common mistake:** Using `begin`...`end` inside a constraint `if`. Constraint sets are grouped with braces.

> **Common mistake:** Writing an implication when an equivalence is meant. `err_inject -> crc_bad` lets `crc_bad` be 1 even when `err_inject` is 0. If the bad CRC must appear only when injection is on, add the reverse implication or use `==`.

> **Verification application:** Conditional constraints encode protocol tables directly. For the ALU: `(op == ALU_NOT) -> (b == 0);` because the NOT operation ignores `b`, or, to stress overflow, `if (op == ALU_ADD) a + b > 255;`. Tests then switch such blocks on and off with `constraint_mode()`.

### Interview questions

**Q1. What does the implication operator do in a constraint?**
`A -> B` means that whenever A is true, B must be true. When A is false, B is unconstrained. It is equivalent to `!A || B`.

**Q2. Is implication bidirectional?**
Yes. Because only "A true and B false" is forbidden, B being false forces A to be false. The solver uses the constraint in both directions.

**Q3. What is the difference between `->` and `if`-`else` in constraints?**
They express the same logic. `if (A) B;` equals `A -> B`. `if`-`else` adds an "otherwise" part, which with implication needs a second constraint `!A -> C`. `if`-`else` is more readable for multi-way choices; `->` is compact and is an expression that can be combined with other operators.

**Q4. `rand bit a; rand bit [3:0] b; constraint c { a -> b == 0; }` What is the probability that `a` is 1?**
There are 16 solutions with `a` = 0 and one with `a` = 1, so 1/17.

**Q5. How do you make `a` in the previous question 1 half of the time?**
Add `solve a before b;`. The solver then chooses `a` first with equal probability for 0 and 1, and then chooses `b`.

**Q6. How do you write "A if and only if B" as a constraint?**
`A <-> B`, or `A == B` when both are 1-bit conditions, or the two implications `A -> B; B -> A;`.

**Q7. Given `constraint c { (a == 1) -> (b == 1); }` and an inline constraint `b == 0`, what is `a`?**
`a` is any value except 1.

## 2.5 foreach Constraints and Array Reduction

### In plain English

A `foreach` constraint applies the same rule to every element of an array: "every payload byte is non-zero", "each element is greater than the one before it". Array reduction methods such as `sum()` let a single constraint talk about the array as a whole: "the elements add up to 100".

### Syntax

```systemverilog
class arr_demo;
  rand bit [7:0] d[];

  constraint size_c { d.size() inside {[4:8]}; }

  constraint each_c {                       // a rule for every element
    foreach (d[i]) d[i] inside {[1:50]};
  }
  constraint neighbour_c {                  // a rule between neighbours
    foreach (d[i]) if (i > 0) d[i] != d[i-1];
  }
  constraint index_c {                      // the index may be used in the rule
    foreach (d[i]) (i % 2 == 0) -> d[i][0] == 0;     // even positions hold even values
  }
  constraint total_c {                      // a rule for the whole array
    d.sum() with (int'(item)) == 100;
  }
endclass
```

### How foreach works internally

A `foreach` constraint is **unrolled**. After the array size is known, the solver replaces the loop by one copy of the body for each index. The loop variable is a constant in each copy.

```text
   d.size() == 3
   foreach (d[i]) if (i > 0) d[i] > d[i-1];

   is solved as:

      i = 0 :   if (0 > 0) ...            -> condition is constant false, no constraint
      i = 1 :   d[1] > d[0];
      i = 2 :   d[2] > d[1];
```

Consequences:

- The guard `if (i > 0)` is evaluated at unrolling time. It costs nothing and it is what prevents the illegal index `d[-1]`.
- A reference to `d[i+1]` or `d[i-1]` without a guard indexes outside the array for the last or first element. That is an error and the randomization fails.
- A large array with a nested `foreach` produces a large number of constraints (an array of 1000 elements compared pairwise gives about half a million). Solving time grows accordingly.

### Array reduction methods in constraints

| Method | Returns | Example constraint |
|---|---|---|
| `sum()` | Sum of the elements | `d.sum() with (int'(item)) == 100;` |
| `product()` | Product of the elements | `d.product() with (int'(item)) < 1000;` |
| `and()` | Bitwise AND of all elements | `d.and() == 0;` |
| `or()` | Bitwise OR of all elements | `d.or() == 8'hFF;` |
| `xor()` | Bitwise XOR of all elements | `d.xor() == 0;` |

Only these reduction methods may be used in constraints. Locator and ordering methods (`find`, `sort`, `unique`, `min`, `max`...) are procedural and are not allowed; they belong in `post_randomize()`.

The optional `with (expression)` clause replaces each element by the value of the expression before reducing. `item` is the current element and `item.index` is its index.

```systemverilog
d.sum() with (int'(item))                 // sum computed in 32 bits
d.sum() with (int'(item > 10))            // how many elements are greater than 10
d.sum() with (item.index < 4 ? int'(item) : 0)     // sum of the first four elements
```

### The sum() width trap

`sum()` returns a value **of the element type**. For an array of `bit [7:0]`, the sum is computed in 8 bits and wraps around.

```text
   rand bit [7:0] d[4];
   constraint c { d.sum() == 20; }

   Accepted by the solver:   5 +   5 +   5 +   5 =  20      (20 mod 256 = 20)
   Also accepted:          100 + 100 +  50 +  26 = 276      (276 mod 256 = 20)
                           200 + 200 + 100 +  32 = 532      (532 mod 256 = 20)

   Fix:   constraint c { d.sum() with (int'(item)) == 20; }
```

The same trap, in a worse form, applies to counting. `item > 10` is a **1-bit** value, so `d.sum() with (item > 10)` adds 1-bit numbers in 1-bit arithmetic: the result is only the parity of the count. Always cast inside the `with` clause: `d.sum() with (int'(item > 10)) == 3`.

### Complete example

```systemverilog file=tb_foreach_sum.sv
module tb_foreach_sum;

  class arr_demo;
    rand bit [7:0] d[];
    rand bit [7:0] w[4];

    constraint size_c  { d.size() inside {[4:6]}; }
    constraint asc_c   { foreach (d[i]) if (i > 0) d[i] > d[i-1]; }
    constraint total_c { d.sum() with (int'(item)) == 100; }

    constraint wrap_c  { w.sum() == 20; }           // the trap: 8-bit sum
  endclass

  arr_demo a;
  int      true_sum, wrapped;

  initial begin
    a = new();
    repeat (200) begin
      if (!a.randomize()) $fatal(1, "randomize failed");

      // check d: strictly ascending, true sum 100
      true_sum = 0;
      foreach (a.d[i]) begin
        true_sum += a.d[i];
        if (i > 0 && a.d[i] <= a.d[i-1]) $error("d is not ascending: %p", a.d);
      end
      if (true_sum != 100) $error("sum of d is %0d", true_sum);

      // check w: count how often the real sum is not 20
      true_sum = 0;
      foreach (a.w[i]) true_sum += a.w[i];
      if (true_sum != 20) wrapped++;
    end
    $display("last d = %p", a.d);
    $display("w.sum() == 20 was satisfied by a wrapped sum in %0d of 200 calls", wrapped);
  end

endmodule
```

**What to expect.** No `$error` messages: `d` always has 4 to 6 strictly ascending elements with a true total of 100. The last line shows a count close to 200. Almost every solution of `w.sum() == 20` in 8-bit arithmetic has a real sum of 276, 532 or 788, because there are vastly more such combinations than combinations that really add up to 20.

**Line by line**

| Line | Explanation |
|---|---|
| `d.size() inside {[4:6]};` | Solved first. |
| `foreach (d[i]) if (i > 0) d[i] > d[i-1];` | Unrolled into size - 1 comparisons. The guard removes the copy for `i` = 0. |
| `d.sum() with (int'(item)) == 100;` | Each element is widened to 32 bits before being added, so the constraint means the true sum. |
| `w.sum() == 20;` | Each element is 8 bits, so the sum is 8 bits. It wraps. |
| Checker code | Recomputes the sums in a 32-bit `int`. This kind of independent check is how you convince yourself that a constraint means what you intended. |

### Common mistakes

> **Common mistake:** `foreach (d[i]) d[i] < d[i+1];` with no guard. For the last element `d[i+1]` does not exist. Write `if (i < d.size() - 1) d[i] < d[i+1];` or use the `i > 0` form with `d[i-1]`.

> **Common mistake:** Forgetting the cast in `sum()`, or casting the result instead of the items. `int'(d.sum()) == 100` does not help: the wrap has already happened.

> **Common mistake:** Using a `for` loop inside a constraint. Only `foreach` is allowed.

> **Interview trap:** "The array size is random and the `foreach` constraint needs at least two elements. What happens when the solver picks size 1?" Nothing goes wrong if the body is guarded: the unrolled copies simply disappear. But remember that size is solved first. If size 1 makes some other constraint (for example a sum) impossible, the call fails; the solver does not go back and choose another size.

> **Verification application:** Burst and packet classes use `foreach` for per-beat rules (strobe patterns, incrementing addresses: `foreach (addr[i]) if (i > 0) addr[i] == addr[i-1] + 4;`) and `sum()` to distribute a total over several fields, such as a frame's total length divided into a random number of fragments.

### Interview questions

**Q1. How do you constrain every element of an array?**
With a `foreach` constraint: `foreach (arr[i]) arr[i] < 100;`.

**Q2. Write a constraint for an array in ascending order.**
`foreach (arr[i]) if (i > 0) arr[i] > arr[i-1];`. Use `>=` if equal neighbours are allowed.

**Q3. Why is the guard `if (i > 0)` needed?**
For `i` = 0 the expression `arr[i-1]` would index element -1, which does not exist. The guard is resolved when the loop is unrolled, so that copy of the constraint is dropped.

**Q4. `rand bit [3:0] a[10]; constraint c { a.sum() == 50; }` Does this guarantee the elements add up to 50?**
No. `sum()` returns a value of the element type, here 4 bits. A 4-bit sum can only be 0 to 15 and can never equal 50, so the randomization fails. With a target below 16 it would succeed, but it would also accept wrapped sums (a true sum of 21 looks like 5). The correct form is `a.sum() with (int'(item)) == 50`.

**Q5. How do you constrain exactly three elements of an array to be zero?**
`arr.sum() with (int'(item == 0)) == 3;`. The comparison gives 1 for each zero element, and the cast makes the sum 32 bits wide.

**Q6. Which array methods can be used inside constraints?**
The reduction methods `sum`, `product`, `and`, `or` and `xor`, optionally with a `with` clause, plus `size()`. Other array methods are not allowed.

**Q7. How does the solver handle `foreach`?**
It first solves the array size, then unrolls the loop into one constraint per element, with the index as a constant in each copy, and solves all of them together.

## 2.6 unique Constraints

### In plain English

`unique` says "all of these must be different from one another". It is the direct way to ask for an array with no repeated values, or for several variables that must not collide.

### Syntax

```systemverilog
class uniq_demo;
  rand bit [3:0] a, b, c;
  rand bit [7:0] ids[6];
  rand bit [2:0] perm[8];

  constraint scalars_c { unique {a, b, c}; }         // three different values
  constraint array_c   { unique {ids}; }             // all six elements differ
  constraint mixed_c   { unique {ids[0:2], a}; }     // a slice and a scalar together
  constraint perm_c    { unique {perm}; }            // 8 different 3-bit values
endclass
```

### Technical definition

`unique { list }` is a constraint item (added in IEEE 1800-2012) whose list contains random variables, arrays and array slices. After randomization, no two members of the expanded list have the same value. It is equivalent to writing `!=` between every pair of members.

| Rule | Detail |
|---|---|
| Members | Scalars, whole arrays, array slices. All must have equivalent types |
| Not allowed in the list | `randc` variables |
| Number of values | If the list has more members than the type has values (for example five `bit [1:0]` variables), the constraint cannot be satisfied |
| Scope | It only requires uniqueness **within one `randomize()` call**. It says nothing about values produced by earlier calls; that is what `randc` does |
| Cost | For N members it is equivalent to N × (N - 1) / 2 inequalities |

### Complete example

```systemverilog file=tb_unique.sv
module tb_unique;

  class uniq_demo;
    rand bit [2:0] perm[8];
    rand bit [3:0] a, b, c;

    constraint perm_c    { unique {perm}; }
    constraint scalars_c { unique {a, b, c}; a < 3; b < 3; c < 3; }
  endclass

  uniq_demo u;
  int       seen[8];
  bit       ok;

  initial begin
    u = new();
    repeat (3) begin
      if (!u.randomize()) $fatal(1, "randomize failed");

      seen = '{default: 0};
      foreach (u.perm[i]) seen[u.perm[i]]++;
      ok = 1;
      foreach (seen[v]) if (seen[v] != 1) ok = 0;

      $display("perm=%p  is a permutation of 0..7: %s", u.perm, ok ? "yes" : "NO");
      $display("a+b+c=%0d", u.a + u.b + u.c);
    end
  end

endmodule
```

**What to expect.** In each of the three iterations `perm` contains the values 0 to 7 in some order: eight different values of a 3-bit type must use every value exactly once, so the line always ends in `yes`. `a`, `b` and `c` are three different values below 3, which can only be 0, 1 and 2 in some order, so the second line is always exactly `a+b+c=3`.

**Line by line**

| Line | Explanation |
|---|---|
| `unique {perm};` | Eight elements, eight possible values: the result is a random permutation. This is the standard way to generate a random ordering. |
| `unique {a, b, c}; a < 3; ...` | Three different values chosen from {0, 1, 2}. The sum is always 3, which gives a deterministic check. |
| `seen[...]++` | The checker counts each value and requires every count to be 1. |

### unique versus randc versus hand-written inequalities

| Requirement | Use |
|---|---|
| Several variables or array elements differ **within one randomization** | `unique { ... }` |
| One variable does not repeat **across successive randomizations** until all values are used | `randc` |
| A tool or coding standard that predates `unique` | Nested `foreach` with `!=` (Problem 5 in Part 5) |
| A random permutation of 0 to N-1 | `unique` on an array of N elements constrained to `[0:N-1]`, or `arr.shuffle()` in `post_randomize()` |

> **Interview trap:** "Does `unique {arr}` prevent a value from appearing again in the next `randomize()` call?" No. Uniqueness is only among the listed members in the current solution.

> **Common mistake:** Asking for more unique values than exist: `rand bit [1:0] v[5]; constraint c { unique {v}; }` has no solution, because a 2-bit element has only four values.

> **Verification application:** Choosing N different slave ports for parallel traffic, generating a set of non-colliding IDs for outstanding transactions, or building a random order in which to program registers.

### Interview questions

**Q1. What does the `unique` constraint do?**
It forces all members of its list (scalar variables, arrays, slices) to have different values in the solution.

**Q2. How would you generate an array of unique values without the `unique` keyword?**
With nested `foreach` loops: `foreach (a[i]) foreach (a[j]) if (i != j) a[i] != a[j];`. Other options are to fill the array with distinct values and call `shuffle()` in `post_randomize()`, or to use a `randc` helper variable.

**Q3. What is the difference between `unique` and `randc`?**
`unique` gives distinct values among several variables in one `randomize()` call. `randc` gives non-repeating values for one variable over successive calls.

**Q4. How do you generate a random permutation of 0 to 15?**
`rand bit [3:0] p[16]; constraint c { unique {p}; }`. Sixteen distinct 4-bit values must be exactly the numbers 0 to 15.

**Q5. What happens with `rand bit [1:0] v[5]; constraint c { unique {v}; }`?**
`randomize()` fails and returns 0, because five distinct values cannot be chosen from a set of four.
