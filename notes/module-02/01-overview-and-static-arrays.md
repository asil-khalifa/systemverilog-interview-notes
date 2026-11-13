# Module 2 Overview

Module 1 introduced packed and unpacked arrays as data types. This module covers arrays completely: every kind of array SystemVerilog offers, every built-in method, how arrays are copied and compared, and every loop construct used to walk through them. Arrays are used in every part of a testbench (payloads, scoreboards, memory models, coverage bookkeeping), and array questions appear in almost every SystemVerilog interview, usually as "write code that..." questions.

**What this module covers**

| Part | Content |
|---|---|
| 1 | The four kinds of unpacked array, fixed-size (static) arrays, multidimensional arrays, the array query functions (`$size`, `$dimensions`, `$left`, `$right`, `$low`, `$high`) |
| 2 | Dynamic arrays (`new[]`, `size()`, `delete()`) and queues (`push_back`, `push_front`, `pop_back`, `pop_front`, `insert`, `delete`) |
| 3 | Associative arrays (`exists`, `first`, `last`, `next`, `prev`, `num`, `delete`) and how to choose between the array kinds |
| 4 | Array methods: searching (`find` and its relatives, `min`, `max`, `unique`), ordering (`sort`, `rsort`, `reverse`, `shuffle`), reduction (`sum`, `product`, `and`, `or`, `xor`) |
| 5 | Assignment, initialisation, copying, comparison, shallow and deep copy |
| 6 | Loops: `for`, `foreach`, `repeat`, `while`, `do`...`while`, `forever`, nested loops, `break` and `continue` |
| 7 | Revision, interview questions, output-prediction and debugging questions, coding exercises |

**What you need from Module 1**

- Packed versus unpacked dimensions and the index order rule (Sections 3.1 and 3.2).
- The difference between `{}` (concatenation) and `'{}` (assignment pattern).
- Two-state and four-state default values (0 and X).
- Expression width rules (Section 4.4), which explain the most common bug with `sum()`.
- `typedef`, `struct` and `enum`.

**Conventions**

The naming conventions of Module 1 continue: `tb_<topic>` for demonstration modules, `exNN_<name>` for exercise solutions, `_t`/`_e` type suffixes, and the 8-bit ALU (`alu_pkg`, `alu_op_e`, `alu_txn`) as the running example whenever a verification context is needed. A few examples use small classes or functions before Modules 3 and 4 explain them fully; each such use is explained where it appears.

> **Note:** As in Module 1, the "Expected output" blocks were derived by hand from the IEEE 1800 rules, not captured from a simulator. The text printed by the `%p` format specifier (used here to print whole arrays) varies slightly between simulators in spacing and number format; the values are the same. Where an output genuinely depends on the simulator or on a random seed, the text says so.

# Part 1: Array Fundamentals and Fixed-Size Arrays

## 1.1 The Kinds of Array in SystemVerilog

### In plain English

An array is a numbered collection of items of the same type, stored under one name. Instead of declaring `data0`, `data1`, ... `data99`, you declare `data [100]` and select an element with an index: `data[37]`.

Different jobs need different kinds of collection:

- A register file with exactly 32 registers needs a collection whose size never changes.
- A packet payload whose length is chosen at random for each packet needs a collection whose size is decided while the simulation runs.
- A list of expected results in a scoreboard needs a collection that grows at one end and shrinks at the other, continuously.
- A model of a 4 GB memory, of which the test touches 50 locations, needs a collection that stores only the locations actually used.

SystemVerilog has one array kind for each of these jobs.

### Technical definition

| Kind | Declaration | Size | Index | Storage allocated |
|---|---|---|---|---|
| Fixed-size (static) array | `int a [8];` | Fixed at compile time | Integer, contiguous | At elaboration, for all elements |
| Dynamic array | `int d [];` | Set and changed at run time with `new[]` | Integer, contiguous, from 0 | When `new[]` is called |
| Queue | `int q [$];` | Grows and shrinks automatically | Integer, contiguous, from 0 | Automatically, as elements are added |
| Associative array | `int aa [string];` | Grows as entries are written | Any type (integer, string, class handle...), sparse | Per entry, when the entry is first written |

All four are **unpacked** arrays: the bracket that makes them an array comes after the name. The element type can be anything, including a packed vector (`logic [7:0] mem [256]`), a struct, a class handle or another array.

