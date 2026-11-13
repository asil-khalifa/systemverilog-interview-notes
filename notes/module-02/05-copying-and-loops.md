# Part 5: Array Initialisation, Assignment, Copying and Comparison

## 5.1 Array Initialisation

### Summary of the forms

| Array kind | In the declaration | Later, in procedural code |
|---|---|---|
| Packed | `logic [7:0] p = 8'hA5;` | `p = '0;` `p = {a, b};` |
| Fixed-size | `int a [4] = '{1, 2, 3, 4};` | `a = '{default: 0};` |
| Dynamic | `int d [] = '{1, 2, 3};` or `int d [] = new[3];` | `d = new[8];` `d = '{4, 5};` |
| Queue | `int q [$] = {1, 2, 3};` | `q = {};` `q.push_back(4);` |
| Associative | `int aa [string] = '{"a": 1, "b": 2};` | `aa["c"] = 3;` |

### Assignment pattern features

| Form | Example | Result |
|---|---|---|
| Positional | `'{1, 2, 3, 4}` | One value per element, in index order from the left bound |
| Default | `'{default: 9}` | Every element is 9 |
| Indexed | `'{0: 5, 3: 7, default: 0}` | Element 0 is 5, element 3 is 7, the rest 0 |
| Replication | `'{4{8}}` | Four elements, each 8 |
| Nested | `'{ '{1, 2}, '{3, 4} }` | One inner pattern per row of a two-dimensional array |
| Key and value | `'{"x": 1, "y": 2}` | Entries of an associative array |

Rules:

- A positional pattern must supply **exactly** as many values as the fixed-size array has elements. For a dynamic array or queue, the number of values sets the size.
- Positional values cannot be mixed with `default:` or index keys in the same pattern.
- Elements that are never initialised keep the default of their type: X for four-state, 0 for two-state, `null` for class handles, `""` for strings.

### Initialising with a loop

Patterns are convenient for small arrays. Larger arrays are filled procedurally:

```systemverilog
logic [7:0] mem [256];
int         sq [];

initial begin
  foreach (mem[i]) mem[i] = i;                 // address pattern: 00, 01, 02 ...
  sq = new[10];
  foreach (sq[i]) sq[i] = i * i;               // 0, 1, 4, 9 ...
end
```

Memories are often loaded from a file with `$readmemh("data.hex", mem);` (hexadecimal text) or `$readmemb` (binary text), which fill a fixed-size array of packed elements.

> **Common mistake:** Giving a declaration initialiser to a variable declared inside a task, function or `initial` block of a module, and expecting it to be applied each time the code runs. Such variables are static by default and are initialised once (Module 3). For arrays this shows up as "my array still has the values from the previous call". Assign in a separate statement, or declare the routine `automatic`.

## 5.2 Array Assignment and Copying

### In plain English

Assigning one array to another with `=` copies **every element**. After the copy the two arrays are separate: changing one does not change the other. This is true for every array kind, and it is different from class handles, where `=` copies only a reference (Section 5.4).

### Technical definition

An unpacked array can be assigned to another unpacked array when both have **equivalent element types** and **compatible shapes**:

| Destination | Source | Rule |
|---|---|---|
| Fixed-size | Fixed-size | Same number of elements in every dimension. The index ranges may differ (`int a [0:3]` and `int b [7:4]` are compatible) |
| Dynamic or queue | Any array of the same element type | Always allowed. The destination is resized to match |
| Fixed-size | Dynamic or queue | Allowed by the compiler; a **run-time error** if the sizes differ |
| Associative | Associative with the same index type | Allowed. All entries are copied |
| Associative | Any non-associative array (and the reverse) | Not allowed |

Elements are copied left to right by position: the leftmost element of the source goes to the leftmost element of the destination, whatever the index numbers are.

### How it works internally

```text
   int a [3] = '{1, 2, 3};
   int b [3];

   b = a;                    a : [ 1 | 2 | 3 ]
                                   |   |   |      every element is copied
                                   v   v   v
                             b : [ 1 | 2 | 3 ]    b has its own storage

   b[0] = 100;               a : [ 1   | 2 | 3 ]   unchanged
                             b : [ 100 | 2 | 3 ]
```

For dynamic arrays and queues the destination's old storage is released and new storage of the right size is allocated before the elements are copied.

### Slices

A contiguous part of an array can be read or written as a unit:

```systemverilog
int a [8];
int b [3];

b        = a[2:4];        // three elements out of a
a[5:7]   = b;             // three elements into a
a[0:1]   = a[6:7];        // copy within the same array
```

For fixed-size arrays the slice bounds must be constants (or use the indexed forms `a[i +: 3]` and `a[i -: 3]`, where the width is constant). For queues the bounds may be variables: `q[lo:hi]`.

### Complete example

