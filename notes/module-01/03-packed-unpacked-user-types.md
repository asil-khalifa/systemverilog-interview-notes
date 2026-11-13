# Part 3: Packed, Unpacked and User-Defined Types

## 3.1 Packed and Unpacked Data Types

### In plain English

Think of two ways of storing eight items.

- **Packed:** the eight items are glued together into one solid block. You can treat the block as a single number (add to it, shift it, compare it), and you can also pick out individual pieces.
- **Unpacked:** the eight items sit in eight separate boxes on a shelf. You work with one box at a time. The shelf as a whole is not a number.

### Technical definition

- A **packed** type is a contiguous set of bits with a guaranteed bit order. It is an *integral* type: the whole thing can be used as one vector in arithmetic, logical, shift and comparison operations. Packed dimensions are written **before** the name.
- An **unpacked** type is a collection of separate elements. The simulator may store the elements however it likes. Only element-wise access and a few whole-aggregate operations (copy, compare) are defined. Unpacked dimensions are written **after** the name.

```text
        logic [7:0]  data  [0:3];
              -----        -----
             packed        unpacked
           dimension       dimension
        (before the name)  (after the name)

   Read it as: "data is an unpacked array of 4 elements; each element is a packed 8-bit vector".
```

### What can be packed

| Can be packed | Cannot be packed (always unpacked) |
|---|---|
| Single-bit types with dimensions: `bit [..]`, `logic [..]`, `reg [..]` | `real`, `shortreal`, `realtime` |
| Packed arrays of packed arrays: `logic [3:0][7:0]` | `string`, `event`, `chandle` |
| `enum` types | Class handles |
| `struct packed`, `union packed` (members must themselves be packed) | Dynamic arrays, queues, associative arrays |
| `byte`, `shortint`, `int`, `longint`, `integer`, `time` are already packed vectors of fixed width | Unpacked structs and unions |

### Memory representation

The standard defines the layout of packed data exactly. It does not define the layout of unpacked data; the picture below shows the typical implementation, in which every unpacked element is stored in its own machine word or words.

```text
  Packed:   bit [3:0][7:0] p;          one 32-bit vector, contiguous

      bit:  31      24 23      16 15       8 7        0
           +----------+----------+----------+----------+
           |   p[3]   |   p[2]   |   p[1]   |   p[0]   |      1 word
           +----------+----------+----------+----------+

  Unpacked: bit [7:0] u [4];           four separate elements

           +------------------------------+----------+
     u[0]  |          (unused)            |  8 bits  |      1 word
           +------------------------------+----------+
     u[1]  |          (unused)            |  8 bits  |      1 word
           +------------------------------+----------+
     u[2]  |          (unused)            |  8 bits  |      1 word
           +------------------------------+----------+
     u[3]  |          (unused)            |  8 bits  |      1 word
           +------------------------------+----------+
```

For four-state types the storage doubles (Section 2.1).

### Comparison table

| Property | Packed | Unpacked |
|---|---|---|
| Dimension position | Before the name: `logic [7:0] a;` | After the name: `logic a [8];` |
| Storage | Contiguous bits, defined order | Separate elements, layout chosen by the tool |
| Is it one number? | Yes (integral type) | No |
| Arithmetic on the whole (`a + 1`) | Yes | No |
| Bitwise / reduction / shift on the whole | Yes | No |
| Bit-select and part-select | Yes: `a[3]`, `a[7:4]` | Element select and slice: `a[3]`, `a[0:1]` |
| Assign from a number (`a = 8'hFF`) | Yes | No, needs an assignment pattern `'{...}` |
| Whole copy and `==` comparison | Yes | Yes, between arrays of the same type and size |
| Element types allowed | Only packed (bit-level) types | Any type: `int`, `real`, `string`, class handles, structs |
| Size fixed at compile time | Always | Fixed-size arrays yes; dynamic arrays, queues and associative arrays no |
| Print with | `%b`, `%h`, `%d` | `%p`, or loop over the elements |
| Synthesizable | Yes | Fixed-size arrays yes |
| Typical use | Buses, registers, bit fields | Memories, lists of transactions, lookup tables |

### Interview questions

**Q1. What is the difference between packed and unpacked?**
A packed type is one contiguous vector of bits with a defined order that can be operated on as a single integral value. An unpacked type is a collection of independent elements that are accessed individually. Packed dimensions come before the name, unpacked dimensions after.

**Q2. In `logic [7:0] mem [0:255];`, which dimension is packed?**
`[7:0]` is packed and `[0:255]` is unpacked. `mem` is an unpacked array of 256 elements, each a packed 8-bit vector. This is the standard way to model a memory.

**Q3. Can you make a packed array of `real` or `string`?**
No. Packed types must be made of bits. `real`, `string`, class handles and events can only be elements of unpacked arrays.

## 3.2 Packed Arrays and Unpacked Arrays

This section introduces fixed-size arrays as data types. Module 2 covers dynamic arrays, associative arrays, queues and all the array methods in depth.

### Packed arrays

A vector such as `logic [7:0]` is a one-dimensional packed array. Adding more packed dimensions subdivides the same vector into fields:

```systemverilog
logic [31:0]       word_a;    // 32 bits
logic [3:0][7:0]   word_b;    // the same 32 bits, viewed as 4 bytes; word_b[3] is the top byte
logic [1:0][3:0][7:0] dword;  // 64 bits: 2 words of 4 bytes of 8 bits
```

The leftmost packed dimension is the outermost subdivision, and the first-declared index (the left one in `[3:0]`) is the most significant.

### Unpacked arrays