Packed arrays (dimensions before the name, as in `logic [3:0][7:0] word`) are a separate concept: one contiguous vector with sub-fields. They were covered in Module 1 and are summarised again in Section 1.3.

```text
                               SystemVerilog arrays
                                       |
              +------------------------+-------------------------+
              |                                                  |
        Packed arrays                                     Unpacked arrays
   (dimensions before the name)                     (dimensions after the name)
   one contiguous vector                            separate elements
   logic [3:0][7:0] word;                                        |
                                    +------------+---------------+--------------+
                                    |            |               |              |
                               Fixed-size     Dynamic          Queue       Associative
                               int a [8];    int d [];       int q [$];   int aa [string];
                               compile-time  run-time size   grows and    sparse, any
                               size          via new[]       shrinks      index type
```

### Why so many kinds are needed

Each kind trades flexibility against speed and memory.

| Requirement | Best kind | Reason |
|---|---|---|
| Size known when the code is written | Fixed-size | Fastest, simplest, and the only unpacked kind that is synthesizable |
| Size known only at run time, then mostly constant | Dynamic array | One contiguous block; fast indexed access; resized explicitly |
| Elements added and removed all the time, mainly at the ends | Queue | Insertion and removal at either end without reallocating |
| Huge or non-numeric index space, few entries used | Associative array | Memory is used only for the entries that exist |

### Synthesizable or simulation-only

| Kind | Synthesizable |
|---|---|
| Packed array | Yes |
| Fixed-size unpacked array | Yes |
| Dynamic array | No |
| Queue | No |
| Associative array | No |

Dynamic arrays, queues and associative arrays exist only in testbench code.

### Interview questions

**Q1. What types of arrays does SystemVerilog have?**
Packed arrays and unpacked arrays. Unpacked arrays are of four kinds: fixed-size (static) arrays, dynamic arrays, queues and associative arrays.

**Q2. Which arrays are synthesizable?**
Packed arrays and fixed-size unpacked arrays. Dynamic arrays, queues and associative arrays are simulation-only because their size is not known at compile time.

**Q3. In one sentence each, when would you use a dynamic array, a queue and an associative array?**
A dynamic array when the size is decided at run time but then stays mostly constant, such as a random-length payload. A queue when elements are continuously added and removed, such as the expected-result list of a scoreboard. An associative array when the index space is large and sparsely used or is not an integer, such as a memory model or a lookup keyed by a string.

## 1.2 Static (Fixed-Size) Arrays

### In plain English

A static array has a size that is written in the source code and never changes. Declaring `int a [5];` creates exactly five `int` elements, numbered 0 to 4, for the whole simulation.

"Static" here means "fixed size". It is not related to the `static` keyword used for variable lifetime (Module 3) or class members (Module 4).

### Technical definition

A fixed-size array is an unpacked array whose dimension ranges are constant expressions. Its storage is allocated before simulation starts and exists for the lifetime of the variable. Each element has the default value of the element type until it is assigned.

### Syntax

```systemverilog
int         a [0:4];              // 5 elements, indices 0 to 4
int         b [5];                // C-style shorthand, identical to [0:4]
logic [7:0] mem [0:255];          // 256 elements of 8 bits (a memory)
int         c [2:6];              // 5 elements, indices 2 to 6
int         d [6:2];              // 5 elements, indices 6 down to 2
int         e [5] = '{1, 2, 3, 4, 5};        // initialised in the declaration
parameter int N = 16;
bit [3:0]   f [N];                // the size may be a parameter (a constant)
```

The size must be a constant: a literal, a `parameter`, a `localparam`, or an expression of constants. A variable is not allowed; that is what dynamic arrays are for.

### How it works internally

```text
   int a [5] = '{10, 20, 30, 40, 50};

   index :     0        1        2        3        4
            +--------+--------+--------+--------+--------+
   a        |   10   |   20   |   30   |   40   |   50   |     5 x 32 bits, allocated
            +--------+--------+--------+--------+--------+     once, before time 0

   a[3]  ->  the simulator computes (start of a) + 3 elements : direct access, no search
```

- The memory is one block whose size never changes, so access by index is the fastest of all array kinds.
- The simulator knows the bounds at compile time. An out-of-range **constant** index is usually reported at compile time; an out-of-range **variable** index is detected at run time (read returns the default value X or 0, write is ignored, normally with a warning).

