## Problem 12: Payload length depends on the packet kind

**Problem.** A packet has a `kind` (SHORT, MEDIUM or LONG). SHORT packets have 1 to 15 payload bytes, MEDIUM 16 to 255, LONG 256 to 1500. The three kinds must occur about equally often, and the payload array must have exactly `len` bytes.

```systemverilog file=tb_p12_kind_len.sv
module tb_p12_kind_len;

  typedef enum {SHORT, MEDIUM, LONG} kind_e;

  class pkt;
    rand kind_e     kind;
    rand bit [10:0] len;
    rand bit [7:0]  payload[];

    constraint len_c {
      (kind == SHORT)  -> len inside {[1:15]};
      (kind == MEDIUM) -> len inside {[16:255]};
      (kind == LONG)   -> len inside {[256:1500]};
    }
    constraint order_c { solve kind before len; }
    constraint size_c  { payload.size() == len; }
  endclass

  pkt p;
  int errors;
  int count[kind_e];

  initial begin
    p = new();
    repeat (300) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      count[p.kind]++;
      case (p.kind)
        SHORT  : if (!(p.len inside {[1:15]}))     errors++;
        MEDIUM : if (!(p.len inside {[16:255]}))   errors++;
        LONG   : if (!(p.len inside {[256:1500]})) errors++;
      endcase
      if (p.payload.size() != p.len) errors++;
    end
    $display("p12: SHORT=%0d MEDIUM=%0d LONG=%0d", count[SHORT], count[MEDIUM], count[LONG]);
    $display("p12: errors=%0d", errors);
  end

endmodule
```

**What to expect.** The first line shows three counts each close to 100. The second line is exactly `p12: errors=0`.

**Explanation.** Three implications describe the table in the specification. Since `kind` is an enum with exactly these three members, the three cases cover everything.

Without `order_c` there are 15 + 240 + 1245 = 1500 solutions, and SHORT packets would be only 1 percent of the traffic. `solve kind before len` makes the solver pick the kind first with probability 1/3 each. This is the standard use of `solve`...`before`.

`payload.size() == len` ties the array size to the length field, so `len` effectively decides the size.

**Alternative to the ordering.** `constraint kind_c { kind dist {SHORT := 1, MEDIUM := 1, LONG := 1}; }`. With a `dist` the test can also change the mix by using weight variables.

**Follow-up.** "Within LONG packets, make maximum-size packets common": add `(kind == LONG) -> len dist {1500 := 30, [256:1499] :/ 70};`.

## Problem 13: Exactly K elements equal to a given value

**Problem.** In an array of ten 4-bit elements, exactly three must be equal to 5.

```systemverilog file=tb_p13_count_value.sv
module tb_p13_count_value;

  class cnt_gen;
    rand bit [3:0] a[10];

    constraint three_fives_c { a.sum() with (int'(item == 5)) == 3; }
  endclass

  cnt_gen g;
  int     errors, fives;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      fives = 0;
      foreach (g.a[i]) if (g.a[i] == 5) fives++;
      if (fives != 3) errors++;
    end
    $display("p13: sample a=%p", g.a);
    $display("p13: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample containing exactly three 5s, then exactly `p13: errors=0`.

**Explanation.** `item == 5` is 1 for a matching element and 0 otherwise. Summing these gives the number of matches. The cast `int'( ... )` is essential: the comparison result is a single bit, and a sum of 1-bit values is computed in 1 bit, which would only give the parity of the count. Without the cast, `== 3` could never be true (a 1-bit value is 0 or 1) and the randomization would fail.

**Follow-ups.** "At least two elements greater than 10": `a.sum() with (int'(item > 10)) >= 2`. "No more than half the elements are zero": `a.sum() with (int'(item == 0)) <= $size(a) / 2`.

## Problem 14: Palindrome array

**Problem.** Generate an array of 5 to 9 decimal digits that reads the same forwards and backwards.

