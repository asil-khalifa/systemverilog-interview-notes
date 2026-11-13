# Part 4: Array Methods: Searching, Ordering and Reduction

## 4.1 Overview of the Built-in Array Methods

### In plain English

Finding an element, sorting, adding everything up: these jobs come up constantly, and each would normally need a loop. SystemVerilog provides them as built-in methods, so that one line replaces five. The methods are called on the array with the dot operator, for example `arr.sort()` or `arr.sum()`.

### The three families

| Family | Methods | What they do | Return |
|---|---|---|---|
| **Locator** (searching) | `find`, `find_index`, `find_first`, `find_first_index`, `find_last`, `find_last_index`, `min`, `max`, `unique`, `unique_index` | Search the array for elements or indices | Always a **queue** |
| **Ordering** | `sort`, `rsort`, `reverse`, `shuffle` | Rearrange the elements **in place** | Nothing (`void`) |
| **Reduction** | `sum`, `product`, `and`, `or`, `xor` | Combine all elements into one value | A single value |

### Which arrays support which methods

| Method family | Fixed-size | Dynamic | Queue | Associative | Packed |
|---|---|---|---|---|---|
| Locator | Yes | Yes | Yes | Yes | No |
| Ordering | Yes | Yes | Yes | **No** | No |
| Reduction | Yes | Yes | Yes | Yes | No |

All of these methods are simulation-only testbench features.

### The with clause and the iterator

Most methods accept a `with` clause: an expression in parentheses that is evaluated once for every element. Inside the expression, the current element is called `item`.

```systemverilog
r = arr.find with (item > 5);          // keep the elements for which the expression is true
```

| Feature | Syntax | Meaning |
|---|---|---|
| Default iterator name | `item` | The current element |
| Your own iterator name | `arr.find(x) with (x > 5)` | The name in the parentheses after the method replaces `item` |
| Index of the current element | `item.index` | The index of the element being examined (`x.index` with a custom name) |
| Member access | `item.addr`, `item.len` | When the elements are structs or class objects |

What the `with` expression means depends on the family:

| Family | Meaning of the `with` expression | Required? |
|---|---|---|
| `find...` methods | A condition: the element is selected if the expression is true | **Mandatory** |
| `min`, `max`, `unique`, `unique_index` | The value to compare instead of the element itself | Optional |
| `sort`, `rsort` | The key to sort by | Optional |
| `reverse`, `shuffle` | Not allowed | Not allowed |
| Reduction methods | The value to combine instead of the element itself | Optional |

`item.index` is part of the standard since IEEE 1800-2009; a few older tool versions do not support it.

## 4.2 Array Searching: Locator Methods

### Technical definition

Locator methods traverse an unpacked array and return a **queue** containing either the matching elements or their indices. The queue is empty when nothing matches.

| Method | Returns a queue containing |
|---|---|
| `find() with (expr)` | **All elements** for which `expr` is true |
| `find_index() with (expr)` | The **indices** of all elements for which `expr` is true |
| `find_first() with (expr)` | The **first** element for which `expr` is true (0 or 1 entries) |
| `find_first_index() with (expr)` | The index of the first such element (0 or 1 entries) |
| `find_last() with (expr)` | The **last** element for which `expr` is true (0 or 1 entries) |
| `find_last_index() with (expr)` | The index of the last such element (0 or 1 entries) |
| `min()` | The element with the smallest value (1 entry; empty if the array is empty) |
| `max()` | The element with the largest value (1 entry; empty if the array is empty) |
| `unique()` | One element for each distinct value |
| `unique_index()` | One index for each distinct value |

**Type of the result**

| Method returns | Result must be declared as |
|---|---|
| Elements (`find`, `find_first`, `find_last`, `min`, `max`, `unique`) | A queue of the **element type**: `int r [$];` for an array of `int` |
| Indices (`find_index`, `find_first_index`, `find_last_index`, `unique_index`) | A queue of `int` for fixed, dynamic and queue arrays; a queue of the **index type** for an associative array |

### Why results are queues

The number of matches is unknown until run time: none, one or many. Even the methods that can return at most one element (`find_first`, `min`, `max`) return a queue, because "no match" must be representable. You therefore always check `size()` before using `result[0]`.

### How it works internally

