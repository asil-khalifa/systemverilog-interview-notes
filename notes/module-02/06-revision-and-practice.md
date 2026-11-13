# Part 7: Module 2 Revision and Practice

## 7.1 Revision Summary

### The array kinds on one page

| Kind | Declaration | Size | Allocate | Count | Remove | Literal |
|---|---|---|---|---|---|---|
| Packed | `logic [7:0] p;` | Fixed | n/a | `$size(p)`, `$bits(p)` | n/a | `8'hA5`, `{a, b}` |
| Fixed-size | `int a [8];` | Fixed | n/a | `$size(a)` | n/a | `'{1, 2, ...}` |
| Dynamic | `int d [];` | Run time | `d = new[n];` `d = new[n](d);` | `d.size()` | `d.delete()` | `'{1, 2, 3}` |
| Queue | `int q [$];` | Automatic | Automatic | `q.size()` | `q.delete(i)`, `q.delete()`, `pop_*` | `{1, 2, 3}` |
| Associative | `int aa [key_t];` | Automatic | On first write | `aa.num()`, `aa.size()` | `aa.delete(k)`, `aa.delete()` | `'{k1: v1, k2: v2}` |

### Methods by array kind

| Kind | Methods specific to it |
|---|---|
| Dynamic | `new[]`, `size()`, `delete()` |
| Queue | `size()`, `push_back()`, `push_front()`, `pop_back()`, `pop_front()`, `insert(i, v)`, `delete(i)`, `delete()` |
| Associative | `num()`, `size()`, `exists(k)`, `delete(k)`, `delete()`, `first(k)`, `last(k)`, `next(k)`, `prev(k)` |
| All unpacked | Locator: `find`, `find_index`, `find_first`, `find_first_index`, `find_last`, `find_last_index`, `min`, `max`, `unique`, `unique_index` |
| All unpacked except associative | Ordering: `sort`, `rsort`, `reverse`, `shuffle` |
| All unpacked | Reduction: `sum`, `product`, `and`, `or`, `xor` |
| Every array | Query functions: `$size`, `$dimensions`, `$unpacked_dimensions`, `$left`, `$right`, `$low`, `$high`, `$increment`, `$bits` |

### Rules to remember

**Fixed-size arrays**

- `int a [5]` means `[0:4]`. The size must be a constant.
- Use `$size(a)`; the `size()` method is not defined for fixed-size arrays.
- Out-of-range read returns X (four-state) or 0 (two-state); out-of-range write is ignored.

**Query functions**

- Dimensions are numbered unpacked first (left to right), then packed (left to right).
- `$left`/`$right` follow the declaration; `$low`/`$high` follow the numbers.
- `$dimensions(int a [4])` is 2, because `int` is itself a packed vector.

**Dynamic arrays**

- Size 0 until `new[n]`. `new[n]` discards the contents; `new[n](d)` keeps them.
- Never grows automatically. `d[d.size()] = x` is ignored.
- `d = other;` resizes and copies.

**Queues**

- `q[0]` is the first element, `q[$]` the last. `q[$+1] = x` appends.
- `push_back` + `pop_front` is a FIFO. `push_back` + `pop_back` is a stack.
- `pop_*` on an empty queue returns the default value with a warning. Check `size()` first.
- `delete(i)` removes one element; `delete()` removes all.

**Associative arrays**

- Entries exist only after being written. Reading a missing key returns the default value and creates nothing.
- Test with `exists()`, never by comparing the value with 0.
- `first`, `last`, `next`, `prev` return a status (1/0) and deliver the key through their argument.
- Traversal is always in sorted key order; signed index types put negative keys first.
- No `sort`, `rsort`, `reverse`, `shuffle`.

**Array methods**

- Every locator method returns a **queue**, possibly empty. `find...` methods require a `with` clause.
- Index-returning methods return `int` (or the index type for an associative array).
- Ordering methods work in place and return nothing. `reverse` and `shuffle` take no `with`.
- A reduction result has the width of the element, or of the `with` expression. Use `int'(item)` to avoid overflow and `int'(condition)` to count.

**Copying and comparing**

- `b = a` copies all elements; the arrays are independent afterwards.
- Arrays of class handles copy the handles only (shallow). A deep copy needs a loop that creates new objects.
- `==`/`!=` compare whole arrays; use `===`/`!==` for four-state data.
- Fixed = dynamic compiles but fails at run time if the sizes differ.

**Loops**

- `foreach` goes from the left bound to the right bound; its variable is implicit and read-only; two dimensions are written `foreach (m[i, j])`.
- `while` may run zero times; `do`...`while` runs at least once.
- `repeat (n)` evaluates `n` once.
- `break` and `continue` act on the innermost loop.
- Do not delete from a queue while looping forward over it.

### Choosing an array