### Operations on a whole fixed-size array

| Operation | Example | Notes |
|---|---|---|
| Element read / write | `a[2] = 99;` | |
| Slice (a contiguous part) | `a[1:3]` | An array of 3 elements |
| Whole-array assignment | `a = b;` | Both must have the same element type and the same number of elements |
| Assignment pattern | `a = '{1, 2, 3, 4, 5};` | One value per element |
| Default pattern | `a = '{default: 0};` | Every element |
| Comparison | `a == b`, `a != b` | Element by element; result is 1 bit |
| Number of elements | `$size(a)` | The `size()` method is **not** defined for fixed-size arrays |
| Arithmetic on the whole | `a + 1` | **Not allowed**: an unpacked array is not a number |
| Array methods | `a.sum()`, `a.sort()`, `a.find with (...)` | Part 4 of this module |

### Complete example

```systemverilog file=tb_static_array.sv
module tb_static_array;

  int         a [5];                          // indices 0 to 4
  int         b [5] = '{10, 20, 30, 40, 50};
  logic [7:0] mem [0:3];
  int         idx;

  initial begin
    $display("1. defaults: a[0]=%0d  mem[0]=%h", a[0], mem[0]);

    a    = '{default: 7};
    a[2] = 99;
    $display("2. a = %p", a);

    a    = b;                 // whole-array copy
    a[0] = -1;
    $display("3. a[0]=%0d  b[0]=%0d", a[0], b[0]);

    $display("4. a == b : %b    a[1:3] == b[1:3] : %b", a == b, a[1:3] == b[1:3]);
    $display("5. $size(a) = %0d", $size(a));

    foreach (mem[i]) mem[i] = 8'h10 + i;
    $display("6. mem[3]=%h  mem[1][0]=%b", mem[3], mem[1][0]);

    idx = 9;
    $display("7. out of range: a[9]=%0d  mem[9]=%h", a[idx], mem[idx]);
  end

endmodule
```

```output
1. defaults: a[0]=0  mem[0]=xx
2. a = '{7, 7, 99, 7, 7}
3. a[0]=-1  b[0]=10
4. a == b : 0    a[1:3] == b[1:3] : 1
5. $size(a) = 5
6. mem[3]=13  mem[1][0]=1
7. out of range: a[9]=0  mem[9]=xx
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Elements take the default of their type: `int` is two-state (0); `logic [7:0]` is four-state (X). |
| 2 | `'{default: 7}` sets all five elements. Then one element is overwritten. `%p` prints the whole array. |
| 3 | `a = b` copies all five values. The arrays stay independent: changing `a[0]` does not change `b[0]`. |
| 4 | The arrays now differ in element 0, so `a == b` is 0. The slices `[1:3]` hold 20, 30, 40 in both, so they are equal. |
| 5 | `$size` returns the number of elements. |
| 6 | `foreach` visits indices 0 to 3 and stores `10`, `11`, `12`, `13` (hex). `mem[1]` is `11` hex = `0001_0001`; its bit 0 is 1. The unpacked index comes first, then the packed bit-select. |
| 7 | Index 9 does not exist. Reading returns the default value of the element type: 0 for `int`, X for `logic`. Simulators print a warning and continue. A variable index is used here because many simulators reject an out-of-range constant index at compile time. |

> **Common mistake:** Calling `a.size()` on a fixed-size array. The `size()` method belongs to dynamic arrays, queues and associative arrays. For a fixed-size array use `$size(a)`. Some simulators accept `a.size()` as an extension, but the standard does not define it, so portable code uses `$size`.

> **Common mistake:** `int a [5]; a = 0;`. An unpacked array cannot be assigned a single number. Use `a = '{default: 0};`.

> **Verification application:** Fixed-size arrays are used where the size is a property of the design: a model of a 32-entry register file (`logic [31:0] regs [32]`), a small lookup table of expected values, an array of virtual interfaces for a DUT with a fixed number of ports (`virtual alu_if vif [4]`), or an array of per-port counters.

### Interview questions

**Q1. What is a static array?**
An unpacked array whose size is a compile-time constant. Its storage is allocated before simulation starts and cannot be resized.

**Q2. What is the difference between `int a [5];` and `int a [0:4];`?**
None. `[5]` is shorthand for `[0:4]`.

