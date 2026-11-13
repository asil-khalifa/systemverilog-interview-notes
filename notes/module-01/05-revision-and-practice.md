# Part 5: Module 1 Revision and Practice

## 5.1 Revision Summary

### The data types on one page

| Type | Bits | States | Signed | Default | One-line use |
|---|---|---|---|---|---|
| `bit` | 1 or `[N-1:0]` | 2 | No | 0 | Testbench variables and `rand` fields |
| `logic` (`reg`) | 1 or `[N-1:0]` | 4 | No | X | RTL and DUT-facing signals |
| `byte` | 8 | 2 | Yes | 0 | Characters, C `char` |
| `shortint` | 16 | 2 | Yes | 0 | C `short` |
| `int` | 32 | 2 | Yes | 0 | Counters, indices, loop variables |
| `longint` | 64 | 2 | Yes | 0 | Large counts, C `long long` |
| `integer` | 32 | 4 | Yes | X | Legacy Verilog |
| `time` | 64 | 4 | No | X | Integer timestamps |
| `real` / `realtime` | 64 | n/a | n/a | 0.0 | Fractional numbers, fractional time |
| `shortreal` | 32 | n/a | n/a | 0.0 | C `float` |
| `string` | dynamic | n/a | n/a | `""` | Text |
| `wire` (net) | 1 or `[N-1:0]` | 4 | No | Z | Multi-driver connections |
| `enum` | base type | base type | base type | Default of base | Named values |
| Class handle | n/a | n/a | n/a | `null` | Reference to an object |

### Rules to remember

**States**

- Four-state: `logic`, `reg`, `integer`, `time`, nets. Two-state: `bit`, `byte`, `shortint`, `int`, `longint`.
- Four-state → two-state: X and Z become 0, silently.
- Four-state costs twice the memory. Use it wherever the DUT is involved; use two-state inside the testbench.

**Nets and variables**

- Net or variable is the *kind*; `logic`, `bit`, `int` is the *data type*.
- Variable: any number of procedural assignments, **or** one continuous assignment, **or** one output-port connection. Never multiple drivers.
- Net: continuous assignments and port connections only; multiple drivers are resolved; conflict gives X; no driver gives Z.
- `reg` and `logic` are the same type. Use `logic` everywhere except for multi-driver or `inout` signals, which need `wire`.

**Signedness**

- An expression is signed only if all operands are signed.
- Sign extension is decided by the right-hand side, not the left-hand side.
- Part-selects, bit-selects and concatenations are unsigned.
- `>>>` is arithmetic only when the left operand is signed.
- `5` is signed; `'d5` and `4'b0101` are unsigned; `4'sb0101` is signed.

**Real numbers**

- Real → integer conversion **rounds** (`int'(2.5)` = 3). `$rtoi` truncates.
- `7 / 2` is 3 even when assigned to a `real`. Write `7.0 / 2`.
- `$time` rounds to a whole time unit; `$realtime` keeps the fraction.

**Packed and unpacked**

- Packed dimensions before the name (one vector); unpacked dimensions after the name (separate elements).
- Access order: unpacked indices first, then packed indices.
- `{}` builds a packed vector; `'{}` assigns per element or per member.
- Packed struct: first member is in the MSBs. Packed union: all members the same width, sharing the same bits.

**Enum**

- Default base type `int`; default values 0, 1, 2...
- Default value of the variable is that of the base type, which may not be a member.
- Integer → enum requires a cast: `type'()` is unchecked, `$cast` is checked.
- Methods: `first`, `last`, `next`, `prev`, `num`, `name`.

**Casting**

- Static `type'(expr)`: compile time, no check. Dynamic `$cast(dst, src)`: run time, checked.
- `$cast` as a function returns 0/1 silently; as a task it raises a run-time error on failure.

**X and Z**

- `if (X)` takes the `else` branch. `X ? a : b` merges `a` and `b`. `case` needs an exact match.
- Arithmetic or relational operators with any X bit give X.
- 0 controls AND, 1 controls OR: `0 & X` = 0, `1 | X` = 1.
- Detect with `$isunknown()` or `===`.

**Operators**

- Logical (`&&`, `||`, `!`): 1-bit result, short-circuit. Bitwise (`&`, `|`, `~`): vector result.
- Reduction: unary, one vector in, one bit out. `^v` is parity.
- Precedence: `==` binds tighter than `&`; `+` binds tighter than `<<`.
- Width: operands are extended to the widest of all operands and the left-hand side before the operation. A carry is lost if nothing in the expression is wide enough.

**Equality**

| Operator | X/Z handling | Result | Use |
|---|---|---|---|
| `==` `!=` | Unknown → X | 0, 1, X | RTL, two-state data |
| `===` `!==` | Literal match | 0, 1 | Scoreboards and checkers |
| `==?` `!=?` | X/Z on the right are wildcards | 0, 1, X | Pattern matching |