| If the data is... | Use |
|---|---|
| A bus or bit field treated as one number | Packed array |
| A fixed number of items | Fixed-size array |
| A block whose size is decided at run time | Dynamic array |
| A list that grows and shrinks, processed in order | Queue |
| Sparse, or indexed by address, ID or string | Associative array |

## 7.2 Interview Questions and Answers

The questions inside Parts 1 to 6 cover each topic directly. The following are additional and are grouped by difficulty.

### Basic level

**Q1. Name the unpacked array types in SystemVerilog.**
Fixed-size (static) arrays, dynamic arrays, queues and associative arrays.

**Q2. How do you declare each of them for elements of type `int`?**
`int a [10];`, `int d [];`, `int q [$];`, `int aa [string];` (or another index type).

**Q3. What is the difference between `new[]` and `new()`?**
`new[n]` allocates the elements of a dynamic array. `new()` constructs a class object.

**Q4. What is the size of a dynamic array before `new[]` is called?**
Zero.

**Q5. What does `q.pop_front()` do?**
It removes the first element of the queue and returns it.

**Q6. How do you add an element at index 2 of a queue?**
`q.insert(2, value);`

**Q7. How do you check whether a key is present in an associative array?**
`aa.exists(key)`

**Q8. How do you get the number of entries of an associative array?**
`aa.num()` or `aa.size()`.

**Q9. What is the default value of an element of `logic [7:0] mem [16]`? Of `int a [16]`?**
X for every bit of the `logic` elements; 0 for the `int` elements.

**Q10. Which loop would you use to visit every element of an array?**
`foreach (arr[i])`.

**Q11. What does `arr.sum()` return for `int arr [3] = '{1, 2, 3}`?**
6.

**Q12. What does `sort()` do?**
It sorts the array in place in ascending order.

**Q13. How do you empty a queue?**
`q.delete();` or `q = {};`

**Q14. What does `$size` return for `int m [3][4]`?**
3. With a second argument, `$size(m, 2)` returns 4.

**Q15. How do you print a whole array?**
With the `%p` format specifier, or with a `foreach` loop.

### Intermediate level

**Q16. What is the difference between a dynamic array and an associative array?**
A dynamic array has contiguous integer indices from 0, must be allocated with `new[]`, and stores every element. An associative array has an index of any declared type, allocates entries one by one when written, and stores only the entries that exist. The dynamic array is faster to index; the associative array saves memory for sparse data.

**Q17. Both a queue and a dynamic array can change size. When is a queue the better choice?**
When single elements are added or removed frequently, especially at the ends. A queue does this in constant time, whereas a dynamic array must be reallocated and copied for every change of size.

**Q18. `int d [] = new[5]; d[5] = 10;` What happens?**
Index 5 is outside the range 0 to 4. The write is ignored (with a warning) and the array keeps its size. A dynamic array never grows on assignment.

**Q19. How do you add an element to the end of a dynamic array?**
`d = new[d.size() + 1](d); d[d.size() - 1] = value;`. If this is needed often, use a queue.

**Q20. How do you iterate over an associative array in reverse key order?**

```systemverilog
if (aa.last(k))
  do $display("%0d", aa[k]);
  while (aa.prev(k));
```

**Q21. What is the difference between `find_first_index()` and `find_last_index()`?**
Both return a queue with at most one index: the lowest and the highest index, respectively, at which the `with` condition is true.

**Q22. How do you find all the indices at which an array holds the value 0?**
`int ix [$] = arr.find_index with (item == 0);`

**Q23. Can you use array methods inside constraints?**
Yes, the reduction methods (`sum`, `product`, `and`, `or`, `xor`) and `size()` are commonly used in constraints, together with `foreach` and `unique`. Locator and ordering methods cannot be used in constraints; they are applied in `post_randomize()` instead. See Module 5.

**Q24. How do you pass an array to a function without copying it?**
Declare the argument as `ref`, or `const ref` if the function must not modify it. An ordinary `input` argument copies the whole array on every call.

**Q25. How do you declare a queue of queues, and an associative array of queues?**
`int qq [$][$];` and `int aq [string][$];`. Each element of the outer array is itself a queue.

**Q26. Is there any difference between `q.delete();` and `q = {};`?**
No. Both leave the queue empty.

**Q27. How do you get the last element of a dynamic array? Of a queue?**
`d[d.size() - 1]` and `q[$]`. The `$` shorthand is available only for queues.

**Q28. `int a [4] = '{1, 2, 3, 4}; int b [4] = '{4, 3, 2, 1};` How do you check that `b` is the reverse of `a`?**
Copy and reverse one of them, then compare: `int t [4] = b; t.reverse(); if (t == a) ...`. (In a module-level or static context, split the declaration and the assignment.)