```systemverilog file=tb_p14_palindrome.sv
module tb_p14_palindrome;

  class pal_gen;
    rand bit [3:0] a[];

    constraint size_c   { a.size() inside {[5:9]}; }
    constraint digit_c  { foreach (a[i]) a[i] < 10; }
    constraint mirror_c { foreach (a[i]) a[i] == a[a.size() - 1 - i]; }
  endclass

  pal_gen g;
  int     errors, n;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      n = g.a.size();
      if (n < 5 || n > 9) errors++;
      for (int i = 0; i < n; i++)
        if (g.a[i] != g.a[n - 1 - i] || g.a[i] > 9) errors++;
    end
    $display("p14: sample a=%p", g.a);
    $display("p14: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample such as `'{'h3, 'h7, 'h0, 'h7, 'h3}`, then exactly `p14: errors=0`.

**Explanation.** Element `i` must equal its mirror image, element `size - 1 - i`. The size is solved before the elements, so `a.size()` is a known constant when the `foreach` is unrolled. Each pair is constrained twice (once from each end) and the middle element of an odd-length array is compared with itself; both are harmless. To halve the work, guard with `if (i < a.size() / 2)`.

## Problem 15: Gray-code neighbours and fixed Hamming distance

**Problem.** (a) Generate eight different 4-bit values such that each differs from the previous one in exactly one bit. (b) Generate two 8-bit values that differ in exactly two bit positions.

```systemverilog file=tb_p15_gray.sv
module tb_p15_gray;

  class gray_gen;
    rand bit [3:0] g[8];
    rand bit [7:0] x, y;

    constraint step_c { foreach (g[i]) if (i > 0) $countones(g[i] ^ g[i-1]) == 1; }
    constraint uniq_c { unique {g}; }
    constraint dist_c { $countones(x ^ y) == 2; }
  endclass

  gray_gen h;
  int      errors;

  initial begin
    h = new();
    repeat (200) begin
      if (!h.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 8; i++)
        if ($countones(h.g[i] ^ h.g[i-1]) != 1) errors++;
      for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 8; j++)
          if (h.g[i] == h.g[j]) errors++;
      if ($countones(h.x ^ h.y) != 2) errors++;
    end
    $display("p15: sample g=%p", h.g);
    $display("p15: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample sequence in which neighbours differ in one bit, then exactly `p15: errors=0`.

**Explanation.** XOR marks the bit positions in which two values differ; `$countones` counts them. The number of differing bits is called the Hamming distance. Requiring a distance of 1 between neighbours is the defining property of a Gray-code sequence. The `unique` constraint prevents the sequence from stepping back to a value it has already visited.

**Verification application.** Checking a clock-domain-crossing FIFO pointer, which must be Gray-coded: a monitor uses exactly this expression, `$countones(ptr ^ prev_ptr) <= 1`, as a check.

## Problem 16: No two adjacent 1 bits

**Problem.** Generate a 16-bit value with exactly four bits set, no two of which are next to each other.

```systemverilog file=tb_p16_no_adjacent_ones.sv
module tb_p16_no_adjacent_ones;

  class bits_gen;
    rand bit [15:0] x;

    constraint spread_c { (x & (x >> 1)) == 0; }
    constraint four_c   { $countones(x) == 4; }
  endclass

  bits_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (300) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 15; i++)
        if (g.x[i] && g.x[i+1]) errors++;
      if ($countones(g.x) != 4) errors++;
    end
    $display("p16: sample x=%b", g.x);
    $display("p16: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample such as `0100101000010001`, then exactly `p16: errors=0`.

**Explanation.** Shifting `x` right by one places each bit on top of its lower neighbour. If the AND of the original and the shifted value is zero, no bit and its neighbour are both 1. The equivalent per-bit form is `foreach (x[i]) if (i > 0) !(x[i] && x[i-1]);`, which is clearer but produces 15 constraints instead of one.

**Follow-up.** "At least two zeros between any two ones": `(x & (x >> 1)) == 0; (x & (x >> 2)) == 0;`.

## Problem 17: A valid calendar date

**Problem.** Generate a valid date between the years 2000 and 2099.

```systemverilog file=tb_p17_date.sv
module tb_p17_date;

  class date_gen;
    rand bit [11:0] year;
    rand bit [3:0]  month;
    rand bit [4:0]  day;

    constraint year_c  { year inside {[2000:2099]}; }
    constraint month_c { month inside {[1:12]}; }
    constraint day_c {
      day >= 1;
      if (month inside {4, 6, 9, 11})
        day <= 30;
      else if (month == 2) {
        if (year % 4 == 0) day <= 29;
        else               day <= 28;
      }
      else
        day <= 31;
    }
  endclass

  function automatic int days_in(int y, int m);
    if (m inside {4, 6, 9, 11}) return 30;
    if (m == 2)                 return (y % 4 == 0) ? 29 : 28;
    return 31;
  endfunction

  date_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (g.year < 2000 || g.year > 2099)                      errors++;
      if (g.month < 1 || g.month > 12)                         errors++;
      if (g.day < 1 || g.day > days_in(g.year, g.month))       errors++;
    end
    $display("p17: sample %0d-%0d-%0d", g.year, g.month, g.day);
    $display("p17: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample date, then exactly `p17: errors=0`.

**Explanation.** A nested `if`-`else` constraint written like the rule everyone knows. Note the braces around the inner `if`-`else`: they make clear which `if` each `else` belongs to. Between 2000 and 2099 every year divisible by 4 is a leap year (2000 is divisible by 400), so the simple test is correct for this range; for a wider range the full rule `(year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)` is needed.

**Distribution note.** With no ordering, every valid date is equally likely, which is the natural result (February is slightly rarer than January because it has fewer days). `solve month before day` would instead make every month equally likely.

## Problem 18: Non-overlapping memory blocks

**Problem.** Allocate four memory blocks inside a 1024-byte region. Each block is 16 to 128 bytes long, starts on a 16-byte boundary, lies completely inside the region, and no two blocks overlap.

```systemverilog file=tb_p18_mem_blocks.sv
module tb_p18_mem_blocks;

  class alloc_gen;
    rand bit [9:0] base[4];        // start address of each block
    rand bit [7:0] blen[4];        // length of each block

    constraint len_c   { foreach (blen[i]) blen[i] inside {[16:128]}; }
    constraint align_c { foreach (base[i]) base[i][3:0] == 4'h0; }
    constraint fit_c   { foreach (base[i]) int'(base[i]) + int'(blen[i]) <= 1024; }
    constraint order_c {
      foreach (base[i])
        if (i > 0) int'(base[i]) >= int'(base[i-1]) + int'(blen[i-1]);
    }
  endclass

  alloc_gen g;
  int       errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 4; i++) begin
        if (g.blen[i] < 16 || g.blen[i] > 128) errors++;
        if (g.base[i] % 16 != 0)               errors++;
        if (g.base[i] + g.blen[i] > 1024)      errors++;
        for (int j = i + 1; j < 4; j++)        // overlap test for every pair
          if (g.base[i] < g.base[j] + g.blen[j] && g.base[j] < g.base[i] + g.blen[i])
            errors++;
      end
    end
    $display("p18: sample base=%p blen=%p", g.base, g.blen);
    $display("p18: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample allocation with increasing base addresses, then exactly `p18: errors=0`.

**Explanation.** Requiring "no two blocks overlap" for every pair needs a pairwise constraint. A simpler and cheaper approach is to **order** the blocks: block `i` must start at or after the end of block `i - 1`. Ordered blocks cannot overlap. If the blocks must appear in random order, shuffle the two arrays consistently in `post_randomize()`.

**The width trap in this problem.** Without the casts, the ordering constraint would be `base[i] >= base[i-1] + blen[i-1]`. The widest operand is 10 bits, so the addition is done in 10 bits. A block that ends exactly at 1024 (for example base 1008, length 16) gives 1024, which wraps to 0 in 10 bits. The constraint then reads `base[i] >= 0`, which is always true, and the next block can be placed anywhere, including on top of earlier blocks. The casts to `int` make the arithmetic 32 bits wide. This is a realistic example of a constraint that passes most runs and fails rarely.

## Problem 19: A matrix with unique rows and unique columns

**Problem.** Fill a 4 × 4 matrix with the values 1 to 4 so that no value repeats in any row or in any column (a Latin square).

```systemverilog file=tb_p19_latin_square.sv
module tb_p19_latin_square;

  class latin_gen;
    rand bit [2:0] m[4][4];

    constraint range_c { foreach (m[i, j]) m[i][j] inside {[1:4]}; }
    constraint uniq_c {
      foreach (m[i, j])
        foreach (m[r, c]) {
          (r == i && c > j) -> m[i][j] != m[r][c];     // same row, later column
          (c == j && r > i) -> m[i][j] != m[r][c];     // same column, later row
        }
    }
  endclass

  latin_gen g;
  int       errors;

  initial begin
    g = new();
    repeat (50) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) begin
          if (g.m[i][j] < 1 || g.m[i][j] > 4) errors++;
          for (int k = j + 1; k < 4; k++) if (g.m[i][j] == g.m[i][k]) errors++;
          for (int k = i + 1; k < 4; k++) if (g.m[i][j] == g.m[k][j]) errors++;
        end
    end
    foreach (g.m[i]) $display("p19: sample row %0d = %p", i, g.m[i]);
    $display("p19: errors=%0d", errors);
  end

endmodule
```

**What to expect.** Four sample rows, each a permutation of 1 to 4, with no repeats down any column. Then exactly `p19: errors=0`.

**Explanation.** The outer `foreach` picks an element `m[i][j]`; the inner `foreach` picks a second element `m[r][c]`. Two implications select the pairs that matter: same row with a later column, and same column with a later row. Since all four loop variables are constants after unrolling, the guards are resolved at that time and only the relevant inequalities remain (24 for rows and 24 for columns).

**Simpler form for the rows.** Where the tool accepts array slices in `unique`, `foreach (m[i]) unique {m[i]};` handles the rows. Columns still need the explicit form, because a column is not a slice of the array.

**Follow-ups.** "All sixteen elements different": `unique {m};` with a wide enough element type. "Zero on the main diagonal": `foreach (m[i, j]) (i == j) -> m[i][j] == 0;`. "Symmetric matrix": `foreach (m[i, j]) m[i][j] == m[j][i];`.

## Problem 20: ALU stimulus with a controlled overflow rate

**Problem.** For the course ALU, generate only additions and subtractions. About 80 percent of the transactions must produce a carry (for `ALU_ADD`, `a + b > 255`) or a borrow (for `ALU_SUB`, `a < b`). This example needs `alu_pkg.sv` from Module 1.

```systemverilog file=tb_p20_alu_overflow.sv
module tb_p20_alu_overflow;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    rand bit       ovf;                      // helper: does this transaction overflow?

    constraint op_c       { op inside {ALU_ADD, ALU_SUB}; }
    constraint ovf_dist_c { ovf dist {1 := 80, 0 := 20}; }
    constraint ovf_c {
      if (op == ALU_ADD) ovf == (a + b > 255);
      else               ovf == (a < b);
    }
    constraint order_c    { solve op, ovf before a, b; }
  endclass

  alu_txn txn;
  int     errors, n_ovf;
  bit     really;

  initial begin
    txn = new();
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (!(txn.op inside {ALU_ADD, ALU_SUB})) errors++;
      really = (txn.op == ALU_ADD) ? (int'(txn.a) + int'(txn.b) > 255) : (txn.a < txn.b);
      if (really != txn.ovf) errors++;
      if (really) n_ovf++;
    end
    $display("p20: carry/borrow in %0d of 1000", n_ovf);
    $display("p20: errors=%0d", errors);
  end

endmodule
```

**What to expect.** The first line reports a count near 800; the exact ratio can deviate somewhat between simulators because the `dist` variable also takes part in other constraints. The second line is exactly `p20: errors=0`.

**Explanation.**

- `ovf` is a **helper random variable**. It is not driven to the DUT. It gives the "interesting property" of the transaction a name, so that the property can be weighted with a `dist` and sampled in coverage.
- `ovf == (a + b > 255)` is an **equivalence**: `ovf` is 1 exactly when the sum overflows. An implication would not be enough, because it would allow an overflow with `ovf` = 0.
- In `a + b > 255` the literal 255 is 32 bits wide, so the sum is computed in 32 bits and does not wrap.
- `solve op, ovf before a, b` makes sure the operation and the overflow decision are taken first, and the operands are then chosen to fit.

**Verification application.** This is how coverage holes are closed in practice: identify the uncovered condition, give it a helper variable, weight it.

## Problem 21: Eight queens

**Problem.** Place eight queens on a chessboard so that none attacks another.

```systemverilog file=tb_p21_queens.sv
module tb_p21_queens;

  class queens_gen;
    rand bit [2:0] col[8];                 // col[r] = column of the queen in row r

    constraint cols_c { unique {col}; }    // no two queens in the same column
    constraint diag_c {
      foreach (col[i])
        foreach (col[j])
          if (i < j) {
            int'(col[i]) - int'(col[j]) != i - j;     // not on the same diagonal
            int'(col[i]) - int'(col[j]) != j - i;     // not on the same anti-diagonal
          }
    }
  endclass

  queens_gen g;
  int        errors, dc;

  initial begin
    g = new();
    if (!g.randomize()) $fatal(1, "randomize failed");
    for (int i = 0; i < 8; i++)
      for (int j = i + 1; j < 8; j++) begin
        dc = int'(g.col[i]) - int'(g.col[j]);
        if (dc == 0 || dc == i - j || dc == j - i) errors++;
      end
    foreach (g.col[r]) begin
      for (int c = 0; c < 8; c++) $write("%s", (g.col[r] == c) ? " Q" : " .");
      $write("\n");
    end
    $display("p21: errors=%0d", errors);
  end

endmodule
```

**What to expect.** An 8 × 8 board with one `Q` in every row and every column and no two on a common diagonal (one of the 92 solutions; which one depends on the seed), then exactly `p21: errors=0`.

**Explanation.** The data structure does half the work. Using one array element per row, holding that row's column, makes "one queen per row" true by construction. `unique {col}` gives one queen per column. Two queens in rows `i` and `j` are on a common diagonal when the column difference equals the row difference, in either direction.

**The sign trap.** `col[i] - col[j]` with 3-bit unsigned elements would be computed as an unsigned value, and a "negative" difference would wrap to a large positive number that never equals `i - j`. Casting each element to `int` first makes the subtraction signed. Whenever a constraint needs a difference that can be negative, cast to a signed type.

## Problem 22: A push/pop sequence that never overflows or underflows a FIFO

**Problem.** Generate a sequence of 20 operations, each a push or a pop, for a FIFO of depth 4 that starts empty. The sequence must never pop from an empty FIFO and never push into a full one.

```systemverilog file=tb_p22_fifo_ops.sv
module tb_p22_fifo_ops;

  class fifo_seq;
    localparam int N     = 20;
    localparam int DEPTH = 4;

    rand bit push[N];                      // 1 = push, 0 = pop
    rand int level[N + 1];                 // helper: fill level before each operation

    constraint start_c { level[0] == 0; }
    constraint step_c  {
      foreach (push[i]) level[i + 1] == level[i] + (push[i] ? 1 : -1);
    }
    constraint bound_c { foreach (level[i]) level[i] inside {[0:DEPTH]}; }
  endclass

  fifo_seq g;
  int      errors, fill;

  initial begin
    g = new();
    repeat (100) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      fill = 0;
      foreach (g.push[i]) begin
        if (g.push[i])  begin if (fill == 4) errors++; fill++; end
        else            begin if (fill == 0) errors++; fill--; end
      end
    end
    $write("p22: sample ops =");
    foreach (g.push[i]) $write(" %s", g.push[i] ? "PU" : "po");
    $write("\n");
    $display("p22: errors=%0d", errors);
  end

endmodule
```

**What to expect.** A sample sequence that always begins with a push (the FIFO starts empty), then exactly `p22: errors=0`.

**Explanation.** Whether operation `i` is legal depends on everything that happened before it, that is, on a **running state**. Constraints have no loops with memory, so the state is made explicit as a helper array: `level[i]` is the fill level before operation `i`. One constraint links consecutive levels through the operation, and one keeps every level within 0 to 4. The solver then chooses all twenty operations **together**, so every legal sequence can be generated, including ones that fill the FIFO completely and drain it again.

Compare this with the procedural alternative: choose each operation in a loop, looking at the current level. That works, but it is a greedy, one-step-at-a-time choice. With the constraint formulation you can add global requirements that a loop cannot guarantee, for example "the FIFO must be full at least twice" (`level.sum() with (int'(item == DEPTH)) >= 2`) or "the sequence ends with an empty FIFO" (`level[N] == 0`).

**Verification application.** This is the pattern behind scenario generation for any stateful protocol: credits, outstanding transaction counts, buffer occupancy. Model the state as a helper array, constrain the transitions, bound the state.

## What the problems have in common

| Technique | Problems |
|---|---|
| Translate the requirement into a property of **index and neighbours** | 6, 7, 9, 11, 14 |
| Use **bit-level** operators instead of arithmetic | 1, 2, 3, 4, 15, 16 |
| Count with `sum() with (int'(...))` | 8, 13 |
| Introduce a **helper random variable** | 3, 4, 20, 22 |
| Keep **history in a state variable**, update it in `post_randomize()` | 10 |
| Control the **distribution** with `solve before` or `dist` | 12, 20 |
| Choose the **data structure** so that part of the requirement holds by construction | 18, 21 |
| Guard against **width and sign** effects | 8, 13, 18, 21 |
| Always write an independent **checker** | all |