### Synthesizable or simulation-only

| Synthesizable | Simulation-only |
|---|---|
| `logic`, `bit`, `wire`, packed arrays, fixed unpacked arrays | `real`, `shortreal`, `realtime`, `time`, `string` |
| `enum`, `typedef`, packed and unpacked `struct`, packed `union` | Dynamic arrays, queues, associative arrays, classes |
| Static casts, `==`, `!=`, `==?` with a constant pattern | `$cast`, `===`, `!==`, `$isunknown` |
| All bitwise, reduction, logical, arithmetic and shift operators (constant shifts are free) | `#delay`, `initial`, `$display`, `$time`, `$realtime` |

## 5.2 Interview Questions and Answers

The questions inside each section of Parts 1 to 4 cover the direct "what is" questions. The questions below are additional, grouped by difficulty, and include the scenario-style questions that are used to separate candidates.

### Basic level

**Q1. How many values can one bit of a `logic` hold? Name them.**
Four: 0, 1, X (unknown) and Z (high impedance).

**Q2. Which data type would you choose for a 16-bit address field in a transaction class, and why?**
`rand bit [15:0] addr;`. It is two-state (random values are never X or Z, and two-state is faster), unsigned, and exactly the required width.

**Q3. What is the difference between `logic [7:0] a` and `byte a`?**
`logic [7:0]` is four-state, unsigned, default X. `byte` is two-state, signed, default 0.

**Q4. What is `$bits()`?**
A system function that returns the number of bits occupied by an expression or a data type, for example `$bits(int)` is 32 and `$bits(hdr_t)` is the total width of the packed struct.

**Q5. What is the difference between `$bits` and `$size`?**
`$bits` returns the total number of bits. `$size` returns the number of elements in a given dimension of an array (the first dimension by default).

**Q6. What is the default value of `integer`? Of `int`?**
X and 0.

**Q7. What is the `string` data type and how does it differ from a Verilog string?**
`string` is a built-in dynamic type: its length grows and shrinks automatically, its default is the empty string, and it has methods such as `len()`, `substr()`, `toupper()`, `atoi()` and `itoa()`. In Verilog a string had to be stored in a fixed-width `reg` vector, 8 bits per character, padded with zeros.

**Q8. Write the declaration of a 2-state, signed, 12-bit variable.**
`bit signed [11:0] x;`

**Q9. What is the difference between `'0`, `'1`, `'x` and `'z`?**
They are unsized fill literals that set every bit of the target to 0, 1, X or Z respectively, whatever the target's width.

**Q10. What does `4'b1010 & 4'b0110` give? And `4'b1010 && 4'b0110`?**
`4'b0010` and `1'b1`.

**Q11. What does `%0d` mean in `$display`?**
Print in decimal using the minimum number of characters (no leading spaces). `%d` alone pads to the widest possible value of the type.

**Q12. What is the difference between `struct` and an array?**
An array holds many elements of the same type accessed by index. A struct holds members of different types accessed by name.

**Q13. Can a `wire` be assigned inside an `initial` block?**
No. Nets cannot be assigned procedurally. Declare the signal as `logic`, or drive the net through a variable and a continuous assignment.

**Q14. What is the difference between `$display` and `$monitor`?**
`$display` prints once, immediately, when it is executed. `$monitor` is called once and then prints automatically at the end of any time step in which one of its arguments changed. (`$strobe` prints once, at the end of the current time step, showing final values.)

**Q15. What are the methods available on an enum?**
`first()`, `last()`, `next()`, `prev()`, `num()`, `name()`.

### Intermediate level

**Q16. `bit [7:0] a = 8'hFF;` What do `$display("%0d", a + 1);` and `$display("%0d", a + 1'b1);` print?**
256 and 0. A `$display` argument is self-determined, so the width is the widest operand. In `a + 1` the literal `1` is 32 bits wide, so the addition is done in 32 bits: 256. In `a + 1'b1` the widest operand is 8 bits, so the sum wraps to 0.

**Q17. Why do interface signals use `logic` and not `bit`?**
Interface signals connect to the DUT. If the DUT drives X or Z (uninitialised output, missing reset, bus not driven), a `bit` would convert it to 0 and hide the problem. `logic` preserves it so that monitors, assertions and the scoreboard can detect it.

**Q18. When must a signal in an interface be a `wire` instead of `logic`?**
When it has more than one driver: a bidirectional pin (`inout`) or a bus driven by both the DUT and the testbench at different times. The testbench then drives it through a `logic` variable and a tri-state continuous assignment.