**Q29. Which array types can be passed through a module port?**
Packed arrays and fixed-size unpacked arrays. Dynamic arrays, queues and associative arrays can be arguments of tasks and functions and members of classes, but are not used as synthesizable port types.

**Q30. What is the difference between `foreach (m[i, j])` and nested `foreach (m[i])` loops?**
The first visits every element of a two-dimensional array in one statement. Nested loops are needed when something must be done between rows (for example printing a newline), or when the inner dimension has a different size per row.

### Advanced and scenario-based

**Q31. Your scoreboard reports "expected queue not empty" at the end of every test, yet all comparisons passed. What could be wrong?**
More expected items are pushed than outputs are checked. Typical causes: the monitor misses some DUT outputs (for example it samples on the wrong condition), the DUT legitimately drops or merges some inputs and the predictor does not model that, the test ends before the last outputs emerge (no drain time), or the predictor pushes an expectation for transactions that produce no output (such as those during reset).

**Q32. A DUT returns responses in a different order from the requests. How do you change a queue-based scoreboard?**
Replace the expected queue with an associative array keyed by something that identifies the transaction, such as an ID or address. On each response, look up the key with `exists()`, compare, and `delete()` the entry. At the end of the test `num()` must be 0. If no unique key exists, search the queue with `find_first_index with (item.compare(rsp))` and delete the matching entry.

**Q33. A constraint `data.sum() < 100` on `rand bit [7:0] data [4]` produces arrays whose real total is 300 or 560. Why?**
`sum()` is computed in the 8-bit width of the elements, so it wraps around at 256. A true total of 300 gives an 8-bit sum of 44, which satisfies the constraint. The solver is doing exactly what was written. The fix is to widen each element before adding: `data.sum() with (int'(item)) < 100`. For the same reason a constraint such as `data.sum() == 300` can never be satisfied, because an 8-bit sum cannot reach 300, and randomization fails.

**Q34. Why should a memory model use an associative array, and what index type should it have?**
The address space is far larger than the set of addresses a test touches, and an associative array stores only the written locations. The index should be an unsigned type of the address width, such as `bit [31:0]`, so that traversal is in true address order and high addresses are not treated as negative.

**Q35. A testbench becomes slower and uses more memory the longer it runs. Which array-related mistakes would you look for?**
A queue or associative array that is only ever added to: a history queue that stores every transaction, a scoreboard whose entries are never deleted after comparison, or a monitor that pushes into a queue nobody pops. Also repeated `new[size+1](arr)` reallocation of a large dynamic array, and passing large arrays by value in frequently called functions.

**Q36. How would you generate the numbers 0 to 15 in a random order, each exactly once, without `randc`?**
Fill a queue or array with 0 to 15 and call `shuffle()`. Alternatively randomize an array of 16 elements with `unique {arr}` and each element constrained to the range 0 to 15 (Module 5).

**Q37. All ten entries of a queue of transactions show identical field values, equal to the last transaction generated. What is the bug?**
The same object handle was pushed ten times. Only one object exists and every entry refers to it. A new object must be created for each iteration, or a copy pushed: `q.push_back(txn.copy());`.

**Q38. What is the time cost of `q.push_back()`, `q.insert(i, x)`, `aa[key]` and `arr.find with (...)` on N elements?**
`push_back`, `push_front`, `pop_back` and `pop_front` take constant time. `insert` and `delete(i)` in the middle of a queue must move the following elements, so they are proportional to N. An associative lookup has to search for the key; the cost depends on the implementation and is typically logarithmic in N. `find` is a linear scan, proportional to N.

**Q39. How do you compare two queues of transactions when the DUT may deliver them in any order?**
Sort both by a key that defines a unique order (`q.sort with (item.id)`), then compare element by element using the transaction's `compare()` method. Whole-queue `==` would compare handles, not contents.

**Q40. When would `foreach` be the wrong loop?**
When elements are removed during the loop, when the loop must run backwards or over part of the array, when two arrays must be walked with different indices, or when the loop variable must be changed inside the body.

## 7.3 Output-Prediction Questions

Work each one out on paper before reading the answer.

**P1.**

```systemverilog
module p1;
  int q [$] = {1, 2, 3};
  initial begin
    q.push_front(0);
    q.push_back(4);
    void'(q.pop_front());
    q.insert(2, 9);
    q.delete(0);
    $display("%0d %0d %0d %0d size=%0d", q[0], q[1], q[2], q[3], q.size());
  end
endmodule
```

Answer: `2 9 3 4 size=4`. Steps: `{0,1,2,3}`, `{0,1,2,3,4}`, `{1,2,3,4}`, `{1,2,9,3,4}`, `{2,9,3,4}`.

**P2.**