**Q3. How do you get the number of elements of a fixed-size array?**
`$size(a)`. The `size()` method is not defined for fixed-size arrays.

**Q4. Can the size of a fixed-size array be a variable?**
No. It must be a constant expression such as a literal or a parameter. Use a dynamic array when the size is known only at run time.

**Q5. What happens when you read beyond the end of a fixed-size array?**
The read returns the default value of the element type (X for four-state, 0 for two-state) and a write is ignored. The simulation continues, usually with a warning.

## 1.3 Packed Arrays and Unpacked Arrays Revisited

Module 1, Sections 3.1 and 3.2, explained the difference in detail. This section restates what matters for the rest of this module and adds the points that concern array methods.

### The two families

| Property | Packed array | Unpacked array |
|---|---|---|
| Declaration | `logic [3:0][7:0] p;` | `logic [7:0] u [4];` |
| What it is | One contiguous vector, viewed as fields | A collection of separate elements |
| Element types allowed | Bit-level types only | Any type |
| Is a number (integral) | Yes: `p + 1`, `p == 32'h0`, `p = 32'hDEADBEEF` | No |
| Size | Always fixed | Fixed, or dynamic / queue / associative |
| Printing | `%h`, `%b`, `%d` | `%p` or a loop |
| Array methods (`sum`, `sort`, `find`...) | **Not available** | Available |
| `foreach` | Allowed (iterates over the bits or fields) | Allowed |
| Query functions (`$size`, `$left`...) | Work | Work |
| Synthesizable | Yes | Fixed-size only |

> **Key point:** The built-in array methods of Part 4 apply to unpacked arrays only. `logic [7:0] v; v.sum()` is illegal. To count the ones in a vector use `$countones(v)`; to reduce a vector use the reduction operators of Module 1 (`^v`, `&v`, `|v`).

### Combining both

Most real declarations have a packed part (the width of one element) and an unpacked part (how many elements):

```systemverilog
logic [7:0] mem [0:255];         // 256 unpacked elements, each a packed byte
bit [31:0]  regs [16];           // 16 registers of 32 bits
bit [7:0]   payload [];          // dynamic array of bytes
logic [8:0] exp_q [$];           // queue of 9-bit expected results
bit [7:0]   sparse_mem [int];    // associative array of bytes
```

The index order rule from Module 1 applies to every kind: **unpacked indices first, then packed indices.** `mem[17][3]` is bit 3 of element 17.

```systemverilog file=tb_packed_vs_unpacked.sv
module tb_packed_vs_unpacked;

  logic [3:0][7:0] p;           // packed: one 32-bit vector made of 4 bytes
  logic [7:0]      u [4];       // unpacked: 4 separate bytes, indices 0 to 3

  initial begin
    p = 32'hA1B2_C3D4;                       // assign as a number
    u = '{8'hA1, 8'hB2, 8'hC3, 8'hD4};       // assign per element

    $display("1. p[3]=%h p[0]=%h   u[0]=%h u[3]=%h", p[3], p[0], u[0], u[3]);
    $display("2. p + 1 = %h", p + 1);        // legal only for the packed array

    foreach (p[i]) $write("p[%0d]=%h ", i, p[i]);
    $display("");
    foreach (u[i]) $write("u[%0d]=%h ", i, u[i]);
    $display("");

    $display("3. $bits(p)=%0d  $bits(u)=%0d  $size(p)=%0d  $size(u)=%0d",
             $bits(p), $bits(u), $size(p), $size(u));
  end

endmodule
```

```output
1. p[3]=a1 p[0]=d4   u[0]=a1 u[3]=d4
2. p + 1 = a1b2c3d5
p[3]=a1 p[2]=b2 p[1]=c3 p[0]=d4 
u[0]=a1 u[1]=b2 u[2]=c3 u[3]=d4 
3. $bits(p)=32  $bits(u)=32  $size(p)=4  $size(u)=4
```

**Explanation**