```systemverilog file=tb_array_assign.sv
module tb_array_assign;

  int fixed [3] = '{1, 2, 3};
  int other [3];
  int rng   [7:5];
  int dyn   [];
  int q     [$];

  initial begin
    other    = fixed;                 // fixed to fixed
    other[0] = 100;
    $display("1. fixed = %p   other = %p", fixed, other);

    rng = fixed;                      // different index range, same size
    $display("2. rng[7] = %0d   rng[5] = %0d", rng[7], rng[5]);

    dyn = fixed;                      // fixed to dynamic: dyn is resized to 3
    q   = dyn;                        // dynamic to queue
    q.push_back(4);
    dyn = q;                          // queue to dynamic: dyn is resized to 4
    $display("3. dyn = %p   size = %0d", dyn, dyn.size());

    fixed = dyn[1:3];                 // a 3-element slice fits the 3-element array
    $display("4. fixed = %p", fixed);

    other[0:1] = fixed[1:2];          // slice to slice
    $display("5. other = %p", other);

    // fixed = dyn;                   // dyn has 4 elements: this would be a run-time error
  end

endmodule
```

```output
1. fixed = '{1, 2, 3}   other = '{100, 2, 3}
2. rng[7] = 1   rng[5] = 3
3. dyn = '{1, 2, 3, 4}   size = 4
4. fixed = '{2, 3, 4}
5. other = '{3, 4, 3}
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | `other = fixed` copied three values. Changing `other[0]` afterwards leaves `fixed` alone. |
| 2 | `rng` is declared `[7:5]`. The copy is positional: the leftmost source element `fixed[0]` goes to the leftmost destination element `rng[7]`. |
| 3 | A dynamic array and a queue take whatever size the source has. |
| 4 | `dyn[1:3]` is `{2, 3, 4}`. |
| 5 | `fixed[1:2]` is `{3, 4}`; it replaces elements 0 and 1 of `other`, whose element 2 still holds 3. |

### Copying when arrays are passed to tasks and functions

Passing an array as an ordinary (`input`) argument **copies the whole array** on every call. For a large array this is slow. Declaring the argument `ref` passes a reference instead, and `const ref` does so while preventing the routine from modifying the caller's array. Module 3 explains argument passing in detail.

```systemverilog
function automatic int total_by_value(int arr []);            // copies arr on every call
function automatic int total_by_ref(const ref int arr []);    // no copy, read-only
```

> **Interview trap:** "Does `b = a` for two arrays make `b` refer to the same storage as `a`?" No. Arrays have value semantics: the elements are copied and the arrays are independent. Only **class handles** have reference semantics.

> **Common mistake:** Assigning a dynamic array to a fixed-size array without checking the size. It compiles, and then fails at run time when the sizes differ.

> **Common mistake:** Assuming the copy matches index numbers. `int a [0:3]` assigned to `int b [3:0]` puts `a[0]` into `b[3]`, because both are the leftmost element.

### Interview questions

**Q1. How do you copy one array to another?**
With a simple assignment, `b = a;`. All elements are copied. A dynamic array or queue destination is resized automatically.

**Q2. When are two fixed-size arrays assignment-compatible?**
When their element types are equivalent and they have the same number of dimensions with the same number of elements in each. The index ranges need not be identical.

**Q3. What happens when a 5-element dynamic array is assigned to a 4-element fixed-size array?**
A run-time error. The sizes must match because a fixed-size array cannot be resized.

**Q4. After `q2 = q1;` and `q2.push_back(9);`, does `q1` change?**
No. `q2` is an independent copy.

**Q5. How do you copy only part of an array?**
With a slice: `b = a[2:5];` for a fixed range, or `q2 = q1[lo:hi];` for a queue.

## 5.3 Array Comparison

### Rules

- Two unpacked arrays of compatible type can be compared as a whole with `==` and `!=`. The comparison is element by element, in position order, and gives a single-bit result.
- Dynamic arrays and queues of different sizes are simply not equal.
- Slices can be compared: `a[0:3] == b[4:7]`.
- With four-state elements, `==` follows the rules of Module 1, Section 4.5: an X or Z in a compared element can make the whole result X. Use `===` and `!==` in checkers so that the result is always 0 or 1.
- Relational operators (`<`, `>`) are **not** defined for unpacked arrays.
- When the elements are class handles, the handles are compared, not the objects they point to (Section 5.4).

### Complete example

```systemverilog file=tb_array_compare.sv
module tb_array_compare;

  logic [7:0] exp_data [4] = '{8'h11, 8'h22, 8'h33, 8'h44};
  logic [7:0] act_data [4] = '{8'h11, 8'h22, 8'h3F, 8'h44};
  logic [7:0] x_data   [4] = '{8'h11, 8'h22, 8'hxx, 8'h44};
  int         q1 [$] = {1, 2, 3};
  int         q2 [$] = {1, 2, 3, 4};

  initial begin
    if (act_data == exp_data) $display("1. arrays match");
    else                      $display("1. arrays differ");

    foreach (exp_data[i])
      if (act_data[i] !== exp_data[i])
        $display("2.   mismatch at [%0d]: actual=%h expected=%h",
                 i, act_data[i], exp_data[i]);

    $display("3. first two elements equal : %b", act_data[0:1] == exp_data[0:1]);

    if (x_data != exp_data)  $display("4. using != : mismatch reported");
    else                     $display("4. using != : no mismatch reported");
    if (x_data !== exp_data) $display("5. using !== : mismatch reported");

    $display("6. different sizes equal? %b", q1 == q2);
    q2.delete(3);
    $display("7. after delete(3) equal? %b", q1 == q2);
  end

