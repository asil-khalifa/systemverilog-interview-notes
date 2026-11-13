# Part 2: Dynamic Arrays and Queues

## 2.1 Dynamic Arrays

### In plain English

Sometimes you do not know, when writing the code, how many elements you will need. A packet may carry 1 byte or 1500 bytes, and the length is chosen at random for each packet. A fixed-size array would have to be declared with the maximum size and would waste memory and hide the real length.

A dynamic array is an array whose size is chosen **while the simulation is running**. You declare it empty, and later tell the simulator "give me N elements now". You can ask for a different size again whenever you like.

### Technical definition

A dynamic array is an unpacked array declared with empty brackets `[]`. It has no storage until the `new[]` constructor allocates it at run time. Its elements are always indexed from 0 to `size()-1`. Its size can be changed at any time by calling `new[]` again, optionally preserving the existing contents.

### Why it is needed

| Need | Why a fixed-size array is not enough |
|---|---|
| Random-length payloads | The length is a random variable; each transaction needs a different size |
| Data whose amount depends on configuration or on a file | The size is known only after the test has started |
| Memory efficiency | Allocating the maximum for every transaction wastes memory when thousands of transactions exist |
| Randomization of the size itself | `rand bit [7:0] payload [];` with a constraint on `payload.size()` lets the solver choose the length (Module 5) |

### Syntax

```systemverilog
int       d [];                    // declaration: empty, size 0
bit [7:0] payload [];              // dynamic array of bytes

d = new[10];                       // allocate 10 elements, each set to the default value
d = new[20](d);                    // resize to 20, keeping the old 10 values
d = '{1, 2, 3};                    // assignment pattern: size becomes 3
int e [] = new[4];                 // allocate in the declaration
int f [] = '{5, 6, 7};             // initialise in the declaration
```

### Methods and operators

| Operation | Syntax | What it does |
|---|---|---|
| Allocate | `d = new[n];` | Creates `n` elements with default values. Any previous contents are discarded |
| Allocate and copy | `d = new[n](src);` | Creates `n` elements and copies as many elements of `src` as fit, starting at index 0. Extra elements get the default value |
| Size | `d.size()` | Returns the current number of elements (0 if not allocated) |
| Delete | `d.delete();` | Frees all elements; the size becomes 0 |
| Copy | `d2 = d1;` | `d2` is resized to match and receives a copy of every element |
| Compare | `d1 == d2` | 1 if the sizes are equal and every element is equal |

`new[]` with square brackets is the array constructor. It is different from `new()` with round brackets, which creates a class object (Module 4).

### How it works internally

```text
   int d [];              d : (no storage)                              size = 0

   d = new[4];            d : [ 0 | 0 | 0 | 0 ]                          size = 4
                               0   1   2   3

   d[1] = 7; d[3] = 9;    d : [ 0 | 7 | 0 | 9 ]

   d = new[6](d);         a NEW block of 6 is allocated,
                          the old 4 values are copied into it,
                          the old block is released:
                          d : [ 0 | 7 | 0 | 9 | 0 | 0 ]                  size = 6

   d = new[2](d);         d : [ 0 | 7 ]                                  size = 2
                          (only the first 2 values fit)

   d = new[3];            d : [ 0 | 0 | 0 ]                              size = 3
                          (no source given: old values are LOST)

   d.delete();            d : (no storage)                              size = 0
```

Important consequences:

- The elements are stored as one contiguous block, so `d[i]` is as fast as for a fixed-size array.
- Resizing means allocating a new block and copying. Doing that once per added element is slow; a queue is the right tool for element-by-element growth.
- A dynamic array **never grows by itself**. Writing to an index at or beyond `size()` is an out-of-range write: it is ignored (with a warning), and the array is not extended.

### Complete example

```systemverilog file=tb_dynamic_array.sv
module tb_dynamic_array;

  int d [];
  int e [];
  int f [4] = '{1, 2, 3, 4};

  initial begin
    $display("1. size = %0d", d.size());

    d = new[4];
    foreach (d[i]) d[i] = (i + 1) * 10;
    $display("2. d = %p  size = %0d", d, d.size());

    d = new[6](d);                       // grow, keep contents
    $display("3. d = %p", d);

    d = new[2](d);                       // shrink, keep the first two
    $display("4. d = %p", d);

    d = new[3];                          // no source: contents are lost
    $display("5. d = %p", d);

    e    = d;                            // independent copy, e is resized to 3
    e[0] = 5;
    $display("6. d[0] = %0d  e[0] = %0d", d[0], e[0]);

    d = '{7, 8, 9, 10, 11};              // the pattern sets the size
    $display("7. size = %0d", d.size());

    d = f;                               // fixed-size array copied into a dynamic array
    $display("8. d = %p", d);

    d.delete();
    $display("9. size = %0d", d.size());
  end

endmodule
```

