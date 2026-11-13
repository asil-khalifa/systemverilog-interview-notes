# Part 4: Casting, Default Values, Four-State Logic and Operators

## 4.1 Type Casting: Static and Dynamic

### In plain English

Casting means converting a value from one data type to another: a real number to an integer, a wide vector to a narrow one, an unsigned value to a signed one, a plain number to an enum. Sometimes SystemVerilog converts automatically (**implicit** conversion). Sometimes you must ask for it, or you want to make it visible to the reader (**explicit** cast).

There are two kinds of explicit cast:

- A **static cast** is decided at compile time and performs no run-time check. You are telling the compiler "trust me".
- A **dynamic cast**, `$cast`, checks at run time whether the value is legal for the destination type and tells you whether it succeeded.

### Why casting is needed

- SystemVerilog is strongly typed in several places: an integer cannot be assigned to an enum, and a base-class handle cannot be assigned to a derived-class handle, without a cast.
- Implicit conversions can silently truncate, extend or reinterpret a value. An explicit cast documents that the conversion is intended and controls exactly how it happens.
- Linting tools flag implicit width and sign conversions in RTL; casts remove the warnings.

### Implicit conversions (what happens when you do not cast)

| Assignment | What happens automatically |
|---|---|
| Wider → narrower (`logic [3:0] n = 8'hAB;`) | Upper bits are discarded: `n` = `B`. No error |
| Narrower → wider, source unsigned | Zero-extended |
| Narrower → wider, source signed | Sign-extended |
| Four-state → two-state | X and Z become 0 |
| Two-state → four-state | Value kept |
| Real → integer | Rounded to nearest, ties away from zero |
| Integer → real | Converted to the nearest representable real |
| Enum → integer | The value of the enum member |
| Integer → enum | **Not allowed** without a cast |
| String literal → packed vector | 8 bits per character, right-justified |

### Static casting

**Syntax:** `<type>'(<expression>)`. Note the apostrophe between the type and the parenthesis.

| Form | Meaning | Example | Result |
|---|---|---|---|
| `type'(expr)` | Convert to a named type | `int'(2.4)` | 2 |
| `N'(expr)` | Change the width to N bits | `4'(8'hAB)` | `4'hB` |
| `signed'(expr)` | Treat as signed | `signed'(4'b1111)` | -1 |
| `unsigned'(expr)` | Treat as unsigned | `unsigned'(-1)` | 4,294,967,295 |
| `enum_type'(expr)` | Integer to enum, **unchecked** | `state_e'(2)` | `EXEC` |
| `struct_type'(expr)` | Vector to packed struct | `hdr_t'(16'hA5C3)` | Fields filled from the bits |
| `const'(expr)` | Treat as constant | `const'(x)` | Used mainly in assertions |

The type in a static cast must be a simple type name. To cast to something like `logic [7:0]`, either use the size cast `8'(expr)` or define a `typedef` first.

### Dynamic casting with $cast

**Syntax:** `$cast(destination, source)`

`$cast` can be called in two ways, and the difference is a frequent interview question.

| Called as | On success | On failure |
|---|---|---|
| Function: `if ($cast(dst, src)) ...` | Assigns and returns 1 | Returns 0, leaves `dst` unchanged, **no error message** |
| Task: `$cast(dst, src);` | Assigns | **Run-time error**, `dst` unchanged |

`$cast` has two main uses:

1. **Integer → enum**, with a check that the value is a declared member (shown below).
2. **Base-class handle → derived-class handle** (downcasting), with a check that the object really is of the derived type. This is the more important use and is covered in Module 4.

### How it works internally

```text
   Static cast   state = state_e'(raw);
   -----------------------------------
   compile time :  the compiler generates a plain copy (with resize / reinterpretation)
   run time     :  bits are copied. No check. An illegal value is stored silently.

   Dynamic cast  ok = $cast(state, raw);
   -----------------------------------
   compile time :  the compiler checks only that the two types could be compatible
   run time     :  1. evaluate raw
                   2. is the value a member of state_e ?
                        yes -> assign, return 1
                        no  -> do not assign, return 0   (task form: report an error)
```

### Complete example

```systemverilog file=tb_casting.sv
module tb_casting;

  typedef enum bit [1:0] {OP_ADD, OP_SUB, OP_MUL, OP_DIV} op_e;
  typedef enum {RD = 1, WR = 2}                           dir_e;
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } nibbles_t;

  int         i;
  real        r;
  byte        b;
  logic [3:0] n;
  nibbles_t   nb;
  op_e        op;
  dir_e       dir;

  initial begin
    // ---- implicit conversions ----
    r = 3.7;
    i = r;                    $display("1.  i = 3.7              -> %0d", i);
    n = 8'hAB;                $display("2.  4-bit n = 8'hAB      -> %h", n);
    i = n;                    $display("3.  int = n              -> %0d", i);

    // ---- static casts ----
    i  = int'(2.4);           $display("4.  int'(2.4)            -> %0d", i);
    b  = byte'(300);          $display("5.  byte'(300)           -> %0d", b);
    n  = 4'(8'hAB);           $display("6.  4'(8'hAB)            -> %h", n);
    i  = signed'(4'b1111);    $display("7.  signed'(4'b1111)     -> %0d", i);
    nb = nibbles_t'(8'h5C);   $display("8.  nibbles_t'(8'h5C)    -> hi=%h lo=%h", nb.hi, nb.lo);
    op = op_e'(2);            $display("9.  op_e'(2)             -> %s", op.name());
    r  = real'(7) / 2;        $display("10. real'(7) / 2         -> %0.1f", r);

    // ---- dynamic casts ----
    if ($cast(dir, 2))        $display("11. $cast(dir, 2) ok     -> %s", dir.name());
    if (!$cast(dir, 5))       $display("12. $cast(dir, 5) failed -> dir stays %s", dir.name());

    dir = dir_e'(5);          $display("13. dir_e'(5)            -> value %0d, name '%s'",
                                       dir, dir.name());
    // $cast(dir, 7);         // task form: this line would produce a run-time error
  end

endmodule
```

