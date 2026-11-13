# Part 3: Associative Arrays and Choosing an Array Type

## 3.1 Associative Arrays

### In plain English

Every array so far uses a small, contiguous range of integers as its index: 0, 1, 2, and so on. That fails in two situations.

1. **The index range is huge but only a few entries are used.** A design has a 32-bit address bus, so its memory has about four billion locations. A test writes to perhaps fifty of them. Declaring `logic [7:0] mem [4294967296]` would need gigabytes; the simulation would not even start.
2. **The natural index is not a number.** You want to look up a count by the *name* of an operation, or find a transaction by an ID, or store a setting under a string key.

An associative array solves both. It works like a dictionary or a phone book: you store a value under a **key**, and later look it up with the same key. Only the keys you actually store take up memory. The key can be a number, a string, or other types.

### Technical definition

An associative array is an unpacked array whose index type is specified in the declaration, and whose elements are allocated individually when they are first written. It implements a lookup table from a **key** (index) to a **value** (element). Entries are kept in the sorted order of their keys, and the built-in methods traverse them in that order.

Other languages call this structure a map, a dictionary or a hash.

### Syntax

```systemverilog
// data_type  name [index_type];
int         count   [string];          // key: string,           value: int
logic [7:0] mem     [bit [31:0]];      // key: 32-bit address,   value: byte
bit [8:0]   exp     [int];             // key: int (signed),     value: 9-bit result
int         hist    [alu_op_e];        // key: an enum,          value: int
alu_txn     pending [int];             // key: int,              value: class handle
int         wild    [*];               // key: any integral value ("wildcard" index)

// initialisation with an assignment pattern of key : value pairs
int level [string] = '{"low": 1, "mid": 5, "high": 9};
int dflt  [string] = '{"a": 1, default: -1};    // default: value returned for missing keys
```

The wildcard form `[*]` accepts any integral key of any width but has restrictions (it cannot be used with `foreach`, and the traversal methods are awkward), so it is avoided in practice. Always name a specific index type.

### Methods

| Method | Prototype | What it does |
|---|---|---|
| `num()` | `function int num();` | Number of entries |
| `size()` | `function int size();` | Same as `num()` |
| `exists(key)` | `function int exists(input index);` | 1 if an entry with this key exists, otherwise 0 |
| `delete(key)` | `function void delete(input index);` | Removes that one entry. No effect if it does not exist |
| `delete()` | `function void delete();` | Removes all entries |
| `first(key)` | `function int first(ref index);` | Sets `key` to the **smallest** key. Returns 1, or 0 if the array is empty |
| `last(key)` | `function int last(ref index);` | Sets `key` to the **largest** key. Returns 1, or 0 if the array is empty |
| `next(key)` | `function int next(ref index);` | Sets `key` to the next key **after** its current value. Returns 1, or 0 if there is none (then `key` is unchanged) |
| `prev(key)` | `function int prev(ref index);` | Sets `key` to the previous key **before** its current value. Returns 1, or 0 if there is none (then `key` is unchanged) |

The four traversal methods have an unusual shape that interviewers like to test:

- Their **argument is an output**. You pass a variable; the method writes a key into it.
- Their **return value is a status** (found or not found), not the key and not the value.

### Reading, writing and existence

| Action | Result |
|---|---|
| Write `aa[key] = v;` when the key does not exist | The entry is created |
| Write when the key exists | The value is replaced |
| Read `aa[key]` when the key exists | The stored value |
| Read `aa[key]` when the key does **not** exist | The default value of the element type (0, X, `""`, `null`), usually with a warning. **No entry is created** |
| `aa[key]++` or `aa[key] += n` when the key does not exist | The entry is created with the default value, then the operation is applied |
| `aa.exists(key)` | The only reliable way to ask whether an entry is present |

If the declaration's initialiser contains `default: value`, reading a missing key returns that value without a warning.

### Order of the keys

Entries are always traversed in sorted key order, regardless of the order in which they were written:

| Index type | Order |
|---|---|
| Unsigned integral (`bit [31:0]`, `int unsigned`) | Numerically increasing |
| Signed integral (`int`, `integer`, `byte`) | Numerically increasing, **negative keys first** |
| `string` | Lexicographic (dictionary) order by character code: `"B"` comes before `"a"` |
| Enum | By the numeric value of the members |
| Class handle | An order exists and is consistent within a run, but it is arbitrary |

### How it works internally