```output
1. size = 0
2. d = '{10, 20, 30, 40}  size = 4
3. d = '{10, 20, 30, 40, 0, 0}
4. d = '{10, 20}
5. d = '{0, 0, 0}
6. d[0] = 0  e[0] = 5
7. size = 5
8. d = '{1, 2, 3, 4}
9. size = 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | A declared but unallocated dynamic array has size 0. |
| 2 | `new[4]` creates four `int` elements, each 0. The `foreach` fills them with 10, 20, 30, 40. |
| 3 | `new[6](d)` allocates six elements and copies the existing four. The two new elements are 0. |
| 4 | `new[2](d)` keeps only the first two values. |
| 5 | `new[3]` without a source allocates three fresh elements. The old 10 and 20 are gone. |
| 6 | Assigning one dynamic array to another resizes the destination and copies the values. The two arrays are independent afterwards. |
| 7 | An assignment pattern with five values makes the size 5. No `new[]` is needed. |
| 8 | A fixed-size array can be assigned to a dynamic array of the same element type; the dynamic array takes its size. |
| 9 | `delete()` releases the storage. |

### A practical example: a variable-length payload

```systemverilog file=tb_dynamic_payload.sv
module tb_dynamic_payload;

  bit [7:0]    payload [];
  int unsigned len;
  bit [7:0]    checksum;

  initial begin
    len     = 6;                              // in a real test this would be random
    payload = new[len];
    foreach (payload[i]) payload[i] = 8'hA0 + i;

    checksum = 8'h00;
    foreach (payload[i]) checksum ^= payload[i];

    // append the checksum: grow by one element, keeping the data
    payload = new[payload.size() + 1](payload);
    payload[payload.size() - 1] = checksum;

    $write("frame (%0d bytes):", payload.size());
    foreach (payload[i]) $write(" %h", payload[i]);
    $display("");
  end

