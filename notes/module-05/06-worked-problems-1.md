# Part 5: Worked Constraint Problems

Constraint writing is tested at the whiteboard in almost every verification interview. This part contains twenty-two problems in rising order of difficulty. Each has a complete solution, the reasoning behind it, the traps, and alternative solutions where an interviewer is likely to ask for one.

**How to use this part.** Cover the solution, write your own, then compare. A constraint is "right" only when (1) every generated value is legal, (2) every legal value can be generated, and (3) it never fails. Requirement 2 is the one candidates forget: a constraint that always produces `1, 2, 3, 4` satisfies "ascending order" but is a poor answer.

**About the checkers.** Each solution contains procedural code that verifies the generated values independently of the constraint and counts violations in `errors`. Every program therefore ends with a line of the form `pNN: errors=0`, which does not depend on the seed. Writing such a checker is itself a skill interviewers look for: it shows that you can state the requirement in a second, independent way.

| No. | Problem | Main technique |
|---|---|---|
| 1 | Address in two regions, aligned, with a hole | `inside`, bit-select, negation |
| 2 | Even numbers; multiples of 5 that are not multiples of 10 | `%`, bit-select |
| 3 | Power of two | `$countones`, bit trick, shift |
| 4 | Exactly N bits set; N contiguous bits | `$countones`, shifted mask |
| 5 | Unique array elements without `unique` | Nested `foreach` |
| 6 | Array in ascending order | Neighbour constraint with guard |
| 7 | No two (or three) consecutive equal elements | Neighbour constraints |
| 8 | Elements that add up to a given total | `sum()` with a cast |
| 9 | Even values at even indices, odd at odd | Index used in the constraint |
| 10 | No repeated value without `randc` | History queue and `post_randomize()` |
| 11 | Fixed patterns: 0101..., 1 2 2 3 3 3... | Index arithmetic, helper function |
| 12 | Payload length depends on packet kind | Implication, `solve before`, array size |
| 13 | Exactly K elements equal to a value | Counting with `sum()` |
| 14 | Palindrome array | Mirrored index |
| 15 | Gray-code neighbours; fixed Hamming distance | `$countones` of an XOR |
| 16 | No two adjacent 1 bits | Shift and AND |
| 17 | A valid calendar date | Nested `if`-`else` |
| 18 | Non-overlapping memory blocks | Ordering between array elements, width control |
| 19 | Matrix with unique rows and columns | Two-dimensional `foreach` |
| 20 | ALU stimulus with a controlled overflow rate | Equivalence, `dist`, `solve before` |
| 21 | Eight queens | `unique`, signed differences |
| 22 | Push/pop sequence that never overflows a FIFO | Helper array for running state |

## Problem 1: Address in two regions, word-aligned, with a reserved hole

**Problem.** Generate a 12-bit address that lies in `0x100` to `0x1FF` or in `0x800` to `0x8FF`, is a multiple of 4, and is not in the reserved range `0x140` to `0x14F`.

```systemverilog file=tb_p01_addr_ranges.sv
module tb_p01_addr_ranges;

  class addr_gen;
    rand bit [11:0] addr;

    constraint region_c { addr inside {[12'h100:12'h1FF], [12'h800:12'h8FF]}; }
    constraint align_c  { addr[1:0] == 2'b00; }
    constraint hole_c   { !(addr inside {[12'h140:12'h14F]}); }
  endclass

  addr_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (!((g.addr >= 12'h100 && g.addr <= 12'h1FF) ||
            (g.addr >= 12'h800 && g.addr <= 12'h8FF)))   errors++;
      if (g.addr % 4 != 0)                               errors++;
      if (g.addr >= 12'h140 && g.addr <= 12'h14F)        errors++;
    end
    $display("p01: errors=%0d", errors);
  end

endmodule
```

```output
p01: errors=0
```

**Explanation.** Three independent rules, three small blocks. `inside` lists the two regions. Alignment to 4 bytes means the two lowest bits are zero; a bit-select is cheaper for the solver than `addr % 4 == 0`. The hole is excluded with a negated `inside`, and the parentheses are required because `!` binds tighter than `inside`.

**Why three blocks.** An error test can now disable just `hole_c` to target the reserved range, or just `align_c` to generate misaligned accesses.