endmodule
```

```output
1. arrays differ
2.   mismatch at [2]: actual=3f expected=33
3. first two elements equal : 1
4. using != : no mismatch reported
5. using !== : mismatch reported
6. different sizes equal? 0
7. after delete(3) equal? 1
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | One comparison for the whole array: it tells you *that* they differ, not *where*. |
| 2 | The usual follow-up in a scoreboard: a loop that reports each differing element. |
| 3 | Slices are compared like whole arrays. |
| 4 | Element 2 of `x_data` is X. The comparison of that element is X, so the whole `!=` is X, which the `if` treats as false. The mismatch is missed. |
| 5 | `!==` compares X literally and reports the mismatch. This is the array form of the scoreboard trap from Module 1. |
| 6 | Arrays of different sizes are not equal. |
| 7 | `delete(3)` removes the element at index 3 of the queue `q2`. Both queues now hold `{1, 2, 3}` and compare equal. |

> **Common mistake:** Comparing arrays of DUT data with `==` or `!=` in a scoreboard. One X element makes the result X and the failure disappears. Use `!==`.

> **Verification application:** A monitor collects the bytes of a packet into a queue; the scoreboard compares that queue with the expected payload in a single statement, `if (act.payload !== exp.payload)`, and only loops over the elements to print details when the comparison fails.

### Interview questions

**Q1. How do you compare two arrays?**
With `==` or `!=` (or `===` / `!==` for four-state data) on the whole arrays. The element types must be equivalent. The result is one bit.

**Q2. What is the result of comparing two queues of different sizes?**
They are not equal: `==` gives 0.

**Q3. Why prefer `!==` over `!=` when comparing arrays of `logic`?**
An X or Z in any element makes `!=` return X, which an `if` treats as false, so a mismatch is not reported. `!==` always returns 0 or 1.

**Q4. Which arrays support `delete(index)`?**
Queues and associative arrays. A dynamic array supports only `delete()` without an argument, which removes all elements.

## 5.4 Shallow Copy and Deep Copy

### In plain English

When the elements of an array are plain values (numbers, structs, strings), copying the array copies the values, and that is the end of it.

When the elements are **class handles**, each element is not the object itself but a reference to an object that lives elsewhere. Copying the array copies the references. Both arrays then refer to the **same objects**. This is a **shallow copy**. If you need a second, independent set of objects, you must create new objects and copy the contents of each one. This is a **deep copy**.

Classes and handles are the subject of Module 4. The small class below is enough to show the effect on arrays: `new(10)` creates an object holding 10 and returns a handle to it.

### Technical definition

| Term | What is copied | Are the two arrays independent? |
|---|---|---|
| Array copy of values | Every element value | Yes |
| Shallow copy of an array of handles | The handles only | The arrays are separate, but they point to the same objects |
| Deep copy of an array of handles | A new object is created for each element and the object's contents are copied into it | Yes, completely |

### How it works internally

```text
   Shallow copy:  h2 = h1;

      h1 : [ o--|--o ]                     +-----------+       +-----------+
             |     |                       | val = 10  |       | val = 20  |
             |     +---------------------> |  object B |       |           |
             +---------------------------> |  object A |       |           |
             +---------------------------> +-----------+       +-----------+
             |     +--------------------------------------------^
      h2 : [ o--|--o ]

      Two arrays, ONE set of objects.    h2[0].val = 99   changes what h1[0].val reads.

   Deep copy:  foreach (h1[i]) h3[i] = new(h1[i].val);

      h1 : [ o | o ] ---> object A (val 10)     object B (val 20)
      h3 : [ o | o ] ---> object A' (val 10)    object B' (val 20)      new objects

      Two arrays, TWO sets of objects.   h3[1].val = 77   does not affect h1.
```

### Complete example