```text
   int score [string];

   score["ravi"] = 82;
   score["anu"]  = 95;
   score["zoya"] = 71;
   score["maya"] = 88;

   What is stored: 4 separate (key, value) entries, kept sorted by key

        key        value
      +--------+--------+
      | "anu"  |   95   |   <- first()
      +--------+--------+
      | "maya" |   88   |
      +--------+--------+
      | "ravi" |   82   |
      +--------+--------+
      | "zoya" |   71   |   <- last()
      +--------+--------+

   score["tom"]         -> not found : returns 0, nothing is added
   score.exists("tom")  -> 0
   score.num()          -> 4
```

The standard does not fix the data structure; simulators use a balanced tree or a hash table combined with ordering. What matters for you:

- Memory is proportional to the number of entries, not to the range of the keys.
- A lookup must search for the key, so it is slower than indexing a fixed or dynamic array.
- Entries do not have positions. There is no "element number 3"; there are only keys.

### Complete example

```systemverilog file=tb_assoc_array.sv
module tb_assoc_array;

  int    score [string];
  int    level [int];
  string name;
  int    key;

  initial begin
    score["ravi"] = 82;
    score["anu"]  = 95;
    score["zoya"] = 71;
    score["maya"] = 88;
    $display("1. entries = %0d", score.num());

    if (score.exists("anu"))  $display("2. anu is present, score %0d", score["anu"]);
    if (!score.exists("tom")) $display("3. tom is not present");

    if (score.first(name))
      do $display("4.   %s = %0d", name, score[name]);
      while (score.next(name));

    void'(score.last(name));  $display("5. last key          = %s", name);
    void'(score.prev(name));  $display("6. key before zoya   = %s", name);

    score.delete("ravi");
    $display("7. after delete(\"ravi\") entries = %0d", score.num());

    foreach (score[k]) $display("8.   %s = %0d", k, score[k]);

    score["maya"]++;                       // existing entry
    score["neel"]++;                       // new entry: created as 0, then incremented
    $display("9. maya = %0d  neel = %0d  entries = %0d",
             score["maya"], score["neel"], score.num());

    // integer keys: stored in numeric order, negative first for a signed index
    level[5]   = 50;
    level[-3]  = 30;
    level[100] = 10;
    void'(level.first(key));  $display("10. first key = %0d", key);
    void'(level.next(key));   $display("11. next key  = %0d", key);
    void'(level.last(key));   $display("12. last key  = %0d", key);
    if (!level.next(key))     $display("13. no key after %0d", key);

    $display("14. level[7] = %0d, entries still %0d", level[7], level.num());

    score.delete();
    $display("15. after delete() entries = %0d", score.num());
  end

endmodule
```

```output
1. entries = 4
2. anu is present, score 95
3. tom is not present
4.   anu = 95
4.   maya = 88
4.   ravi = 82
4.   zoya = 71
5. last key          = zoya
6. key before zoya   = ravi
7. after delete("ravi") entries = 3
8.   anu = 95
8.   maya = 88
8.   zoya = 71
9. maya = 89  neel = 1  entries = 4
10. first key = -3
11. next key  = 5
12. last key  = 100
13. no key after 100
14. level[7] = 0, entries still 3
15. after delete() entries = 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Four writes created four entries. No `new` is needed. |
| 2, 3 | `exists()` tests for a key without reading the element. |
| 4 | The standard traversal idiom. `first(name)` puts the smallest key into `name` and returns 1 because the array is not empty. The `do`...`while` body runs for that key, then `next(name)` moves `name` to the following key. When there is no further key, `next` returns 0 and the loop ends. The keys come out in dictionary order, not in the order written. |
| 5, 6 | `last()` gives the largest key. `prev()` steps backwards from the key currently in `name`. The return value is discarded with `void'()`. |
| 7 | `delete("ravi")` removes one entry. |
| 8 | `foreach` does the same traversal as line 4 with less code. The loop variable `k` automatically has the index type (`string`). |
| 9 | Incrementing an existing entry changes it from 88 to 89. Incrementing a missing entry creates it with the default value 0 and then adds 1. |
| 10 to 12 | With a signed index type the keys are ordered -3, 5, 100. |
| 13 | `next()` returns 0 when there is no later key, and leaves `key` unchanged. |
| 14 | Reading a missing key returns the default value (0) and does **not** create an entry. A simulator warning is normal here. |
| 15 | `delete()` with no argument removes everything. |

### A practical example: sparse memory model