## Problem 2: Even numbers, and multiples of 5 that are not multiples of 10

**Problem.** `x` must be even. `y` must be between 1 and 200, divisible by 5 and not divisible by 10.

```systemverilog file=tb_p02_divisible.sv
module tb_p02_divisible;

  class div_gen;
    rand bit [7:0] x, y;

    constraint even_c { x[0] == 1'b0; }
    constraint five_c { y inside {[1:200]}; y % 5 == 0; y % 10 != 0; }
  endclass

  div_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (g.x % 2 != 0)                                 errors++;
      if (g.y < 1 || g.y > 200)                         errors++;
      if (!(g.y % 5 == 0 && g.y % 10 != 0))             errors++;
    end
    $display("p02: errors=%0d", errors);
  end

endmodule
```

```output
p02: errors=0
```

**Explanation.** Even means bit 0 is zero; odd would be `x[0] == 1'b1`. For `y` the two modulus constraints together leave 5, 15, 25, ..., 195. An equivalent single constraint is `y % 10 == 5`.

**Trap.** With a signed variable (`rand int y`), `%` can be negative and `y % 5 == 0` also admits negative multiples. Bound the range, as done here.

## Problem 3: Power of two

**Problem.** Generate a 16-bit value that is a power of two (1, 2, 4, ..., 32768). Show three ways.

```systemverilog file=tb_p03_power_of_two.sv
module tb_p03_power_of_two;

  class pow2_gen;
    rand bit [15:0] p1, p2, p3;
    rand bit [3:0]  sh;

    constraint count_c { $countones(p1) == 1; }                 // exactly one bit set
    constraint trick_c { p2 != 0; (p2 & (p2 - 1)) == 0; }       // classic bit trick
    constraint shift_c { p3 == (16'd1 << sh); }                 // 1 shifted by a random amount
  endclass

  pow2_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (!$onehot(g.p1)) errors++;
      if (!$onehot(g.p2)) errors++;
      if (!$onehot(g.p3)) errors++;
    end
    $display("p03: errors=%0d", errors);
  end

endmodule
```

```output
p03: errors=0
```

**Explanation.**

| Method | Why it works |
|---|---|
| `$countones(p1) == 1` | A power of two has exactly one bit set. `$onehot(p1)` is the same condition |
| `(p2 & (p2 - 1)) == 0` | Subtracting 1 clears the lowest set bit and sets all bits below it. ANDing with the original is zero only if there was a single set bit. Zero must be excluded separately |
| `p3 == (16'd1 << sh)` | Constructs the value from a random exponent 0 to 15 |

**Trap.** Writing `p2 & (p2 - 1) == 0` without the outer parentheses. `==` has higher precedence than `&`, so this is `p2 & ((p2 - 1) == 0)`, which is non-zero only for `p2` = 1.

**Follow-up.** "Not a power of two": `$countones(x) != 1`. "A power of two minus one (1, 3, 7, 15...)": `(x & (x + 1)) == 0; x != 0;`.

## Problem 4: Exactly N bits set, and N contiguous bits set

**Problem.** (a) A 32-bit value with exactly five bits set, anywhere. (b) A 32-bit value with exactly five bits set, all next to each other.

```systemverilog file=tb_p04_n_bits.sv
module tb_p04_n_bits;

  class bits_gen;
    rand bit [31:0] any5;
    rand bit [31:0] run5;
    rand bit [4:0]  pos;

    constraint any_c { $countones(any5) == 5; }
    constraint run_c { pos <= 27; run5 == (32'h0000_001F << pos); }
  endclass

  bits_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if ($countones(g.any5) != 5)              errors++;
      if ($countones(g.run5) != 5)              errors++;
      if (((g.run5 >> g.pos) & 32'h1F) != 5'h1F) errors++;
    end
    $display("p04: errors=%0d", errors);
  end

endmodule
```

```output
p04: errors=0
```

**Explanation.** (a) is a direct use of `$countones`. For (b), a run of five ones is the mask `1F` shifted left by a random position. The position must not exceed 27, otherwise ones are shifted out of the top and fewer than five remain. Introducing a helper random variable (`pos`) is a standard technique: constrain something simple and derive the complicated value from it.