```systemverilog file=tb_array_copy.sv
module tb_array_copy;

  class item_c;
    int val;
    function new(int v);
      val = v;
    endfunction
  endclass

  int    a [3] = '{1, 2, 3};
  int    b [3];
  item_c h1 [2];
  item_c h2 [2];
  item_c h3 [2];

  initial begin
    // arrays of values: a real copy
    b    = a;
    b[0] = 100;
    $display("1. values : a[0] = %0d   b[0] = %0d", a[0], b[0]);

    // arrays of class handles
    h1[0] = new(10);
    h1[1] = new(20);

    h2 = h1;                                  // shallow copy: only the handles are copied
    h2[0].val = 99;
    $display("2. shallow: h1[0].val = %0d   h2[0].val = %0d", h1[0].val, h2[0].val);

    foreach (h1[i]) h3[i] = new(h1[i].val);   // deep copy: a new object per element
    h3[1].val = 77;
    $display("3. deep   : h1[1].val = %0d   h3[1].val = %0d", h1[1].val, h3[1].val);

    $display("4. h1 == h2 : %b    h1 == h3 : %b", h1 == h2, h1 == h3);
  end

endmodule
```

```output
1. values : a[0] = 1   b[0] = 100
2. shallow: h1[0].val = 99   h2[0].val = 99
3. deep   : h1[1].val = 20   h3[1].val = 77
4. h1 == h2 : 1    h1 == h3 : 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | `int` elements: `b` is a true copy, so the change to `b[0]` is not seen in `a`. |
| 2 | `h2 = h1` copies two handles. `h2[0]` and `h1[0]` refer to the same object, so writing 99 through `h2[0]` is visible through `h1[0]`. |
| 3 | The loop creates a new object for each element and initialises it with the value from the original. `h3[1]` is a different object from `h1[1]`, so changing it has no effect on `h1`. |
| 4 | Comparing arrays of handles compares the handles. `h1` and `h2` hold identical handles: equal. `h3` holds handles to different objects, so it is not equal to `h1`, even though at the moment of copying the object contents were the same. |

### Comparison table

| Property | Array of values (`int`, struct, `bit [7:0]`) | Array of class handles |
|---|---|---|
| What an element holds | The data | A reference to an object |
| `b = a;` | Copies the data. Fully independent | Copies the references. Objects are shared (shallow) |
| How to get an independent copy | `b = a;` is enough | Loop: create a new object per element and copy its fields (deep) |
| `a == b` | Compares the data | Compares the references |
| Default element value | 0 or X | `null` |
| Memory after `delete()` | Elements are released | Handles are released; an object is freed only when no handle refers to it any more |

> **Interview trap:** "I pushed the same transaction object into a queue ten times inside a loop, changing its fields each time. Why do all ten queue entries show the last values?" Because the queue holds ten copies of the **same handle**. Only one object exists. A new object must be created (or the object copied) for each entry. This bug appears in almost every beginner's generator and is covered again in Modules 4 and 9.

> **Common mistake:** Believing that `new[n]` on a dynamic array of handles creates `n` objects. It creates `n` handles, all `null`. Each object must still be constructed: `foreach (arr[i]) arr[i] = new();`.

> **Verification application:** A scoreboard that stores received transactions in a queue must store copies if the sender keeps reusing the same object. Transaction classes therefore provide a `copy()` method (as `alu_txn` does) and components write `exp_q.push_back(txn.copy());`.

### Interview questions

**Q1. What is the difference between a shallow copy and a deep copy?**
A shallow copy duplicates the handles, so the original and the copy refer to the same objects. A deep copy creates a new object for each original object and copies its contents, so the two are fully independent.

**Q2. Is `b = a` for two arrays of `int` shallow or deep?**
The distinction does not apply: the elements are values, and the assignment copies them. The arrays are independent.

**Q3. What does `arr = new[5];` create when `arr` is a dynamic array of class handles?**
Five `null` handles. No objects are created until `new()` is called for each element.

**Q4. How do you deep-copy a queue of transactions?**
Loop over the source and push a copy of each object: `foreach (src[i]) dst.push_back(src[i].copy());`.

# Part 6: Loops and Array Iteration

## 6.1 The for Loop

### In plain English

A `for` loop repeats a block of code while counting. You state where the counter starts, the condition under which the loop continues, and how the counter changes after each pass.

### Syntax

```systemverilog
for (initialisation; condition; step) statement

for (int i = 0; i < 8; i++) begin
  ...
end
```

Execution order: the initialisation runs once; then the condition is tested **before** every pass; if it is true the body runs, then the step, then the condition is tested again.

```text
          +----------------+
          | initialisation |   (once)
          +-------+--------+
                  |
                  v
          +----------------+   false
   +----> |   condition ?  | ----------> exit
   |      +-------+--------+
   |              | true
   |              v
   |      +----------------+
   |      |      body      |
   |      +-------+--------+
   |              |
   |              v
   |      +----------------+
   +------|      step      |
          +----------------+