endmodule
```

```output
frame (7 bytes): a0 a1 a2 a3 a4 a5 01
```

The payload holds `A0` to `A5`. XORing them pairwise: `A0^A1` = `01`, `^A2` = `A3`, `^A3` = `00`, `^A4` = `A4`, `^A5` = `01`. The array is then grown by one element with `new[size+1](payload)` and the checksum is stored in the new last position.

### Fixed-size array versus dynamic array

| Property | Fixed-size array | Dynamic array |
|---|---|---|
| Declaration | `int a [8];` | `int d [];` |
| Size decided | At compile time | At run time, with `new[]` |
| Can be resized | No | Yes |
| Storage exists | For the whole simulation | From `new[]` until `delete()` or reallocation |
| Index range | Any declared range, e.g. `[2:9]` | Always `0` to `size()-1` |
| Number of elements | `$size(a)` | `d.size()` or `$size(d)` |
| Size can be randomized | No | Yes, by constraining `d.size()` |
| Synthesizable | Yes | No |
| Typical use | Design-defined sizes: register files, port arrays | Payloads, data read from files, anything of run-time length |

### Assignment between fixed-size and dynamic arrays

| Assignment | Legal? | Behaviour |
|---|---|---|
| `dyn = fixed;` | Yes | `dyn` is resized to the size of `fixed` |
| `dyn1 = dyn2;` | Yes | `dyn1` is resized to match `dyn2` |
| `fixed = dyn;` | Compiles | **Run-time error** if `dyn.size()` differs from the size of `fixed` |

In all cases the element types must be equivalent.

> **Interview trap:** "What is the difference between `d = new[10];` and `d = new[10](d);`?" The first discards the existing contents. The second preserves them. Forgetting the `(d)` when growing an array silently erases the data.

> **Common mistake:** Using a dynamic array before allocating it. `int d []; d[0] = 5;` compiles, but at run time index 0 does not exist: the write is ignored, and a later read returns 0. Allocate with `new[]` or an assignment pattern first.

> **Common mistake:** Appending one element at a time with `d = new[d.size() + 1](d);` inside a loop. Every iteration allocates a new block and copies the whole array. Use a queue, or allocate the final size once.

> **Verification application:** In a packet-based testbench the transaction class contains `rand bit [7:0] payload [];` together with `constraint len_c { payload.size() inside {[1:64]}; }`. Calling `randomize()` first chooses the size, allocates the array, and then randomizes every element. The driver walks the array with `foreach` and sends one byte per clock. Module 5 covers this in detail.

### Interview questions

**Q1. What is a dynamic array?**
An unpacked array whose size is not fixed at compile time. It is declared with empty brackets, allocated at run time with `new[]`, and can be resized or deleted during simulation.

**Q2. How do you allocate, resize and free a dynamic array?**
`d = new[n];` allocates. `d = new[m](d);` resizes while keeping the contents. `d.delete();` frees it.

**Q3. What does `new[8](d)` do if `d` has 10 elements? If `d` has 5?**
With 10 elements, the first 8 are copied and the last two are dropped. With 5 elements, all five are copied and the remaining three elements get the default value.

**Q4. What is the default size of a dynamic array?**
Zero.

**Q5. Can you write to `d[d.size()]` to append an element?**
No. A dynamic array does not grow automatically; that write is out of range and is ignored. (A queue does allow `q[$+1] = x`.)

**Q6. Is a dynamic array synthesizable?**
No. Its size is determined at run time, which hardware cannot do.

**Q7. How do you copy a dynamic array?**
`copy = orig;`. The destination is resized automatically and receives its own copy of the elements. `copy = new[orig.size()](orig);` does the same.

**Q8. Can a dynamic array be an element of another array, or contain other arrays?**
Yes. `int d [][];` is a dynamic array of dynamic arrays, `int q [][$];` is a dynamic array of queues, and `int a [4][];` is a fixed array of four dynamic arrays. Each inner array is allocated separately.

## 2.2 Queues

### In plain English

A queue is a list that can grow and shrink freely. You can add an element at the back or the front, remove one from the back or the front, and insert or delete in the middle. It never needs to be allocated: it starts empty and adjusts its own size as elements come and go.

Two everyday patterns are built from it:

- **First-in, first-out (FIFO):** add at the back, remove from the front. A line of people at a counter.
- **Last-in, first-out (LIFO, a stack):** add at the back, remove from the back. A pile of plates.

### Technical definition

A queue is a variable-size, ordered collection of elements of the same type, declared with `[$]`. Elements are indexed from 0 (the first element) to `$` (the last element). The queue supports constant-time insertion and removal at both ends and offers built-in methods for these operations. Storage is managed automatically by the simulator.

### Why it is needed

A testbench is full of data that arrives and leaves at unpredictable times:

- The scoreboard receives an expected result whenever a transaction is driven, and removes it when the DUT produces the corresponding output.
- A reference model of a FIFO stores written data and returns it on reads.
- A driver keeps a list of pending requests.

A dynamic array would need a reallocation and full copy for every element added or removed. A queue does this efficiently and with far less code.

### Syntax

```systemverilog
int       q [$];                     // unbounded queue of int, initially empty
bit [7:0] byte_q [$];                // queue of bytes
string    names [$] = {"a", "b"};    // initialised queue
int       bq [$:7];                  // bounded queue: max index 7, at most 8 elements
alu_txn   exp_q [$];                 // queue of class handles (transactions)
```

The `$` symbol has two meanings: in the declaration it marks the array as a queue; in an index expression it means "the index of the last element".

### Queue methods

| Method | Prototype | What it does |
|---|---|---|
| `size()` | `function int size();` | Number of elements |
| `push_back(item)` | `function void push_back(T item);` | Adds `item` at the end |
| `push_front(item)` | `function void push_front(T item);` | Adds `item` at the beginning; existing elements move up one index |
| `pop_back()` | `function T pop_back();` | Removes and returns the last element |
| `pop_front()` | `function T pop_front();` | Removes and returns the first element |
| `insert(index, item)` | `function void insert(int index, T item);` | Inserts `item` so that it becomes element `index`; elements from that position onward move up |
| `delete(index)` | `function void delete(int index);` | Removes the element at `index`; later elements move down |
| `delete()` | `function void delete();` | Removes all elements |

In addition a queue supports everything a dynamic array supports: indexing, slicing, `foreach`, whole-queue copy and comparison, and the array methods of Part 4 (`find`, `sort`, `sum` and so on).

### Indexing, slices and concatenation

| Expression | Meaning |
|---|---|
| `q[0]` | First element |
| `q[$]` | Last element |
| `q[$-1]` | Second-to-last element |
| `q[1:3]` | A new queue holding elements 1, 2 and 3 |
| `q[2:$]` | From element 2 to the end |
| `q[0:$-1]` | Everything except the last element |
| `q[$+1] = x;` | Appends `x` (the only index beyond the end that may be written) |
| `q = {};` | Empties the queue |
| `q = {q, x};` | Same as `q.push_back(x)` |
| `q = {x, q};` | Same as `q.push_front(x)` |
| `q = q[1:$];` | Same as discarding `q.pop_front()` |
| `q = q[0:$-1];` | Same as discarding `q.pop_back()` |
| `q = {q[0:i-1], x, q[i:$]};` | Same as `q.insert(i, x)` |
| `q = {q[0:i-1], q[i+1:$]};` | Same as `q.delete(i)` |

Queues are written with **plain braces** `{ }` (an unpacked array concatenation), not with `'{ }`, because items and whole queues can be mixed freely inside the braces: `q = {q1, 5, q2};`. An assignment pattern `'{1, 2, 3}` is also accepted for a list of plain elements.

A slice whose bounds are in the wrong order or completely outside the queue (`q[3:1]`, or `q[5:9]` on a 3-element queue) yields an empty queue.

### How it works internally

```text
   int q [$];                       q : (empty)                          size 0

   q.push_back(10);                 q : [10]
   q.push_back(20);                 q : [10 | 20]
   q.push_back(30);                 q : [10 | 20 | 30]
                                         0    1    2  <- index      q[$] is 30

   q.push_front(5);                 q : [ 5 | 10 | 20 | 30]          every index shifts by 1
                                         0    1    2    3

   x = q.pop_front();   x = 5       q : [10 | 20 | 30]
   x = q.pop_back();    x = 30      q : [10 | 20]

   q.insert(1, 15);                 q : [10 | 15 | 20]               15 becomes element 1
   q.delete(0);                     q : [15 | 20]