**Q19. If a `rand logic [7:0] data;` is randomized, can it get X or Z?**
No. The constraint solver generates only two-state values, so a four-state `rand` variable always receives 0s and 1s. Using `bit` for random fields is therefore the normal choice.

**Q20. What is the difference between a packed struct and a packed array?**
Both are single contiguous vectors. A packed array subdivides the vector into equal-sized elements accessed by index. A packed struct subdivides it into fields of possibly different sizes accessed by name.

**Q21. How do you convert an unpacked struct into a bit vector?**
With a bit-stream cast to a vector type of the same total size (`u32_t'(s)`), or with the streaming operator (`v = {>>{s}};`). The first member ends up in the most significant bits.

**Q22. `logic [7:0] a = 8'b1000_0001;` What are `a >> 1`, `a >>> 1` and `$signed(a) >>> 1`?**
`0100_0000`, `0100_0000` (because `a` is unsigned) and `1100_0000`.

**Q23. What is the difference between `casez`, `casex` and `case inside`?**
`casez` treats Z and `?` as don't-care in both the selector and the items. `casex` treats X and Z as don't-care in both, which can mask real X problems in the selector and is therefore discouraged in RTL. `case ... inside` treats X/Z/`?` as don't-care in the items only and can also match ranges; it is the recommended form.

**Q24. Can you write `if (a = b)` in SystemVerilog?**
No. Unlike C, an assignment inside a condition is not allowed unless it is enclosed in an extra pair of parentheses: `if ((a = b))`. This rule prevents the classic `=` versus `==` typing error.

**Q25. Two files each contain `typedef enum {IDLE, BUSY} state_e;`. Are the two types compatible?**
No. Each declaration creates a distinct type, even though the text is identical. A variable of one cannot be assigned to a variable of the other without a cast. The type should be declared once in a package and imported.

**Q26. What is the result of `{4'b1010, 2'b11}` and `{3{2'b01}}`?**
`6'b101011` and `6'b010101`.

**Q27. Why is `{a, 1}` an error?**
The literal `1` is unsized, and every operand of a concatenation must have a definite width. Write `{a, 1'b1}`.

**Q28. How would you check, in one expression, that a 4-bit vector has exactly one bit set?**
`$onehot(v)`. Without the system function: `(v != 0) && ((v & (v - 1)) == 0)`.

**Q29. What is the size of `logic [3:0] a [2][3]` in bits, and how do you select one bit?**
2 × 3 × 4 = 24 bits. One bit is `a[i][j][k]`: the two unpacked indices first, then the packed index.

**Q30. What is the difference between `integer i = 3.5;` and `integer i = $rtoi(3.5);`?**
The first rounds to 4. The second truncates to 3.

### Advanced and scenario-based

**Q31. A test passes in RTL simulation but the same test fails in gate-level simulation with X on the outputs. What are the likely causes?**
(1) A flip-flop without reset: RTL simulation hid the X through X-optimism (an `if` or `case` took a definite branch), while the gate netlist propagates it. (2) The RTL or testbench used two-state types that turned X into 0. (3) The testbench compared with `==`/`!=`, so X never caused a failure in RTL simulation. (4) In gate-level simulation with timing, setup or hold violations can also generate X. The first step is to trace the X backwards in the waveform to the first register that is X after reset.

**Q32. The scoreboard reports zero errors, but the waveform clearly shows X on the DUT output during the test. What is wrong with the testbench?**
Either the comparison uses `!=`, which evaluates to X and is treated as false, or the monitor stores the sampled value in a two-state variable, converting X to 0. Fix: sample into `logic`, compare with `!==`, and add an explicit `$isunknown` check or assertion.

**Q33. The scoreboard reports mismatches only when the operands have the MSB set. Where do you look first?**
Signedness. The reference model and the DUT are interpreting the operands differently: one is sign-extending and the other zero-extending, or a signed operation (comparison, multiplication, arithmetic shift) is modelled with unsigned types, or one unsigned operand has turned a signed expression unsigned.

**Q34. A log shows an enum field printing as an empty name. How can that happen?**
The variable holds a value that is not a member of the enum. Causes: it was never assigned and the default of the base type (0 or X) is not a member; it was assigned through an unchecked static cast; or it came from the DUT with an illegal encoding. `$cast` should be used so that the illegal value is reported.

**Q35. Why is `casex` dangerous?**
It treats X in the *selector* as a wildcard. If the selector goes X because of a bug, `casex` still matches an item (the first one whose non-X bits fit) and the design appears to work. `case inside` or `casez` with `?` avoids this.

**Q36. Explain why `always_comb` is safer than `always @*`.**
`always_comb` runs once at time 0 even if no input changes, so outputs are never left at their initial X because of a missing event. Its sensitivity list includes signals read inside functions it calls. It forbids the variables it writes from being written anywhere else. And tools check that it really describes combinational logic, warning about inferred latches.