| Line | Explanation |
|---|---|
| 1 | In the packed array the dimension is `[3:0]`, so the leftmost byte of the number (`A1`) is `p[3]`. In the unpacked array the dimension is `[0:3]`, so the first value of the pattern (`A1`) is `u[0]`. The same data, opposite numbering, purely because of how each range was declared. |
| 2 | Arithmetic on the whole value is legal for `p`. `u + 1` would not compile. |
| `foreach` lines | `foreach` walks from the left bound of the declared range to the right bound: 3, 2, 1, 0 for `p`; 0, 1, 2, 3 for `u`. `$write` prints without a newline; the empty `$display` ends the line. |
| 3 | Both hold 32 bits and both have 4 elements in their first dimension. |

### Interview questions

**Q1. Can you call `sum()` or `sort()` on a packed array?**
No. Array methods are defined for unpacked arrays only. A packed array is a single integral value.

**Q2. In what order does `foreach` visit `logic [7:0] v`?**
From the left bound to the right bound of the declaration: bit 7 first, bit 0 last.

**Q3. `bit [7:0] a [4] = '{1, 2, 3, 4};` and `bit [3:0][7:0] b = {8'd1, 8'd2, 8'd3, 8'd4};`. Which element holds 1 in each?**
`a[0]` holds 1 because the assignment pattern fills the range `[0:3]` left to right. `b[3]` holds 1 because the first item of a concatenation is the most significant and the packed range is `[3:0]`.

## 1.4 Multidimensional Arrays

### In plain English

A one-dimensional array is a row of elements. A two-dimensional array is a grid: rows and columns. A three-dimensional array is a stack of grids. In SystemVerilog a multidimensional array is simply **an array whose elements are themselves arrays**.

### Technical definition

A multidimensional unpacked array is declared by writing more than one dimension after the name. Each dimension can independently be fixed-size, dynamic, a queue or associative. The dimensions are indexed left to right as written.

### Syntax

```systemverilog
int       m [2][3];              // 2 rows, 3 columns: 6 ints
int       c [4][8][2];           // 3 dimensions: 64 ints
bit [7:0] frame [10][64];        // 10 rows of 64 bytes
int       jag [][];              // dynamic array of dynamic arrays (jagged rows)
int       per_port_q [4][$];     // 4 queues
int       hist [string][int];    // associative array of associative arrays
```

### How it works internally

```text
   int m [2][3] = '{ '{1, 2, 3},
                     '{4, 5, 6} };

                 column:    0     1     2
                         +-----+-----+-----+
            m[0] (row 0) |  1  |  2  |  3  |        m[0]    is an array of 3 ints
                         +-----+-----+-----+
            m[1] (row 1) |  4  |  5  |  6  |        m[1][2] is the int 6
                         +-----+-----+-----+

   The FIRST index selects the row (the outer array).
   The SECOND index selects the element inside that row.
   $size(m, 1) = 2 (rows)        $size(m, 2) = 3 (columns)
```

For fixed-size arrays the rows all have the same length. When an inner dimension is dynamic (`int jag [][]`), each row is a separate dynamic array with its own size, so the rows can have different lengths. Such an array is called **jagged**.

```text
   int jag [][];
   jag = new[3];             // 3 rows, each still empty
   jag[0] = new[1];
   jag[1] = new[2];
   jag[2] = new[3];

        jag[0] -> [ . ]
        jag[1] -> [ . | . ]
        jag[2] -> [ . | . | . ]
```

### Initialisation with nested assignment patterns

One level of `'{ }` is needed per dimension:

```systemverilog
int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };      // row by row
int z [2][3] = '{default: 0};                    // every element
int r [2][3] = '{ '{default: 1}, '{7, 8, 9} };   // row 0 all ones, row 1 listed
int s [2][3] = '{2{ '{3{5}} }};                  // replication: every element is 5
```

### Accessing parts of a multidimensional array

| Expression | Meaning for `int m [2][3]` |
|---|---|
| `m` | The whole array, 2 × 3 |
| `m[1]` | Row 1: an array of 3 ints. Can be copied to or from an `int x [3]` |
| `m[1][2]` | One element |
| `m[0][0:1]` | A slice of row 0: 2 elements |
| `foreach (m[i, j])` | Visits every element; `i` is the row, `j` the column |
| `foreach (m[i])` | Visits every row |

### Complete example