```

The standard does not prescribe an implementation, only the behaviour: adding and removing at either end takes constant time, and access by index is efficient. Simulators typically use a double-ended buffer. Inserting or deleting **in the middle** requires moving the elements after that point, so it costs time proportional to the size.

```text
        front                                         back
        push_front --> +----+----+----+----+----+ <-- push_back
        pop_front  <-- | q0 | q1 | q2 | q3 | q4 | --> pop_back
                       +----+----+----+----+----+
                         0    1    2    3    $

        FIFO  : push_back  + pop_front      (or push_front + pop_back)
        Stack : push_back  + pop_back       (or push_front + pop_front)
```

### Complete example

```systemverilog file=tb_queue.sv
module tb_queue;

  int q [$];
  int x;

  initial begin
    q = {10, 20, 30};
    $display("1.  q = %p  size = %0d", q, q.size());

    q.push_back(40);          $display("2.  push_back(40)   : %p", q);
    q.push_front(5);          $display("3.  push_front(5)   : %p", q);

    x = q.pop_front();        $display("4.  pop_front -> %0d : %p", x, q);
    x = q.pop_back();         $display("5.  pop_back  -> %0d : %p", x, q);

    q.insert(1, 15);          $display("6.  insert(1, 15)   : %p", q);
    q.delete(2);              $display("7.  delete(2)       : %p", q);

    $display("8.  first = %0d  last = %0d  second-to-last = %0d", q[0], q[$], q[$-1]);

    q = {q, 50, 60};          $display("9.  {q, 50, 60}     : %p", q);
    q = q[1:3];               $display("10. q[1:3]          : %p", q);
    q = {q[0:0], 99, q[1:$]}; $display("11. insert by slice : %p", q);
    q[$+1] = 7;               $display("12. q[$+1] = 7      : %p", q);

    q.delete();               $display("13. delete()        : size = %0d", q.size());
    x = q.pop_front();        $display("14. pop from empty  : %0d", x);
  end