**Q37. What is the difference between a signal being X because of "no reset" and being X because of "contention"?**
A missing reset leaves a *variable* (flip-flop) at its initial X until it is first written with a known value. Contention occurs on a *net* with two or more active drivers of opposite values, and lasts as long as the drivers disagree. In the waveform the first is X from time 0; the second appears at the moment both drivers are enabled.

**Q38. `logic [7:0] a, b; logic [15:0] p; p = a * b;` Is the product computed correctly? What about `p = (a * b) >> 4;`?**
Yes in both cases. The left-hand side is 16 bits, so the operands are extended to 16 bits before the multiplication, and the shift's left operand is in the same 16-bit context. The problem arises only when nothing in the context is wide enough, for example `logic [7:0] q = (a * b) >> 4;`, where the product is truncated to 8 bits before shifting.

**Q39. How can the same module port be both a net and carry an enum or struct type?**
Kind and data type are independent. `input alu_op_e op` declares a net (the default kind for inputs) whose data type is the enum. Written out in full it is `input wire alu_op_e op`.

**Q40. What is `uwire` and why would a methodology require it?**
An unresolved net that permits only one driver. A second driver is a compile or elaboration error. It gives nets the same single-driver safety that variables have, catching accidental shorts at compile time.

**Q41. Why can a variable not have multiple drivers while a net can?**
A variable is storage: it holds whatever was last written, so "two simultaneous sources" has no defined meaning. A net is a connection with a resolution function that combines the strength and value of every driver into one value, which is how real wires with several drivers behave.

**Q42. Your DUT has a 9-bit `result`. Your reference model computes `int exp = a - b;` with `bit [7:0] a = 5, b = 10`. The DUT gives `9'h1FB`. Does `exp == result` hold?**
No. `a - b` is evaluated in 32 bits (the width of `exp`), unsigned, giving `32'hFFFF_FFFB`, which is -5 as an `int`. The DUT result `1FB` is 507. The model must be truncated to the DUT width: `bit [8:0] exp = a - b;` gives `1FB`.

## 5.3 Output-Prediction Questions

Work out the output on paper first. Then check the answer, and then run the code.

**P1.**

```systemverilog
module p1;
  logic [3:0] a;
  bit   [3:0] b;
  integer     i;
  int         j;
  initial begin
    a = 4'b1z0x;
    b = a;  i = a;  j = a;
    $display("%b %b %b %0d", a, b, i[3:0], j);
  end
endmodule
```

Answer: `1z0x 1000 1z0x 8`. `b` and `j` are two-state, so Z and X become 0 (`1000` = 8). `i` is four-state and keeps them.

**P2.**

```systemverilog
module p2;
  byte      a = 8'h80;
  bit [7:0] b = 8'h80;
  int       x, y;
  initial begin
    x = a;  y = b;
    $display("%0d %0d %b", x, y, a < b);
  end
endmodule
```

Answer: `-128 128 0`. `a` is signed and is sign-extended; `b` is unsigned and is zero-extended. The comparison mixes signed and unsigned, so it is unsigned: 128 < 128 is false.

**P3.**

```systemverilog
module p3;
  bit [3:0] a = 4'd12, b = 4'd7;
  bit [3:0] s4;
  bit [4:0] s5;
  initial begin
    s4 = a + b;
    s5 = a + b;
    $display("%0d %0d %0d", s4, s5, a + b);
  end
endmodule
```

Answer: `3 19 3`. 12 + 7 = 19. In 4 bits it wraps to 3. With a 5-bit destination the operands are extended first and the carry is kept. Inside `$display` the expression is self-determined at 4 bits.

**P4.**

```systemverilog
module p4;
  typedef enum {A = 3, B, C = 10, D} e_t;
  e_t e;
  initial begin
    $display("%0d %0d '%s'", e, D, e.name());
    e = e.first();
    e = e.prev();
    $display("%s %0d", e.name(), e.num());
  end
endmodule
```

Answer: `0 11 ''` then `D 4`. The default is 0 (base type `int`), which is not a member, so the name is empty. `D` follows `C` = 10, so it is 11. `prev()` from the first member wraps to the last.

**P5.**

```systemverilog
module p5;
  logic [2:0] a = 3'b1x0;
  initial begin
    $display("%b %b %b %b", a == 3'b1x0, a === 3'b1x0, a ==? 3'b1x0, a ==? 3'b100);
    if (a != 3'b111) $display("different");
    else             $display("same or unknown");
  end
endmodule
```