```systemverilog
int         a1 [0:7];          // 8 ints, indices 0 to 7
int         a2 [8];            // C-style shorthand, identical to [0:7]
logic [7:0] mem [0:255];       // 256 bytes
int         grid [4][3];       // 2-dimensional: 4 rows of 3 ints
```

### Mixed arrays and index order

```systemverilog
logic [3:0][7:0] lut [2][5];
//      |    |          |  |
//      3rd  4th        1st 2nd      order in which indices are written when accessing
```

**Rule:** when accessing an element, write the unpacked indices first (left to right), then the packed indices (left to right).

```text
   lut              the whole   array: 2 x 5 elements of 32 bits
   lut[1]           one row  : 5 elements of 32 bits (unpacked array)
   lut[1][4]        one element  : a 32-bit packed value
   lut[1][4][2]     byte 2   of that element: 8 bits
   lut[1][4][2][7]  bit 7   of that byte
```

### Initialisation and assignment

| Syntax | Used for | Example |
|---|---|---|
| `{a, b, c}` | Concatenation: builds one **packed** vector | `word_a = {8'hDE, 8'hAD, 8'hBE, 8'hEF};` |
| `{4{8'hFF}}` | Replication: packed | `word_a = {4{8'hFF}};` |
| `'{a, b, c}` | Assignment pattern: one value **per element** of an unpacked array or struct | `a2 = '{0, 1, 2, 3, 4, 5, 6, 7};` |
| `'{default: v}` | Every element gets `v` | `mem = '{default: 8'h00};` |
| `'{n{v}}` | Replication inside a pattern | `a2 = '{8{0}};` |
| `'{index: v, default: w}` | Selected elements by index | `a2 = '{0: 5, 7: 9, default: 0};` |
| `'0`, `'1`, `'x`, `'z` | Fill a **packed** value of any width | `word_a = '1;` |

> **Interview trap:** `{...}` and `'{...}` are different. `{a, b}` is a concatenation: for packed data it joins bits into one vector. `'{a, b}` is an assignment pattern: it supplies one value per element of an unpacked array, or per member of a struct. For a struct, for a multi-dimensional array, and whenever you need `default:` or index keys, only `'{...}` works. Since IEEE 1800-2009 a one-dimensional unpacked array may also be written as `{1, 2, 3}` (an "unpacked array concatenation", the form normally used with queues in Module 2), but the safe habit is: `{}` for packed vectors, `'{}` for unpacked arrays and structs.

### Complete example

```systemverilog file=tb_packed_unpacked.sv
module tb_packed_unpacked;

  logic [3:0][7:0] word;       // packed: 4 bytes forming one 32-bit vector
  bit   [7:0]      mem [4];    // unpacked array of 4 packed bytes, indices 0 to 3
  bit   [7:0]      copy [4];

  initial begin
    word = 32'hDEAD_BEEF;
    $display("1. word        = %h", word);
    $display("2. word[3]     = %h   word[0] = %h", word[3], word[0]);
    $display("3. word[1:0]   = %h", word[1:0]);
    $display("4. word[2][7]  = %b", word[2][7]);
    $display("5. word + 1    = %h", word + 1);
    $display("6. $bits(word) = %0d", $bits(word));

    mem = '{8'h11, 8'h22, 8'h33, 8'h44};
    $display("7. mem[0] = %h   mem[3] = %h", mem[0], mem[3]);
    $display("8. mem[1][3:0] = %h", mem[1][3:0]);
    $display("9. $bits(mem) = %0d   $size(mem) = %0d", $bits(mem), $size(mem));

    copy = mem;                               // whole-array copy
    copy[2] = 8'h00;
    if (copy == mem) $display("10. copy == mem");
    else             $display("10. copy != mem (mem[2]=%h copy[2]=%h)", mem[2], copy[2]);

    mem = '{default: 8'hFF};
    foreach (mem[i]) $display("11. mem[%0d] = %h", i, mem[i]);
  end

endmodule
```

```output
1. word        = deadbeef
2. word[3]     = de   word[0] = ef
3. word[1:0]   = beef
4. word[2][7]  = 1
5. word + 1    = deadbef0
6. $bits(word) = 32
7. mem[0] = 11   mem[3] = 44
8. mem[1][3:0] = 2
9. $bits(mem) = 32   $size(mem) = 4
10. copy != mem (mem[2]=33 copy[2]=00)
11. mem[0] = ff
11. mem[1] = ff
11. mem[2] = ff
11. mem[3] = ff
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | A packed array is assigned from a plain 32-bit number. |
| 2 | Index 3 is the most significant byte (`DE`); index 0 is the least significant (`EF`). |
| 3 | A slice of the first packed dimension: bytes 1 and 0 together, 16 bits. Note that `word[15:8]` would be wrong here: the first dimension of `word` only has indices 3 to 0. |
| 4 | Byte 2 is `AD` = `1010_1101`; its bit 7 is 1. |
| 5 | Because `word` is packed, arithmetic on the whole value is legal. |
| 7 | `'{...}` assigns the listed values to indices 0, 1, 2, 3 in that order, because `mem [4]` means `[0:3]`. |
| 8 | Unpacked index first (`[1]` selects `22`), then a packed part-select (`[3:0]` selects the low nibble, `2`). |
| 9 | `$bits` counts all bits (4 × 8). `$size` returns the number of elements in the first dimension. |
| 10 | Unpacked arrays of the same type can be copied and compared as a whole. The copy is independent of the original. |
| 11 | `foreach` iterates over every index. Module 2 covers it in detail. |

### Reading and writing out of range