```systemverilog
module p2;
  int d [] = '{1, 2, 3, 4, 5};
  initial begin
    d = new[3](d);
    d = new[5](d);
    $display("%0d %0d %0d %0d %0d", d[0], d[1], d[2], d[3], d[4]);
    d = new[2];
    $display("%0d %0d size=%0d", d[0], d[1], d.size());
  end
endmodule
```

Answer: `1 2 3 0 0` then `0 0 size=2`. Shrinking to 3 drops 4 and 5; growing back to 5 adds two zeros. `new[2]` without a source discards everything.

**P3.**

```systemverilog
module p3;
  int aa [int];
  int k, x;
  initial begin
    aa[5] = 1;  aa[-3] = 2;  aa[100] = 3;
    void'(aa.first(k));  $write("%0d ", k);
    void'(aa.next(k));   $display("%0d", k);
    $display("%0d %0d", aa.exists(7), aa.num());
    x = aa[7];
    $display("%0d %0d", x, aa.num());
    aa[7]++;
    $display("%0d %0d", aa[7], aa.num());
  end
endmodule
```

Answer: `-3 5`, then `0 3`, then `0 3`, then `1 4`. Keys are ordered -3, 5, 100. Reading the missing key 7 returns 0 and adds nothing. The increment creates the entry.

**P4.**

```systemverilog
module p4;
  bit [3:0] v [] = '{8, 8, 4};
  initial $display("%0d %0d %0d %0d", v.sum(), v.sum() with (int'(item)), v.xor(), v.and());
endmodule
```

Answer: `4 20 4 0`. The 4-bit sum of 20 is 20 mod 16 = 4. With the cast it is 20. `1000 ^ 1000 ^ 0100` = `0100` = 4. `1000 & 1000 & 0100` = 0.

**P5.**

```systemverilog
module p5;
  int a [6] = '{5, 3, 8, 3, 9, 1};
  int ix [$], r [$], m [$], u [$];
  initial begin
    ix = a.find_index with (item == 3);
    r  = a.find_last with (item > 4);
    m  = a.min();
    u  = a.unique();
    $display("%0d %0d %0d %0d %0d", ix[0], ix[1], r[0], m[0], u.size());
  end
endmodule
```

Answer: `1 3 9 1 5`. The value 3 is at indices 1 and 3. The last element greater than 4 is 9. The minimum is 1. There are five distinct values.

**P6.**

```systemverilog
module p6;
  int a [3:1] = '{10, 20, 30};
  initial begin
    foreach (a[i]) $write("%0d:%0d ", i, a[i]);
    $display("| %0d %0d %0d %0d", $left(a), $right(a), $low(a), $high(a));
  end
endmodule
```

Answer: `3:10 2:20 1:30 | 3 1 1 3`. The pattern fills from the left bound (index 3), and `foreach` iterates from the left bound to the right bound.

**P7.**

```systemverilog
module p7;
  logic [3:0][7:0] x [2][5];
  initial $display("%0d %0d %0d %0d %0d %0d", $dimensions(x), $size(x), $size(x, 2),
                   $size(x, 3), $size(x, 4), $bits(x));
endmodule
```

Answer: `4 2 5 4 8 320`. Dimensions 1 and 2 are the unpacked `[2]` and `[5]`; dimensions 3 and 4 are the packed `[3:0]` and `[7:0]`. 2 × 5 × 4 × 8 = 320 bits.

**P8.**

```systemverilog
module p8;
  int n, c;
  initial begin
    for (int i = 0; i < 10; i++) begin
      if (i % 2) continue;
      if (i > 6) break;
      n += i;
    end
    do c++; while (c < 0);
    $display("%0d %0d", n, c);
  end
endmodule
```

Answer: `12 1`. Even values 0, 2, 4 and 6 are added; at 8 the loop breaks. The `do`...`while` body runs once although the condition is false.

**P9.**

```systemverilog
module p9;
  int q [$] = {1, 2, 3, 4, 5};
  initial begin
    q = q[1:$-1];
    q = {q[$], q[0:$-1]};
    q[$+1] = 7;
    $display("%0d %0d %0d %0d", q[0], q[1], q[2], q[3]);
  end
endmodule
```

Answer: `4 2 3 7`. The slice gives `{2, 3, 4}`. Moving the last element to the front gives `{4, 2, 3}`. Writing to `$+1` appends 7.

**P10.**

```systemverilog
module p10;
  int d [] = '{3, 1, 2};
  int e [];
  initial begin
    e = d;
    e.sort();
    d.reverse();
    $display("%0d %0d %0d | %0d %0d %0d", d[0], d[1], d[2], e[0], e[1], e[2]);
    d.rsort();
    $write("%b ", d == e);
    e.reverse();
    $display("%b", d == e);
  end
endmodule
```