```text
   int d [] = '{4, 9, 2, 9, 7, 2, 5};
   index :       0  1  2  3  4  5  6

   d.find with (item > 5)

      index 0 : item = 4   4 > 5 ?  no
      index 1 : item = 9   9 > 5 ?  yes  -> result = {9}
      index 2 : item = 2            no
      index 3 : item = 9            yes  -> result = {9, 9}
      index 4 : item = 7            yes  -> result = {9, 9, 7}
      index 5 : item = 2            no
      index 6 : item = 5            no
                                            returns {9, 9, 7}

   d.find_index with (item > 5)             returns {1, 3, 4}
   d.find_first with (item > 5)             stops at index 1,   returns {9}
   d.find_last_index with (item < 5)        scans from the end, returns {5}
```

Each method is a linear scan: its cost is proportional to the number of elements.

### Complete example

```systemverilog file=tb_array_locator.sv
module tb_array_locator;

  int d [] = '{4, 9, 2, 9, 7, 2, 5};
  int r  [$];          // for returned elements
  int ix [$];          // for returned indices

  initial begin
    r  = d.find with (item > 5);              $display("1.  find > 5             : %p", r);
    ix = d.find_index with (item > 5);        $display("2.  find_index > 5       : %p", ix);
    r  = d.find_first with (item > 5);        $display("3.  find_first > 5       : %p", r);
    ix = d.find_first_index with (item > 5);  $display("4.  find_first_index > 5 : %p", ix);
    r  = d.find_last with (item < 5);         $display("5.  find_last < 5        : %p", r);
    ix = d.find_last_index with (item < 5);   $display("6.  find_last_index < 5  : %p", ix);

    r  = d.find with (item > 100);
    $display("7.  find > 100           : size %0d", r.size());

    r  = d.min();                             $display("8.  min                  : %p", r);
    r  = d.max();                             $display("9.  max                  : %p", r);

    r  = d.unique();
    r.sort();                                 $display("10. unique (sorted)      : %p", r);
    ix = d.unique_index();
    $display("11. unique_index         : size %0d", ix.size());

    r  = d.find with (item.index >= 4);       $display("12. index >= 4           : %p", r);
    r  = d.find(x) with (x % 2 == 0);         $display("13. even values          : %p", r);

    ix = d.find_index with (item == 9);
    $display("14. the value 9 occurs %0d times, first at index %0d", ix.size(), ix[0]);
  end

endmodule
```