| Situation | Result |
|---|---|
| Read with an out-of-range index, four-state element type | Returns X |
| Read with an out-of-range index, two-state element type | Returns 0 |
| Read with an index containing X or Z | Returns X (four-state) or 0 (two-state) |
| Write with an out-of-range or unknown index | The write is ignored; nothing changes |

Most simulators issue a warning, not an error, and continue.

> **Common mistake:** `logic [7:0] mem [256];` and `logic [0:7] mem [256];` are both legal but number the bits in opposite directions. `[7:0]` (little-endian bit numbering, MSB has the highest index) is the convention almost everywhere. Mixing the two in one project causes bit-reversal bugs.

> **Verification application:** A reference model of a RAM in a scoreboard is usually `logic [7:0] mem [int]` (an associative array, Module 2) for large sparse memories, or a fixed unpacked array `logic [7:0] mem [0:255]` for small ones. A register's bit fields are usually a packed struct (next section) so that the same 32 bits can be handled as a whole word on the bus and as named fields in the checker.

### Interview questions

**Q1. What is the difference between `logic [7:0] a;` and `logic a [7:0];`?**
The first is a packed 8-bit vector: one integral value that supports arithmetic and can be assigned a number. The second is an unpacked array of eight separate 1-bit elements: you cannot write `a = 8'hFF` or `a + 1`.

**Q2. Declare a memory of 1024 locations, each 16 bits wide.**
`logic [15:0] mem [0:1023];` or `logic [15:0] mem [1024];`

**Q3. For `bit [3:0][7:0] a [2][3];`, how many bits in total and what is `a[1][2][3]`?**
2 × 3 × 4 × 8 = 192 bits. `a[1][2]` is one 32-bit element; `a[1][2][3]` is its most significant byte (8 bits).

**Q4. What is the difference between `{}` and `'{}`?**
`{}` is the concatenation operator and produces one packed vector. `'{}` is an assignment pattern that provides one value per element of an unpacked array or per member of a struct.

**Q5. What does `'1` mean? How is it different from `1` and `1'b1`?**
`'1` sets every bit of the target to 1, whatever its width. `1` is the 32-bit signed number one. `1'b1` is a single bit of value 1. For a 16-bit `x`: `x = '1` gives `FFFF`, while `x = 1` and `x = 1'b1` both give `0001`.

**Q6. What happens when you read `mem[300]` from a 256-entry array?**
Not a fatal error. A four-state array returns X and a two-state array returns 0, normally with a simulator warning.

## 3.3 Structures (struct)

### In plain English

An array groups values of the **same** type under one name. A structure groups values of **different** types under one name. A bus transfer has an address, some data and a read/write flag; a struct lets you carry all three around as one object called, say, `req`, and refer to the parts as `req.addr`, `req.data` and `req.write`.

### Technical definition

A `struct` is a user-defined aggregate data type consisting of named **members** (also called fields), each with its own data type. A struct is **unpacked by default**. Adding the keyword `packed` makes it a packed struct, which is a single vector with named sub-fields.

### Why it is needed

Without structs, related signals are separate variables. Passing them to a function means a long argument list, copying them means several assignments, and adding a field means editing every place they are used. A struct turns them into one unit that can be copied with one assignment, passed as one argument, and passed through a module port as one signal.

### Syntax

```systemverilog
// Unpacked struct (default): members may be of any type
typedef struct {
  int       id;
  bit [7:0] data;
  string    name;
  real      delay_ns;
} item_t;

// Packed struct: members must be packed types; the whole struct is one vector
typedef struct packed {
  logic [3:0] kind;     // most significant field  : bits [15:12]
  logic [3:0] len;      //                           bits [11:8]
  logic [7:0] addr;     // least significant field : bits [7:0]
} hdr_t;

item_t item;            // variables of the new types
hdr_t  hdr;
```

A struct is nearly always declared through `typedef`, so that the type has a name that can be reused for variables, ports and function arguments.

### How it works internally

```text
  Packed struct hdr_t  (16 bits, one vector)

      bit:  15      12 11       8 7                 0
           +----------+----------+-------------------+
           |   kind   |   len    |       addr        |
           +----------+----------+-------------------+
            first member = most significant bits

      hdr          is a 16-bit value   (hdr = 16'hA5C3 is legal)
      hdr.len      is bits [11:8]
      hdr[7:0]     is the same as hdr.addr

  Unpacked struct item_t  (separate members, no defined bit layout)

           +------------------+
           | id       : int   |
           +------------------+
           | data     : 8 bit |
           +------------------+
           | name     : string|
           +------------------+
           | delay_ns : real  |
           +------------------+

      item         is NOT a number; only item.<member> access, whole copy, and == / !=
```

**Rule:** in a packed struct, the **first** member declared occupies the **most significant** bits.

If any member of a packed struct is four-state, the whole struct is four-state. A packed struct is unsigned unless declared `struct packed signed`.

### Packed versus unpacked struct

| Property | Packed struct | Unpacked struct |
|---|---|---|
| Keyword | `struct packed` | `struct` |
| Member types | Only packed types (bits, vectors, enums, packed structs) | Any type (`int`, `real`, `string`, arrays, class handles) |
| Is one vector | Yes | No |
| Assign from / to a vector | Yes: `hdr = 16'hA5C3;` | No |
| Bit-select / part-select on the whole | Yes: `hdr[7:0]` | No |
| Arithmetic on the whole | Yes | No |
| `$bits()` | Sum of member widths | Sum of member widths if all members are fixed-size |
| Member default values in the typedef | Not allowed | Allowed: `int id = 1;` |
| Synthesizable | Yes | Yes with synthesizable member types |
| Typical use | Protocol headers, register fields, instruction formats, struct-typed RTL ports | Grouping mixed-type testbench data, configuration records |