```systemverilog file=tb_multidim.sv
module tb_multidim;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int row [3];
  int jag [][];
  int total;

  initial begin
    $display("1. m[1][2] = %0d", m[1][2]);

    row = m[0];                               // copy one whole row
    $display("2. row = %p", row);

    foreach (m[i, j]) m[i][j] = m[i][j] * 10;
    foreach (m[i]) $display("3. row %0d : %0d %0d %0d", i, m[i][0], m[i][1], m[i][2]);

    $display("4. rows = %0d, columns = %0d", $size(m, 1), $size(m, 2));

    total = 0;
    for (int i = 0; i < $size(m, 1); i++)
      for (int j = 0; j < $size(m, 2); j++)
        total += m[i][j];
    $display("5. total = %0d", total);

    m    = '{default: 0};
    m[1] = '{7, 8, 9};
    $display("6. m = %p", m);

    // jagged array: every row has a different length
    jag = new[3];
    foreach (jag[i]) begin
      jag[i] = new[i + 1];
      for (int j = 0; j < jag[i].size(); j++) jag[i][j] = i * 10 + j;
    end
    foreach (jag[i]) $display("7. jag[%0d] has %0d elements: %p", i, jag[i].size(), jag[i]);
  end

endmodule
```

```output
1. m[1][2] = 6
2. row = '{1, 2, 3}
3. row 0 : 10 20 30
3. row 1 : 40 50 60
4. rows = 2, columns = 3
5. total = 210
6. m = '{'{0, 0, 0}, '{7, 8, 9}}
7. jag[0] has 1 elements: '{0}
7. jag[1] has 2 elements: '{10, 11}
7. jag[2] has 3 elements: '{20, 21, 22}
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Row 1, column 2. |
| 2 | `m[0]` is itself an array of three ints, so it can be assigned to `row`. |
| 3 | `foreach (m[i, j])` is the multidimensional form: the loop variables are listed inside **one** pair of brackets, separated by a comma. It visits (0,0), (0,1), (0,2), (1,0), (1,1), (1,2). Each element is multiplied by 10. |
| 4 | The second argument of `$size` selects the dimension. |
| 5 | The same traversal with nested `for` loops. 10 + 20 + 30 + 40 + 50 + 60 = 210. |
| 6 | `'{default: 0}` reaches every element of every dimension. Then row 1 is replaced as a whole. |
| 7 | `jag = new[3]` creates three empty rows. Each row is then allocated with its own size, and an ordinary `for` loop bounded by `jag[i].size()` fills that row. |

> **Interview trap:** The loop is written `foreach (m[i, j])`, not `foreach (m[i][j])`. The standard defines only the first form: all loop variables inside one pair of brackets, separated by commas. Some simulators accept the second form as an extension, but it is not portable.

> **Common mistake:** Forgetting that an inner dynamic dimension must be allocated separately. After `jag = new[3];` the rows exist but each has size 0; writing `jag[0][0] = 5;` is an out-of-range write and is ignored.

> **Verification application:** Two-dimensional arrays model anything with rows and columns: a pixel frame in a video testbench (`bit [7:0] frame [HEIGHT][WIDTH]`), a set of per-channel payloads, or a memory organised in pages. A fixed array of queues, `alu_txn exp_q [4][$]`, is the usual scoreboard structure for a design with four output ports: one expected queue per port.

### Interview questions

**Q1. How do you declare and initialise a 2 × 3 array?**
`int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };`

**Q2. How do you iterate over a two-dimensional array with `foreach`?**
`foreach (m[i, j])`, with both loop variables inside one pair of brackets.

**Q3. What is the difference between `int a [2][3];` and `bit [1:0][2:0] a;`?**
The first is an unpacked two-dimensional array of six separate 32-bit ints. The second is a packed two-dimensional array: one 6-bit vector divided into two 3-bit fields.

**Q4. What is a jagged array and how do you create one?**
An array of arrays whose rows have different lengths. Declare `int j [][];`, allocate the outer dimension with `j = new[n];`, then allocate each row separately with `j[i] = new[len];`.

**Q5. How do you find the number of columns of `int m [4][7]`?**
`$size(m, 2)`, which returns 7.

## 1.5 Array Query Functions: $size, $dimensions, $left, $right, $low, $high

### In plain English

These system functions answer questions about the **shape** of an array: how many dimensions it has, how many elements a dimension has, and what its index bounds are. They let you write loops and checks that keep working when a declaration is changed.

### Technical definition