```output
1.  i = 3.7              -> 4
2.  4-bit n = 8'hAB      -> b
3.  int = n              -> 11
4.  int'(2.4)            -> 2
5.  byte'(300)           -> 44
6.  4'(8'hAB)            -> b
7.  signed'(4'b1111)     -> -1
8.  nibbles_t'(8'h5C)    -> hi=5 lo=c
9.  op_e'(2)             -> OP_MUL
10. real'(7) / 2         -> 3.5
11. $cast(dir, 2) ok     -> WR
12. $cast(dir, 5) failed -> dir stays WR
13. dir_e'(5)            -> value 5, name ''
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Implicit real-to-integer conversion rounds 3.7 to 4. |
| 2 | Implicit truncation: only the low 4 bits of `AB` are kept. |
| 3 | `n` is unsigned, so it is zero-extended: `B` = 11. |
| 4 | 2.4 rounds to 2. |
| 5 | 300 is `1_0010_1100`. Only the low 8 bits `0010_1100` are kept: 44. |
| 6 | Size cast: the same truncation as line 2, but written explicitly so that a reader and a lint tool know it is intentional. |
| 7 | `4'b1111` is unsigned (15). `signed'` reinterprets it as -1, which is then sign-extended to 32 bits. |
| 8 | An 8-bit vector is cast to a packed struct: upper nibble to `hi`, lower nibble to `lo`. |
| 9 | Integer to enum by static cast. 2 is a legal member, `OP_MUL`. |
| 10 | The cast makes the left operand real, so the division is a real division. Compare with `7 / 2` = 3 in Section 2.7. |
| 11 | Function form of `$cast`; 2 is the value of `WR`, so it succeeds. |
| 12 | 5 is not a member of `dir_e`. The function returns 0 and `dir` is not modified. |
| 13 | The static cast stores 5 anyway. `dir` now holds a value that is not a member; `name()` returns an empty string. This is the danger of static casts to enums. |

### Bit-stream casting and streaming operators

Two further forms convert between aggregates (unpacked structs, arrays) and flat bit vectors. They are used to **pack** a transaction into bits for driving, and to **unpack** bits back into fields in a monitor.

```systemverilog file=tb_bitstream.sv
module tb_bitstream;

  typedef struct {            // unpacked struct, 32 bits in total
    bit [7:0]  addr;
    bit [7:0]  data;
    bit [15:0] crc;
  } pkt_t;
  typedef bit [31:0] u32_t;

  pkt_t     p, q;
  u32_t     v;
  bit [7:0] b8;

  initial begin
    p = '{addr: 8'hA1, data: 8'hB2, crc: 16'hC3D4};

    v = u32_t'(p);                 $display("1. bit-stream cast       : %h", v);
    v = {>>{p}};                   $display("2. streaming {>>{p}}     : %h", v);

    q = pkt_t'(32'h1122_3344);     $display("3. unpack                : addr=%h data=%h crc=%h",
                                            q.addr, q.data, q.crc);

    v  = {<<8{32'hA1B2_C3D4}};     $display("4. byte reverse {<<8{..}} : %h", v);
    b8 = {<<{8'b1100_0001}};       $display("5. bit reverse  {<<{..}}  : %b", b8);
  end

endmodule
```

```output
1. bit-stream cast       : a1b2c3d4
2. streaming {>>{p}}     : a1b2c3d4
3. unpack                : addr=11 data=22 crc=3344
4. byte reverse {<<8{..}} : d4c3b2a1
5. bit reverse  {<<{..}}  : 10000011
```

| Line | Explanation |
|---|---|
| 1 | A bit-stream cast flattens the struct into a vector. The first member becomes the most significant bits. Source and destination must have the same total number of bits. |
| 2 | The streaming operator `{>>{...}}` does the same: it streams the members left to right into a vector. |
| 3 | The reverse direction: a 32-bit value is distributed over the members. |
| 4 | `{<<8{...}}` streams right to left in chunks of 8 bits, so the byte order is reversed. Used for endianness conversion. |
| 5 | `{<<{...}}` with no chunk size reverses bit by bit. |

### Static cast versus dynamic cast

| Property | Static cast `type'(expr)` | Dynamic cast `$cast(dst, src)` |
|---|---|---|
| When it is resolved | Compile time | Run time |
| Checks whether the value is legal | No | Yes |
| On an illegal value | Silently stores it | Function form returns 0; task form gives a run-time error |
| Returns a status | No | Yes (function form) |
| Run-time cost | None | Small |
| Main uses | Width, sign, real↔integer, vector↔packed struct | Integer→enum, base-class handle→derived-class handle |
| Synthesizable | Yes | No (`$cast` is a simulation system task) |

> **Interview trap:** "What is the difference between calling `$cast` as a function and as a task?" As a function it returns 1 or 0 and never reports an error, so you must test the return value. As a task it reports a run-time error when the cast fails. Calling the function form and ignoring the result hides failures.

> **Common mistake:** Using a static cast to put a value from the DUT into an enum, for example `op = alu_op_e'(vif.op);` in a monitor. If the DUT drives an illegal encoding, the enum silently holds a non-member value. Use `if (!$cast(op, vif.op)) $error("illegal opcode %0h", vif.op);`.

> **Common mistake:** Forgetting the apostrophe. `int(x)` is a syntax error; the cast is `int'(x)`.

### Interview questions

**Q1. What is type casting?**
Converting a value of one data type into another data type, either implicitly by the language rules or explicitly with a cast operator or `$cast`.

**Q2. What is the difference between static and dynamic casting?**
A static cast, `type'(expr)`, is resolved at compile time and does not check the value. A dynamic cast, `$cast(dst, src)`, checks at run time that the source value is valid for the destination type, assigns only if it is, and reports success or failure.

**Q3. When must `$cast` be used?**
When assigning an integral value to an enum safely, and when assigning a base-class handle to a derived-class handle (downcasting).

**Q4. What does `$cast` return?**
When called as a function it returns 1 if the cast succeeded and 0 if it failed. When called as a task there is no return value; a failure causes a run-time error.

**Q5. What is `int'(3.5)`? What is `$rtoi(3.5)`?**
`int'(3.5)` is 4, because the cast rounds. `$rtoi(3.5)` is 3, because it truncates.

**Q6. How do you convert a real to its 64-bit pattern?**
With `$realtobits(r)`. A cast `longint'(r)` would instead convert the numeric value (rounding it).

**Q7. What does a size cast such as `16'(x)` do?**
It changes the width of the expression to 16 bits: truncating the upper bits if `x` is wider, or extending (sign- or zero-extending according to the signedness of `x`) if it is narrower.

## 4.2 Default Values of Different Data Types

### The rule

A variable that has not been assigned has the default value of its data type:

- **Four-state** integral types start as **X**.
- **Two-state** integral types start as **0**.
- **Nets** have no stored value: an undriven net is **Z**.
- Everything dynamic starts **empty** or **null**.

### Complete table

| Data type | Default value | Notes |
|---|---|---|
| `bit`, `bit [N:0]` | 0 | Two-state |
| `byte`, `shortint`, `int`, `longint` | 0 | Two-state |
| `logic`, `reg`, `logic [N:0]` | X | Four-state |
| `integer` | X | Four-state |
| `time` | X | Four-state |
| `real`, `shortreal`, `realtime` | 0.0 | |
| `string` | `""` (empty string) | Length 0 |
| `enum` | Default of the base type | 0 for `int` or `bit` base; X for a `logic` base. Not necessarily a declared member |
| `wire`, `tri` and other nets | Z | When there is no driver |
| `trireg` | X | Charge-storage net |
| `tri0` / `tri1` | 0 / 1 | When there is no driver |
| Packed struct, packed union | Per bit: X if four-state, 0 if two-state | |
| Unpacked struct | Each member gets the default of its own type | Unless the typedef gives a member default |
| Fixed-size array | Each element gets the default of the element type | |
| Dynamic array | Empty, `size()` is 0 | |
| Queue | Empty, `size()` is 0 | |
| Associative array | Empty, `num()` is 0 | |
| Class handle | `null` | No object exists until `new()` is called |
| Virtual interface | `null` | Must be assigned before use |
| `event` | A new, untriggered event | |
| `chandle` (C pointer for DPI) | `null` | |
| `mailbox`, `semaphore` variables | `null` | They are class handles; `new()` is required |

### Complete example

```systemverilog file=tb_defaults.sv
module tb_defaults;

  typedef enum {LOW, HIGH} level_e;

  class dummy;
  endclass

  bit       v_bit;
  logic     v_logic;
  int       v_int;
  integer   v_integer;
  real      v_real;
  string    v_string;
  wire      v_wire;
  level_e   v_enum;
  int       v_dyn [];
  int       v_queue [$];
  int       v_assoc [string];
  dummy     v_handle;
  struct { int a; logic [3:0] b; } v_struct;

  initial begin
    $display("bit=%b logic=%b int=%0d integer=%0d real=%0.1f",
             v_bit, v_logic, v_int, v_integer, v_real);
    $display("string='%s' (length %0d)", v_string, v_string.len());
    $display("wire=%b", v_wire);
    $display("enum=%s", v_enum.name());
    $display("dynamic array size=%0d  queue size=%0d  associative array entries=%0d",
             v_dyn.size(), v_queue.size(), v_assoc.num());
    if (v_handle == null) $display("class handle is null");
    $display("struct: a=%0d b=%b", v_struct.a, v_struct.b);
  end

endmodule
```

```output
bit=0 logic=x int=0 integer=x real=0.0
string='' (length 0)
wire=z
enum=LOW
dynamic array size=0  queue size=0  associative array entries=0
class handle is null
struct: a=0 b=xxxx
```

### Related rules

| Situation | Value |
|---|---|
| Declaration with an initialiser, `int count = 5;` at module level | Set once, before time 0 processes run |
| Variable declared `static` (the default inside a module-level task or function) with an initialiser | Initialised once at the start of simulation, **not** on each call. A frequent bug; see Module 3 |
| `automatic` variable with an initialiser | Initialised on every entry to the task, function or block |
| Reading a non-existent associative array entry | Returns the default value of the element type, with a warning |
| Reading out of range from an array | X for four-state elements, 0 for two-state |
| `rand` class property before `randomize()` is called | The normal default of its type (0 for `bit`/`int`) |
| Function return value when no `return` is executed | The default of the return type |

> **Interview trap:** "What is the default value of `logic`?" X. "Of `wire`?" Z. "Of `int`?" 0. "Of `integer`?" X. "Of a class handle?" `null`. "Of an enum?" The default of its base type, which may not be a valid member. Interviewers ask these as rapid-fire questions; know the table by heart.

> **Common mistake:** Using a class handle, mailbox or virtual interface that is still at its default `null`. The result is a run-time "null object access" (null pointer) error, the most common run-time error in class-based testbenches.

> **Verification application:** The first check in most testbenches is that DUT outputs leave X after reset. The four-state default is what makes that check possible: before reset, flip-flops are X; after reset, any output still at X points to a register that was not reset.

### Interview questions

**Q1. What is the default value of two-state and four-state variables?**
0 and X respectively.

**Q2. What is the default value of a `wire`, a `string`, a `real`, a class handle?**
Z, the empty string, 0.0, and `null`.

**Q3. Why do four-state variables default to X and not 0?**
Because X models reality: a storage element that has not been initialised has an unknown value. Starting at 0 would hide missing-reset bugs.

**Q4. What is the default size of a dynamic array?**
Zero. Memory is allocated with `new[n]`.

## 4.3 Four-State Logic Values: 0, 1, X, Z

Section 2.1 introduced the four values. This section explains exactly how X and Z behave in operators and statements, because that behaviour causes real bugs and many interview questions.

### Meaning of each value

| Value | In simulation | In real hardware | In synthesis |
|---|---|---|---|
| 0 | Logic low | Low voltage | Logic 0 |
| 1 | Logic high | High voltage | Logic 1 |
| X | Unknown: could be 0 or 1 | Does not exist; the node has some voltage | Assigned in RTL (`y = 'x`) it means "don't care", letting the tool optimise |
| Z | Not driven | A floating node | Infers a tri-state buffer (`assign y = en ? d : 'z;`) |

### Writing X and Z in literals

```systemverilog
4'b10xz        // individual x and z digits
8'hxF          // one hex x digit = four x bits : xxxx_1111
8'bz           // if the leftmost digit is x or z, it is used to pad : zzzz_zzzz
8'b1           // otherwise padding is with zeros : 0000_0001
'x  'z  '0  '1 // fill literals: every bit of the target, whatever its width
4'b1?0?        // ? is another way to write z in a literal (used in casez and ==? patterns)
```

X and Z are case-insensitive in literals: `4'bXXzz` is the same as `4'bxxZZ`.

### Truth tables

For bitwise operators, Z on an input is treated exactly like X.

| `&` (AND) | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 0 | 0 | 0 |
| **1** | 0 | 1 | X | X |
| **X** | 0 | X | X | X |
| **Z** | 0 | X | X | X |

| `\|` (OR) | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 1 | X | X |
| **1** | 1 | 1 | 1 | 1 |
| **X** | X | 1 | X | X |
| **Z** | X | 1 | X | X |

| `^` (XOR) | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 0 | 1 | X | X |
| **1** | 1 | 0 | X | X |
| **X** | X | X | X | X |
| **Z** | X | X | X | X |

| `~` (NOT) | 0 | 1 | X | Z |
|---|---|---|---|---|
| Result | 1 | 0 | X | X |

The way to remember them: a **controlling value** decides the output regardless of the other input. 0 controls AND (0 AND anything is 0). 1 controls OR (1 OR anything is 1). XOR has no controlling value, so any X gives X.

### How X behaves in each kind of construct

| Construct | Behaviour with X or Z | Example |
|---|---|---|
| Bitwise `&`, `\|`, `^`, `~` | Bit by bit, using the tables above | `4'b1x00 & 4'b0011` = `0000` |
| Arithmetic `+ - * / % **` | **Any** X or Z bit in any operand makes the **whole** result X | `4'b1x00 + 1` = `xxxx` |
| Relational `< <= > >=` | Any X or Z bit makes the result `1'bx` | `4'b1x00 > 0` = `x` |
| Logical equality `==`, `!=` | `1'bx` if the outcome depends on an X or Z bit | See Section 4.5 |
| Case equality `===`, `!==` | X and Z are compared literally; result is always 0 or 1 | See Section 4.5 |
| Logical `&&`, `\|\|`, `!` | Operand is true if it has at least one 1 bit, false if all bits are 0, otherwise unknown; then the AND/OR tables apply | `1'b0 && 1'bx` = 0 |
| Reduction `&`, `\|`, `^` | The tables above applied across the bits | `&4'b1x0x` = 0, `\|4'b1x0x` = 1 |
| Shift by an X amount | Result is all X | |
| `if (cond)` | If `cond` is X or Z it is treated as **false**: the `else` branch runs | X-optimism |
| `cond ? a : b` | If `cond` is X: bits where `a` and `b` agree keep that value, the other bits become X | X-pessimism is partly modelled |
| `case` | Uses `===` matching: an X in the selector matches only an item with X in the same position; usually falls to `default` | |
| `while`, `for`, `wait` conditions | X is treated as false | |
| Edge `@(posedge clk)` | Transitions 0→1, 0→X, 0→Z, X→1, Z→1 all count as a posedge | |
| Array index | Read returns X (or 0 for two-state elements); write is ignored | |

### X-optimism and X-pessimism

- **X-optimism:** the simulation shows a known value where real hardware could have either value. The `if` statement is the main cause: with an unknown condition the simulator simply executes the `else` branch as though the condition were 0. A bug can be hidden because the simulation looks cleaner than reality.
- **X-pessimism:** the simulation shows X where real hardware would have a known value. Example: `y = (sel & a) | (~sel & a)` in gates. With `sel` = X and `a` = 1, the real output is 1 whichever value `sel` has, but the simulator computes `(X & 1) | (X & 1)` = X.

RTL simulation tends to be X-optimistic; gate-level simulation tends to be X-pessimistic. This difference is one reason gate-level simulations are still run.

### Complete example

```systemverilog file=tb_four_state.sv
module tb_four_state;

  logic       sel;
  logic [3:0] a, b, y;

  initial begin
    a   = 4'b1100;
    b   = 4'b1010;
    sel = 1'bx;

    if (sel) y = a;
    else     y = b;
    $display("1. if-else with X select : y = %b", y);

    y = sel ? a : b;
    $display("2. ?: with X select      : y = %b", y);

    case (sel)
      1'b0   : $display("3. case: matched 0");
      1'b1   : $display("3. case: matched 1");
      default: $display("3. case: X matched neither 0 nor 1, default taken");
    endcase

    $display("4. 0&x=%b  1&x=%b  0|x=%b  1|x=%b  1^x=%b  ~x=%b  1&z=%b",
             1'b0 & 1'bx, 1'b1 & 1'bx, 1'b0 | 1'bx, 1'b1 | 1'bx, 1'b1 ^ 1'bx, ~1'bx,
             1'b1 & 1'bz);

    y = 4'b1x00;
    $display("5. 1x00 + 1 = %b", y + 4'b0001);
    $display("6. 1x00 > 0 = %b", y > 4'b0000);
    $display("7. &1x00 = %b   |1x00 = %b   ^1x00 = %b", &y, |y, ^y);
    $display("8. $isunknown(1x00) = %b   $countones(1x00) = %0d", $isunknown(y), $countones(y));
  end

endmodule
```

```output
1. if-else with X select : y = 1010
2. ?: with X select      : y = 1xx0
3. case: X matched neither 0 nor 1, default taken
4. 0&x=0  1&x=x  0|x=x  1|x=1  1^x=x  ~x=x  1&z=x
5. 1x00 + 1 = xxxx
6. 1x00 > 0 = x
7. &1x00 = 0   |1x00 = 1   ^1x00 = x
8. $isunknown(1x00) = 1   $countones(1x00) = 1
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | `if (sel)` with `sel` = X is treated as false. The `else` branch executes and `y` gets `b`, a fully known value. The unknown select has disappeared. This is X-optimism. |
| 2 | The conditional operator merges both inputs. Bits 3 and 0 are the same in `a` and `b` (1 and 0), so they are known. Bits 2 and 1 differ, so they are X. This is a more accurate model of a multiplexer. |
| 3 | `case` compares with `===`. X is not identical to 0 or 1, so the `default` item runs. Without a `default`, nothing would execute. |
| 4 | Direct check of the truth tables. Note `1 & z` = X: Z at a gate input is unknown. |
| 5 | One X bit in an arithmetic operand makes every result bit X. |
| 6 | A relational operator with an X operand returns X. |
| 7 | Reduction AND sees a 0, so the answer is 0. Reduction OR sees a 1, so the answer is 1. Reduction XOR has no controlling value: X. |
| 8 | `$isunknown` detects X/Z. `$countones` counts only the bits that are 1. |

> **Interview trap:** "If `sel` is X, what does `if (sel) y = a; else y = b;` assign?" It assigns `b`. Many candidates answer "X". An `if` never produces X by itself; it just takes the `else` branch.

> **Common mistake:** Believing `case` treats X as a wildcard. Plain `case` requires an exact four-state match. Only `casex` treats X and Z as don't-care, `casez` treats Z (and `?`) as don't-care, and `case ... inside` treats X/Z in the case items as don't-care.

> **Verification application:** Testbenches include "X checks": an assertion or monitor check that control signals are never X or Z after reset, typically `assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(valid));`. Because `if` and `==` are optimistic about X, an explicit `$isunknown` check is the reliable way to catch X on the DUT interface.

### Interview questions

**Q1. What is the difference between X and Z?**
X means the value is unknown: driven, but the simulator cannot tell whether it is 0 or 1 (uninitialised, conflicting drivers). Z means high impedance: not driven at all. Z read by logic behaves as X.

**Q2. What is `1'b0 & 1'bx`? `1'b1 | 1'bx`? `1'b1 & 1'bx`?**
0, 1 and X. A controlling value (0 for AND, 1 for OR) gives a known result despite the X.

**Q3. What happens to `if (a)` when `a` is X?**
The condition is treated as false, so the `else` branch (if any) executes.

**Q4. What is X-propagation / X-optimism?**
X-optimism is when RTL simulation turns an unknown into a known value (for example through `if` or `case`), hiding a potential bug that real hardware or gate-level simulation would expose. X-pessimism is the opposite: simulation reports X where hardware would have a definite value.

**Q5. What is the result of `4'b101x + 4'b0001`?**
`4'bxxxx`. Arithmetic with any unknown bit gives an entirely unknown result.

**Q6. Is X synthesizable?**
Assigning X in RTL is accepted by synthesis and is treated as a don't-care for optimisation. Comparing against X (`if (a === 1'bx)`) is not synthesizable, because hardware has no X to compare with.

## 4.4 Logical, Bitwise, Reduction and Shift Operators

### All operators at a glance

| Group | Operators | Operands | Result |
|---|---|---|---|
| Arithmetic | `+ - * / % **` | Two (also unary `+ -`) | A number |
| Increment / decrement | `++ --` | One variable | Modifies the variable |
| Logical | `&& \|\| ! -> <->` | Treated as true/false | 1 bit: 0, 1 or X |
| Bitwise | `& \| ^ ~ ~^ ^~` | Vectors, bit by bit | A vector as wide as the wider operand |
| Reduction | `& ~& \| ~\| ^ ~^ ^~` (unary) | One vector | 1 bit |
| Shift | `<< >> <<< >>>` | Value, shift amount | A vector as wide as the left operand |
| Relational | `< <= > >=` | Two | 1 bit |
| Equality | `== != === !== ==? !=?` | Two | 1 bit |
| Conditional | `? :` | Three | One of the two values |
| Concatenation / replication | `{a, b}`, `{n{a}}` | Any number | A vector of the total width |
| Assignment | `= += -= *= /= %= &= \|= ^= <<= >>= <<<= >>>=` | | |
| Set membership | `inside` | Value, set | 1 bit |
| Streaming | `{>>{}}`, `{<<{}}` | | Packs / unpacks / reorders bits |

### Logical operators: && || !

**Definition.** Logical operators treat each operand as one truth value and return **one bit**.

- An operand is **true** if it is non-zero (at least one bit is 1).
- An operand is **false** if it is zero (all bits are 0).
- An operand is **unknown** if it has no 1 bit but has X or Z bits.

| Operator | Meaning | Result |
|---|---|---|
| `a && b` | Logical AND | 1 if both are true |
| `a \|\| b` | Logical OR | 1 if at least one is true |
| `!a` | Logical NOT | 1 if `a` is false |
| `a -> b` | Logical implication | Same as `(!a) \|\| b` |
| `a <-> b` | Logical equivalence | 1 if both true or both false |

**Short-circuit evaluation.** `&&`, `||`, `->` and `?:` evaluate their operands left to right and stop as soon as the result is known. In `a && b`, if `a` is false, `b` is **not evaluated**. This matters when `b` has a side effect or would be illegal to evaluate:

```systemverilog
if (txn != null && txn.addr == 8'h10) ...      // txn.addr is not read when txn is null
if (idx < q.size() && q[idx] == 0) ...         // q[idx] is not read when idx is out of range
```

### Bitwise operators: & | ^ ~ ~^

**Definition.** Bitwise operators work on each bit position independently and return a **vector**. If the operands have different widths, the narrower one is extended on the left first.

| Operator | Meaning |
|---|---|
| `a & b` | AND of each bit pair |
| `a \| b` | OR of each bit pair |
| `a ^ b` | XOR of each bit pair |
| `a ~^ b` or `a ^~ b` | XNOR of each bit pair |
| `~a` | Invert every bit |

### Logical versus bitwise

| Property | Logical (`&&`, `\|\|`, `!`) | Bitwise (`&`, `\|`, `~`) |
|---|---|---|
| Operands are treated as | A single true/false value | A set of independent bits |
| Result width | 1 bit | Width of the operands |
| `4'b1010 && 4'b0101` vs `4'b1010 & 4'b0101` | 1 (both non-zero) | `0000` |
| `!4'b1010` vs `~4'b1010` | 0 | `0101` |
| Short-circuit | Yes | No, both operands are always evaluated |
| Typical use | Conditions in `if`, `while`, assertions | Masking, setting, clearing and toggling bits |
| For 1-bit operands | The two give the same value (but differ in short-circuit behaviour) | |

> **Interview trap:** `if (!a)` and `if (~a)` are the same only when `a` is one bit wide. For `a = 4'b1010`, `!a` is 0 (false), but `~a` is `0101`, which is non-zero and therefore true. Use `!` in conditions.

> **Interview trap:** `bit flag = 1; int n = ~flag;` gives -2, not 0. The right-hand side is evaluated at the width of the destination (32 bits): `flag` is first extended to `0000...0001` and then inverted to `1111...1110`. With `!flag` the result is 0. Use `!` for a truth value and `~` only when you mean to invert bits.

### Reduction operators

**Definition.** A reduction operator is a unary operator placed before a single vector. It applies the operation across all the bits of that vector and returns **one bit**.

| Operator | Name | Returns 1 when | `a = 4'b1011` |
|---|---|---|---|
| `&a` | Reduction AND | Every bit is 1 | 0 |
| `~&a` | Reduction NAND | Not every bit is 1 | 1 |
| `\|a` | Reduction OR | At least one bit is 1 | 1 |
| `~\|a` | Reduction NOR | Every bit is 0 | 0 |
| `^a` | Reduction XOR | The number of 1 bits is odd (parity) | 1 |
| `~^a` | Reduction XNOR | The number of 1 bits is even | 0 |

The same symbols `&`, `|`, `^` are bitwise when they have two operands and reduction when they have one.

| Practical use | Expression |
|---|---|
| Even-parity bit | `parity = ^data;` |
| All ones? | `full = &count;` |
| Any bit set? (an interrupt pending) | `irq = \|irq_status;` |
| All zero? | `empty = ~\|count;` |
| Contains X or Z? | `(^data) === 1'bx` |

### Shift operators

| Operator | Name | Vacated bits are filled with |
|---|---|---|
| `a << n` | Logical left shift | 0 |
| `a >> n` | Logical right shift | 0 |
| `a <<< n` | Arithmetic left shift | 0 (identical to `<<`) |
| `a >>> n` | Arithmetic right shift | The sign bit if `a` is **signed**; 0 if `a` is unsigned |

```text
   a = 8'b1001_0110  (signed: -106, unsigned: 150)

   a << 2          ->  0101_1000     two zeros enter on the right; the top two bits are lost
   a >> 2          ->  0010_0101     two zeros enter on the left
   a >>> 2  signed ->  1110_0101     two copies of the sign bit enter on the left  (-27)
   a >>> 2 unsigned->  0010_0101     same as >>
```

- The result has the width of the **left** operand. Bits shifted out are lost.
- The shift amount is always treated as unsigned.
- Shifting left by n multiplies by 2^n; shifting right by n divides by 2^n. For a signed value, `>>>` keeps the sign, but note that it rounds toward minus infinity (`-7 >>> 1` is -4) whereas `/` rounds toward zero (`-7 / 2` is -3).
- Shifts by a constant are free in hardware (just wiring). Shifts by a variable synthesise to a barrel shifter.

### Arithmetic, relational and other operators in brief

| Operator | Notes |
|---|---|
| `/` | Integer division truncates toward zero: `7 / 2` = 3, `-7 / 2` = -3 |
| `%` | Remainder takes the sign of the first operand: `-7 % 2` = -1, `7 % -2` = 1. Not allowed on reals |
| `**` | Power: `2 ** 10` = 1024 |
| `/ 0`, `% 0` | Result is X |
| `a ? b : c` | Selects `b` if `a` is true, `c` if false; merges if `a` is X |
| `{a, b}` | Concatenation. Every operand must have a known width, so unsized literals such as `1` are not allowed inside |
| `{n{a}}` | Replication: `{4{2'b10}}` = `8'b10101010` |
| `i++`, `++i`, `i += 2` | These are **blocking** assignments. Use them for testbench variables and loop counters, not for flip-flops in `always_ff` |
| `x inside {1, 2, [5:9]}` | True if `x` equals any listed value or lies in a listed range. Uses `==?` matching, so X/Z in the set are wildcards |

### Operator precedence

Highest precedence first. Operators on the same row have equal precedence and associate left to right, except `?:`, `->`, `<->` and the assignment operators, which associate right to left.

| Level | Operators |
|---|---|
| 1 (highest) | `()` `[]` `::` `.` |
| 2 | Unary `+` `-` `!` `~` `&` `~&` `\|` `~\|` `^` `~^` `++` `--` |
| 3 | `**` |
| 4 | `*` `/` `%` |
| 5 | Binary `+` `-` |
| 6 | `<<` `>>` `<<<` `>>>` |
| 7 | `<` `<=` `>` `>=` `inside` `dist` |
| 8 | `==` `!=` `===` `!==` `==?` `!=?` |
| 9 | Binary `&` |
| 10 | Binary `^` `~^` `^~` |
| 11 | Binary `\|` |
| 12 | `&&` |
| 13 | `\|\|` |
| 14 | `?:` |
| 15 | `->` `<->` |
| 16 | `=` `+=` `-=` and the other assignment operators |
| 17 (lowest) | `{}` `{{}}` |

> **Interview trap:** `if (a & b == c)` is parsed as `if (a & (b == c))`, because `==` has higher precedence than `&`. Write `if ((a & b) == c)`. When in doubt, add parentheses; nobody is impressed by code that relies on precedence.

### Expression width: the rule behind many bugs

Before an expression is evaluated, SystemVerilog decides how many bits to use.

1. For "context-determined" operands (operands of `+ - * / % & | ^`, the left operand of a shift, both result operands of `?:`), the width is the **largest** width among all those operands **and the left-hand side** of the assignment.
2. Every such operand is extended to that width **before** the operation.
3. "Self-determined" operands use only their own width: the shift amount, operands inside a concatenation, operands of a comparison (which are sized against each other only), and arguments to `$display`.

```text
   logic [7:0] p = 200, q = 100;
   logic [8:0] sum9;
   logic [7:0] avg;

   sum9 = p + q;            width = max(8, 8, 9) = 9   ->  300        carry kept
   avg  = (p + q) >> 1;     width = max(8, 8, 8) = 8   ->  300 mod 256 = 44, then 44 >> 1 = 22   WRONG
   avg  = ({1'b0, p} + q) >> 1;   width = 9            ->  300 >> 1 = 150                        correct
```

### Complete example

```systemverilog file=tb_operators.sv
module tb_operators;

  logic [3:0] a, b;
  logic [7:0] p, q, avg;
  bit         flag;
  int         n;

  initial begin
    a = 4'b1010;
    b = 4'b0101;
    $display("1.  logical : a && b = %b   a || b = %b   !a = %b", a && b, a || b, !a);
    $display("2.  bitwise : a & b = %b   a | b = %b   a ^ b = %b   ~a = %b",
             a & b, a | b, a ^ b, ~a);

    a = 4'b1011;
    $display("3.  reduction of 1011 : &a=%b  |a=%b  ^a=%b  ~&a=%b  ~|a=%b  ~^a=%b",
             &a, |a, ^a, ~&a, ~|a, ~^a);
    $display("4.  shift of 1011     : a << 1 = %b   a >> 1 = %b", a << 1, a >> 1);

    $display("5.  7 / 2 = %0d   -7 / 2 = %0d   -7 %% 2 = %0d   2 ** 10 = %0d",
             7 / 2, -7 / 2, -7 % 2, 2 ** 10);
    $display("6.  a / 0 = %b", a / 4'd0);

    flag = 1;
    n = ~flag;   $display("7.  int n = ~flag -> %0d", n);
    n = !flag;   $display("8.  int n = !flag -> %0d", n);

    p = 8'd200;
    q = 8'd100;
    avg = (p + q) >> 1;             $display("9.  (p + q) >> 1          = %0d", avg);
    avg = ({1'b0, p} + q) >> 1;     $display("10. ({1'b0, p} + q) >> 1  = %0d", avg);

    $display("11. max = %0d", (p > q) ? p : q);
    $display("12. {a, b} = %b   {2{a}} = %b", {a, b}, {2{a}});

    if (a inside {4'd3, [4'd9:4'd12]}) $display("13. a (=%0d) is inside {3, [9:12]}", a);

    $display("14. a & b == b   -> %b", a & b == b);
    $display("15. (a & b) == b -> %b", (a & b) == b);
  end

endmodule
```

```output
1.  logical : a && b = 1   a || b = 1   !a = 0
2.  bitwise : a & b = 0000   a | b = 1111   a ^ b = 1111   ~a = 0101
3.  reduction of 1011 : &a=0  |a=1  ^a=1  ~&a=1  ~|a=0  ~^a=0
4.  shift of 1011     : a << 1 = 0110   a >> 1 = 0101
5.  7 / 2 = 3   -7 / 2 = -3   -7 % 2 = -1   2 ** 10 = 1024
6.  a / 0 = xxxx
7.  int n = ~flag -> -2
8.  int n = !flag -> 0
9.  (p + q) >> 1          = 22
10. ({1'b0, p} + q) >> 1  = 150
11. max = 200
12. {a, b} = 10110101   {2{a}} = 10111011
13. a (=11) is inside {3, [9:12]}
14. a & b == b   -> 0001
15. (a & b) == b -> 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Both `a` and `b` are non-zero, so each is "true". `a && b` = 1, `a \|\| b` = 1, `!a` = 0. One-bit results. |
| 2 | Bit-by-bit: `1010 & 0101` = `0000`, OR = `1111`, XOR = `1111`, `~1010` = `0101`. Compare with line 1: the logical AND is 1 while the bitwise AND is 0. |
| 3 | `1011`: not all ones → `&` = 0; some ones → `\|` = 1; three ones (odd) → `^` = 1. The last three are the inverses. |
| 4 | Inside `$display` the expression is 4 bits wide (self-determined). `1011 << 1` loses the top bit: `0110`. `1011 >> 1` = `0101`. |
| 5 | Integer division truncates toward zero; the remainder has the sign of the first operand. |
| 6 | Division by zero gives X in every bit. |
| 7 | `flag` is extended to 32 bits, then inverted: `FFFF_FFFE` = -2. |
| 8 | `!flag` is the 1-bit value 0, extended to 32 bits: 0. |
| 9 | Width is 8 bits. 200 + 100 = 300 overflows to 44; 44 >> 1 = 22. The carry was lost **before** the shift. |
| 10 | The concatenation `{1'b0, p}` is 9 bits wide, so the addition is done in 9 bits: 300 >> 1 = 150. |
| 11 | Conditional operator used as "maximum". |
| 12 | Concatenation joins `1011` and `0101`. Replication repeats `1011` twice. |
| 13 | `a` is 11, which lies in the range 9 to 12. |
| 14 | Parsed as `a & (b == b)`. `b == b` is 1; `1011 & 0001` = `0001`. |
| 15 | `(1011 & 0101)` = `0001`, which is not equal to `0101`: 0. Lines 14 and 15 show why parentheses are needed. |

> **Common mistake:** Writing `a = b << 1 + 1;` and expecting `(b << 1) + 1`. Addition has higher precedence than shift, so this is `b << 2`.

> **Verification application:** Reference models in a scoreboard must reproduce the DUT's widths exactly. For the ALU, the model computes `exp = {1'b0, a} + {1'b0, b};` into a 9-bit variable so that the carry is modelled. A model that computes in 8 bits will mismatch on every overflow, and a model that computes in 32-bit `int` will mismatch on every subtraction that borrows unless the result is truncated to 9 bits.

### Interview questions

**Q1. What is the difference between `&&` and `&`?**
`&&` is logical AND: each operand is reduced to true or false and the result is one bit, with short-circuit evaluation. `&` with two operands is bitwise AND: each pair of bits is ANDed and the result is a vector.

**Q2. What is the difference between `!` and `~`?**
`!` is logical negation and gives a 1-bit result: 1 if the operand is zero. `~` inverts every bit of the operand and gives a result of the same width. They are equivalent only for 1-bit operands.

**Q3. What is a reduction operator? Give a use.**
A unary operator that combines all bits of one vector into a single bit, for example `^data` to compute parity, `&vec` to test for all ones, or `|vec` to test for any bit set.

**Q4. With `a = 4'b0110` and `b = 4'b1001`, what are `a & b`, `a && b`, `a | b`, `a || b`, `&a`, `|a`, `^a`?**
`0000`, 1, `1111`, 1, 0, 1, 0 (two ones, even parity).

**Q5. What is the difference between `>>` and `>>>`? And between `<<` and `<<<`?**
`>>` always fills with zeros. `>>>` fills with the sign bit when the left operand is signed. `<<` and `<<<` are identical.

**Q6. What is short-circuit evaluation?**
For `&&`, `||`, `->` and `?:`, evaluation stops as soon as the result is determined, so the remaining operand is not evaluated. It is commonly used to guard an access: `if (h != null && h.valid)`.

**Q7. `logic [7:0] a = 8'hFF, b = 8'h01; logic [7:0] s; s = (a + b) >> 1;` What is `s`?**
0. The expression is evaluated in 8 bits, so `FF + 01` wraps to `00`, and `00 >> 1` is `00`. To get `80`, widen an operand: `s = ({1'b0, a} + b) >> 1;`.

**Q8. What is the result of `-7 % 3` and `7 % -3`?**
-1 and 1. The result of `%` takes the sign of the first operand.

**Q9. Which has higher precedence, `==` or `&`?**
`==`. So `a & b == c` means `a & (b == c)`.

**Q10. How would you swap the upper and lower nibbles of a byte in one statement?**
`data = {data[3:0], data[7:4]};`

## 4.5 Equality Operators: ==, ===, !=, !==

### In plain English

There are two ways to ask "are these two values the same?".

- **Logical equality** `==` answers as hardware would: if an operand contains an unknown bit that matters, the honest answer is "I do not know" (X).
- **Case equality** `===` answers as a text comparison would: it compares the four-state symbols literally, so X equals X and Z equals Z, and the answer is always a definite yes or no.

### Technical definition

| Operator | Name | How X and Z in the operands are handled | Possible results |
|---|---|---|---|
| `a == b` | Logical equality | If the result depends on an X or Z bit, the result is X | 0, 1, X |
| `a != b` | Logical inequality | Same | 0, 1, X |
| `a === b` | Case equality (four-state equality) | X and Z are compared as ordinary values and must match exactly | 0, 1 |
| `a !== b` | Case inequality | Same | 0, 1 |

### How == works, step by step

1. Operands of different width are extended to the same width.
2. If any pair of **known** bits (0/1) differs, the values are definitely different: result **0**.
3. Otherwise, if any bit of either operand is X or Z, the result is ambiguous: result **X**.
4. Otherwise all bits are known and equal: result **1**.

`===` simply compares each bit position for an identical symbol (0, 1, X or Z) and returns 1 only if all positions match.

Single-bit truth tables:

| `==` | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 1 | 0 | X | X |
| **1** | 0 | 1 | X | X |
| **X** | X | X | X | X |
| **Z** | X | X | X | X |

| `===` | 0 | 1 | X | Z |
|---|---|---|---|---|
| **0** | 1 | 0 | 0 | 0 |
| **1** | 0 | 1 | 0 | 0 |
| **X** | 0 | 0 | 1 | 0 |
| **Z** | 0 | 0 | 0 | 1 |

### Complete example

```systemverilog file=tb_equality.sv
module tb_equality;

  logic [3:0] a, b, c;
  logic [7:0] actual, expected;

  initial begin
    a = 4'b10x1;
    b = 4'b10x1;
    c = 4'b00x1;

    $display("1. a == b : %b    a === b : %b", a == b, a === b);
    $display("2. a != b : %b    a !== b : %b", a != b, a !== b);
    $display("3. a == c : %b    a === c : %b", a == c, a === c);

    if (a == b) $display("4. if (a == b) : taken");
    else        $display("4. if (a == b) : NOT taken, X is treated as false");

    if (a != b) $display("5. if (a != b) : taken");
    else        $display("5. if (a != b) : NOT taken either");

    // The scoreboard trap: the DUT output is X
    expected = 8'h3C;
    actual   = 8'hxx;

    if (actual != expected)  $display("6. using != : MISMATCH reported");
    else                     $display("6. using != : no mismatch reported  <-- bug hidden");

    if (actual !== expected) $display("7. using !== : MISMATCH reported    <-- correct");
    else                     $display("7. using !== : no mismatch reported");
  end

endmodule
```

```output
1. a == b : x    a === b : 1
2. a != b : x    a !== b : 0
3. a == c : 0    a === c : 0
4. if (a == b) : NOT taken, X is treated as false
5. if (a != b) : NOT taken either
6. using != : no mismatch reported  <-- bug hidden
7. using !== : MISMATCH reported    <-- correct
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | `a` and `b` are both `10x1`. With `==`, the X bit makes the answer unknown: X. With `===`, X matches X: 1. |
| 2 | The same for inequality: `!=` gives X, `!==` gives a definite 0. |
| 3 | `a` and `c` differ in bit 3 (1 versus 0), both known. They cannot be equal whatever the X is, so `==` gives a definite 0. |
| 4, 5 | Both `a == b` and `a != b` evaluate to X, and `if (X)` is false. **Neither** branch condition is true. `a == b` and `a != b` are not opposites when X is involved. |
| 6 | The DUT output is all X. `actual != expected` is X, the `if` is not taken, and the testbench reports nothing. The test passes with a completely broken output. |
| 7 | `!==` returns 1 because X is not identical to the expected bits. The error is reported. |

### Which operator to use where

| Situation | Operator | Reason |
|---|---|---|
| RTL (synthesizable code) | `==`, `!=` | `===` has no hardware meaning; synthesis tools reject it or treat it as `==` |
| Scoreboard / checker comparing DUT output with expected | `!==` / `===` | X or Z on the DUT output must count as a mismatch |
| Checking explicitly for X or Z | `===`, or `$isunknown()` | `sig == 1'bx` is always X and therefore never true |
| Comparing two-state values (`bit`, `int`) | `==` | No X possible, so both operators behave the same |
| Comparing class handles | `==`, `!=` | Compares whether both handles refer to the same object, not the object contents (Module 4) |
| Comparing strings, unpacked arrays, unpacked structs | `==`, `!=` | Compared element by element |
| Comparing reals | `==` with caution | `===` is not allowed on reals; prefer a tolerance comparison |

### Relationship with case statements

| Statement | Comparison used |
|---|---|
| `case` | `===`: exact four-state match |
| `casez` | Z and `?` bits (in the selector or the item) are don't-care |
| `casex` | X, Z and `?` bits (in the selector or the item) are don't-care |
| `case (...) inside` | `==?`: X, Z and `?` bits **in the item only** are don't-care |

> **Interview trap:** "What does `if (sig == 1'bx)` do?" It is never true. Comparing anything with X using `==` gives X, which an `if` treats as false. To test for X use `if (sig === 1'bx)` or `if ($isunknown(sig))`.

> **Interview trap:** "Is `!(a == b)` the same as `a != b`?" In value, yes: both are X when the comparison is ambiguous. But candidates often assume that if `a == b` is false then `a != b` must be true. With X, both can be "not true".

> **Verification application:** Every scoreboard comparison of DUT data should be written as `if (actual !== expected) $error(...)`. This single habit prevents the most damaging kind of testbench bug: a test that passes while the DUT outputs X.

### Interview questions

**Q1. What is the difference between `==` and `===`?**
`==` is logical equality: if either operand has X or Z bits that affect the outcome, the result is X. `===` is case equality: it compares all four states literally, so X matches X and Z matches Z, and the result is always 0 or 1.

**Q2. `a = 4'b1x01; b = 4'b1x01;` What are `a == b` and `a === b`?**
X and 1.

**Q3. `a = 4'b1x01; b = 4'b0x01;` What is `a == b`?**
0. Bit 3 is known and different, so the values cannot be equal regardless of the X.

**Q4. Which equality operator is synthesizable?**
`==` and `!=`. `===` and `!==` are for simulation, because real hardware cannot test for X or Z.

**Q5. Which would you use in a scoreboard and why?**
`===` / `!==`, so that an X or Z on the DUT output is detected as a mismatch. With `!=` the comparison would be X, the `if` would be skipped, and the failure would go unreported.

**Q6. How do you check whether a signal is X?**
`$isunknown(sig)`, or `sig === 'x` for an exact all-X match. Not `sig == 'x`.

**Q7. What does `==` return when comparing two-state operands?**
Always 0 or 1. X is only possible when an operand is four-state.

## 4.6 Wildcard Equality: ==? and !=?

### In plain English

Sometimes only part of a value matters: "is the address in the range `A0xx`?", "is the top bit of the opcode 1?". The wildcard equality operator compares two values while **ignoring the bit positions that are marked as don't-care in the right-hand operand**.

### Technical definition

| Operator | Name | Behaviour |
|---|---|---|
| `a ==? b` | Wildcard equality | Bit positions where `b` (the **right** operand) is X or Z are not compared. The remaining positions are compared like `==` |
| `a !=? b` | Wildcard inequality | The logical inverse of `==?` |

Three points define the operator completely:

1. **Only the right-hand operand supplies wildcards.** X or Z (also written `?`) in `b` means "don't care about this bit".
2. **X or Z in the left-hand operand is not a wildcard.** If the left operand has X/Z in a position that is being compared, the result is X, as with `==`.
3. The result can be 0, 1 or X.

So the operator is **asymmetric**: `a ==? b` and `b ==? a` can give different results.

### How it works, step by step

```text
   a ==? b

   1. Build a mask from b:   mask bit = 0 where b is X or Z,  1 where b is 0 or 1
   2. Compare only the positions where mask = 1, using the rules of ==

   Example:   a = 1010,  b = 1xx0

        a      :  1  0  1  0
        b      :  1  x  x  0
        mask   :  1  0  0  1          <- only bit 3 and bit 0 are compared
        compare:  =  -  -  =          -> result 1
```

### Complete example

```systemverilog file=tb_wildcard.sv
module tb_wildcard;

  logic [3:0]  a;
  logic [15:0] addr;

  initial begin
    a = 4'b1010;
    $display("1. 1010 ==? 1xx0 : %b", a ==? 4'b1xx0);
    $display("2. 1010 ==? 0xxx : %b", a ==? 4'b0xxx);
    $display("3. 1010 ==? 1?1? : %b", a ==? 4'b1?1?);
    $display("4. 1010 !=? 1xx0 : %b", a !=? 4'b1xx0);

    a = 4'b1x10;
    $display("5. 1x10 ==? 1010 : %b", a ==? 4'b1010);
    $display("6. 1x10 ==? 1?10 : %b", a ==? 4'b1?10);
    $display("7. 1x10 ==? 0xxx : %b", a ==? 4'b0xxx);

    $display("8. 1010 ==? 1xx0 : %b   but   1xx0 ==? 1010 : %b",
             4'b1010 ==? 4'b1xx0, 4'b1xx0 ==? 4'b1010);

    addr = 16'hA07C;
    if (addr ==? 16'hA0??) $display("9. address %h is in the A0xx block", addr);

    a = 4'b1010;
    if (a inside {4'b0???, 4'b1??0}) $display("10. inside also uses wildcard matching");
  end

endmodule
```

```output
1. 1010 ==? 1xx0 : 1
2. 1010 ==? 0xxx : 0
3. 1010 ==? 1?1? : 1
4. 1010 !=? 1xx0 : 0
5. 1x10 ==? 1010 : x
6. 1x10 ==? 1?10 : 1
7. 1x10 ==? 0xxx : 0
8. 1010 ==? 1xx0 : 1   but   1xx0 ==? 1010 : x
9. address a07c is in the A0xx block
10. inside also uses wildcard matching
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Bits 2 and 1 of the right operand are X, so only bits 3 and 0 are compared: 1=1 and 0=0. Match. |
| 2 | Only bit 3 is compared: 1 versus 0. No match. |
| 3 | `?` in a literal means Z, which is also a wildcard. Bits 3 and 1 are compared: 1=1, 1=1. Match. |
| 4 | `!=?` is the inverse of line 1. |
| 5 | The right operand has no wildcards, so all bits are compared. The **left** operand has an X in bit 2, which is not a wildcard, so the result is X. |
| 6 | Now the right operand has a wildcard in bit 2, which masks the X on the left. The other bits match: 1. |
| 7 | Bit 3 is 1 versus 0, known and different: 0. The X on the left is in a masked position and does not matter. |
| 8 | Asymmetry: with the pattern on the right the answer is 1; with the pattern on the left it is X. |
| 9 | In a hex literal each `?` stands for four Z bits, so `16'hA0??` matches any address whose upper byte is `A0`. |
| 10 | The `inside` operator compares with `==?`, so X, Z and `?` in the set are wildcards. `1010` matches `1??0`. |

### Comparison of the three equality families

Using `a = 4'b10x1`:

| Expression | `==` | `===` | `==?` |
|---|---|---|---|
| `a` op `4'b10x1` | X | 1 | 1 (the X on the right masks bit 1) |
| `a` op `4'b1001` | X | 0 | X (the X on the left is compared) |
| `a` op `4'b00x1` | 0 | 0 | 0 |
| `4'b1011` op `4'b10x1` | X | 0 | 1 |

| Property | `==` / `!=` | `===` / `!==` | `==?` / `!=?` |
|---|---|---|---|
| X/Z in the right operand | Makes the result X | Must match exactly | Don't-care (wildcard) |
| X/Z in the left operand | Makes the result X | Must match exactly | Makes the result X (if in a compared position) |
| Possible results | 0, 1, X | 0, 1 | 0, 1, X |
| Symmetric | Yes | Yes | No |
| Synthesizable | Yes | No | Yes, when the right operand is a constant pattern |
| Typical use | RTL and general comparison | Testbench checks that must see X/Z | Pattern matching on part of a value |

### Where wildcard matching appears in verification

| Construct | Wildcard behaviour |
|---|---|
| `==?`, `!=?` | X/Z/`?` in the right operand |
| `inside` | X/Z/`?` in the values of the set |
| `case (...) inside` | X/Z/`?` in the case items |
| `casez` / `casex` | Z (and X for `casex`) on **both** sides, which is why `casex` is considered dangerous in RTL |
| `wildcard bins` in a coverpoint | X/Z/`?` in the bin value: `wildcard bins odd = {4'b???1};` (Module 10) |

> **Interview trap:** "Does `==?` ignore X in both operands?" No. Only X and Z in the **right** operand are wildcards. An X in the left operand gives an X result. That one-sidedness is the difference between `==?` (and `case inside`) and `casex`.

> **Common mistake:** Putting the pattern on the left: `if (4'b1??0 ==? a)`. The wildcards are then on the wrong side and are treated as real Z values; the result is X and the `if` never executes.

### Interview questions

**Q1. What does `==?` do?**
It compares two values but ignores the bit positions in which the right-hand operand is X or Z. It is used to match a value against a pattern with don't-care bits.

**Q2. What is the difference between `==`, `===` and `==?`?**
`==` returns X if any relevant bit is X/Z. `===` compares X and Z literally and always returns 0 or 1. `==?` treats X/Z in the right operand as wildcards and otherwise behaves like `==`.

**Q3. Is `a ==? b` the same as `b ==? a`?**
No. Only the right operand provides wildcards, so the operator is asymmetric.

**Q4. `4'b1x01 ==? 4'b1001`: what is the result?**
X. The X is in the left operand, where it is not a wildcard, and the right operand masks nothing.

**Q5. How is `==?` related to `inside` and to wildcard bins?**
`inside` uses `==?` to compare the value with each member of the set, and `case inside` does the same with its items, so X/Z/`?` in the set or items act as wildcards. Wildcard bins in functional coverage apply the same idea to bin definitions.

**Q6. Is `==?` synthesizable?**
Yes, when the wildcard pattern is a constant; the tool simply omits the don't-care bits from the comparator.