Answer: `x 1 1 x` then `different`. `==` with X is X. `===` matches exactly. `==?` with X on the right masks bit 1, so the rest match. `==?` with no wildcard on the right compares the left X: X. In the last line bit 0 is 0 versus 1, a definite difference, so `!=` is 1 even though `a` contains an X.

**P6.**

```systemverilog
module p6;
  typedef struct packed { bit [3:0] hi; bit [3:0] lo; } s_t;
  s_t s = 8'h3C;
  initial begin
    s.hi = s.lo;
    s    = s + 1;
    $display("%h %h %b", s, s.hi, s[0]);
  end
endmodule
```

Answer: `cd c 1`. `3C` → `hi` = 3, `lo` = C. After the copy: `CC`. A packed struct supports arithmetic: `CD`. Bit 0 of `CD` is 1.

**P7.**

```systemverilog
module p7;
  bit [3:0] a = 4'b0110;
  initial $display("%b %b %b %b %0d", !a, ~a, &a, ^a, a >> 1 + 1);
endmodule
```

Answer: `0 1001 0 0 1`. `a` is non-zero so `!a` is 0. `~a` inverts the bits. Not all ones, so `&a` is 0. Two ones (even), so `^a` is 0. `+` binds tighter than `>>`, so the shift is by 2: `0001`.

**P8.**

```systemverilog
module p8;
  int  i;
  real r;
  initial begin
    i = 7 / 2;    r = 7 / 2;    $display("%0d %0.1f", i, r);
    i = 7 / 2.0;  r = 7 / 2.0;  $display("%0d %0.1f", i, r);
    $display("%0d %0d %0d", -7 / 2, $rtoi(-3.5), int'(-3.5));
  end
endmodule
```

Answer: `3 3.0`, then `4 3.5`, then `-3 -3 -4`. Integer division truncates toward zero. 3.5 assigned to an `int` rounds away from zero to 4. `$rtoi` truncates; the cast rounds.

**P9.**

```systemverilog
module p9;
  logic       c;
  logic [1:0] y;
  initial begin
    if (c)       y = 2'b01;
    else if (!c) y = 2'b10;
    else         y = 2'b11;
    $display("%b", y);
  end
endmodule
```

Answer: `11`. `c` is X. `if (c)` is false. `!c` is also X, so the second condition is false too. The final `else` executes. With X, a condition and its negation can both be "not true".

**P10.**

```systemverilog
module p10;
  logic signed [7:0] s = -16;
  logic        [7:0] u = 8'hF0;
  initial $display("%0d %0d %0d %0d", s >>> 2, s >> 2, u >>> 2, $signed(u) >>> 2);
endmodule
```

Answer: `-4 60 60 -4`. `s` and `u` hold the same bits `1111_0000`. `>>>` on the signed operand keeps the sign (`1111_1100`). `>>` always shifts in zeros (`0011_1100` = 60). `>>>` on the unsigned operand also shifts in zeros. Converting `u` to signed first makes the shift arithmetic.

## 5.4 Find-the-Error and Debugging Questions

### Compile-time errors

For each fragment, find the error and fix it.

**E1.**

```systemverilog
logic [7:0] d;
assign d = a;
always_comb d = b;
```

A variable is driven by both a continuous assignment and a procedural block. Use one driver, or select between `a` and `b` inside one `always_comb`.

**E2.**

```systemverilog
wire w;
initial w = 1'b1;
```

Procedural assignment to a net. Declare `logic w;`, or use `assign w = 1'b1;`.

**E3.**

```systemverilog
typedef enum {IDLE, RUN} st_e;
st_e s;
initial s = 1;
```

An integer cannot be assigned to an enum without a cast. Write `s = RUN;`, or `$cast(s, 1);`, or `s = st_e'(1);`.

**E4.**

```systemverilog
typedef union packed {
  logic [7:0]  b;
  logic [15:0] w;
} u_t;
```

Members of a packed union must be the same width. Make `b` 16 bits wide, for example with `struct packed { logic [7:0] pad; logic [7:0] b; } bs;`.

**E5.**

```systemverilog
typedef struct packed {
  int    id;
  string name;
} s_t;
```

`string` is not a packed type and cannot be a member of a packed struct. Remove `packed`.

**E6.**

```systemverilog
byte [3:0] word;
```

A type with a predefined width cannot take a packed dimension. Write `bit [3:0][7:0] word;` or `byte word [4];`.

**E7.**

```systemverilog
int arr [4] = '{1, 2, 3};
```

The assignment pattern has three values for four elements. Supply four values, or use index keys with a default: `'{0: 1, 1: 2, 2: 3, default: 0}`. Positional values and `default:` cannot be mixed in one pattern.

**E8.**

```systemverilog
real r = 2.5;
logic [1:0] v = r[1:0];
```