```

SystemVerilog additions compared with Verilog:

- The loop variable can be declared inside the loop (`for (int i = 0; ...`). It is then local to the loop, which prevents accidental sharing between loops running in parallel threads.
- Several variables can be initialised and stepped, separated by commas.
- `i++`, `i--`, `i += 2` are available.

### Complete example

```systemverilog file=tb_loop_for.sv
module tb_loop_for;

  int arr [5] = '{3, 8, 1, 6, 4};
  int total;
  int tmp;

  initial begin
    total = 0;
    for (int i = 0; i < $size(arr); i++) total += arr[i];
    $display("1. total = %0d", total);

    $write("2. backwards            :");
    for (int i = $high(arr); i >= $low(arr); i--) $write(" %0d", arr[i]);
    $display("");

    $write("3. every second element :");
    for (int i = 0; i < $size(arr); i += 2) $write(" %0d", arr[i]);
    $display("");

    // two loop variables: reverse the array in place
    for (int lo = 0, hi = $size(arr) - 1; lo < hi; lo++, hi--) begin
      tmp     = arr[lo];
      arr[lo] = arr[hi];
      arr[hi] = tmp;
    end
    $display("4. reversed in place    : %p", arr);
  end

endmodule
```

```output
1. total = 22
2. backwards            : 4 6 1 8 3
3. every second element : 3 1 4
4. reversed in place    : '{4, 6, 1, 8, 3}
```

| Line | Explanation |
|---|---|
| 1 | The classic counting loop. `$size(arr)` keeps the bound correct if the array is resized in the source. 3 + 8 + 1 + 6 + 4 = 22. |
| 2 | Counting down from the highest index. The loop variable is a signed `int`, so `i >= 0` becomes false when `i` reaches -1. |
| 3 | A step other than 1: indices 0, 2, 4. |
| 4 | Two variables move toward each other and the elements are swapped. The pairs are (0,4) and (1,3); when `lo` and `hi` meet at 2 the loop ends. |

> **Interview trap:** `for (int unsigned i = n - 1; i >= 0; i--)` never terminates. An unsigned variable is always greater than or equal to 0; after 0 it wraps to 4,294,967,295. Use a signed `int` for a loop that counts down to zero.

> **Common mistake:** `for (int i = 0; i <= arr.size(); i++)`. The `<=` makes one pass too many and reads one element past the end. The condition is `i < arr.size()`.

## 6.2 The foreach Loop

### In plain English

"For each element of this array, do the following." You do not write the bounds or the step. The loop works them out from the array, so it is always right, whatever the array's size or index range.

### Technical definition

`foreach` iterates over the indices of an array. The loop variable named in the brackets is declared implicitly; it is local to the loop, has the type of the array's index, and cannot be assigned inside the loop. Iteration proceeds from the left bound of the dimension to its right bound; for dynamic arrays and queues from 0 to `size()-1`; for associative arrays in key order.

### Syntax

```systemverilog
foreach (arr[i])       statement      // one dimension
foreach (m[i, j])      statement      // two dimensions: i is the outer index
foreach (m[i])         statement      // only the first dimension
foreach (m[, j])       statement      // only the second dimension (first one skipped)
```

### What foreach can iterate over

| Operand | The loop variable takes |
|---|---|
| Fixed-size array `int a [3:1]` | 3, 2, 1 (left bound to right bound) |
| Dynamic array, queue | 0 to `size()-1` |
| Associative array | Each existing key, in sorted order |
| Packed vector `logic [3:0] v` | 3, 2, 1, 0 |
| `string` | 0 to `len()-1` (each character) |

### Complete example

```systemverilog file=tb_loop_foreach.sv
module tb_loop_foreach;

  int         arr [5]  = '{3, 8, 1, 6, 4};
  int         rev [3:1] = '{10, 20, 30};
  int         q [$]    = {7, 8};
  int         aa [string] = '{"b": 2, "a": 1};
  logic [3:0] nib      = 4'b1010;
  string      s        = "SV";
  int         max_val, max_idx;

  initial begin
    max_val = arr[0];
    max_idx = 0;
    foreach (arr[i])
      if (arr[i] > max_val) begin
        max_val = arr[i];
        max_idx = i;
      end
    $display("1. largest is %0d at index %0d", max_val, max_idx);

    $write("2. fixed [3:1] :");
    foreach (rev[i]) $write(" rev[%0d]=%0d", i, rev[i]);
    $display("");

    $write("3. queue       :");
    foreach (q[i]) $write(" q[%0d]=%0d", i, q[i]);
    $display("");

    $write("4. associative :");
    foreach (aa[k]) $write(" aa[%s]=%0d", k, aa[k]);
    $display("");

    $write("5. packed bits :");
    foreach (nib[i]) $write(" nib[%0d]=%b", i, nib[i]);
    $display("");

    $write("6. string      :");
    foreach (s[i]) $write(" s[%0d]=%c", i, s[i]);
    $display("");
  end

endmodule
```

```output
1. largest is 8 at index 1
2. fixed [3:1] : rev[3]=10 rev[2]=20 rev[1]=30
3. queue       : q[0]=7 q[1]=8
4. associative : aa[a]=1 aa[b]=2
5. packed bits : nib[3]=1 nib[2]=0 nib[1]=1 nib[0]=0
6. string      : s[0]=S s[1]=V
```

| Line | Explanation |
|---|---|
| 1 | A typical search loop: remember the best value and its index. |
| 2 | The array is declared `[3:1]`. The pattern `'{10, 20, 30}` fills it from the left bound, so `rev[3]` is 10. `foreach` also starts at the left bound: 3, 2, 1. |
| 3 | A queue is visited from 0 upward. |
| 4 | The keys come out sorted (`"a"` before `"b"`), not in the order written in the initialiser. `k` is a `string`. |
| 5 | A packed vector is visited from its left bound (bit 3) to its right bound (bit 0). |
| 6 | Each element of a string is a character (a `byte`); `%c` prints it as a character. |

### for versus foreach

| Property | `for` | `foreach` |
|---|---|---|
| Bounds | Written by you | Taken from the array |
| Step | Any | Always one element, in declaration order |
| Direction | Either | Left bound to right bound only |
| Loop variable | Declared by you; can be modified | Implicit; read-only |
| Partial ranges, skipping elements | Yes | No (use `if` / `continue` inside) |
| Associative arrays | Needs `first()` / `next()` | Direct |
| Multidimensional | Nested loops | One statement: `foreach (m[i, j])` |
| Risk of off-by-one errors | Yes | None |
| Usable in constraints | No | Yes (Module 5) |

Use `foreach` to visit every element. Use `for` when you need a different direction, step or range.

> **Interview trap:** "Can you assign to an element inside `foreach`?" Yes: `foreach (arr[i]) arr[i] = 0;` is fine. What you cannot assign is the loop variable `i`.

> **Common mistake:** Declaring the `foreach` index variable yourself. `int i; foreach (arr[i]) ...` creates a **new** implicit `i` inside the loop; the outer `i` is untouched and still has its old value afterwards.

## 6.3 The repeat Loop

### Definition and syntax

`repeat (n) statement` executes the statement exactly `n` times. There is no loop variable and no condition. The count `n` is evaluated **once**, before the first pass; changing the variables in the count expression inside the body does not change the number of passes. If `n` is zero or negative the body does not run; if it is X or Z it is treated as zero.

```systemverilog
repeat (5) @(posedge clk);            // wait for five rising clock edges
repeat (num_txn) begin                // generate num_txn transactions
  ...
end
```

`repeat` is the clearest loop when the number of passes is known and the pass number is not needed in the body. Its most common use in testbenches is waiting a number of clock cycles.

## 6.4 The while and do-while Loops

### Definition

| Loop | Syntax | Condition tested | Minimum passes |
|---|---|---|---|
| `while` | `while (cond) statement` | **Before** each pass | 0 |
| `do`...`while` | `do statement while (cond);` | **After** each pass | 1 |

```text
        while                                  do ... while

    +-------------+  false                  +-------------+
+-> | condition ? | ------> exit        +-> |    body     |
|   +------+------+                     |   +------+------+
|          | true                       |          |
|          v                            |          v
|   +-------------+                     |   +-------------+  false
+---|    body     |                     +---| condition ? | ------> exit
    +-------------+                    true +-------------+
```

Both are used when the number of passes is not known in advance: "keep going until something happens". A condition that is X or Z is treated as false.

### Complete example: repeat, while, do-while, break and continue

```systemverilog file=tb_loop_while.sv
module tb_loop_while;

  int q [$] = {5, 12, 7, 20, 3};
  int count, x, idx, n;

  initial begin
    // repeat: a fixed number of passes
    count = 0;
    repeat (4) count += 2;
    $display("1. repeat (4)          : count = %0d", count);

    // the repeat count is evaluated once
    count = 3;
    repeat (count) count++;
    $display("2. repeat (count)      : count = %0d", count);

    // while: search for the first element greater than 10
    idx = 0;
    while (idx < q.size() && q[idx] <= 10) idx++;
    $display("3. first element > 10  : q[%0d] = %0d", idx, q[idx]);

    // while may run zero times, do-while runs at least once
    x = 100;
    count = 0;
    while (x < 10) count++;
    $display("4. while (false)       : %0d passes", count);
    count = 0;
    do count++; while (x < 10);
    $display("5. do-while (false)    : %0d pass", count);

    // while: drain a queue
    $write("6. drained             :");
    while (q.size() > 0) begin
      x = q.pop_front();
      $write(" %0d", x);
    end
    $display("");

    // continue and break
    $write("7. continue and break  :");
    for (int i = 0; i < 10; i++) begin
      if (i % 2 == 1) continue;        // skip odd numbers
      if (i > 6)      break;           // stop the loop
      $write(" %0d", i);
    end
    $display("");

    // forever with break
    n = 0;
    forever begin
      n++;
      if (n == 5) break;
    end
    $display("8. forever with break  : n = %0d", n);
  end

endmodule
```

```output
1. repeat (4)          : count = 8
2. repeat (count)      : count = 6
3. first element > 10  : q[1] = 12
4. while (false)       : 0 passes
5. do-while (false)    : 1 pass
6. drained             : 5 12 7 20 3
7. continue and break  : 0 2 4 6
8. forever with break  : n = 5
```

| Line | Explanation |
|---|---|
| 1 | Four passes, each adding 2. |
| 2 | The count is read once (3). The body changes `count`, but the loop still runs exactly three times: 3 → 6. |
| 3 | The condition has two parts. `idx < q.size()` is checked first; because `&&` short-circuits, `q[idx]` is never read with an invalid index. The loop stops at index 1 (the value 12). |
| 4 | The condition is false at the start, so the `while` body never runs. |
| 5 | The `do`...`while` body runs once before the condition is tested. |
| 6 | The standard way to empty a queue while processing every element. |
| 7 | `continue` jumps to the next pass (to the step `i++`); `break` leaves the loop. Even numbers 0, 2, 4, 6 are printed; at `i` = 8 the loop is left. |
| 8 | `forever` has no condition. In testbench components it normally contains a timing control (`@(posedge clk)`, a mailbox `get`) and runs for the whole simulation. Here it is ended by `break`. A `forever` loop with neither a timing control nor a `break` hangs the simulator at one time step. |

### break, continue and return

| Statement | Effect |
|---|---|
| `break` | Leaves the innermost enclosing loop immediately |
| `continue` | Skips the rest of the current pass and goes to the next one |
| `return` | Leaves the whole task or function (and therefore every loop in it) |

All three are SystemVerilog additions; Verilog needed `disable` of a named block.

> **Interview trap:** "What is the difference between `while` and `do`...`while`?" The `while` loop tests the condition first and may execute zero times. The `do`...`while` loop executes the body first and tests afterwards, so it executes at least once. The associative array traversal `if (aa.first(k)) do ... while (aa.next(k));` relies on this: the body must run for the first key before `next` is called.

> **Common mistake:** A `while` or `forever` loop in a testbench with no statement that lets simulation time advance and no exit condition that can become true. The simulation appears to hang at a fixed time. Every such loop needs either a timing control or a guaranteed exit.

## 6.5 Nested Loops

### Definition

A nested loop is a loop inside the body of another loop. For each pass of the outer loop, the inner loop runs completely. Nested loops are used for multidimensional arrays, for comparing every element with every other element, and for sorting.

`break` and `continue` act on the **innermost** loop only. To leave both loops, use a flag tested by the outer loop, or put the loops in a function and `return`.

### Complete example

```systemverilog file=tb_loop_nested.sv
module tb_loop_nested;

  int arr [5] = '{5, 2, 9, 1, 7};
  int tmp, swaps;
  bit found;

  initial begin
    // 1. triangle: the inner bound depends on the outer variable
    for (int i = 1; i <= 3; i++) begin
      $write("1. row %0d:", i);
      for (int j = 1; j <= i; j++) $write(" %0d", i * j);
      $display("");
    end

    // 2. bubble sort
    swaps = 0;
    for (int i = 0; i < $size(arr) - 1; i++)
      for (int j = 0; j < $size(arr) - 1 - i; j++)
        if (arr[j] > arr[j + 1]) begin
          tmp        = arr[j];
          arr[j]     = arr[j + 1];
          arr[j + 1] = tmp;
          swaps++;
        end
    $display("2. sorted = %p after %0d swaps", arr, swaps);

    // 3. find the first pair of elements that adds up to 10
    found = 0;
    for (int i = 0; i < $size(arr) && !found; i++)
      for (int j = i + 1; j < $size(arr); j++)
        if (arr[i] + arr[j] == 10) begin
          $display("3. %0d + %0d = 10", arr[i], arr[j]);
          found = 1;
          break;                       // leaves the inner loop only
        end
  end

endmodule
```

```output
1. row 1: 1
1. row 2: 2 4
1. row 3: 3 6 9
2. sorted = '{1, 2, 5, 7, 9} after 5 swaps
3. 1 + 9 = 10
```

| Part | Explanation |
|---|---|
| 1 | The inner loop runs `i` times for outer value `i`, producing a triangle. |
| 2 | Bubble sort. Pass 0 moves the largest value to the end: `{2, 5, 1, 7, 9}` after three swaps. Pass 1: `{2, 1, 5, 7, 9}` (one swap). Pass 2: `{1, 2, 5, 7, 9}` (one swap). Pass 3: no swap. Five swaps in total. In real code you would write `arr.sort();` but interviewers ask for the loop version. |
| 3 | On the sorted array, the first pair found is `arr[0]` = 1 with `arr[4]` = 9. `break` leaves the inner loop; the `!found` term in the outer condition then ends the outer loop. |

## 6.6 Loop Summary and Iterating Safely

### All loops compared

| Loop | Use when | Number of passes | Loop variable |
|---|---|---|---|
| `for` | Counting with a known start, end and step; partial or reverse traversal | Determined by the condition | Explicit |
| `foreach` | Visiting every element of an array | One per element | Implicit, read-only |
| `repeat (n)` | Doing something exactly `n` times | `n`, evaluated once | None |
| `while` | Continuing as long as a condition holds; may not run at all | 0 or more | None (your own) |
| `do`...`while` | As `while`, but the body must run at least once | 1 or more | None (your own) |
| `forever` | Processes that run for the whole simulation | Unlimited, until `break`, `return` or `disable` | None |

All loop statements are usable in testbenches. In synthesizable RTL, `for`, `foreach` and `repeat` with constant bounds are accepted, because the tool unrolls them into parallel hardware; a loop does not become a sequential circuit.

### Changing an array while looping over it

Removing elements from a queue while walking forward through it skips elements, because every deletion shifts the following elements down by one.

```systemverilog file=tb_loop_delete.sv
module tb_loop_delete;

  int q1 [$] = {1, 2, 4, 5, 6};
  int q2 [$] = {1, 2, 4, 5, 6};
  int q3 [$] = {1, 2, 4, 5, 6};

  initial begin
    // WRONG: forward loop, deleting even values
    for (int i = 0; i < q1.size(); i++)
      if (q1[i] % 2 == 0) q1.delete(i);
    $display("1. forward delete  : %p", q1);

    // RIGHT: walk backwards, so the shifted elements have already been visited
    for (int i = q2.size() - 1; i >= 0; i--)
      if (q2[i] % 2 == 0) q2.delete(i);
    $display("2. backward delete : %p", q2);

    // RIGHT: build the result with a locator method
    q3 = q3.find with (item % 2 != 0);
    $display("3. find            : %p", q3);
  end

endmodule
```

```output
1. forward delete  : '{1, 4, 5}
2. backward delete : '{1, 5}
3. find            : '{1, 5}
```

Trace of the wrong loop: at `i` = 1 the value 2 is deleted and the queue becomes `{1, 4, 5, 6}`. The value 4 has moved to index 1, but `i` advances to 2, so 4 is never examined. At `i` = 3 the value 6 is deleted. The even value 4 survives.

The same hazard exists with `foreach` (whose behaviour is not defined when the array size changes during the loop) and with associative arrays.

> **Common mistake:** Deleting from a queue inside a forward loop. Loop backwards, or use `find` to build the filtered queue, or (when using `while`) advance the index only when nothing was deleted.

### Interview questions

**Q1. Which loops does SystemVerilog provide?**
`for`, `foreach`, `repeat`, `while`, `do`...`while` and `forever`, with `break` and `continue` for control.

**Q2. What is the difference between `for` and `foreach`?**
`for` has explicit initialisation, condition and step, so it can cover any range in any direction. `foreach` visits every index of an array automatically, with an implicit read-only loop variable, and works directly on associative arrays and multiple dimensions.

**Q3. What is the difference between `while` and `do`...`while`?**
`while` tests the condition before the body and may run zero times. `do`...`while` tests after the body and always runs at least once.

**Q4. In `repeat (n)`, what happens if `n` changes inside the loop?**
Nothing. The count is evaluated once, before the first pass.

**Q5. What do `break` and `continue` do in nested loops?**
They affect only the innermost loop that contains them.

**Q6. In what order does `foreach` traverse `int a [5:1]`?**
From the left bound to the right bound: 5, 4, 3, 2, 1.

**Q7. How do you loop over a two-dimensional array?**
`foreach (m[i, j])`, or two nested `for` loops using `$size(m, 1)` and `$size(m, 2)`.

**Q8. Are loops synthesizable?**
`for`, `foreach` and `repeat` loops with bounds that are constant at compile time are synthesizable and are unrolled into replicated logic. Loops whose number of passes depends on run-time data, and `forever` loops without a clock event, are not.

**Q9. How do you safely delete elements from a queue while iterating over it?**
Iterate from the last index down to 0, or replace the queue with the result of `find with (...)` that keeps the wanted elements.

**Q10. Why does a `forever` loop without a delay hang the simulation?**
The simulator executes the loop endlessly within the current time step and never gets the opportunity to advance simulation time or run other processes.