endmodule
```

```output
1.  q = '{10, 20, 30}  size = 3
2.  push_back(40)   : '{10, 20, 30, 40}
3.  push_front(5)   : '{5, 10, 20, 30, 40}
4.  pop_front -> 5 : '{10, 20, 30, 40}
5.  pop_back  -> 40 : '{10, 20, 30}
6.  insert(1, 15)   : '{10, 15, 20, 30}
7.  delete(2)       : '{10, 15, 30}
8.  first = 10  last = 30  second-to-last = 15
9.  {q, 50, 60}     : '{10, 15, 30, 50, 60}
10. q[1:3]          : '{15, 30, 50}
11. insert by slice : '{15, 99, 30, 50}
12. q[$+1] = 7      : '{15, 99, 30, 50, 7}
13. delete()        : size = 0
14. pop from empty  : 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | A queue is initialised with braces. Size 3. |
| 2, 3 | `push_back` adds at the end, `push_front` at the beginning. |
| 4, 5 | `pop_front` and `pop_back` remove an element **and return it**. |
| 6 | `insert(1, 15)` places 15 at index 1; 20 and 30 move to indices 2 and 3. |
| 7 | `delete(2)` removes the element at index 2 (the value 20). |
| 8 | `$` is the last index, `$-1` the one before it. |
| 9 | Concatenation of the queue with two more values appends them. |
| 10 | The slice `[1:3]` of `{10, 15, 30, 50, 60}` is `{15, 30, 50}`. Assigning it back shortens the queue. |
| 11 | Building a new queue from two slices and a value: `{15}`, `99`, `{30, 50}`. |
| 12 | Writing to index `$+1` appends one element. |
| 13 | `delete()` without an argument empties the queue. |
| 14 | Popping from an empty queue is not a fatal error: it returns the default value of the element type (0 for `int`) and the simulator issues a warning. A testbench must check `size()` first, because the returned 0 looks like real data. |

### A practical example: the expected-result queue of a scoreboard

This is the most common use of a queue in verification. When the testbench drives a transaction it computes the expected result and pushes it. When the DUT produces an output, the scoreboard pops the oldest expected value and compares. The two small functions used here are explained in Module 3; read them as named blocks of code.

```systemverilog file=tb_queue_scoreboard.sv
module tb_queue_scoreboard;

  logic [8:0] exp_q [$];
  int         pass_cnt, fail_cnt;

  function automatic void add_expected(logic [8:0] value);
    exp_q.push_back(value);
  endfunction

  function automatic void check_actual(logic [8:0] actual);
    logic [8:0] expected;
    if (exp_q.size() == 0) begin
      $display("FAIL: unexpected output %0d (nothing was expected)", actual);
      fail_cnt++;
      return;
    end
    expected = exp_q.pop_front();
    if (actual !== expected) begin
      $display("FAIL: actual=%0d expected=%0d", actual, expected);
      fail_cnt++;
    end
    else begin
      $display("PASS: %0d", actual);
      pass_cnt++;
    end
  endfunction

  initial begin
    add_expected(9'd300);
    add_expected(9'd17);
    add_expected(9'd255);
    $display("pending = %0d", exp_q.size());

    check_actual(9'd300);
    check_actual(9'd18);
    check_actual(9'd255);
    check_actual(9'd1);

    $display("pass=%0d fail=%0d leftover=%0d", pass_cnt, fail_cnt, exp_q.size());
  end

endmodule
```

```output
pending = 3
PASS: 300
FAIL: actual=18 expected=17
PASS: 255
FAIL: unexpected output 1 (nothing was expected)
pass=2 fail=2 leftover=0
```

**Explanation**

| Code | Explanation |
|---|---|
| `logic [8:0] exp_q [$];` | A queue of 9-bit expected ALU results. |
| `exp_q.push_back(value);` | New expectations go to the back. |
| `if (exp_q.size() == 0)` | The DUT produced an output that nothing predicted. Without this check, `pop_front()` would return 0 and the comparison would be meaningless. |
| `expected = exp_q.pop_front();` | The oldest expectation comes off the front, so results are checked in the order they were predicted (FIFO order). |
| `actual !== expected` | Case inequality, so that an X on the DUT output is a mismatch (Module 1, Section 4.5). |
| `leftover=%0d` | At the end of a test the queue must be empty. Remaining entries mean the DUT dropped outputs. This end-of-test check is a standard part of every scoreboard. |