Bit-selects and part-selects are not allowed on a real. Convert first: `int t = int'(r);` then `v = t[1:0];`, or use `$realtobits`.

**E9.**

```systemverilog
typedef enum bit [1:0] {A = 1, B, C, D} e_t;
```

`D` would be 4, which does not fit in two bits. Widen the base type or start from 0.

**E10.**

```systemverilog
logic [7:0] a;
logic [8:0] r;
assign r = {a, 1};
```

An unsized literal inside a concatenation. Write `{a, 1'b1}`.

### Run-time bugs (the code compiles)

Find why each fragment misbehaves.

**D1.**

```systemverilog
if (dut_result != expected) $error("mismatch");
```

If `dut_result` contains X, the condition is X and nothing is reported. Use `!==`.

**D2.**

```systemverilog
for (bit [2:0] i = 0; i < 8; i++) mem[i] = 0;
```

Infinite loop. A 3-bit variable is always less than 8; after 7 it wraps to 0. Declare `int i`.

**D3.**

```systemverilog
for (st = st.first(); st <= st.last(); st = st.next()) $display("%s", st.name());
```

Infinite loop. After the last member, `next()` wraps to the first. Use a `do`...`while (st != st.first())` loop or count `num()` iterations.

**D4.**

```systemverilog
logic [7:0] a, b, avg;
assign avg = (a + b) / 2;
```

The sum is computed in 8 bits and the carry is lost before the division. Use `({1'b0, a} + b) / 2` or declare a 9-bit intermediate.

**D5.**

```systemverilog
if (valid == 1'bx) $error("valid is unknown");
```

Never true: `==` against X yields X. Use `if ($isunknown(valid))` or `=== 1'bx`.

**D6.**

```systemverilog
bit [7:0] sampled;
always @(posedge clk) sampled = vif.data;      // monitor
```

X or Z on the DUT bus is converted to 0 by the two-state variable, hiding the problem from the scoreboard. Declare `sampled` as `logic [7:0]`.

**D7.**

```systemverilog
real ratio;
int  pass = 45, total = 60;
initial begin
  ratio = pass / total * 100;
  $display("pass rate %0.1f%%", ratio);
end
```

Prints 0.0. `pass / total` is an integer division (0). Write `ratio = 100.0 * pass / total;`.

**D8.**

```systemverilog
logic signed [7:0] offset;
logic        [7:0] base;
logic signed [8:0] sum;
assign sum = base + offset;
```

`base` is unsigned, so the whole expression is unsigned and `offset` is zero-extended instead of sign-extended. A negative offset is added as a large positive number. Fix: `assign sum = $signed({1'b0, base}) + offset;`.

## 5.5 Coding Exercises with Solutions

Try each exercise before reading the solution. The solutions are also in the `examples/module-01/` folder.

### Exercise 1: count the ones

Count the number of 1 bits in an 8-bit value without using `$countones`, then verify against `$countones`.

```systemverilog file=ex01_count_ones.sv
module ex01_count_ones;

  bit [7:0] data = 8'b1011_0010;
  int       count;

  initial begin
    count = 0;
    for (int i = 0; i < $bits(data); i++)
      count += data[i];
    $display("%b has %0d ones ($countones says %0d)", data, count, $countones(data));
  end

endmodule
```

```output
10110010 has 4 ones ($countones says 4)
```

`$bits(data)` makes the loop independent of the width. Each bit is 0 or 1, so adding it to the count counts the ones.

### Exercise 2: parity generation and checking

For an 8-bit data value, generate the even-parity bit, build the 9-bit transmitted word, and show that a single-bit error is detected.

```systemverilog file=ex02_parity.sv
module ex02_parity;

  bit [7:0] data = 8'hA7;
  bit       even_par, odd_par;
  bit [8:0] tx;

  initial begin
    even_par = ^data;        // makes the total number of ones even
    odd_par  = ~^data;       // makes the total number of ones odd
    $display("data=%h  even_parity=%b  odd_parity=%b", data, even_par, odd_par);

    tx = {even_par, data};
    $display("no error    : parity check = %b", ^tx);

    tx[2] = ~tx[2];          // inject a single-bit error
    $display("1-bit error : parity check = %b", ^tx);
  end

endmodule
```

```output
data=a7  even_parity=1  odd_parity=0
no error    : parity check = 0
1-bit error : parity check = 1
```

`A7` is `1010_0111`, which has five ones. The reduction XOR is 1, so the even-parity bit is 1 and the nine transmitted bits contain six ones. The receiver XORs all nine bits: 0 means no error. Flipping any one bit makes the check 1.

### Exercise 3: decode an instruction with a packed struct