### Complete example

```systemverilog file=tb_struct.sv
module tb_struct;

  typedef struct packed {
    logic [3:0] kind;
    logic [3:0] len;
    logic [7:0] addr;
  } hdr_t;

  typedef struct {
    int       id;
    bit [7:0] data;
    string    name;
    real      delay_ns;
  } item_t;

  hdr_t  hdr;
  item_t item, item_copy;

  initial begin
    // ---------------- packed struct ----------------
    hdr = 16'hA5C3;
    $display("1. kind=%h len=%h addr=%h", hdr.kind, hdr.len, hdr.addr);

    hdr.len = 4'hF;
    $display("2. hdr=%h  hdr[7:0]=%h  $bits(hdr)=%0d", hdr, hdr[7:0], $bits(hdr));

    hdr = '{kind: 4'h1, len: 4'h2, addr: 8'h34};
    $display("3. hdr=%h", hdr);

    hdr = '{default: '0};
    $display("4. hdr=%h", hdr);

    // ---------------- unpacked struct ----------------
    item = '{id: 7, data: 8'hAB, name: "pkt", delay_ns: 1.5};
    item_copy    = item;        // copies every member
    item_copy.id = 8;
    $display("5. item.id=%0d  item_copy.id=%0d", item.id, item_copy.id);

    if (item == item_copy) $display("6. structs are equal");
    else                   $display("6. structs differ");

    $display("7. item = %p", item);
  end

endmodule
```

```output
1. kind=a len=5 addr=c3
2. hdr=afc3  hdr[7:0]=c3  $bits(hdr)=16
3. hdr=1234
4. hdr=0000
5. item.id=7  item_copy.id=8
6. structs differ
7. item = '{id:7, data:'hab, name:"pkt", delay_ns:1.5}
```

The exact text printed by `%p` on line 7 differs slightly between simulators (spacing, number format); the content is the same.

**Line by line**

| Line | Explanation |
|---|---|
| `hdr = 16'hA5C3;` | A packed struct accepts a plain vector. `A` goes to `kind` (the first, most significant member), `5` to `len`, `C3` to `addr`. |
| `hdr.len = 4'hF;` | Writes one member. The vector becomes `AFC3`. |
| `hdr[7:0]` | A part-select on the struct as a vector, equal to `hdr.addr`. |
| `'{kind: ..., len: ..., addr: ...}` | Assignment pattern with member names. Order does not matter when names are given. Positional form `'{4'h1, 4'h2, 8'h34}` also works, in declaration order. |
| `'{default: '0}` | Every member is set to zero. |
| `item_copy = item;` | Assigning a struct copies all of its members. A struct variable holds the data itself (unlike a class handle, which holds a reference; see Module 4). Changing `item_copy.id` does not affect `item`. |
| `item == item_copy` | Unpacked structs of the same type can be compared member by member with `==` and `!=`. |
| `%p` | Prints an aggregate in assignment-pattern form. Very useful for debug. |

### Struct versus class (a preview of Module 4)

| Property | `struct` | `class` |
|---|---|---|
| Nature | Static data container | Dynamic object |
| Memory allocation | When the variable is declared | When `new()` is called |
| A variable holds | The data itself | A handle (reference) to an object |
| Assignment `a = b` | Copies all the data | Copies only the handle; both names then refer to one object |
| Methods (functions, tasks) | Not allowed | Allowed |
| Constraints and `randomize()` | No `randomize()` method and no constraint blocks of its own. It can be randomized as a `rand` property of a class | Yes |
| Inheritance, polymorphism | No | Yes |
| Synthesizable | Yes | No |
| Typical use | RTL signal bundles, bit fields | Transactions and all testbench components |

> **Common mistake:** Putting an `int`, `string` or `real` member in a packed struct. All members of a packed struct must be packed types. (`int` is allowed because it is a 32-bit packed type; `string` and `real` are not.)

> **Common mistake:** Forgetting the member order rule. If a 16-bit header arrives on a bus as `{kind, len, addr}`, the struct must declare `kind` first. Declaring the members in the reverse order silently swaps the fields.

> **Verification application:** RTL designers define bus request and response types as packed structs in a package. The testbench imports the same package, so the monitor can write `hdr_t h = hdr_t'(vif.data);` and read named fields, instead of using error-prone part-selects like `vif.data[11:8]`.

### Interview questions

**Q1. What is a struct?**
A user-defined type that groups several members of possibly different types under one name. Members are accessed with the dot operator.

**Q2. What is the difference between a packed and an unpacked struct?**
A packed struct is stored as one contiguous vector with the first member in the most significant bits, so it can be assigned from a vector, sliced and used in arithmetic; all its members must be packed types. An unpacked struct is a collection of separate members of any type and supports only member access, whole copy and equality comparison. Structs are unpacked by default.

**Q3. In a packed struct, which member is in the MSBs?**
The first one declared.

**Q4. Is a struct synthesizable?**
Yes. Packed structs are fully synthesizable and widely used in RTL. Unpacked structs are synthesizable when their members are.

**Q5. What is the difference between a struct and a class?**
A struct is a static grouping of data with no methods, and a struct variable contains the data. A class is created dynamically with `new`, is accessed through a handle, and supports methods, randomization with constraints, inheritance and polymorphism. Structs are synthesizable; classes are not.

**Q6. How do you initialise all members of a struct to zero?**
`s = '{default: 0};` For a packed struct `s = '0;` also works.