### Bounded queues

```systemverilog
int bq [$:2];             // highest index is 2, so the queue holds at most 3 elements

initial begin
  bq = {1, 2, 3};
  bq.push_back(4);        // the queue is full: 4 is discarded and a warning is issued
  $display("%0d", bq.size());     // 3
end
```

A bounded queue never holds more than its limit. An operation that would exceed the limit loses the elements beyond the bound and produces a warning. Bounded queues are rarely used; a testbench usually checks `size()` itself so that overflow is reported as a proper error.

### Dynamic array versus queue

| Property | Dynamic array | Queue |
|---|---|---|
| Declaration | `int d [];` | `int q [$];` |
| Allocation | Explicit, with `new[n]` | Automatic |
| Growing by one element | Reallocate and copy everything: `d = new[n+1](d)` | `push_back()`, constant time |
| Removing an element | Rebuild the array | `pop_front()`, `pop_back()`, `delete(i)` |
| Add/remove at the front | Not supported directly | `push_front()`, `pop_front()` |
| Access by index | Yes | Yes |
| Last element | `d[d.size()-1]` | `q[$]` |
| Literal | `'{1, 2, 3}` | `{1, 2, 3}` |
| Size can be randomized | Yes (`d.size()` in a constraint) | Yes (`q.size()` in a constraint) |
| Array methods (`find`, `sort`, `sum`...) | Yes | Yes |
| Best for | A block of data whose size is set once | Lists that change continuously; FIFOs; stacks |

> **Interview trap:** "What does `pop_front()` return on an empty queue?" It does not stop the simulation. It returns the default value of the element type and gives a warning. For a queue of class handles the returned value is `null`, and the next statement that uses it causes a null-handle error far away from the real cause.

> **Common mistake:** Confusing `q.delete(i)` with `q.delete()`. With an argument it removes one element. Without an argument it removes everything. A missing argument empties the whole scoreboard queue.

> **Common mistake:** Calling `q.pop_front();` as a statement to discard an element. A function that returns a value cannot be called as a statement without a warning (or an error, depending on the tool). Write `void'(q.pop_front());`.

> **Common mistake:** Using `insert()` and `delete(index)` heavily on a very large queue. They move all later elements. If the data is looked up by a key instead of by position, an associative array is the right structure.

> **Verification application:** Queues appear throughout a class-based testbench: the scoreboard's expected-transaction queue (`alu_txn exp_q [$]`), the reference model of a FIFO DUT (`push_back` on write, `pop_front` on read, `size()` for the `full` and `empty` flags), a list of transactions collected by a monitor for end-of-test reporting, and the results of the array search methods, which are always returned as queues (Part 4).

### Interview questions

**Q1. What is a queue?**
A variable-size ordered collection declared with `[$]`. It grows and shrinks automatically and supports efficient insertion and removal at both ends, plus access by index.

**Q2. What are the queue methods?**
`size()`, `push_back()`, `push_front()`, `pop_back()`, `pop_front()`, `insert()` and `delete()`.

**Q3. What does `$` mean in `q[$]` and in `int q [$]`?**
In the declaration it specifies that the array is a queue. In an index it stands for the index of the last element, `size()-1`.

**Q4. How do you model a FIFO with a queue? A stack?**
FIFO: `push_back()` to write and `pop_front()` to read. Stack: `push_back()` to push and `pop_back()` to pop.

**Q5. What is the difference between a queue and a dynamic array?**
A dynamic array must be allocated with `new[]` and is resized only by reallocating the whole array. A queue manages its own storage and can add or remove single elements at either end in constant time. Both can be indexed and both support the array methods.

**Q6. What is a bounded queue?**
A queue with a maximum index, declared as `int q [$:N];`, which can hold at most N+1 elements. Elements that would go beyond the bound are discarded with a warning.

**Q7. How do you delete the last element of a queue without using `pop_back()`?**
`q.delete(q.size() - 1);` or `q = q[0:$-1];`

**Q8. How do you remove all elements of a queue?**
`q.delete();` or `q = {};`

**Q9. Write three ways to append the value 5 to queue `q`.**
`q.push_back(5);`, `q = {q, 5};` and `q[$+1] = 5;`

**Q10. Why are the results of `find()` returned as a queue?**
Because the number of matching elements is not known in advance. It may be zero, one or many, and a queue can hold any number.