```systemverilog file=tb_sparse_memory.sv
module tb_sparse_memory;

  logic [7:0] mem [bit [31:0]];           // only the written addresses use memory

  function automatic void mem_write(bit [31:0] addr, logic [7:0] data);
    mem[addr] = data;
  endfunction

  function automatic logic [7:0] mem_read(bit [31:0] addr);
    if (mem.exists(addr)) return mem[addr];
    return 'x;                            // unwritten memory reads as unknown
  endfunction

  initial begin
    mem_write(32'h0000_0010, 8'hAA);
    mem_write(32'hFFFF_FFF0, 8'hBB);
    mem_write(32'h8000_0000, 8'hCC);
    mem_write(32'h0000_0010, 8'hDD);      // overwrite

    $display("read 00000010 = %h", mem_read(32'h0000_0010));
    $display("read 00000020 = %h", mem_read(32'h0000_0020));
    $display("locations in use = %0d", mem.num());
    foreach (mem[a]) $display("  mem[%h] = %h", a, mem[a]);
  end

endmodule
```

```output
read 00000010 = dd
read 00000020 = xx
locations in use = 3
  mem[00000010] = dd
  mem[80000000] = cc
  mem[fffffff0] = bb
```

**Explanation**

| Code | Explanation |
|---|---|
| `logic [7:0] mem [bit [31:0]];` | The key is an unsigned 32-bit address. Four billion possible addresses, three entries stored. |
| `mem_write` | Writing creates or replaces the entry. The second write to address `10` replaces `AA` with `DD`. |
| `mem.exists(addr)` | A real memory that was never written contains unknown data, so the model returns X for a missing address instead of the silent default. This lets the scoreboard detect reads of uninitialised memory. |
| `foreach (mem[a])` | Visits the addresses in increasing unsigned order. Had the index type been `int` (signed), `80000000` and `FFFFFFF0` would be negative and would come first. |

### A practical example: counting by key

```systemverilog file=tb_assoc_histogram.sv
module tb_assoc_histogram;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  alu_op_e ops [10] = '{ALU_ADD, ALU_SUB, ALU_ADD, ALU_XOR, ALU_ADD,
                        ALU_SHL, ALU_SUB, ALU_ADD, ALU_XOR, ALU_ADD};
  int      hist [alu_op_e];

  initial begin
    foreach (ops[i]) hist[ops[i]]++;

    $display("%0d different operations seen", hist.num());
    foreach (hist[op]) $display("  %-8s : %0d", op.name(), hist[op]);

    if (!hist.exists(ALU_NOT)) $display("ALU_NOT was never generated");
  end

endmodule
```

```output
4 different operations seen
  ALU_ADD  : 5
  ALU_SUB  : 2
  ALU_XOR  : 2
  ALU_SHL  : 1
ALU_NOT was never generated
```

The array is indexed by the enum. `hist[ops[i]]++` creates an entry the first time an operation is seen and increments it afterwards. Traversal is in the order of the enum values (`ALU_ADD` = 0, `ALU_SUB` = 1, `ALU_XOR` = 4, `ALU_SHL` = 6). The `exists()` test at the end is a hand-made version of a coverage hole report; Module 10 shows how covergroups do this properly.

### A practical example: out-of-order scoreboard

When a DUT may return responses in a different order from the requests, a queue is the wrong structure, because `pop_front()` assumes order. Expected results are instead stored in an associative array keyed by a transaction ID.

```systemverilog file=tb_assoc_scoreboard.sv
module tb_assoc_scoreboard;

  logic [8:0] exp_by_id [int];

  function automatic void check(int id, logic [8:0] actual);
    if (!exp_by_id.exists(id)) begin
      $display("FAIL: id %0d was not expected", id);
      return;
    end
    if (actual !== exp_by_id[id])
      $display("FAIL: id %0d actual=%0d expected=%0d", id, actual, exp_by_id[id]);
    else
      $display("PASS: id %0d = %0d", id, actual);
    exp_by_id.delete(id);                  // this expectation has been consumed
  endfunction

  initial begin
    exp_by_id[1] = 9'd30;
    exp_by_id[2] = 9'd40;
    exp_by_id[3] = 9'd50;

    check(3, 9'd50);                       // responses arrive out of order
    check(1, 9'd31);
    check(7, 9'd0);

    $display("still pending: %0d", exp_by_id.num());
    foreach (exp_by_id[id]) $display("  no response received for id %0d", id);
  end

endmodule
```

```output
PASS: id 3 = 50
FAIL: id 1 actual=31 expected=30
FAIL: id 7 was not expected
still pending: 1
  no response received for id 2
```