## 3.4 Unions (union)

### In plain English

A struct gives each member its own storage; all members exist side by side. A union gives all members the **same** storage; they are different ways of looking at the same bits. Writing through one member changes what you read through every other member.

### Technical definition

A `union` is a user-defined type whose members all share one storage location. At any time it holds a single value, which can be read or written through any member.

- A **packed union** is one vector. All members must be packed types of **exactly the same width**. Reading through a different member than the one written is well defined: you see the same bits reinterpreted.
- An **unpacked union** may have members of any type and different sizes. The standard does not define the result of reading a member other than the one most recently written (except in special cases), so the behaviour depends on the simulator.
- A **tagged union** additionally stores a tag that records which member is currently valid, and the tool checks every access against the tag.

### Why it is needed

The same bits often have several meaningful interpretations:

- A 32-bit instruction is a whole word on the bus, four bytes in a memory model, and `{opcode, operand}` to the decoder.
- A register is a 32-bit value on the bus and a set of named fields in the checker.
- A data channel carries a different packet format depending on a type field.

A packed union lets one variable be accessed in every one of these forms with no shifting, masking or casting.

### Syntax

```systemverilog
typedef union packed {
  logic [31:0]     word;                 // view 1: one 32-bit value
  logic [3:0][7:0] bytes;                // view 2: four bytes
  struct packed {
    logic [7:0]  opcode;                 // view 3: instruction fields
    logic [23:0] operand;
  } instr;
} reg_view_u;
```

### How it works internally

```text
  Packed union reg_view_u  (32 bits of storage, shared by all three members)

      bit:   31        24 23        16 15         8 7          0
            +------------+------------+------------+------------+
   word     |                      word[31:0]                   |
            +------------+------------+------------+------------+
   bytes    |  bytes[3]  |  bytes[2]  |  bytes[1]  |  bytes[0]  |
            +------------+------------+------------+------------+
   instr    |   opcode   |              operand                 |
            +------------+--------------------------------------+

   One set of bits. Three names for it.
   $bits(reg_view_u) = 32   (the width of one member, not the sum)

  For comparison, a struct with the same three members would occupy 32 + 32 + 32 = 96 bits.
```

### Complete example

```systemverilog file=tb_union.sv
module tb_union;

  typedef union packed {
    logic [31:0]     word;
    logic [3:0][7:0] bytes;
    struct packed {
      logic [7:0]  opcode;
      logic [23:0] operand;
    } instr;
  } reg_view_u;

  reg_view_u u;

  initial begin
    u.word = 32'h12_345678;
    $display("1. word    = %h", u.word);
    $display("2. bytes   = %h %h %h %h", u.bytes[3], u.bytes[2], u.bytes[1], u.bytes[0]);
    $display("3. opcode  = %h   operand = %h", u.instr.opcode, u.instr.operand);

    u.bytes[0] = 8'hFF;                  // write through one view...
    $display("4. word    = %h", u.word); // ...and read through another

    u.instr.opcode = 8'hA0;
    $display("5. word    = %h", u.word);

    $display("6. $bits   = %0d", $bits(u));
  end

endmodule
```

```output
1. word    = 12345678
2. bytes   = 12 34 56 78
3. opcode  = 12   operand = 345678
4. word    = 123456ff
5. word    = a03456ff
6. $bits   = 32
```

**Line by line**

| Line | Explanation |
|---|---|
| `u.word = 32'h12_345678;` | Writes all 32 shared bits. |
| Lines 2, 3 | The same bits read as four bytes, and as an 8-bit opcode plus a 24-bit operand. Nothing was copied or converted. |
| `u.bytes[0] = 8'hFF;` | Changes only the lowest 8 of the shared bits. `u.word` shows the change because it is the same storage. |
| `u.instr.opcode = 8'hA0;` | Changes the top 8 bits. |
| `$bits(u)` | 32: the size of the union is the size of one member, because they overlap. |

### Tagged unions (awareness level)

```systemverilog
typedef union tagged {
  void        Invalid;          // a member with no data
  logic [7:0] Data;
} maybe_byte_t;

maybe_byte_t m;

initial begin
  m = tagged Data 8'h5A;        // stores the value and sets the tag to "Data"
  case (m) matches
    tagged Invalid : $display("no value");
    tagged Data .d : $display("value = %h", d);
  endcase
end
```

A tagged union is type-safe: reading a member that does not match the current tag is a run-time error. Support for tagged unions and pattern matching varies between tools, and they are rare in production code, so it is enough to know that they exist and what problem they solve.

### Struct versus union

| Property | `struct` | `union` |
|---|---|---|
| Storage | Each member has its own storage | All members share one storage |
| Total size | Sum of all member sizes | Size of one member (packed: all members equal) |
| Members valid at the same time | All | One value, seen through any member |
| Writing one member | Does not affect the other members | Changes what every other member reads |
| Purpose | Group different pieces of data together | View the same data in different formats |
| Packed form rule | Members must be packed types | Members must be packed types **of equal width** |
| Synthesizable | Yes | Packed unions yes |

> **Common mistake:** Declaring a packed union with members of different widths, for example `logic [31:0] word; logic [7:0] b;`. This is a compile error. Pad the narrow member inside a packed struct so the widths match.

> **Common mistake:** Using an unpacked union to convert between types (for example writing an `int` member and reading a `shortreal` member). The result is not defined by the standard. Use a packed union, a cast, or `$realtobits`/`$bitstoreal`.