Answer: `2 1 3 | 1 2 3`, then `0 1`. `e` is an independent copy, so sorting it leaves `d` alone. `reverse()` only mirrors `{3,1,2}` into `{2,1,3}`. After `rsort`, `d` is `{3,2,1}`, which differs from `{1,2,3}` until `e` is reversed.

**P11.**

```systemverilog
module p11;
  class item_c;
    int val;
    function new(int v); val = v; endfunction
  endclass
  item_c a [1], b [1];
  initial begin
    a[0] = new(1);
    b    = a;
    b[0].val = 5;
    b[0] = new(9);
    $display("%0d %0d", a[0].val, b[0].val);
  end
endmodule
```

Answer: `5 9`. After `b = a` both handles refer to one object, so `b[0].val = 5` is seen through `a[0]`. Then `b[0] = new(9)` makes `b[0]` refer to a new object; `a[0]` still refers to the first one.

**P12.**

```systemverilog
module p12;
  int n [] = '{5, 10, 15, 20};
  int r [$];
  initial begin
    r = n.find with (item > 8);
    $display("%0d %0d %0d", n.sum() with (item > 8),
             n.sum() with (int'(item > 8)), r.size());
  end
endmodule
```

Answer: `1 3 3`. Three elements exceed 8. The first sum adds three 1-bit ones in a 1-bit result: 3 truncated to one bit is 1. The cast makes the sum 32 bits wide.

## 7.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
int a [4];
initial $display("%0d", a.size());
```

`size()` is not defined for fixed-size arrays. Use `$size(a)`.

**E2.**

```systemverilog
int arr [5] = '{3, 8, 1, 6, 4};
int r;
initial r = arr.find_first with (item > 5);
```

Locator methods return a queue. Declare `int r [$];` and read `r[0]`.

**E3.**

```systemverilog
int arr [5] = '{3, 8, 1, 6, 4};
int r [$];
initial r = arr.find(item > 5);
```

The condition must be in a `with` clause: `arr.find with (item > 5)`.

**E4.**

```systemverilog
int d [] = new[4];
initial d.push_back(5);
```

`push_back` is a queue method. For a dynamic array use `d = new[5](d); d[4] = 5;`, or declare a queue.

**E5.**

```systemverilog
int aa [string];
initial aa.sort();
```

Ordering methods are not available for associative arrays.

**E6.**

```systemverilog
int aa [string];
string k;
initial k = aa.first();
```

`first` takes the key variable as a `ref` argument and returns a status: `if (aa.first(k)) ...`.

**E7.**

```systemverilog
bit [7:0] m [4];
initial m = 0;
```

A single value cannot be assigned to an unpacked array. Use `m = '{default: 0};`.

**E8.**

```systemverilog
int d [];
initial d = new(5);
```

The array constructor uses square brackets: `d = new[5];`. Round brackets belong to the class constructor.

**E9.**

```systemverilog
logic [7:0] v = 8'hA5;
int n;
initial n = v.sum();
```

Array methods do not apply to packed vectors. To count ones use `$countones(v)`.

**E10.**

```systemverilog
int a [4] = '{1, 2, 3};
```

Three values for four elements. Supply four, or `'{0: 1, 1: 2, 2: 3, default: 0}`.

**E11.**

```systemverilog
int d [];
int s [] = d.sort();
```

`sort()` returns nothing. Copy first, then sort: `s = d; s.sort();`.

**E12.**

```systemverilog
foreach (arr[i]) begin
  if (arr[i] == 0) i = i + 1;
end
```

The `foreach` loop variable is read-only. Use `continue`, or a `for` loop if the index must be changed.

### Run-time bugs (the code compiles)

**D1.**

```systemverilog
int d [];
initial begin
  d[0] = 5;
  $display("%0d", d[0]);
end
```

Prints 0. The array was never allocated, so the write is ignored. Add `d = new[1];`.

**D2.**

```systemverilog
bit [7:0] payload [] = '{200, 200, 200};
int total;
initial total = payload.sum();
```

`total` is 88, not 600: the sum is computed in 8 bits (600 mod 256). Use `payload.sum() with (int'(item))`.

**D3.**

```systemverilog
for (int i = 0; i <= q.size(); i++) $display("%0d", q[i]);
```

One pass too many: `q[q.size()]` does not exist. Use `<`.

**D4.**

```systemverilog
int count [string];
initial if (count["ADD"] == 0) $display("ADD never seen");
```

A missing key and a stored 0 cannot be distinguished, and reading a missing key produces a warning. Use `if (!count.exists("ADD"))`.

**D5.**

```systemverilog
foreach (q[i]) if (q[i] < 0) q.delete(i);
```

Deleting while iterating forward skips the element after each deleted one, and the behaviour of `foreach` when the size changes is undefined. Loop backwards with `for`, or `q = q.find with (item >= 0);`.