Each response is looked up by its ID, compared, and removed. Whatever is left at the end of the test is a request that never received a response.

### Associative array versus the other kinds

| Property | Dynamic array | Queue | Associative array |
|---|---|---|---|
| Index | 0 to size-1 | 0 to size-1 | Any declared type; any values |
| Elements contiguous | Yes | Yes | No (sparse) |
| Allocation | `new[n]` | Automatic | Automatic, one entry per written key |
| Access speed | Fastest | Fast | Slower (a search per access) |
| Memory | All elements | All elements | Only the entries that exist |
| Find out if an element exists | Compare index with `size()` | Compare index with `size()` | `exists(key)` |
| Number of elements | `size()` | `size()` | `num()` or `size()` |
| Traversal | `foreach`, `for` | `foreach`, `for` | `foreach`, or `first`/`next`, `last`/`prev` |
| `sort`, `rsort`, `reverse`, `shuffle` | Yes | Yes | **No** |
| `find`, `min`, `max`, `unique`, `sum`... | Yes | Yes | Yes |
| Literal | `'{1, 2, 3}` | `{1, 2, 3}` | `'{key: value, ...}` |

> **Interview trap:** "What does `aa.first(k)` return?" It returns 1 or 0: whether the array has any entry. The first key is delivered through the argument `k`. Writing `k = aa.first();` is wrong on both counts.

> **Interview trap:** "How do you check whether a key is in an associative array?" With `exists()`. Testing `if (aa[key] == 0)` is wrong: a missing key and a key whose stored value is 0 look the same, and the read produces a warning.

> **Common mistake:** Expecting entries to come back in insertion order. They always come back in sorted key order. If insertion order matters, also keep a queue of the keys.

> **Common mistake:** Using a signed index type for addresses. With `mem [int]`, the address `32'h8000_0000` is a negative key and sorts before address 0. Use `bit [31:0]` or `int unsigned` for addresses.

> **Common mistake:** Deleting entries of the same associative array inside a `foreach` over it. Changing the set of keys while iterating gives undefined results. Collect the keys to delete in a queue first, then delete them in a second loop.

> **Verification application:** Associative arrays are the standard choice for (1) memory models of RAM, ROM and register spaces; (2) out-of-order scoreboards keyed by ID or address; (3) per-key statistics, such as transactions per address or errors per message string; (4) configuration databases that map a string name to a value (the UVM configuration database is built this way); (5) address-to-register-object maps in register models.

### Interview questions

**Q1. What is an associative array?**
An array whose elements are allocated individually when written and are accessed by a key of a declared index type. It is a sparse lookup table from key to value.

**Q2. When would you use an associative array instead of a dynamic array?**
When the index range is very large but sparsely used, such as a memory model with a 32-bit address, or when the index is not a small contiguous integer, such as a string or an ID.

**Q3. What index types can an associative array have?**
Any integral type, `string`, an enum, a class handle, a packed struct, or the wildcard `*` for any integral value.

**Q4. List the associative array methods.**
`num()`, `size()`, `exists()`, `delete()`, `first()`, `last()`, `next()`, `prev()`.

**Q5. What do `first()` and `next()` return, and how is the key obtained?**
They return 1 if a key was found and 0 otherwise. The key is written into the variable passed as the argument, which must be of the index type.

**Q6. What happens when you read a key that does not exist?**
The default value of the element type is returned, a warning is normally issued, and no entry is created.

**Q7. In what order does `foreach` visit an associative array?**
In increasing order of the keys: numeric order for integral keys (signed keys with negatives first) and lexicographic order for string keys.

**Q8. What is the difference between `num()` and `size()` for an associative array?**
None. Both return the number of entries.

**Q9. Can you sort an associative array?**
No. `sort()`, `rsort()`, `reverse()` and `shuffle()` are not available, because the entries are always kept in key order. To get the values in sorted order, copy them into a queue and sort the queue.

**Q10. How do you delete one entry? All entries?**
`aa.delete(key);` and `aa.delete();`

**Q11. Write code to print all keys and values of `int aa [string]` without using `foreach`.**

```systemverilog
string k;
if (aa.first(k))
  do $display("%s = %0d", k, aa[k]);
  while (aa.next(k));
```

**Q12. How would you model a 4 GB memory in a testbench?**
`logic [7:0] mem [bit [31:0]];`. Only written locations consume memory. A read function returns X (or a defined default) when `exists(addr)` is false.

## 3.2 Choosing the Right Array Type

### All array kinds side by side