**Follow-up.** "Equal number of ones and zeros in a 16-bit value": `$countones(x) == 8`. "At most three bits differ from the previous value `prev`": `$countones(x ^ prev) <= 3` with `prev` a state variable updated in `post_randomize()`.

## Problem 5: Unique array elements without the unique keyword

**Problem.** Fill an array of eight 4-bit elements with eight different values. You may not use `unique` or `randc`.

```systemverilog file=tb_p05_unique_manual.sv
module tb_p05_unique_manual;

  class uniq_gen;
    rand bit [3:0] a[8];

    constraint uniq_c {
      foreach (a[i])
        foreach (a[j])
          if (i < j) a[i] != a[j];
    }
  endclass

  uniq_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 8; j++)
          if (g.a[i] == g.a[j]) errors++;
    end
    $display("p05: sample a=%p", g.a);
    $display("p05: errors=%0d", errors);
  end

endmodule
```

**What to expect.** The first line shows eight different values from 0 to 15 (sample; values differ per seed). The second line is exactly `p05: errors=0`.

**Explanation.** Two nested `foreach` loops over the same array, with different loop variables, visit every pair of elements. The guard `i < j` keeps each pair once and, more importantly, skips `i == j`: without a guard the constraint would contain `a[0] != a[0]`, which is always false, and the randomization would fail. `if (i != j)` also works but generates each inequality twice.

**Alternatives an interviewer may ask for.**

```systemverilog
// (1) The direct way, when allowed
constraint uniq_c { unique {a}; }

// (2) No constraint at all: fill with distinct values, then shuffle
function void post_randomize();
  foreach (a[i]) a[i] = i;     // any set of distinct values
  a.shuffle();
endfunction

// (3) Ascending order implies uniqueness; shuffle afterwards for a random order
constraint asc_c { foreach (a[i]) if (i > 0) a[i] > a[i-1]; }
function void post_randomize();
  a.shuffle();
endfunction
```

Solution 3 uses 7 constraints instead of 28, which matters for large arrays: the pairwise form grows with the square of the array size.

## Problem 6: Array in ascending order

**Problem.** Generate six 8-bit elements in strictly ascending order.