**D6.**

```systemverilog
d = new[d.size() + 1];
d[d.size() - 1] = new_value;
```

The existing contents are lost because the source array was not passed. Write `d = new[d.size() + 1](d);`.

**D7.**

```systemverilog
expected = exp_q.pop_front();
if (actual !== expected) $error("mismatch");
```

If `exp_q` is empty, `pop_front()` returns the default value and the comparison is made against garbage (or passes by coincidence when the DUT outputs 0). Check `exp_q.size()` first and report an unexpected output.

**D8.**

```systemverilog
alu_txn txn = new();
repeat (5) begin
  void'(txn.randomize());
  q.push_back(txn);
end
```

All five queue entries are the same handle, so they all show the last random values. Create the object inside the loop, or push `txn.copy()`.

**D9.**

```systemverilog
for (int unsigned i = arr.size() - 1; i >= 0; i--) $display("%0d", arr[i]);
```

Infinite loop: an unsigned variable is never negative. Use `int`.

**D10.**

```systemverilog
logic [7:0] mem [int];
...
foreach (mem[addr]) $display("%h", addr);     // addresses above 7FFF_FFFF print first
```

The signed index type makes addresses with the top bit set negative, so they sort before 0. Declare the index as `bit [31:0]`.

**D11.**

```systemverilog
int m [2][3];
initial foreach (m[i]) foreach (m[j]) m[i][j] = 7;
```

Column 2 is never written. The inner loop iterates over the first dimension again, so `j` only takes the values 0 and 1. Write `foreach (m[i, j]) m[i][j] = 7;`.

## 7.5 Coding Exercises with Solutions

Attempt each exercise before reading the solution. The solutions are also in `examples/module-02/`.

### Exercise 1: rotate an array

Rotate `'{1, 2, 3, 4, 5}` left by `k` = 2 positions, once with a fixed-size array and index arithmetic, once with a queue.

```systemverilog file=ex01_rotate.sv
module ex01_rotate;

  int arr [5] = '{1, 2, 3, 4, 5};
  int rot [5];
  int q [$];
  int k = 2;

  initial begin
    // 1. index arithmetic: element i of the result comes from index (i + k) modulo size
    foreach (arr[i]) rot[i] = arr[(i + k) % $size(arr)];
    $display("fixed array : %p", rot);

    // 2. queue: move the front element to the back, k times
    q = arr;
    repeat (k) q.push_back(q.pop_front());
    $display("queue       : %p", q);
  end

endmodule
```

```output
fixed array : '{3, 4, 5, 1, 2}
queue       : '{3, 4, 5, 1, 2}
```

### Exercise 2: second-largest value

Find the second-largest distinct value of `'{12, 45, 7, 45, 30}` with a single loop, then with array methods. Assume the values are not negative.

```systemverilog file=ex02_second_largest.sv
module ex02_second_largest;

  int a [5] = '{12, 45, 7, 45, 30};
  int first, second;
  int r [$];

  initial begin
    first  = -1;
    second = -1;
    foreach (a[i]) begin
      if (a[i] > first) begin
        second = first;
        first  = a[i];
      end
      else if (a[i] > second && a[i] != first)
        second = a[i];
    end
    $display("loop    : largest = %0d, second largest = %0d", first, second);

    r = a.unique();
    r.rsort();
    $display("methods : largest = %0d, second largest = %0d", r[0], r[1]);
  end

endmodule
```

```output
loop    : largest = 45, second largest = 30
methods : largest = 45, second largest = 30
```

Trace of the loop: 12 becomes `first`. 45 pushes 12 down to `second`. 7 changes nothing. The second 45 equals `first`, so it is ignored (the `!= first` test). 30 is greater than `second` (12) and replaces it.

### Exercise 3: remove duplicates, keeping the original order

```systemverilog file=ex03_remove_duplicates.sv
module ex03_remove_duplicates;

  int in_q  [$] = {3, 1, 3, 2, 1, 5};
  int out_q [$];
  bit seen  [int];                     // associative array used as a set

  initial begin
    foreach (in_q[i])
      if (!seen.exists(in_q[i])) begin
        seen[in_q[i]] = 1;
        out_q.push_back(in_q[i]);
      end
    $display("%p", out_q);
  end

endmodule
```

```output
'{3, 1, 2, 5}
```

An associative array whose values do not matter acts as a set: `exists()` answers "have I seen this value before?". `unique()` would also remove duplicates, but the standard does not promise the order of its result.

### Exercise 4: frequency count

Count how often each operation name appears and report the most frequent one.