> **Verification application:** A register model stores each register as a packed union of `logic [31:0] value` and a packed struct of fields. The bus monitor writes `reg.value = bus_data;` and the checker reads `reg.fields.enable`. One variable serves both the bus view and the functional view.

### Interview questions

**Q1. What is a union?**
A user-defined type in which all members share the same storage, so the same bits can be accessed under different names and formats.

**Q2. What is the difference between a struct and a union?**
In a struct each member has separate storage and the total size is the sum of the members. In a union all members overlap, the size is that of one member, and writing one member changes all the others.

**Q3. What is the restriction on a packed union?**
Every member must be a packed type and all members must have the same number of bits.

**Q4. What is a tagged union?**
A union that also stores a tag identifying the currently valid member. Values are written with the `tagged` keyword and the simulator checks that reads use the matching member, which makes the union type-safe.

**Q5. Give a practical use of a union.**
Viewing a register or instruction word both as a single vector and as named fields; viewing a word as bytes for a byte-oriented memory model; a data bus that carries different packet formats.

## 3.5 Enumerated Data Types (enum)

### In plain English

Hardware is full of small numbers that stand for something: state 0 means idle, state 1 means fetch; opcode 3 means OR. Writing the raw numbers makes code and waveforms unreadable, and nothing stops you from assigning state 7 when only four states exist. An **enumeration** gives each legal value a name and makes the compiler enforce that only those names are assigned.

### Technical definition

An `enum` declares a data type whose legal values are a set of **named constants**. Each name has an integral value of an underlying **base type**. If no base type is given it is `int`. If no values are given, the first name is 0 and each following name is one more than the previous one.

### Why it is needed

| Without enum | With enum |
|---|---|
| `parameter IDLE = 2'b00, FETCH = 2'b01;` and `logic [1:0] state;` | `typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;` and `state_e state;` |
| Waveform shows `2'b01` | Waveform shows `FETCH` |
| `state = 2'b11;` or any other number is accepted | Assigning a plain number is a compile error |
| `$display` prints a number | `state.name()` prints `"FETCH"` |
| Adding a state means renumbering by hand | Values are assigned automatically |
| Coverage bins and random values must be listed by hand | Coverage creates one bin per name; `randomize()` generates only named values |

### Syntax

```systemverilog
// 1. Simplest form: base type int, values 0, 1, 2
enum {RED, GREEN, BLUE} light;                         // an anonymous enum variable

// 2. With typedef (the normal way) and an explicit base type
typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;

// 3. With explicit values
typedef enum bit [2:0] {RD = 3'b001, WR = 3'b010, RST = 3'b100} cmd_e;

// 4. Mixed: unassigned names continue from the previous value
typedef enum {A = 5, B, C, D = 20, E} mix_e;          // A=5 B=6 C=7 D=20 E=21

// 5. Ranges of names
typedef enum {S[3]}        r1_e;     // S0, S1, S2          = 0, 1, 2
typedef enum {T[2:4]}      r2_e;     // T2, T3, T4          = 0, 1, 2
typedef enum {U[2] = 8}    r3_e;     // U0 = 8, U1 = 9
```

### Rules for values

| Rule | Example of a violation |
|---|---|
| Every name must have a unique value | `enum {A = 1, B, C = 2}`: `B` is automatically 2, which collides with `C` → error |
| Every value must fit in the base type | `enum bit [1:0] {A, B, C, D, E}`: `E` would be 4, which needs 3 bits → error |
| X or Z values are allowed only with a four-state base type, and a name following an X/Z value must be given an explicit value | `enum bit [1:0] {A = 2'bxx}` → error |
| Names must be unique within their scope | Two enums in the same module both containing `IDLE` → error. Use prefixes, or put the types in different packages or classes |

### How it works internally

An enum variable is stored exactly like a variable of its base type; `state_e` above is two four-state bits. The names are constants known to the compiler and to the debugger. The default value of an enum variable is the default of the base type: **0 for a two-state base, X for a four-state base**, whether or not that value has a name.

```text
   typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;

      name      value      stored bits
      -----     -----      -----------
      IDLE        0            00
      FETCH       1            01
      EXEC        2            10
      DONE        3            11
```

### Built-in methods

| Method | Returns |
|---|---|
| `first()` | The first member of the enumeration |
| `last()` | The last member |
| `next(N)` | The Nth next member (default N = 1). Wraps around from the last to the first |
| `prev(N)` | The Nth previous member (default N = 1). Wraps around from the first to the last |
| `num()` | The number of members |
| `name()` | The name of the current value as a `string`. Returns an empty string `""` if the value matches no member |

### Type-checking rules

| Operation | Legal? | Explanation |
|---|---|---|
| `state = FETCH;` | Yes | Assigning a member of the same enum |
| `state = other_state;` | Yes | Same enum type |
| `int i = state;` | Yes | Enum → integer conversion is automatic |
| `i = state + 1;` | Yes | In an expression the enum is used as its base-type value; the result is an integer |
| `state = 1;` | **No** | Integer → enum needs a cast |
| `state = state + 1;` | **No** | The right-hand side is an integer |
| `state++;` | **No** (strictly) | Same reason; some simulators accept it with a warning |
| `state = state_e'(1);` | Yes | Static cast; **no check** that the value is a legal member |
| `$cast(state, 1);` | Yes | Dynamic cast; **checks** at run time that the value is a legal member |
| `state = state.next();` | Yes | The proper way to step to the next member |

### Complete example