```output
1.  find > 5             : '{9, 9, 7}
2.  find_index > 5       : '{1, 3, 4}
3.  find_first > 5       : '{9}
4.  find_first_index > 5 : '{1}
5.  find_last < 5        : '{2}
6.  find_last_index < 5  : '{5}
7.  find > 100           : size 0
8.  min                  : '{2}
9.  max                  : '{9}
10. unique (sorted)      : '{2, 4, 5, 7, 9}
11. unique_index         : size 5
12. index >= 4           : '{7, 2, 5}
13. even values          : '{4, 2, 2}
14. the value 9 occurs 2 times, first at index 1
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | All elements greater than 5, in array order. |
| 2 | Their indices. Note the result variable is the `int` queue `ix`. |
| 3, 4 | Only the first match and its index. The result is still a queue, with one entry. |
| 5, 6 | Elements less than 5 are at indices 0 (4), 2 (2) and 5 (2). The last one is index 5, value 2. |
| 7 | Nothing matches, so the queue is empty. Reading `r[0]` here would return 0 with a warning. |
| 8, 9 | `min()` and `max()` return one-element queues. To get the value, use `r[0]`. |
| 10 | The array contains five distinct values. The standard does not define the order in which `unique()` returns them (most simulators return them in order of first appearance), so the result is sorted before printing to make the output predictable. |
| 11 | Five indices, one per distinct value. For a duplicated value the standard does not say which of its indices is returned, so only the count is printed. |
| 12 | `item.index` gives access to the position: elements at indices 4, 5 and 6. |
| 13 | A custom iterator name `x` is used instead of `item`. |
| 14 | A common idiom: the size of `find_index` is the number of occurrences. `ix` is `{1, 3}`. |

### Searching arrays of structs or objects

The `with` clause becomes more useful when the elements have members. The same code works unchanged when the elements are class handles such as `alu_txn` (Module 4).

```systemverilog file=tb_array_locator_struct.sv
module tb_array_locator_struct;

  typedef struct {
    int       id;
    bit [7:0] addr;
    int       len;
  } pkt_t;

  pkt_t pkts [$];
  pkt_t res  [$];
  int   idx  [$];

  initial begin
    pkts = '{ '{1, 8'h40, 12}, '{2, 8'h10, 64}, '{3, 8'h40, 3}, '{4, 8'h80, 30} };

    res = pkts.find with (item.addr == 8'h40);
    foreach (res[i]) $display("1. addr 40 : id %0d", res[i].id);

    res = pkts.max with (item.len);
    $display("2. longest packet  : id %0d (len %0d)", res[0].id, res[0].len);

    res = pkts.min with (item.len);
    $display("3. shortest packet : id %0d (len %0d)", res[0].id, res[0].len);

    idx = pkts.find_first_index(p) with (p.len > 20);
    $display("4. first packet longer than 20 is at index %0d", idx[0]);

    res = pkts.unique with (item.addr);
    $display("5. %0d different addresses", res.size());

    idx = pkts.find_index with (item.len > 100);
    if (idx.size() == 0) $display("6. no packet longer than 100");
  end

endmodule
```

```output
1. addr 40 : id 1
1. addr 40 : id 3
2. longest packet  : id 2 (len 64)
3. shortest packet : id 3 (len 3)
4. first packet longer than 20 is at index 1
5. 3 different addresses
6. no packet longer than 100
```

| Line | Explanation |
|---|---|
| 1 | `find` returns the whole elements (structs) whose `addr` is `40`: the packets with id 1 and 3. |
| 2, 3 | With a `with` clause, `max` and `min` compare the given expression (`len`) but return the **element**, so its other members are available. |
| 4 | A custom iterator name `p`. Packet 2 (index 1, len 64) is the first with `len` above 20. |
| 5 | `unique with (item.addr)` keeps one element per distinct address: `40`, `10`, `80`. |
| 6 | Always test `size()` before using the result of a locator method. |

### Useful one-line idioms

| Task | Code |
|---|---|
| Does the array contain the value `v`? | `if (v inside {arr})` |
| How many elements satisfy a condition? | `n = arr.find with (item > 5).size();` or `n = arr.sum() with (int'(item > 5));` |
| Index of the largest element | `mx = arr.max(); ix = arr.find_first_index with (item == mx[0]);` |
| Remove duplicates | `q = q.unique();` |
| Are all elements different? | `arr.unique().size() == arr.size()` |
| Remove all elements that satisfy a condition | `q = q.find with (!(item > 5));` |
| Is the array already sorted? | `tmp = arr; tmp.sort(); if (tmp == arr) ...` |

Calling a method directly on the result of another (`arr.find with (...).size()`) is accepted by current simulators; if a tool rejects it, store the result in a queue first.

> **Interview trap:** "What does `find_first()` return?" A queue, not a single element. `int x = arr.find_first with (item > 5);` is a compile error (a queue cannot be assigned to an `int`). Declare `int r [$];` and use `r[0]` after checking `r.size()`.

> **Interview trap:** "Is the `with` clause optional for `find()`?" No. For all six `find...` methods it is mandatory, because without a condition there is nothing to search for. It is optional for `min`, `max`, `unique` and `unique_index`.

> **Common mistake:** Declaring the result of `find_index` with the element type. Indices are `int` (or the index type for an associative array), whatever the element type is.

> **Common mistake:** Using `min()` or `max()` on an empty array and reading `[0]` of the empty result.

> **Verification application:** Locator methods are used in scoreboards and checkers. To match a response against pending requests: `idx = pending.find_first_index with (item.id == rsp.id);` and then `pending.delete(idx[0]);`. To check that a randomized array of IDs has no duplicates: `assert (ids.unique().size() == ids.size());`. To report the worst case at the end of a test: `worst = latency_q.max();`.

### Interview questions

**Q1. What do the locator methods return?**
A queue: of elements for `find`, `find_first`, `find_last`, `min`, `max` and `unique`; of indices for `find_index`, `find_first_index`, `find_last_index` and `unique_index`.

**Q2. What is the difference between `find()` and `find_index()`?**
`find()` returns the matching elements. `find_index()` returns the positions of the matching elements.

**Q3. What is the difference between `find_first()` and `find()`?**
`find()` returns every match. `find_first()` stops at the first match and returns a queue with at most one element.

**Q4. What is `item` in a `with` clause?**
The default name of the iterator: it refers to the array element currently being examined. A different name can be given as an argument of the method, and `item.index` gives the element's index.

**Q5. How do you find the number of elements greater than 10 in an array?**
`int r [$] = arr.find with (item > 10);` then `r.size()`. Alternatively `arr.sum() with (int'(item > 10))`.

**Q6. What do `min()` and `max()` return for an empty array?**
An empty queue.

**Q7. How do you find the index of the maximum element?**
Get the maximum with `m = arr.max();`, then `ix = arr.find_first_index with (item == m[0]);`.

**Q8. How do you remove duplicate values from a queue?**
`q = q.unique();`

**Q9. What does `unique_index()` return?**
A queue of indices, one for each distinct value in the array.

**Q10. For an associative array `int aa [string]`, what is the type of the result of `aa.find_index with (item > 5)`?**
A queue of `string`, because the index type is `string`.

## 4.3 Array Sorting and Ordering Methods

### Technical definition

Ordering methods rearrange the elements of the array itself. They return nothing. They work on fixed-size arrays, dynamic arrays and queues, but not on associative arrays.

| Method | Effect | `with` clause |
|---|---|---|
| `sort()` | Sorts in **ascending** order | Optional: the key to sort by |
| `rsort()` | Sorts in **descending** order | Optional: the key to sort by |
| `reverse()` | Reverses the current order of the elements | Not allowed |
| `shuffle()` | Puts the elements in a random order | Not allowed |

Elements are compared according to their type: integers by value (signed types as signed numbers), strings in lexicographic order. For elements that cannot be compared directly, such as structs and class handles, a `with` clause naming a sortable member is required.

### How it works internally

```text
   int d [] = '{4, 9, 2, 9, 7, 2, 5};

   d.sort();      d = '{2, 2, 4, 5, 7, 9, 9}       ascending, in place
   d.rsort();     d = '{9, 9, 7, 5, 4, 2, 2}       descending, in place
   d.reverse();   d = '{2, 2, 4, 5, 7, 9, 9}       mirror of the previous order
   d.shuffle();   d = some random permutation      same elements, random order

   With a key:
   pkts.sort with (item.len);     the elements are whole structs,
                                  but they are ordered by their len member
```

The original order is lost. If you need both the original and the sorted version, copy the array first and sort the copy. The standard does not say what happens to the relative order of elements with equal keys, so do not rely on it.

### Complete example

```systemverilog file=tb_array_ordering.sv
module tb_array_ordering;

  typedef struct {
    int id;
    int len;
  } pkt_t;

  int    d [] = '{4, 9, 2, 9, 7, 2, 5};
  int    copy [];
  string names [$] = {"ravi", "anu", "zoya", "maya"};
  pkt_t  pkts [4] = '{ '{1, 12}, '{2, 64}, '{3, 3}, '{4, 30} };

  initial begin
    copy = d;                       // keep the original order
    d.sort();                       $display("1. sort     : %p", d);
    d.rsort();                      $display("2. rsort    : %p", d);
    d.reverse();                    $display("3. reverse  : %p", d);
    $display("4. original is untouched in the copy : %p", copy);

    names.sort();                   $display("5. strings sorted  : %p", names);
    names.rsort();                  $display("6. strings rsorted : %p", names);

    pkts.sort with (item.len);
    $write("7. packets by len        :");
    foreach (pkts[i]) $write(" id%0d(len %0d)", pkts[i].id, pkts[i].len);
    $display("");

    pkts.rsort(p) with (p.id);
    $write("8. packets by id, reverse:");
    foreach (pkts[i]) $write(" id%0d", pkts[i].id);
    $display("");

    d.sort with (-item);            $display("9. sort with (-item) : %p", d);

    d.shuffle();
    $display("10. after shuffle: size %0d, sum %0d", d.size(), d.sum());
  end

endmodule
```

```output
1. sort     : '{2, 2, 4, 5, 7, 9, 9}
2. rsort    : '{9, 9, 7, 5, 4, 2, 2}
3. reverse  : '{2, 2, 4, 5, 7, 9, 9}
4. original is untouched in the copy : '{4, 9, 2, 9, 7, 2, 5}
5. strings sorted  : '{"anu", "maya", "ravi", "zoya"}
6. strings rsorted : '{"zoya", "ravi", "maya", "anu"}
7. packets by len        : id3(len 3) id1(len 12) id4(len 30) id2(len 64)
8. packets by id, reverse: id4 id3 id2 id1
9. sort with (-item) : '{9, 9, 7, 5, 4, 2, 2}
10. after shuffle: size 7, sum 38
```

**Line by line**

| Line | Explanation |
|---|---|
| `copy = d;` | Ordering methods modify the array. The copy preserves the original. |
| 1 | Ascending order. |
| 2 | Descending order. |
| 3 | `reverse()` does not sort; it mirrors whatever order the array currently has. Since the array was in descending order, the result is ascending. |
| 5, 6 | Strings are compared character by character. |
| 7 | A struct cannot be compared as a whole, so the key is given with `with (item.len)`. The elements that move are the complete structs. |
| 8 | `rsort` with a custom iterator name, descending by `id`. |
| 9 | Sorting by the negated value gives descending order: an alternative to `rsort()`. |
| 10 | `shuffle()` produces a random permutation, so the order differs from run to run and between simulators. What can be stated for certain is that the same seven elements are still there: the size is 7 and the sum is 38. |

### sort, rsort, reverse and shuffle compared

| Method | Result depends on current order? | Result predictable? | Typical use |
|---|---|---|---|
| `sort()` | No | Yes | Ordering results for reports, comparing two collections regardless of order |
| `rsort()` | No | Yes | Highest first: "top N" reports |
| `reverse()` | Yes | Yes | Reversing byte order of a payload; processing last-to-first |
| `shuffle()` | No | No (random) | Randomising the order of a fixed set of items, such as a list of addresses or tests |

> **Interview trap:** "What is the difference between `rsort()` and `reverse()`?" `rsort()` sorts into descending order whatever the starting order. `reverse()` only flips the existing order and does not compare elements at all. They give the same result only if the array was already sorted ascending.

> **Interview trap:** "Can you sort an associative array?" No. Ordering methods are not defined for associative arrays, whose entries are always kept in key order.

> **Common mistake:** Writing `sorted = arr.sort();`. Ordering methods return `void` and change `arr` itself. Write `sorted = arr; sorted.sort();`.

> **Common mistake:** Calling `sort()` on an array of structs or class handles without a `with` clause. There is no defined ordering for such elements; give the key explicitly.

> **Verification application:** (1) A scoreboard for a DUT that may reorder data compares sorted copies: `exp.sort(); act.sort(); if (exp != act) $error(...)`. (2) `shuffle()` is a simple way to visit every item of a list exactly once in random order, for example to write all registers in a random sequence: fill a queue with the addresses, shuffle it, then loop. (3) Sorting a queue of latencies gives the minimum, median and maximum for a performance report.

### Interview questions

**Q1. Which array ordering methods exist?**
`sort()`, `rsort()`, `reverse()` and `shuffle()`.

**Q2. Do ordering methods return a new array?**
No. They return nothing and modify the array in place.

**Q3. How do you sort an array of transactions by their address field?**
`txn_q.sort with (item.addr);`

**Q4. How do you sort in descending order?**
`arr.rsort();`, or `arr.sort(); arr.reverse();`, or `arr.sort with (-item);` for signed numeric elements.

**Q5. How do you sort by two fields, first by address and then by ID?**
Use a `with` expression that combines them with the more important field in the upper bits: `q.sort with ({item.addr, item.id});`. Both fields must be unsigned (or non-negative) for the concatenation to order correctly.

**Q6. What does `shuffle()` do, and is its result repeatable?**
It rearranges the elements randomly. Like other random features, it is repeatable for the same simulator and the same seed, and differs between seeds.

**Q7. Which array types support `sort()`?**
Fixed-size arrays, dynamic arrays and queues. Not associative arrays, and not packed arrays.

## 4.4 Array Reduction Methods

### Technical definition

A reduction method combines all the elements of an unpacked array into a single value by applying one operator across them.

| Method | Operation | Result for `'{1, 2, 3, 4}` |
|---|---|---|
| `sum()` | Adds all elements | 10 |
| `product()` | Multiplies all elements | 24 |
| `and()` | Bitwise AND of all elements | 0 |
| `or()` | Bitwise OR of all elements | 7 |
| `xor()` | Bitwise XOR of all elements | 4 |

An optional `with` clause supplies an expression to be combined instead of the element itself:

```systemverilog
total_len = pkts.sum() with (item.len);            // add up a member
sq        = arr.sum() with (item * item);          // sum of squares
evens     = arr.sum() with (item % 2 == 0 ? item : 0);   // sum of the even values only
```

### The rule that causes the most bugs

> **Key point:** The result of a reduction method has **the type of the array element** (or the type of the `with` expression, if there is one). The calculation is done in that width. The width of the variable you assign the result to does not matter.

```text
   bit [7:0] b [] = '{200, 100, 50};

   int total = b.sum();
        |
        |   elements are 8 bits  ->  the sum is computed in 8 bits
        |   200 + 100 + 50 = 350 = 1_0101_1110  ->  truncated to 0101_1110 = 94
        v
   total = 94          (NOT 350, even though total is 32 bits wide)

   int total = b.sum() with (int'(item));
        |
        |   the with expression is an int  ->  the sum is computed in 32 bits
        v
   total = 350
```

The same rule produces a second classic bug. A comparison such as `item > 2` is **one bit** wide, so `arr.sum() with (item > 2)` adds up 1-bit values in a 1-bit result. Cast the comparison to `int` to count.

### Complete example

```systemverilog file=tb_array_reduction.sv
module tb_array_reduction;

  int       n [] = '{1, 2, 3, 4};
  bit [7:0] b [] = '{200, 100, 50};
  bit [3:0] m [] = '{4'b1100, 4'b1010, 4'b1001};
  int       e [$];                         // empty queue
  int       total;

  initial begin
    $display("1. sum = %0d   product = %0d", n.sum(), n.product());
    $display("2. and = %0d   or = %0d   xor = %0d", n.and(), n.or(), n.xor());

    total = b.sum();
    $display("3. b.sum()                    = %0d", total);
    total = b.sum() with (int'(item));
    $display("4. b.sum() with (int'(item))  = %0d", total);

    $display("5. count of n > 2 : wrong = %0d   right = %0d",
             n.sum() with (item > 2), n.sum() with (int'(item > 2)));

    $display("6. and = %b   or = %b   xor = %b", m.and(), m.or(), m.xor());

    $display("7. sum of squares     = %0d", n.sum() with (item * item));
    $display("8. sum of even values = %0d", n.sum() with (item % 2 == 0 ? item : 0));
    $display("9. sum of index*value = %0d", n.sum() with (item.index * item));

    $display("10. sum of an empty queue = %0d", e.sum());
    $display("11. average = %0.2f", real'(n.sum()) / n.size());
  end

endmodule
```

```output
1. sum = 10   product = 24
2. and = 0   or = 7   xor = 4
3. b.sum()                    = 94
4. b.sum() with (int'(item))  = 350
5. count of n > 2 : wrong = 0   right = 2
6. and = 1000   or = 1111   xor = 1111
7. sum of squares     = 30
8. sum of even values = 6
9. sum of index*value = 20
10. sum of an empty queue = 0
11. average = 2.50
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | 1+2+3+4 = 10 and 1×2×3×4 = 24. |
| 2 | In binary the values are `001`, `010`, `011`, `100`. AND of all: `000`. OR of all: `111` = 7. XOR: `001^010` = `011`, `^011` = `000`, `^100` = `100` = 4. |
| 3 | The elements are 8 bits wide, so the sum is 8 bits wide: 350 mod 256 = 94. The 32-bit `total` receives the already truncated value. |
| 4 | Casting each element to `int` in the `with` clause makes the sum 32 bits wide: 350. |
| 5 | Two elements (3 and 4) are greater than 2. Without the cast each comparison is a 1-bit value and so is the sum: 1 + 1 = 2 does not fit in one bit and becomes 0. With `int'()` the count is correct. |
| 6 | Bit by bit over `1100`, `1010`, `1001`: AND is `1000`, OR is `1111`, XOR is `1111`. |
| 7 | 1 + 4 + 9 + 16 = 30. |
| 8 | The conditional expression contributes the value for even elements and 0 otherwise: 2 + 4 = 6. |
| 9 | `item.index` is the position: 0×1 + 1×2 + 2×3 + 3×4 = 20. |
| 10 | Reducing an empty array gives 0 for `sum()`. |
| 11 | `n.sum() / n.size()` would be the integer division 10 / 4 = 2. Casting to `real` first gives 2.50 (Module 1, Section 2.7). |

### Reduction over more than one dimension

A reduction method works on one dimension. For a two-dimensional array the elements of the outer array are themselves arrays, so the inner reduction is written inside the `with` clause:

```systemverilog
int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
int total;

total = m.sum() with (item.sum());         // item is one row; result is 21
```

This nested form is accepted by the major simulators, but support has been uneven historically. A pair of nested `foreach` loops is the portable alternative.

### Reduction methods versus reduction operators

Do not confuse the array reduction **methods** with the reduction **operators** of Module 1.

| | Reduction operator | Reduction method |
|---|---|---|
| Syntax | `^v`, `&v`, `\|v` (unary, before the operand) | `arr.xor()`, `arr.and()`, `arr.or()`, `arr.sum()`, `arr.product()` |
| Works on | The **bits** of one packed vector | The **elements** of one unpacked array |
| Result | 1 bit | A value as wide as one element |
| Example | `^8'b1011_0010` = 0 (four ones: even parity) | For `arr` = `'{8'hA0, 8'h0A}`, `arr.xor()` = `8'hAA` |
| Synthesizable | Yes | No |

> **Interview trap:** `bit [7:0] arr [4] = '{100, 100, 100, 100}; int s = arr.sum();`. What is `s`? It is 144, not 400. The sum is computed in 8 bits: 400 mod 256 = 144. Fix: `arr.sum() with (int'(item))`.

> **Interview trap:** "Count the elements greater than 5 using `sum()`." The answer `arr.sum() with (item > 5)` is wrong because the expression is one bit wide. The correct answer is `arr.sum() with (int'(item > 5))`.

> **Common mistake:** Computing an average with `arr.sum() / arr.size()` and expecting a fraction. Both operands are integers. Cast one to `real`.

> **Common mistake:** Using `product()` on more than a few elements. The result overflows the element width very quickly and is silently truncated.

> **Verification application:** (1) Checksums: `checksum = payload.xor();` gives the XOR of all payload bytes; `payload.sum() with (int'(item))` gives an additive checksum. (2) Constraints (Module 5): `constraint c { payload.sum() with (int'(item)) < 1000; }` limits the total of a random array, and the same width rule applies inside constraints. (3) End-of-test statistics: total bytes transferred, average latency. (4) Checking a one-hot array of grants: `assert (grant.sum() with (int'(item)) <= 1);`.

### Interview questions

**Q1. What are the array reduction methods?**
`sum()`, `product()`, `and()`, `or()` and `xor()`. Each combines all elements of an unpacked array into one value.

**Q2. What is the width of the result of `sum()`?**
The width of the array element type, or of the `with` expression if one is given. It does not depend on the variable receiving the result.

**Q3. `bit [7:0] a [3] = '{255, 1, 1}; $display("%0d", a.sum());` What is printed, and how do you get the true total?**
1, because 257 is truncated to 8 bits. Use `a.sum() with (int'(item))` to get 257.

**Q4. How do you compute the XOR checksum of a byte array?**
`chk = payload.xor();`

**Q5. How do you add up only the elements at even indices?**
`arr.sum() with (item.index % 2 == 0 ? item : 0)`

**Q6. What is the difference between `^vec` and `arr.xor()`?**
`^vec` is the reduction operator: it XORs the bits of one packed vector and returns one bit. `arr.xor()` is the reduction method: it XORs the elements of an unpacked array and returns a value of the element width.

**Q7. How do you find the total length of all packets in a queue of packet structs?**
`total = pkts.sum() with (item.len);`

**Q8. Can reduction methods be used on an associative array?**
Yes. They combine the values of all existing entries.