```systemverilog file=ex04_frequency.sv
module ex04_frequency;

  string ops [6] = '{"ADD", "SUB", "ADD", "XOR", "ADD", "SUB"};
  int    freq [string];
  string best;

  initial begin
    foreach (ops[i]) freq[ops[i]]++;

    foreach (freq[k]) $display("%s = %0d", k, freq[k]);

    best = "";
    foreach (freq[k])
      if (best == "" || freq[k] > freq[best]) best = k;
    $display("most frequent: %s (%0d times)", best, freq[best]);
  end

endmodule
```

```output
ADD = 3
SUB = 2
XOR = 1
most frequent: ADD (3 times)
```

### Exercise 5: reference model of a FIFO

Model a FIFO of depth 4 with a queue. Report overflow on a write to a full FIFO and underflow on a read from an empty FIFO. This is the reference model a scoreboard would use for the `sync_fifo` DUT.

```systemverilog file=ex05_fifo_model.sv
module ex05_fifo_model;

  localparam int DEPTH = 4;
  bit [7:0] fifo_q [$];

  function automatic void fifo_write(bit [7:0] data);
    if (fifo_q.size() == DEPTH) begin
      $display("write %h : FULL, data dropped", data);
      return;
    end
    fifo_q.push_back(data);
    $display("write %h : ok   (count %0d)", data, fifo_q.size());
  endfunction

  function automatic void fifo_read();
    bit [7:0] data;
    if (fifo_q.size() == 0) begin
      $display("read     : EMPTY");
      return;
    end
    data = fifo_q.pop_front();
    $display("read  %h : ok   (count %0d)", data, fifo_q.size());
  endfunction

  initial begin
    fifo_write(8'h11);
    fifo_write(8'h22);
    fifo_write(8'h33);
    fifo_write(8'h44);
    fifo_write(8'h55);
    fifo_read();
    fifo_read();
    fifo_write(8'h66);
    repeat (4) fifo_read();
  end

endmodule
```

```output
write 11 : ok   (count 1)
write 22 : ok   (count 2)
write 33 : ok   (count 3)
write 44 : ok   (count 4)
write 55 : FULL, data dropped
read  11 : ok   (count 3)
read  22 : ok   (count 2)
write 66 : ok   (count 3)
read  33 : ok   (count 2)
read  44 : ok   (count 1)
read  66 : ok   (count 0)
read     : EMPTY
```

`size() == DEPTH` is the model's `full` flag and `size() == 0` its `empty` flag. Data leaves in the order it entered.

### Exercise 6: transpose a matrix

```systemverilog file=ex06_transpose.sv
module ex06_transpose;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int t [3][2];

  initial begin
    foreach (m[i, j]) t[j][i] = m[i][j];
    foreach (t[i]) $display("%0d %0d", t[i][0], t[i][1]);
  end

endmodule
```

```output
1 4
2 5
3 6
```

### Exercise 7: one-line answers with array methods

For `'{4, 9, 2, 9, 7, 2, 5}` compute, without writing a loop: the sum of the even values, the number of values above 5, the largest value and its first index, the second-smallest distinct value, whether all values are below 10, and whether 7 is present.

```systemverilog file=ex07_methods.sv
module ex07_methods;

  int d [] = '{4, 9, 2, 9, 7, 2, 5};
  int r [$], ix [$];

  initial begin
    $display("sum of even values       = %0d", d.sum() with (item % 2 == 0 ? item : 0));
    $display("number of values above 5 = %0d", d.sum() with (int'(item > 5)));

    r  = d.max();
    ix = d.find_first_index with (item == r[0]);
    $display("largest = %0d at index %0d", r[0], ix[0]);

    r = d.unique();
    r.sort();
    $display("second-smallest distinct = %0d", r[1]);

    r = d.find with (item >= 10);
    $display("all values below 10      : %s", (r.size() == 0) ? "yes" : "no");
    $display("contains 7               : %s", (7 inside {d}) ? "yes" : "no");
  end

endmodule
```

```output
sum of even values       = 8
number of values above 5 = 3
largest = 9 at index 1
second-smallest distinct = 4
all values below 10      : yes
contains 7               : yes
```

### Exercise 8: find the missing number

An array holds the numbers 1 to N with exactly one missing. Find it.

```systemverilog file=ex08_missing_number.sv
module ex08_missing_number;

  int arr [] = '{1, 2, 4, 5, 6};
  int n, missing;

  initial begin
    n       = arr.size() + 1;                 // the complete set would have n numbers
    missing = n * (n + 1) / 2 - arr.sum();    // sum of 1..n minus the actual sum
    $display("N = %0d, missing number = %0d", n, missing);
  end

endmodule
```

```output
N = 6, missing number = 3
```

1 + 2 + ... + 6 = 21, and the array sums to 18. The elements are `int`, so `sum()` has no overflow problem here.

### Exercise 9: are two arrays permutations of each other?