```systemverilog file=tb_enum.sv
module tb_enum;

  typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;
  typedef enum {RED = 1, GREEN = 2, BLUE = 4}        color_e;

  state_e state;
  color_e color;
  int     raw;

  initial begin
    $display("1. default state = %b, name = '%s'", state, state.name());
    $display("2. default color = %0d, name = '%s'", color, color.name());

    $display("3. state_e has %0d members:", state.num());
    state = state.first();
    do begin
      $display("     %-5s = %0d", state.name(), state);
      state = state.next();
    end while (state != state.first());

    state = DONE;
    state = state.next();
    $display("4. next of DONE    = %s", state.name());
    state = state.prev(2);
    $display("5. prev(2) of IDLE = %s", state.name());

    raw = 2;
    if ($cast(color, raw))  $display("6. $cast of 2 succeeded: %s", color.name());
    raw = 3;
    if (!$cast(color, raw)) $display("7. $cast of 3 failed, color is still %s", color.name());

    color = color_e'(raw);
    $display("8. static cast of 3: value = %0d, name = '%s'", color, color.name());

    color = BLUE;
    raw   = color + 1;
    $display("9. BLUE + 1 = %0d", raw);
  end

endmodule
```

```output
1. default state = xx, name = ''
2. default color = 0, name = ''
3. state_e has 4 members:
     IDLE  = 0
     FETCH = 1
     EXEC  = 2
     DONE  = 3
4. next of DONE    = IDLE
5. prev(2) of IDLE = EXEC
6. $cast of 2 succeeded: GREEN
7. $cast of 3 failed, color is still GREEN
8. static cast of 3: value = 3, name = ''
9. BLUE + 1 = 5
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | The base type is `logic [1:0]` (four-state), so the variable starts as `xx`. X matches no member, so `name()` returns an empty string. |
| 2 | The base type is `int`, so the variable starts at 0. But 0 is not a member of `color_e` (the members are 1, 2 and 4). The variable holds an illegal value and `name()` returns an empty string. This is a classic trap. |
| 3 | The `do`...`while` loop visits every member exactly once: start at `first()`, step with `next()`, stop when `next()` has wrapped around to `first()` again. |
| 4 | `next()` wraps from the last member to the first. |
| 5 | `prev(2)` steps back twice: `IDLE` → `DONE` → `EXEC`. |
| 6 | `$cast` used as a function returns 1 on success and performs the assignment. 2 is the value of `GREEN`. |
| 7 | 3 is not a member. `$cast` returns 0 and leaves `color` unchanged. |
| 8 | The static cast does no checking. `color` now holds 3, an out-of-range value with no name. |
| 9 | Using an enum in arithmetic gives a plain integer (4 + 1 = 5), which may be stored in an `int` but not back into the enum without a cast. |

> **Interview trap:** How do you loop over all members of an enum? The obvious loop
> `for (state = state.first(); state <= state.last(); state = state.next())`
> never terminates. After the last member, `next()` wraps to the first, so the condition is always true. Use the `do`...`while` loop from the example, or loop a counter from 0 to `num()-1` and call `next()` inside.

> **Interview trap:** "What is the default value of an enum variable?" It is the default of the base type (0 for `int`), **not** the first member. If the first member is not 0, the variable starts with an illegal value. Good practice: let the first (reset/idle) member have the value 0.

### Enums in RTL: a state machine

```systemverilog
typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;
state_e state, next_state;

always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) state <= IDLE;
  else        state <= next_state;

always_comb begin
  next_state = state;                       // default: stay
  unique case (state)
    IDLE : if (start) next_state = FETCH;
    FETCH:            next_state = EXEC;
    EXEC :            next_state = DONE;
    DONE :            next_state = IDLE;
  endcase
end
```

Enums are synthesizable. The waveform viewer shows `IDLE`, `FETCH`... instead of numbers, which is a large practical benefit when debugging.

> **Verification application:** In the ALU testbench the opcode field of the transaction is `rand alu_op_e op;`. The solver then generates only the eight legal opcodes. A coverpoint on `op` automatically gets one bin per name. Log messages print `op.name()`. The scoreboard's reference model is a `case (op)` on the names.

### Interview questions

**Q1. What is an enum and why is it used?**
A data type with a fixed set of named values. It makes code and waveforms readable and adds type safety: only declared names may be assigned without a cast.

**Q2. What is the default base type and what are the default values?**
The base type is `int`. The first name is 0 and each following name is the previous value plus one.

**Q3. What is the default value of an enum variable?**
The default value of its base type: 0 for a two-state base, X for a four-state base. It is not necessarily a legal member.

**Q4. What are the enum methods?**
`first()`, `last()`, `next()`, `prev()`, `num()` and `name()`.

**Q5. Can you assign an integer to an enum variable?**
Not directly; it is a compile error. Use a static cast `state_e'(value)`, which does not check the value, or `$cast(state, value)`, which checks at run time that the value is a member.

**Q6. What does `name()` return for a value that is not a member?**
An empty string.

**Q7. `typedef enum {A = 1, B, C = 2} t;` Is this legal?**
No. `B` automatically gets the value 2, and `C` is also 2. Enum values must be unique.

**Q8. `typedef enum bit [1:0] {A, B, C, D, E} t;` Is this legal?**
No. Five members need values 0 to 4, and 4 does not fit in 2 bits.

**Q9. How do you print the name of an enum value?**
`$display("%s", var.name());`. `%p` also prints the name in most simulators. `%d` prints the numeric value.

**Q10. Can two enums in the same scope share a member name?**
No, names must be unique in a scope. Give the names a prefix (`ALU_ADD`, `BUS_IDLE`) or declare the enums in different packages or classes.

## 3.6 typedef

### In plain English