| Function | Returns |
|---|---|
| `$dimensions(arr)` | Total number of dimensions, packed and unpacked together |
| `$unpacked_dimensions(arr)` | Number of unpacked dimensions only |
| `$size(arr, dim)` | Number of elements in dimension `dim` |
| `$left(arr, dim)` | The left bound of the dimension, as written in the declaration |
| `$right(arr, dim)` | The right bound of the dimension, as written in the declaration |
| `$low(arr, dim)` | The smaller of the two bounds |
| `$high(arr, dim)` | The larger of the two bounds |
| `$increment(arr, dim)` | 1 if `$left` >= `$right`, otherwise -1 |
| `$bits(arr)` | Total number of bits in the whole array |

The `dim` argument is optional and defaults to 1.

**How dimensions are numbered:** dimension 1 is the **leftmost unpacked** dimension. Numbering continues through the remaining unpacked dimensions left to right, then through the packed dimensions left to right.

```text
        logic [3:0][7:0]  arr  [2][5];
               |     |          |  |
           dim 3   dim 4     dim 1  dim 2

        $dimensions(arr)           = 4
        $unpacked_dimensions(arr)  = 2
        $size(arr, 1) = 2     $size(arr, 2) = 5     $size(arr, 3) = 4     $size(arr, 4) = 8
```

This is the same order in which you write the indices when accessing an element: `arr[i][j][k][l]`.

### $left / $right versus $low / $high

`$left` and `$right` follow the declaration. `$low` and `$high` follow the numeric values.

| Declaration | `$left` | `$right` | `$low` | `$high` | `$increment` | `$size` |
|---|---|---|---|---|---|---|
| `logic [7:0] v` | 7 | 0 | 0 | 7 | 1 | 8 |
| `logic [0:7] v` | 0 | 7 | 0 | 7 | -1 | 8 |
| `int a [0:3]` or `int a [4]` | 0 | 3 | 0 | 3 | -1 | 4 |
| `int a [6:2]` | 6 | 2 | 2 | 6 | 1 | 5 |
| Dynamic array or queue with N elements | 0 | N-1 | 0 | N-1 | -1 | N |

Remember `$increment` like this: stepping from `$left` to `$right` means **subtracting** `$increment`. For `[7:0]` the increment is 1, and 7 - 1 = 6 moves toward 0.

### $size() versus size()

| | `$size(arr)` | `arr.size()` |
|---|---|---|
| What it is | A system function | A built-in method |
| Works on | Every array: packed, fixed-size, dynamic, queue, associative | Dynamic arrays, queues and associative arrays only |
| Can select a dimension | Yes: `$size(arr, 2)` | No: it reports the dimension it is called on (`arr[i].size()` for an inner one) |
| Typical use | Fixed-size arrays, generic code, multidimensional arrays | Dynamic arrays and queues |

For an associative array, `num()` and `size()` both return the number of entries.

### Complete example

```systemverilog file=tb_array_query.sv
module tb_array_query;

  logic [7:0]      mem  [0:3];        // dim 1 = [0:3] (unpacked), dim 2 = [7:0] (packed)
  logic [3:0][7:0] word;              // dim 1 = [3:0], dim 2 = [7:0] (both packed)
  bit [15:0]       grid [2][6:4];     // dim 1 = [0:1], dim 2 = [6:4], dim 3 = [15:0]
  int              dyn  [];

  initial begin
    $display("--- mem : logic [7:0] mem [0:3] ---");
    $display("dimensions=%0d unpacked=%0d bits=%0d",
             $dimensions(mem), $unpacked_dimensions(mem), $bits(mem));
    $display("dim 1: size=%0d left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $size(mem), $left(mem), $right(mem), $low(mem), $high(mem), $increment(mem));
    $display("dim 2: size=%0d left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $size(mem, 2), $left(mem, 2), $right(mem, 2), $low(mem, 2), $high(mem, 2),
             $increment(mem, 2));

    $display("--- word : logic [3:0][7:0] word ---");
    $display("dimensions=%0d unpacked=%0d size1=%0d size2=%0d left1=%0d",
             $dimensions(word), $unpacked_dimensions(word), $size(word, 1), $size(word, 2),
             $left(word, 1));

    $display("--- grid : bit [15:0] grid [2][6:4] ---");
    $display("dimensions=%0d size1=%0d size2=%0d size3=%0d",
             $dimensions(grid), $size(grid, 1), $size(grid, 2), $size(grid, 3));
    $display("dim 2: left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $left(grid, 2), $right(grid, 2), $low(grid, 2), $high(grid, 2),
             $increment(grid, 2));

    $display("--- dyn : int dyn [] ---");
    dyn = new[5];
    $display("size=%0d $size=%0d left=%0d right=%0d high=%0d",
             dyn.size(), $size(dyn), $left(dyn), $right(dyn), $high(dyn));
  end

endmodule
```