```systemverilog file=ex09_permutation.sv
module ex09_permutation;

  function automatic bit is_permutation(int x [], int y []);
    if (x.size() != y.size()) return 0;
    x.sort();                  // x and y are copies: the caller's arrays are not changed
    y.sort();
    return (x == y);
  endfunction

  int a [] = '{3, 1, 2};
  int b [] = '{2, 3, 1};
  int c [] = '{3, 1, 1};

  initial begin
    $display("a and b : %b", is_permutation(a, b));
    $display("a and c : %b", is_permutation(a, c));
    $display("a is still %p", a);
  end

endmodule
```

```output
a and b : 1
a and c : 0
a is still '{3, 1, 2}
```

Arrays passed as ordinary arguments are copied, so sorting inside the function does not disturb the caller. Sorted copies of two permutations are identical.

### Exercise 10: row and column totals

```systemverilog file=ex10_row_col_sums.sv
module ex10_row_col_sums;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int col;

  initial begin
    foreach (m[i]) $display("row %0d total = %0d", i, m[i].sum());

    for (int j = 0; j < $size(m, 2); j++) begin
      col = 0;
      for (int i = 0; i < $size(m, 1); i++) col += m[i][j];
      $display("column %0d total = %0d", j, col);
    end
  end

endmodule
```

```output
row 0 total = 6
row 1 total = 15
column 0 total = 5
column 1 total = 7
column 2 total = 9
```

A row `m[i]` is a one-dimensional array, so `sum()` can be called on it. A column is not a contiguous sub-array, so it needs a loop.

### Further practice (no solutions given)

1. Write a function that returns 1 if an array of `int` is a palindrome (reads the same in both directions).
2. Merge two sorted queues into one sorted queue without calling `sort()`.
3. Given `bit [7:0] data [$]`, split it into two queues: values with even parity and values with odd parity.
4. Implement a stack with `push`, `pop` and `peek` functions on a queue, with underflow reporting.
5. Model a 64 KB memory with an associative array. Add a function that prints every written address range as `start-end` when consecutive addresses have been written.
6. Given an array of 9-bit ALU results, print the three largest values and their indices.
7. Count the number of distinct values in an array without using `unique()`.
8. Fill a 4 × 4 two-dimensional array so that element `[i][j]` is `i * 4 + j`, then print its two diagonals.
9. Predict, then run: `int q [$] = {1, 2, 3}; foreach (q[i]) q.push_front(q[i]);` Explain why this loop is dangerous.
10. Write the bubble sort of Section 6.5 so that it stops early when a complete pass makes no swap.

## 7.6 Concepts You Must Understand Before Moving Forward

Do not start Module 3 until you can answer each of these without looking at the notes.

**Array kinds**

- [ ] I can declare a fixed-size array, a dynamic array, a queue and an associative array, and say when each is used in a testbench.
- [ ] I know which arrays are synthesizable.
- [ ] I can explain `$size` versus `size()`, and `$left`/`$right` versus `$low`/`$high`.
- [ ] I can number the dimensions of a mixed packed/unpacked array.

**Dynamic arrays and queues**

- [ ] I can explain the difference between `new[n]` and `new[n](d)`.
- [ ] I know that a dynamic array never grows on assignment.
- [ ] I can write a FIFO and a stack with queue methods.
- [ ] I know what `pop_front()` returns on an empty queue and why the size must be checked.
- [ ] I can rewrite each queue method as a slice/concatenation expression.

**Associative arrays**

- [ ] I can explain why a memory model uses an associative array.
- [ ] I can traverse an associative array with `first`/`next` and with `foreach`, and I know the order.
- [ ] I know what reading a missing key does and why `exists()` is required.

**Array methods**

- [ ] I know that every locator method returns a queue and that `find...` needs a `with` clause.
- [ ] I can explain why `sum()` of a byte array can give a wrong total, and fix it.
- [ ] I can count matching elements with `sum()` and with `find`.
- [ ] I can explain `rsort()` versus `reverse()`.
- [ ] I can sort an array of structs or transactions by a field.

**Copying and loops**

- [ ] I can explain why `b = a` gives independent arrays, except that arrays of class handles share objects.
- [ ] I can write a deep copy of an array of handles.
- [ ] I can explain `while` versus `do`...`while` and `for` versus `foreach`.
- [ ] I can iterate over a two-dimensional array in both ways.
- [ ] I know how to delete elements from a queue safely inside a loop.

## 7.7 What Comes Next

Module 3 covers tasks and functions: the differences between them, argument directions (`input`, `output`, `inout`, `ref`), pass by value and pass by reference, default arguments, `automatic` and `static` lifetime, `void` functions, recursion, and timing control inside tasks. It uses the arrays of this module heavily, in particular to show why large arrays are passed by `ref`, and it explains the functions that the examples in this module used informally.