A 32-bit instruction has the format `{opcode[5:0], rd[4:0], rs1[4:0], rs2[4:0], imm[10:0]}`. Decode `32'hA871_4155` without writing any part-select.

```systemverilog file=ex03_instruction.sv
module ex03_instruction;

  typedef struct packed {
    logic [5:0]  opcode;    // bits [31:26]
    logic [4:0]  rd;        // bits [25:21]
    logic [4:0]  rs1;       // bits [20:16]
    logic [4:0]  rs2;       // bits [15:11]
    logic [10:0] imm;       // bits [10:0]
  } instr_t;

  instr_t      instr;
  logic [31:0] raw = 32'hA871_4155;

  initial begin
    instr = raw;            // vector to packed struct: no cast needed
    $display("opcode=%h rd=%0d rs1=%0d rs2=%0d imm=%h",
             instr.opcode, instr.rd, instr.rs1, instr.rs2, instr.imm);
    instr.rd = 5'd31;
    $display("after changing rd: %h   ($bits = %0d)", instr, $bits(instr_t));
  end

endmodule
```

```output
opcode=2a rd=3 rs1=17 rs2=8 imm=155
after changing rd: abf14155   ($bits = 32)
```

In binary the word is `101010_00011_10001_01000_00101010101`. The struct lays the fields out in declaration order from the MSB, so each named field picks up the right bits. Setting `rd` to `11111` changes bits 25 to 21, giving `ABF1_4155`.

### Exercise 4: byte-swap a word in three ways

Convert `32'h1122_3344` to `32'h4433_2211`.

```systemverilog file=ex04_byte_swap.sv
module ex04_byte_swap;

  logic [31:0]     w = 32'h1122_3344;
  logic [31:0]     r1, r2;
  logic [3:0][7:0] v, r3;

  initial begin
    // 1. concatenation of part-selects
    r1 = {w[7:0], w[15:8], w[23:16], w[31:24]};

    // 2. streaming operator, 8 bits at a time, right to left
    r2 = {<<8{w}};

    // 3. packed array of bytes and a loop
    v = w;
    for (int i = 0; i < 4; i++) r3[i] = v[3 - i];

    $display("%h %h %h", r1, r2, r3);
  end

endmodule
```

```output
44332211 44332211 44332211
```

### Exercise 5: list the members of an enum

Print every member of the ALU opcode enum with its numeric value, using a loop that terminates.

```systemverilog file=ex05_enum_list.sv
module ex05_enum_list;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  alu_op_e op;

  initial begin
    op = op.first();
    for (int i = 0; i < op.num(); i++) begin
      $display("%-8s = %0d (%b)", op.name(), op, op);
      op = op.next();
    end
  end

endmodule
```

```output
ALU_ADD  = 0 (000)
ALU_SUB  = 1 (001)
ALU_AND  = 2 (010)
ALU_OR   = 3 (011)
ALU_XOR  = 4 (100)
ALU_NOT  = 5 (101)
ALU_SHL  = 6 (110)
ALU_SHR  = 7 (111)
```

The loop is controlled by an `int` counter that runs `num()` times, so the wrap-around of `next()` cannot cause an infinite loop.

### Exercise 6: safe conversion of a raw value to an enum

A 3-bit command field arrives from the DUT. Only the encodings 0, 1, 2 and 4 are legal. Convert each possible raw value to the enum and report the illegal ones.

```systemverilog file=ex06_safe_cast.sv
module ex06_safe_cast;

  typedef enum bit [2:0] {NOP = 0, LOAD = 1, STORE = 2, JUMP = 4} cmd_e;

  cmd_e cmd;

  initial begin
    for (int raw = 0; raw < 8; raw++) begin
      if ($cast(cmd, raw)) $display("raw %0d -> %s", raw, cmd.name());
      else                 $display("raw %0d -> ILLEGAL encoding", raw);
    end
  end

endmodule
```

```output
raw 0 -> NOP
raw 1 -> LOAD
raw 2 -> STORE
raw 3 -> ILLEGAL encoding
raw 4 -> JUMP
raw 5 -> ILLEGAL encoding
raw 6 -> ILLEGAL encoding
raw 7 -> ILLEGAL encoding
```

### Exercise 7: a checker that cannot be fooled by X

Write a checking routine for the 9-bit ALU result that reports PASS, reports a value mismatch, and separately reports an unknown output. (Functions are covered in Module 3; here the function is only a convenient wrapper.)

```systemverilog file=ex07_checker.sv
module ex07_checker;

  function automatic void check(string what, logic [8:0] actual, logic [8:0] expected);
    if ($isunknown(actual))
      $display("FAIL %s: output contains X/Z (%b)", what, actual);
    else if (actual !== expected)
      $display("FAIL %s: actual=%0d expected=%0d", what, actual, expected);
    else
      $display("PASS %s: %0d", what, actual);
  endfunction

  initial begin
    check("add", 9'd300,        9'd300);
    check("sub", 9'd5,          9'd6);
    check("xor", 9'bx_0000_1111, 9'd15);
  end

endmodule
```