`typedef` gives a new name to a type. It does not create any storage. After `typedef logic [7:0] byte_t;` you can write `byte_t x;` wherever you would have written `logic [7:0] x;`.

### Why it is needed

1. **Readability and single point of change.** If the address width is defined once as `typedef logic [31:0] addr_t;`, changing to 64 bits is a one-line edit.
2. **Naming complex types.** Enums, structs and unions need a name to be reused for several variables, ports and arguments.
3. **Where the language requires a simple type name.** A function cannot directly return an unpacked array type, and a cast needs a type name; both are solved by a `typedef`.
4. **Forward declaration.** Two classes that refer to each other need one of them to be announced before it is defined.
5. **Short names for parameterized classes.** `typedef mailbox #(alu_txn) txn_mbx_t;`

### Syntax and forms

```systemverilog
// 1. Alias for a built-in type
typedef logic [7:0]  byte_t;
typedef int unsigned uint_t;

// 2. Enum, struct and union types (seen in the previous sections)
typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;
typedef struct packed { logic [3:0] kind; logic [3:0] len; logic [7:0] addr; } hdr_t;

// 3. Array types: the dimension goes after the new type name, as in a variable declaration
typedef byte_t     mem_t  [0:255];     // unpacked array type: 256 bytes
typedef bit [7:0]  byte_q_t [$];       // queue-of-bytes type        (Module 2)
typedef int        int_da_t [];        // dynamic-array-of-int type  (Module 2)

// 4. Forward declaration of a class                              (Module 4)
typedef class driver;

// 5. Alias for a specialisation of a parameterized class         (Modules 7 and 11)
// typedef mailbox #(alu_txn) txn_mbx_t;
```

### Complete example

```systemverilog file=tb_typedef.sv
module tb_typedef;

  typedef logic [7:0] byte_t;
  typedef byte_t      buf_t [4];                  // array type: 4 bytes
  typedef enum bit {READ, WRITE} dir_e;
  typedef struct {
    dir_e  dir;
    byte_t addr;
    buf_t  payload;
  } xfer_t;

  // A function can return an array only through a typedef name
  function automatic buf_t make_ramp(byte_t start);
    buf_t result;
    foreach (result[i]) result[i] = start + i;
    return result;
  endfunction

  xfer_t x;

  initial begin
    x.dir     = WRITE;
    x.addr    = 8'h40;
    x.payload = make_ramp(8'h10);
    $display("dir=%s addr=%h", x.dir.name(), x.addr);
    foreach (x.payload[i]) $display("payload[%0d] = %h", i, x.payload[i]);
    $display("$bits(byte_t) = %0d, $bits(buf_t) = %0d", $bits(byte_t), $bits(buf_t));
  end

endmodule
```

```output
dir=WRITE addr=40
payload[0] = 10
payload[1] = 11
payload[2] = 12
payload[3] = 13
$bits(byte_t) = 8, $bits(buf_t) = 32
```

**Line by line**

| Line | Explanation |
|---|---|
| `typedef logic [7:0] byte_t;` | A name for an 8-bit four-state vector. |
| `typedef byte_t buf_t [4];` | A name for "unpacked array of 4 `byte_t`". Types can be built from other user-defined types. |
| `typedef enum bit {READ, WRITE} dir_e;` | A 1-bit enum: `READ` = 0, `WRITE` = 1. |
| `typedef struct {...} xfer_t;` | A struct type using the three types above. |
| `function automatic buf_t make_ramp(...)` | The return type is an array. Writing `function logic [7:0] [4] ...` is not possible; the typedef makes it legal. Functions are covered in Module 3. |
| `x.payload = make_ramp(8'h10);` | The returned array is copied into the struct member. |
| `$bits(byte_t)` | `$bits` accepts a type name as well as a variable. |

### typedef compared with related constructs

| Construct | Creates | Example | Notes |
|---|---|---|---|
| `typedef` | A new name for a type | `typedef logic [7:0] byte_t;` | Scoped and type-checked. No storage |
| `` `define `` | A text substitution | `` `define BYTE logic [7:0] `` | Global, no scope, no checking, hard to debug. Avoid for types |
| `parameter` / `localparam` | A named constant **value** | `parameter int WIDTH = 8;` | Names a value, not a type |
| `parameter type` | A type that can be overridden per instance | `module fifo #(parameter type T = logic [7:0])` | Makes a module or class generic (Module 11) |

Naming conventions used in industry: `_t` for general types, `_e` for enums, `_s` for structs and `_u` for unions. Typedefs shared between files are placed in a package.

> **Common mistake:** Declaring the same `typedef` in two modules and then connecting the two modules through a port of that type. Two separately declared structs or enums are *different types* even if they are written identically, and tools may reject the connection. Declare the type once in a package and import it in both places.

### Interview questions

**Q1. What is `typedef`?**
A statement that creates a new name for an existing or user-defined data type. It allocates no storage.

**Q2. Why use `typedef` instead of `` `define ``?**
A `typedef` is a real type known to the compiler: it obeys scope rules, can be placed in a package, is type-checked, and works with casting and `$bits`. A `` `define `` is blind text replacement with global visibility.

**Q3. What is a forward typedef and when is it needed?**
`typedef class B;` tells the compiler that `B` is a class that will be defined later. It is needed when class `A` contains a handle of class `B` and class `B` contains a handle of class `A`, or simply when a class is used before its definition appears in the file.

**Q4. How do you write a function that returns an array?**
Create a `typedef` for the array type and use that name as the function's return type.

**Q5. Where should shared typedefs be placed?**
In a package, which is then imported by every module, interface and class that needs them.