```systemverilog file=tb_p06_ascending.sv
module tb_p06_ascending;

  class asc_gen;
    rand bit [7:0] a[6];

    constraint asc_c { foreach (a[i]) if (i > 0) a[i] > a[i-1]; }
  endclass

  asc_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 6; i++)
        if (g.a[i] <= g.a[i-1]) errors++;
    end
    $display("p06: sample a=%p", g.a);
    $display("p06: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample of six increasing values, then exactly `p06: errors=0`.

**Explanation.** Each element is compared with its predecessor. The guard `if (i > 0)` removes the comparison for the first element, which has no predecessor. Use `>=` for non-decreasing order and `<` for descending order.

**Alternative.** Randomize without the constraint and call `a.sort()` in `post_randomize()`. Know the difference: sorting does not guarantee strictly ascending values (duplicates may remain), and it is a procedural step, so other constraints cannot refer to the sorted order.

**Trap.** `foreach (a[i]) a[i] < a[i+1];` indexes one past the end for the last element. Either guard with `if (i < $size(a) - 1)` or use the `a[i-1]` form.

## Problem 7: No two consecutive elements equal; no three in a row

**Problem.** (a) An array of ten 2-bit values in which neighbouring elements are never equal. (b) An array of twelve single bits that never contains three equal bits in a row.

```systemverilog file=tb_p07_no_consecutive.sv
module tb_p07_no_consecutive;

  class seq_gen;
    rand bit [1:0] a[10];
    rand bit       b[12];

    constraint no_pair_c {
      foreach (a[i]) if (i > 0) a[i] != a[i-1];
    }
    constraint no_triple_c {
      foreach (b[i]) if (i > 1) !(b[i] == b[i-1] && b[i] == b[i-2]);
    }
  endclass

  seq_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 10; i++)
        if (g.a[i] == g.a[i-1]) errors++;
      for (int i = 2; i < 12; i++)
        if (g.b[i] == g.b[i-1] && g.b[i] == g.b[i-2]) errors++;
    end
    $display("p07: sample a=%p b=%p", g.a, g.b);
    $display("p07: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample line, then exactly `p07: errors=0`.

**Explanation.** (a) compares each element with the previous one. (b) forbids the situation "this bit equals both of the two before it"; the guard is `i > 1` because two predecessors are needed. Note that (a) allows a value to reappear after a gap (`2, 1, 2` is legal), which distinguishes it from uniqueness.

**Follow-up.** "No value may repeat within any window of three elements": add `if (i > 1) a[i] != a[i-2];` to (a).

## Problem 8: Elements that add up to a given total

**Problem.** Five elements, each between 1 and 40, whose sum is exactly 100.

```systemverilog file=tb_p08_sum.sv
module tb_p08_sum;

  class sum_gen;
    rand bit [7:0] a[5];

    constraint each_c { foreach (a[i]) a[i] inside {[1:40]}; }
    constraint sum_c  { a.sum() with (int'(item)) == 100; }
  endclass

  sum_gen g;
  int     errors, total;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      total = 0;
      foreach (g.a[i]) begin
        total += g.a[i];
        if (g.a[i] < 1 || g.a[i] > 40) errors++;
      end
      if (total != 100) errors++;
    end
    $display("p08: sample a=%p", g.a);
    $display("p08: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample of five values between 1 and 40, then exactly `p08: errors=0`.

**Explanation.** `sum()` returns the element type. The `with (int'(item))` clause widens every element to 32 bits before the addition, so the total cannot wrap (Section 2.5). In this particular problem the largest possible sum is 200, which still fits in 8 bits, so the cast is not strictly needed. Write it anyway and say why: the habit prevents the bug when the limits change.

**Follow-up.** "Divide 100 into a random number of parts": make the array dynamic, constrain `a.size() inside {[2:10]}`, keep the other two constraints. Because the size is solved first, check that every allowed size has a solution: with elements of at most 40, size 2 cannot reach 100, so the size range must start at 3.

## Problem 9: Even values at even indices, odd values at odd indices

**Problem.** In an array of eight elements, the element at an even index must be even and the element at an odd index must be odd.

```systemverilog file=tb_p09_even_odd_index.sv
module tb_p09_even_odd_index;

  class eo_gen;
    rand bit [7:0] a[8];

    constraint parity_c { foreach (a[i]) a[i] % 2 == i % 2; }
  endclass

  eo_gen g;
  int    errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      foreach (g.a[i])
        if ((g.a[i] % 2) != (i % 2)) errors++;
    end
    $display("p09: sample a=%p", g.a);
    $display("p09: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample line, then exactly `p09: errors=0`.

**Explanation.** Inside a `foreach` constraint the loop variable is a constant for each unrolled copy, and it may be used freely in the expression. Here the parity of the element is tied to the parity of its index. An equivalent form with implications:

```systemverilog
constraint parity_c {
  foreach (a[i]) {
    (i % 2 == 0) -> (a[i][0] == 1'b0);
    (i % 2 == 1) -> (a[i][0] == 1'b1);
  }
}
```

**Follow-up.** "Element value equals twice its index": `foreach (a[i]) a[i] == 2 * i;`. "Elements at indices divisible by 3 are zero, the others non-zero": `foreach (a[i]) (a[i] == 0) == (i % 3 == 0);`, an equivalence.

## Problem 10: No repeated value without randc

**Problem.** A 4-bit variable must go through all 16 values without repetition, then start again, without using `randc`. Then modify the solution so that a value only has to differ from the last four values.

```systemverilog file=tb_p10_no_repeat.sv
module tb_p10_no_repeat;

  class no_repeat;
    rand bit [3:0] v;
    bit [3:0]      hist[$];                 // values already used in this cycle

    constraint fresh_c { !(v inside {hist}); }

    function void post_randomize();
      hist.push_back(v);
      if (hist.size() == 16) hist.delete(); // all values used: start a new cycle
    endfunction
  endclass

  no_repeat g;
  int       seen[16];
  int       errors;

  initial begin
    g = new();
    repeat (3) begin                        // three complete cycles
      seen = '{default: 0};
      repeat (16) begin
        if (!g.randomize()) $fatal(1, "randomize failed");
        seen[g.v]++;
      end
      foreach (seen[i]) if (seen[i] != 1) errors++;
    end
    $display("p10: errors=%0d", errors);
  end

endmodule
```

```output
p10: errors=0
```

**Explanation.** The object remembers what it has produced. `hist` is a state variable: at each call the solver sees its current contents as a constant set and must choose a value outside it. `post_randomize()` records the new value, and empties the history when all 16 values have been used. An `inside` test against an empty queue is false, so on the first call of each cycle nothing is excluded.

This reproduces the behaviour of `randc` with ordinary `rand`, and unlike `randc` it works for wide variables, because only the values actually used are stored.

**Variant: differ from the last four values only.**

```systemverilog
function void post_randomize();
  hist.push_back(v);
  if (hist.size() > 4) void'(hist.pop_front());   // keep a sliding window of four
endfunction
```

**Trap.** Forgetting to clear the history. After 16 calls the excluded set contains every value and the 17th `randomize()` fails.

**Verification application.** "Do not reuse a transaction ID that is still outstanding": the scoreboard or driver keeps a queue of IDs in flight, and the generator constrains `!(id inside {busy_ids})`.

## Problem 11: Fixed patterns

**Problem.** (a) Generate the bit pattern 0, 1, 0, 1, ... (b) Generate 1, 2, 2, 3, 3, 3, 4, 4, 4, 4, ... up to a given `n`.

```systemverilog file=tb_p11_patterns.sv
module tb_p11_patterns;

  class pat_gen;
    rand bit b[8];
    rand int a[];
    int      n = 4;

    // value of the pattern 1,2,2,3,3,3,... at position idx
    function automatic int val_at(int idx);
      int v   = 1;
      int end_of_group = 1;                  // number of elements up to and including group v
      while (idx >= end_of_group) begin
        v++;
        end_of_group += v;
      end
      return v;
    endfunction

    constraint alt_c  { foreach (b[i]) b[i] == i % 2; }
    constraint size_c { a.size() == n * (n + 1) / 2; }
    constraint tri_c  { foreach (a[i]) a[i] == val_at(i); }
  endclass

  pat_gen g;

  initial begin
    g = new();
    if (!g.randomize()) $fatal(1, "randomize failed");
    $write("p11: b =");
    foreach (g.b[i]) $write(" %0d", g.b[i]);
    $write("\np11: a =");
    foreach (g.a[i]) $write(" %0d", g.a[i]);
    $write("\n");
  end

endmodule
```

```output
p11: b = 0 1 0 1 0 1 0 1
p11: a = 1 2 2 3 3 3 4 4 4 4
```

**Explanation.** Both patterns are fully determined, so there is nothing random about the result; the question tests whether you can express a rule in terms of the index.

(a) The value is the parity of the index.

(b) The value `v` occupies `v` consecutive positions, so the total length for values 1 to `n` is `n(n+1)/2`. The helper function walks through the groups: group 1 ends before index 1, group 2 before index 3, group 3 before index 6, and so on. It is called with the loop index, which is a constant in each unrolled constraint, so the function's "arguments are solved first" behaviour (Section 3.4) causes no problem here.

**A constraint-only alternative for (b).** State the defining properties instead of computing the value: the sequence starts at 1, never decreases, rises by at most 1, and each value `k` occurs exactly `k` times.

```systemverilog
constraint tri_c {
  a[0] == 1;
  foreach (a[i]) if (i > 0) a[i] inside {a[i-1], a[i-1] + 1};
  foreach (a[i]) a.sum() with (int'(item == a[i])) == a[i];
}
```

This is elegant but much more expensive to solve. In real code a fixed pattern is simply written in `post_randomize()` with two nested loops. Say so in the interview, then show the constraint to demonstrate that you can.

**Follow-up patterns.**

| Pattern | Constraint |
|---|---|
| 0, 0, 1, 1, 0, 0, 1, 1, ... | `a[i] == (i / 2) % 2` |
| 0, 1, 2, 0, 1, 2, ... | `a[i] == i % 3` |
| 1, 0, 2, 0, 3, 0, ... | `a[i] == ((i % 2 == 0) ? i / 2 + 1 : 0)` |
| 7, 6, 5, ..., 0 | `a[i] == $size(a) - 1 - i` |