```output
PASS add: 300
FAIL sub: actual=5 expected=6
FAIL xor: output contains X/Z (x00001111)
```

The arguments are `logic` so that X survives the call. `$isunknown` is tested first to give a precise message, and `!==` is used so that the comparison itself can never evaluate to X.

### Exercise 8: sign-extend a 12-bit immediate to 32 bits

Extend `12'hF85` to 32 bits in three different ways and print its signed value.

```systemverilog file=ex08_sign_extend.sv
module ex08_sign_extend;

  logic        [11:0] imm = 12'hF85;
  logic signed [11:0] imm_s;
  logic        [31:0] e1, e2, e3;
  int                 value;

  initial begin
    e1 = {{20{imm[11]}}, imm};     // 1. replicate the sign bit manually
    e2 = signed'(imm);             // 2. cast: a signed right-hand side is sign-extended
    imm_s = imm;
    e3 = imm_s;                    // 3. copy into a signed variable first
    value = signed'(imm);
    $display("%h %h %h %0d", e1, e2, e3, value);
  end

endmodule
```

```output
ffffff85 ffffff85 ffffff85 -123
```

`F85` has its MSB set. As a 12-bit two's complement number it is 3973 - 4096 = -123. All three methods fill the upper 20 bits with ones.

### Further practice (no solutions given)

1. Declare a packed struct for a 16-bit status register with fields `busy` (1 bit), `error` (1 bit), `reserved` (6 bits) and `count` (8 bits). Assign `16'hC02A` and print each field.
2. Write a packed union that lets a 64-bit value be accessed as one `longint`-sized vector, two 32-bit words, or eight bytes.
3. Using only bitwise operators, write expressions that set bit 5, clear bit 2 and toggle bit 0 of an 8-bit variable.
4. Given `logic [15:0] v`, write one expression for each: "all bits are 1", "exactly one bit is 1", "the number of 1 bits is odd", "v contains X or Z".
5. Predict, then run: `byte a = -1; bit [7:0] b = a; int c = b; int d = a; $display("%0d %0d %0d", b, c, d);`
6. Write a module that prints the truth tables of `==`, `===` and `==?` for all sixteen combinations of two 1-bit four-state values, using nested loops.
7. Add a ninth operation to the ALU package and design (for example `ALU_INC`). Which declarations must change, and what does the compiler tell you if you forget one?

## 5.6 Concepts You Must Understand Before Moving Forward

Do not start Module 2 until you can answer each of these without looking at the notes.

**Types and states**

- [ ] I can list the two-state and four-state types, with width, signedness and default value of each.
- [ ] I can explain what X and Z mean and give three sources of X.
- [ ] I can explain why DUT-facing signals are `logic` and testbench data is `bit`/`int`.
- [ ] I can explain the difference between a net and a variable, and between kind and data type.
- [ ] I can state when `wire` is still required.

**Signed and real**

- [ ] I can predict whether an assignment sign-extends or zero-extends.
- [ ] I can explain why `-1 < 1` can be false.
- [ ] I can explain `>>` versus `>>>`.
- [ ] I know that real-to-integer conversion rounds, and that `7 / 2` is 3.
- [ ] I know the difference between `$time` and `$realtime`.

**Aggregates and user-defined types**

- [ ] I can tell packed from unpacked dimensions and write the index order for a mixed array.
- [ ] I know when to use `{}` and when to use `'{}`.
- [ ] I can draw the bit layout of a packed struct and a packed union.
- [ ] I can explain why assigning 1 to an enum is illegal and give two ways to do it.
- [ ] I can write a loop over all members of an enum that terminates.
- [ ] I can explain what `typedef` does and why shared types belong in a package.

**Casting and operators**

- [ ] I can explain static versus dynamic casting and the two calling forms of `$cast`.
- [ ] I can explain the difference between logical, bitwise and reduction operators.
- [ ] I can explain how expression width is determined and why a carry can be lost.
- [ ] I can explain `==` versus `===` versus `==?` and say which belongs in a scoreboard.
- [ ] I know what `if`, `?:` and `case` do when the condition is X.

## 5.7 What Comes Next

Module 2 covers arrays in depth: static arrays, dynamic arrays, associative arrays and queues, every built-in array method (`size`, `delete`, `push_back`, `find`, `sort`, `sum`, `unique` and the rest), copying and comparison, and all the looping constructs. It builds directly on Sections 3.1 and 3.2 of this module and uses the same ALU-based naming.