| Property | Packed | Fixed-size | Dynamic | Queue | Associative |
|---|---|---|---|---|---|
| Declaration | `bit [7:0] p;` | `int a [8];` | `int d [];` | `int q [$];` | `int aa [key_t];` |
| Size set | Compile time | Compile time | Run time, `new[]` | Automatic | Automatic |
| Resizable | No | No | Yes, by reallocation | Yes, any time | Yes, per entry |
| Index | Integer range | Integer range | 0..N-1 | 0..N-1 | Any type, sparse |
| Element type | Bits only | Any | Any | Any | Any |
| Is one number | Yes | No | No | No | No |
| Add/remove single elements | No | No | Costly | Cheap at the ends | Cheap by key |
| Indexed access speed | Fastest | Fastest | Fast | Fast | Slowest |
| Memory use | Minimal | Full size | Current size | Current size | Entries only, plus overhead per entry |
| Element count | `$size` | `$size` | `size()` | `size()` | `num()` |
| Array methods | No | Yes | Yes | Yes | Locator and reduction only |
| Randomizable size | No | No | Yes | Yes | No |
| Synthesizable | Yes | Yes | No | No | No |

### A decision procedure

```text
   Is it a bus, a register or a bit field that must behave as one number?
        yes -> packed array                      logic [31:0] data;

   Is the number of elements fixed by the design or known when writing the code?
        yes -> fixed-size array                  logic [31:0] regs [32];

   Is the index sparse, very large, or not an integer (string, ID, address)?
        yes -> associative array                 logic [7:0] mem [bit [31:0]];

   Are elements added and removed one at a time as the simulation runs?
        yes -> queue                             alu_txn exp_q [$];

   Otherwise (size chosen at run time, then used as a block)
            -> dynamic array                     rand bit [7:0] payload [];
```

### Where each kind appears in a verification environment

| Testbench need | Array | Example declaration |
|---|---|---|
| DUT data bus, register value | Packed | `logic [31:0] rdata;` |
| Model of a small register file | Fixed-size | `logic [31:0] regs [32];` |
| One virtual interface per DUT port | Fixed-size | `virtual alu_if vif [4];` |
| Random-length packet payload | Dynamic | `rand bit [7:0] payload [];` |
| Data loaded from a file whose length is read first | Dynamic | `bit [31:0] image [];` |
| Expected results, in-order checking | Queue | `alu_txn exp_q [$];` |
| Reference model of a FIFO | Queue | `bit [7:0] fifo_q [$];` |
| List of all transactions seen, for a final report | Queue | `alu_txn history [$];` |
| Results of a search (`find`) | Queue | `int idx_q [$];` |
| Memory model | Associative | `logic [7:0] mem [bit [31:0]];` |
| Expected results, out-of-order checking | Associative | `alu_txn exp_by_id [int];` |
| Count of events per name | Associative | `int err_count [string];` |
| One expected queue per port | Fixed array of queues | `alu_txn exp_q [4][$];` |
| One expected queue per ID | Associative array of queues | `alu_txn exp_q [int][$];` |

> **How to say it in an interview:** "I choose the array type from how the data is accessed. A fixed-size array when the size is a design constant. A dynamic array when the size is decided at run time but then stable, for example a randomized payload. A queue when I continuously push and pop, for example the scoreboard's expected list for in-order checking. An associative array when the index is sparse or not an integer, for example a memory model or an out-of-order scoreboard keyed by transaction ID."

### Interview questions

**Q1. Which array type would you use for a scoreboard, and why?**
A queue when the DUT preserves order: expected transactions are pushed at the back and popped from the front. An associative array keyed by ID when responses can arrive out of order, because a response must be found by its key and not by its position.

**Q2. Which array type would you use to model a memory with a 32-bit address?**
An associative array indexed by `bit [31:0]`, because only a tiny fraction of the address space is used.

**Q3. Which array types can have their size randomized?**
Dynamic arrays and queues, by constraining `size()`. Fixed-size arrays have a constant size, and the size of an associative array cannot be randomized.

**Q4. Which is faster to index, a dynamic array or an associative array?**
A dynamic array. Its elements are contiguous, so the address of an element is computed directly. An associative array must search for the key.

**Q5. You need to store 1000 transactions and frequently delete the 500th. Which array?**
If the transactions are identified by a key such as an ID, an associative array, because deletion by key does not move other entries. A queue would work but each `delete(index)` moves all later elements.

**Q6. How do you declare an array of 8 queues of bytes?**
`bit [7:0] q [8][$];`