```output
--- mem : logic [7:0] mem [0:3] ---
dimensions=2 unpacked=1 bits=32
dim 1: size=4 left=0 right=3 low=0 high=3 increment=-1
dim 2: size=8 left=7 right=0 low=0 high=7 increment=1
--- word : logic [3:0][7:0] word ---
dimensions=2 unpacked=0 size1=4 size2=8 left1=3
--- grid : bit [15:0] grid [2][6:4] ---
dimensions=3 size1=2 size2=3 size3=16
dim 2: left=6 right=4 low=4 high=6 increment=1
--- dyn : int dyn [] ---
size=5 $size=5 left=0 right=4 high=4
```

**Explanation**

| Output line | Explanation |
|---|---|
| `mem`, first line | One unpacked dimension plus one packed dimension gives 2. Total bits 4 × 8 = 32. |
| `mem` dim 1 | The unpacked range `[0:3]`: left 0, right 3. Left is smaller than right, so increment is -1. |
| `mem` dim 2 | The packed range `[7:0]`: left 7, right 0, low 0, high 7, increment 1. |
| `word` | Both dimensions are packed, so the unpacked count is 0. Dimension 1 is `[3:0]`. |
| `grid` | Three dimensions: `[2]` means `[0:1]`, then `[6:4]`, then the packed `[15:0]`. Dimension 2 has left 6, right 4. |
| `dyn` | A dynamic array is always indexed from 0 to size-1. `$size` and the `size()` method agree. |

### Writing loops that do not depend on the declaration

```systemverilog
// Works for [0:N-1] and for [N-1:0], and for any bounds
for (int i = $low(arr); i <= $high(arr); i++) ...

// Visit in declaration order (the order foreach uses)
for (int i = $left(arr); i != $right(arr) - $increment(arr); i -= $increment(arr)) ...
```

In practice `foreach (arr[i])` does the second form for you and is what you should write. The query functions are needed when you must loop over only part of an array, loop backwards, or check a size.

> **Interview trap:** "What does `$dimensions` return for `int a [4];`?" The answer is 2, not 1. `int` is itself a 32-bit packed vector, so there is one unpacked dimension and one packed dimension. `$unpacked_dimensions(a)` is 1. The same reasoning gives `$dimensions(bit [7:0] b [4])` = 2 and `$dimensions(bit c [4])` = 1.

> **Common mistake:** Writing loops with hard-coded bounds, `for (int i = 0; i < 16; i++)`. When someone changes the array to 32 entries, the loop silently covers half of it. Use `foreach`, `$size(arr)` or `arr.size()`.

> **Verification application:** Generic checkers and utilities use the query functions so that they work for any array passed in. A common assertion in a testbench is a size check before a copy or comparison: `if ($size(actual) != $size(expected)) $error("length mismatch");`.

### Interview questions

**Q1. What is the difference between `$size` and `size()`?**
`$size` is a system function that works on any array, including packed and fixed-size arrays, and can report any dimension. `size()` is a method available only on dynamic arrays, queues and associative arrays.

**Q2. What is the difference between `$left` and `$low`?**
`$left` returns the bound written on the left in the declaration. `$low` returns the numerically smaller bound. For `logic [7:0] v`, `$left` is 7 and `$low` is 0.

**Q3. For `bit [7:0] a [2][3];`, what are `$dimensions(a)`, `$size(a)`, `$size(a, 2)`, `$size(a, 3)` and `$bits(a)`?**
3, 2, 3, 8 and 48.

**Q4. How are dimensions numbered?**
Unpacked dimensions first, left to right, starting from 1; then the packed dimensions, left to right.

**Q5. What does `$increment` return?**
1 if the left bound is greater than or equal to the right bound, and -1 otherwise.

**Q6. What do `$left`, `$right` and `$size` return for a queue with 6 elements?**
0, 5 and 6.
