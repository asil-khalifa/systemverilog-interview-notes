# Part 4: Arguments

Everything in this part applies equally to functions and tasks. Where the two differ, the text says so.

Two words are used throughout:

- The **formal** argument is the name in the subroutine declaration: `x` in `function int f(int x)`.
- The **actual** argument is what the caller supplies: `count` in `f(count)`.

## 4.1 Argument Directions: input, output, inout and ref

### In plain English

Each argument has a direction that says which way the data travels.

| Direction | Meaning in everyday terms |
|---|---|
| `input` | "Here is a value for you to use." A photocopy is handed to the subroutine. |
| `output` | "Fill this in and give it back when you have finished." A blank form. |
| `inout` | "Here is a value; update it and give it back when you have finished." A photocopy, returned and filed over the original at the end. |
| `ref` | "Work directly on my original." No copy at all. |

### Technical definition

| Direction | At the call | During execution | At the return |
|---|---|---|---|
| `input` | Actual value is **copied in** to the formal | Formal is a local variable; changes stay local | Nothing copied back |
| `output` | Nothing copied in; the formal starts at the **default value of its type** | Formal is a local variable | Formal value is **copied out** to the actual |
| `inout` | Actual value is copied in | Formal is a local variable | Formal value is copied out to the actual |
| `ref` | The formal becomes another name (an alias) for the actual variable | Every read and write acts on the caller's variable **immediately** | Nothing to copy |

`input`, `output` and `inout` are all forms of **pass by value** (copying). `ref` is **pass by reference**.

### How it works internally

```text
   task automatic demo(input int in_v, output int out_v, inout int io_v, ref int ref_v);

   Caller variables            Subroutine variables
   ----------------            --------------------
   x  [ 1 ] ----copy at call----------> in_v  [ 1 ]        changes are lost

   y  [ 50]                             out_v [ 0 ]        starts at default, NOT 50
      [ 77] <---copy at return--------- out_v [ 77]

   z  [ 10] ----copy at call----------> io_v  [ 10]
      [ 20] <---copy at return--------- io_v  [ 20]

   w  [ 5 ] <=========================> ref_v              same storage, no copy;
                                                           a write is visible at once
```

### Default direction and type

The rules by which omitted directions and types are filled in produce several interview questions.

| Rule | Example | Result |
|---|---|---|
| The first argument defaults to `input` | `task t(int a);` | `a` is `input int` |
| An argument with no direction inherits the direction of the previous argument | `task t(output int a, b);` | `b` is also `output int` |
| An argument with no type inherits the type of the previous argument, **if its direction is not written** | `task t(input int a, b);` | `b` is `input int` |
| An argument whose direction **is** written but whose type is not becomes `logic` | `task t(input int a, output b);` | `b` is `output logic` (1 bit) |
| First argument with no type at all | `function f(a);` | `a` is `input logic` (1 bit) |

> **Interview trap:** `task automatic t(input int a, b, output int c, d);` Here `b` is an `input int` and `d` is an `output int`, as intended. But in `task automatic t(input int a, output c, d);` both `c` and `d` are 1-bit `logic`, because writing the direction resets the type to the default. Always write direction and type for every argument.

### Complete example

```systemverilog file=tb_arg_directions.sv
module tb_arg_directions;

  task automatic demo(input int in_v, output int out_v, inout int io_v);
    $display("inside : in_v=%0d out_v=%0d io_v=%0d", in_v, out_v, io_v);
    in_v  = in_v + 100;      // modifies the local copy only
    out_v = 77;
    io_v  = io_v * 2;
  endtask

  int x, y, z;

  initial begin
    x = 1;  y = 50;  z = 10;
    $display("before : x=%0d y=%0d z=%0d", x, y, z);
    demo(x, y, z);
    $display("after  : x=%0d y=%0d z=%0d", x, y, z);
  end

endmodule
```

```output
before : x=1 y=50 z=10
inside : in_v=1 out_v=0 io_v=10
after  : x=1 y=77 z=20
```

**Line by line**

| Line | Explanation |
|---|---|
| `inside` line | `in_v` received a copy of `x`. `out_v` is **0**, not 50: an output formal does not receive the caller's value; it starts at the default of `int`. `io_v` received a copy of `z`. |
| `in_v = in_v + 100;` | Legal: an input formal is an ordinary local variable. The caller's `x` is unaffected. |
| `after` line | `x` is still 1. `y` received 77 and `z` received 20 when the task returned. |

### Output arguments are copied back only at the return

In a function this detail is invisible, because a function returns at once. In a task that consumes time it matters a great deal.

```systemverilog file=tb_output_vs_ref.sv
module tb_output_vs_ref;

  int out_val, ref_val;

  task automatic count_out(output int v);
    for (int i = 1; i <= 3; i++) begin
      #10;
      v = i;
    end
  endtask

  task automatic count_ref(ref int v);
    for (int i = 1; i <= 3; i++) begin
      #10;
      v = i;
    end
  endtask

  initial fork
    count_out(out_val);
    count_ref(ref_val);
  join

  initial begin
    #15 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
    #10 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
    #10 $display("[%0t] out_val=%0d ref_val=%0d", $time, out_val, ref_val);
  end

endmodule
```

```output
[15] out_val=0 ref_val=1
[25] out_val=0 ref_val=2
[35] out_val=3 ref_val=3
```

Both tasks write 1, 2, 3 to their argument at times 10, 20 and 30. The caller's `ref_val` changes at each write. The caller's `out_val` stays 0 until `count_out` returns at time 30, and then jumps straight to 3. An observer never sees the values 1 and 2.

### Summary of the four directions

| Property | `input` | `output` | `inout` | `ref` |
|---|---|---|---|---|
| Copied in at call | Yes | No | Yes | No copy |
| Copied out at return | No | Yes | Yes | No copy |
| Initial value of the formal | The actual's value | Default of the type | The actual's value | It **is** the actual |
| Caller sees changes | Never | At return | At return | Immediately |
| Subroutine sees later changes made by the caller's side | No | No | No | Yes |
| Actual may be a constant or expression | Yes | No, must be assignable | No, must be assignable | No, must be a variable |
| Actual may be a net (`wire`) | Yes | Yes | Yes | No |
| Type compatibility | Assignment compatible (converted) | Assignment compatible | Assignment compatible | Must match exactly |
| Allowed in static subroutines | Yes | Yes | Yes | No, automatic only |
| Cost for a large array | Whole array copied | Whole array copied | Copied twice | Nothing copied |

> **Common mistake:** Reading an `output` argument inside the subroutine and expecting the caller's value. It holds the type's default. Use `inout` or `ref` when the old value is needed.

> **Common mistake:** Passing a `logic [7:0]` module signal to an `output` argument of a task that runs for many cycles and expecting the signal to follow the task's assignments cycle by cycle. It changes once, when the task returns.

> **Verification application:** `output` suits a result that is complete only when the task ends: `task read_reg(input bit [7:0] addr, output logic [31:0] data);`. `ref` suits a signal or status variable that must be observed or updated while the task is still running.

### Interview questions

**Q1. What are the argument directions in SystemVerilog?**
`input`, `output`, `inout` and `ref`. The first three pass by value with copy-in and/or copy-out; `ref` passes by reference.

**Q2. What is the default direction and type of an argument?**
`input` and `logic`. An argument written without a direction or type inherits them from the previous argument.

**Q3. What is the value of an `output` argument at the start of a task?**
The default value of its type (0 for two-state, X for four-state), not the value of the caller's variable.

**Q4. When does the caller's variable change for an `output` argument?**
When the subroutine returns. Intermediate values assigned during a time-consuming task are not visible to the caller.

**Q5. What is the difference between `inout` and `ref`?**
`inout` copies the value in at the call and out at the return; in between the subroutine works on a private copy. `ref` creates no copy: the subroutine works on the caller's variable directly, so changes are visible in both directions immediately.

## 4.2 Pass by Value

### In plain English

Passing by value means the subroutine receives its own copy of the data. Whatever it does to the copy, the caller's original is untouched (for `input`), or is replaced only at the end (for `output` and `inout`). This is the default behaviour in SystemVerilog and it is the safe one: a subroutine cannot accidentally damage the caller's data.

### What "copy" means for each kind of data

| Actual argument | What is copied | Consequence |
|---|---|---|
| Scalar or vector (`int`, `logic [31:0]`) | The value | Cheap |
| Struct | Every member | Cheap for small structs |
| Fixed-size array | **Every element** | Expensive for large arrays, repeated on every call |
| Dynamic array, queue, associative array | **Every element** | Same, and the size is unbounded |
| `string` | The characters | Usually small |
| Class handle | **The handle only**, not the object | Cheap. Caller and subroutine refer to the same object (see below) |

### Complete example

```systemverilog file=tb_pass_by_value.sv
module tb_pass_by_value;

  int data [4] = '{1, 2, 3, 4};
  int n;

  function automatic void try_change(int v);
    v = 99;                                   // changes the copy
  endfunction

  function automatic void clear_copy(int arr [4]);
    foreach (arr[i]) arr[i] = 0;              // clears the copy
  endfunction

  function automatic void clear_ref(ref int arr [4]);
    foreach (arr[i]) arr[i] = 0;              // clears the caller's array
  endfunction

  function automatic int total(const ref int arr [4]);
    int sum;
    sum = 0;
    foreach (arr[i]) sum += arr[i];
    return sum;
  endfunction

  function automatic void show(string label);
    $display("%s: %0d %0d %0d %0d  total=%0d", label,
             data[0], data[1], data[2], data[3], total(data));
  endfunction

  initial begin
    n = 5;
    try_change(n);
    $display("n after try_change = %0d", n);

    show("initial         ");
    clear_copy(data);
    show("after clear_copy");
    clear_ref(data);
    show("after clear_ref ");
  end

endmodule
```

```output
n after try_change = 5
initial         : 1 2 3 4  total=10
after clear_copy: 1 2 3 4  total=10
after clear_ref : 0 0 0 0  total=0
```

**Line by line**

| Line | Explanation |
|---|---|
| `try_change(n);` | `v` is a copy of `n`. Assigning 99 to it changes nothing outside. |
| `clear_copy(int arr [4])` | The whole array is copied at the call. The function clears its copy; `data` is unchanged, and the copy is discarded. The function is useless as written, and it paid for copying four elements. |
| `clear_ref(ref int arr [4])` | No copy. `arr` is `data` under another name, so the caller's array is cleared. |
| `total(const ref int arr [4])` | Reads the caller's array without copying it and without being allowed to modify it. Section 4.3 explains `const ref`. |

### Class handles: passed by value, but the object is shared

This is a preview of Module 4, and one of the most frequently asked questions about arguments.

A variable of a class type does not contain an object; it contains a **handle**, which refers to an object. Passing it by value copies the handle. The copy refers to the same object.

```text
   caller:      txn  ----------------+
                                     v
                                 +--------+
                                 | object |
                                 +--------+
                                     ^
   subroutine:  t (copy of handle) --+

   t.a = 5;       modifies the shared object       -> the caller sees it
   t = new();     points the COPY at a new object  -> the caller's txn is unchanged
```

```systemverilog
function automatic void set_a(alu_txn t);        // input handle
  t.a = 8'd5;            // changes the caller's object: both handles point to it
endfunction

function automatic void make_bad(alu_txn t);     // input handle
  t = new();             // only the local copy of the handle changes; caller's stays null
endfunction

function automatic void make_good(ref alu_txn t);
  t = new();             // the caller's handle now points to the new object
endfunction
```

So: to modify the **object**, an `input` handle is enough. To make the caller's **handle** point somewhere else, use `ref` or `output`, or return the handle.

> **Interview trap:** "Are class objects passed by value or by reference?" The precise answer: the *handle* is passed by value, and since a handle is a reference to the object, the object is effectively shared. Changes to the object's properties are seen by the caller. A new assignment to the handle inside the subroutine is not.

> **Common mistake:** Passing a large queue or array as an `input` to a function that is called once per transaction, for example `function bit is_in(int list[$], int x)`. The whole queue is copied on every call. Use `const ref`.

### Interview questions

**Q1. What is pass by value?**
The value of the actual argument is copied into the formal argument, which is a local variable of the subroutine. Changes to the formal do not affect the actual, except through the copy-out of `output` and `inout` arguments when the subroutine returns.

**Q2. What is the default argument-passing mechanism in SystemVerilog?**
Pass by value, with direction `input`.

**Q3. What happens when an array is passed as an `input`?**
The entire array is copied on each call. This costs time and memory, and any changes made inside are lost.

**Q4. If a class handle is passed as an `input` and the function changes a property of the object, does the caller see the change?**
Yes. The handle is copied, but both handles refer to the same object.

**Q5. If the function does `t = new();` on an input handle, does the caller's handle change?**
No. Only the local copy of the handle is redirected. Use `ref`, `output`, or a return value.

## 4.3 Pass by Reference Using ref

### In plain English

With `ref`, the subroutine is not given a copy. It is given access to the caller's own variable. Inside the subroutine the formal name and the caller's variable are the same piece of storage. Writing to one is writing to the other, immediately, in both directions.

### Technical definition

An argument declared `ref` is passed by reference: the formal argument becomes an alias of the actual argument for the duration of the call. No value is copied at the call or at the return.

`const ref` passes by reference but makes the formal read-only inside the subroutine. Any attempt to assign to it is a compile error.

### Why it is needed

| Need | How `ref` solves it |
|---|---|
| Efficiency: avoid copying a large array, queue or struct on every call | Nothing is copied |
| The subroutine must modify the caller's array or struct in place | Writes go to the original |
| A time-consuming task must see changes that happen **while it is running** | The task reads the live variable, not a snapshot taken at the call |
| A time-consuming task must make its updates visible **before it returns** | Writes are visible at once (Section 4.1, `tb_output_vs_ref`) |
| Several values must be returned or updated | Any number of `ref` arguments |

### Syntax

```systemverilog
function automatic void scale(ref int arr[], input int factor);

function automatic int  find_max(const ref int arr[]);      // read-only, no copy

task automatic wait_for(ref logic sig, input int max_cycles, output bit timed_out);
```

### The rules of ref

| Rule | Detail |
|---|---|
| Automatic subroutines only | A `ref` argument is illegal in a subroutine with static lifetime. In a module, write `task automatic` / `function automatic`. Class methods are automatic already |
| The actual must be a variable | A variable, a class property, a member of an unpacked struct, or an element of an unpacked array. Not a constant, not an expression, **not a net** |
| The type must match exactly | No implicit conversion: an `int` formal needs an `int` actual; a `logic [7:0]` actual cannot be bound to a `ref int` |
| `const ref` is read-only | Assignment to the formal is a compile error |
| Not inside `fork`...`join_any` / `join_none` | A `ref` formal may not be used inside a `fork`...`join_any` or `fork`...`join_none` block in the subroutine, because the subroutine might return (and the reference end) while the spawned process is still running |
| Direction is sticky | `ref` applies to following arguments until another direction is written: in `(ref int a, int b)`, `b` is also `ref` |

### How it works internally

```text
   Pass by value (input)                       Pass by reference (ref)

   caller           subroutine                 caller           subroutine
   +-------+        +-------+                  +-------+
   | 0  1  |  copy  | 0  1  |                  | 0  1  | <----- sig   (alias, no storage)
   | ready | -----> |  sig  |                  | ready |
   +-------+        +-------+                  +-------+
   later: ready = 1                            later: ready = 1
          sig is still 0  (stale copy)                sig reads 1  (same variable)
```

### Complete example: a task that must see a live signal

```systemverilog file=tb_ref_wait.sv
module tb_ref_wait;

  logic clk   = 0;
  logic ready = 0;
  bit   timed_out;

  always #5 clk = ~clk;

  initial #42 ready = 1;

  // WRONG: sig is a copy of the signal taken when the task was called
  task automatic wait_by_value(input logic sig, input int max_cycles, output bit timeout);
    timeout = 1;
    for (int i = 1; i <= max_cycles; i++) begin
      @(posedge clk);
      if (sig) begin
        $display("[%0t] by value: signal seen after %0d cycles", $time, i);
        timeout = 0;
        return;
      end
    end
    $display("[%0t] by value: timed out after %0d cycles", $time, max_cycles);
  endtask

  // RIGHT: sig is the caller's signal itself
  task automatic wait_by_ref(ref logic sig, input int max_cycles, output bit timeout);
    timeout = 1;
    for (int i = 1; i <= max_cycles; i++) begin
      @(posedge clk);
      if (sig) begin
        $display("[%0t] by ref  : signal seen after %0d cycles", $time, i);
        timeout = 0;
        return;
      end
    end
    $display("[%0t] by ref  : timed out after %0d cycles", $time, max_cycles);
  endtask

  initial begin
    wait_by_value(ready, 6, timed_out);
    $display("        timed_out = %b", timed_out);
    wait_by_ref(ready, 6, timed_out);
    $display("        timed_out = %b", timed_out);
    $finish;
  end

endmodule
```

```output
[55] by value: timed out after 6 cycles
        timed_out = 1
[65] by ref  : signal seen after 1 cycles
        timed_out = 0
```

**Execution flow**

| Time | What happens |
|---|---|
| 0 | `wait_by_value` is called. `ready` is 0, and that 0 is copied into `sig`. |
| 5, 15, 25, 35 | Four clock edges; `sig` is 0, and so is the real signal. |
| 42 | `ready` becomes 1 in the module. The task's `sig` is a private copy and stays 0. |
| 45, 55 | The fifth and sixth edges. The task still reads 0, although the real signal has been 1 since 42. After the sixth test the loop ends and the time-out is reported at 55. |
| 55 | `wait_by_ref` is called. Its `sig` is the module's `ready` itself. |
| 65 | The first `@(posedge clk)` waits for the next edge. `sig` reads 1: the signal is seen after one cycle. |

When predicting times for code like this, list the clock edges explicitly (5, 15, 25...). Being one period off is the most common error in "at what time does this print?" questions.

**Line by line**

| Line | Explanation |
|---|---|
| `input logic sig` | The value of `ready` at the moment of the call is copied. The task can never observe a later change. A task that polls an `input` argument is always a bug. |
| `ref logic sig` | The task reads the module's `ready` each time `sig` is evaluated. |
| `output bit timeout` | The status is needed only when the task ends, so `output` is appropriate. It is assigned before every exit path. |
| `return;` | Leaves the task early; the output is still copied back. |

### const ref

```systemverilog
function automatic int find_max(const ref int arr[]);
  int m;
  m = arr[0];
  foreach (arr[i]) if (arr[i] > m) m = arr[i];
  // arr[0] = 0;        // compile error: arr is read-only
  return m;
endfunction
```

`const ref` gives the efficiency of a reference with the safety of an input. It is the right choice for any large array, queue or struct that a subroutine only reads.

### ref compared with the other mechanisms

| Property | `input` | `inout` | `ref` | `const ref` |
|---|---|---|---|---|
| Copy made | In | In and out | None | None |
| Subroutine can modify the caller's data | No | Yes, at return | Yes, immediately | No |
| Subroutine sees external changes during a time-consuming task | No | No | Yes | Yes |
| Works in static subroutines | Yes | Yes | No | No |
| Actual can be an expression or constant | Yes | No | No | No |
| Actual can be a net | Yes | Yes | No | No |
| Typical use | Small values | Small values to be updated | Large or live data to be modified | Large data to be read |

> **Interview trap:** "What is the difference between `inout` and `ref`? They both let the subroutine change the caller's variable." `inout` works on a private copy and writes it back at the return. `ref` works on the original throughout. The difference is visible when the subroutine takes time, or when the same variable is passed twice: with `task swap_add(inout int a, inout int b)` called as `swap_add(x, x)`, two separate copies exist and the last one copied out wins; with `ref` both names are the same variable.

> **Common mistake:** `task wait_until_set(input bit flag); wait (flag); endtask`. If `flag` is 0 at the call, the task waits for ever, because its copy never changes. Declare the argument `ref` (and the task `automatic`).

> **Common mistake:** Declaring a `ref` argument in a module-level task without `automatic`. The compiler rejects it, because static subroutines cannot have reference arguments.

> **Common mistake:** Passing a `wire` or an expression such as `a + 1`, a constant, or a part-select of a vector to a `ref` argument. The actual must be a whole variable (or a struct member or unpacked array element) of exactly the formal's type.

> **Verification application:** Scoreboards and checkers pass queues of expected transactions to helper functions as `ref` (to pop from them) or `const ref` (to search them). Utility tasks that wait on a flag or counter owned by another component take it by `ref`. In class-based testbenches the need is reduced, because objects are already shared through handles and signals are reached through the virtual interface `vif`.

### Interview questions

**Q1. What is pass by reference?**
The formal argument becomes an alias for the caller's variable. No copy is made; every read and write in the subroutine acts directly on the caller's storage.

**Q2. Why use `ref`?**
To avoid copying large arrays or structs, to modify the caller's data in place, and to let a time-consuming task see and make changes while it is running.

**Q3. What is `const ref`?**
Pass by reference with a read-only formal. It avoids the copy but guarantees that the subroutine cannot change the caller's data.

**Q4. What are the restrictions on `ref` arguments?**
The subroutine must be automatic; the actual must be a variable (not a net, constant or expression) whose type matches the formal exactly; and the formal cannot be used inside a `fork`...`join_any` or `fork`...`join_none` block.

**Q5. Why is `ref` not allowed in static tasks?**
A static task has one permanent set of argument storage shared by all calls, and a reference to a caller's variable (which may itself be automatic and short-lived) cannot be stored safely there. The standard therefore restricts `ref` to automatic subroutines, where the reference exists only for the life of the call.

**Q6. A task has `input logic sig` and loops `@(posedge clk); if (sig) ...`. What is wrong?**
`sig` is a copy made at the call and never changes. The task must take the signal by `ref`, or read it through an interface handle.

## 4.4 Default Argument Values and Binding by Name

### In plain English

Many subroutines have arguments that are nearly always given the same value: a verbosity level, a number of cycles, a tag for messages. A **default value** lets the caller leave such an argument out. **Binding by name** lets the caller say which argument each value is for, so the order does not matter and the call documents itself.

### Syntax

```systemverilog
function automatic void report(string msg, int verbosity = 1, string tag = "TB");

report("one");                        // both defaults used
report("two", 3);                     // tag defaults
report("three", 2, "DRV");            // no defaults
report("four", , "MON");              // verbosity skipped with an empty position
report(.tag("SCB"), .msg("five"));    // by name, any order
report("six", .tag("GEN"));           // positional first, then by name
```

### Rules

| Rule | Detail |
|---|---|
| Any argument can have a default | Written as `= expression` after the name in the declaration |
| Omitted trailing arguments take their defaults | `report("x")` |
| A middle argument is skipped with an empty position | `report("x", , "MON")` |
| An argument without a default must be supplied | Otherwise a compile error |
| Named binding uses `.formal(actual)` | Same syntax as module port connections |
| Positional and named may be mixed | All positional arguments must come first |
| The default expression is evaluated at each call | In the scope where the subroutine is declared, not where it is called |
| Defaults are normally for `input` arguments | `inout` and `ref` defaults are permitted by the standard but unusual; `output` arguments are simply left unconnected when not needed |

### Complete example

```systemverilog file=tb_default_args.sv
module tb_default_args;

  logic clk = 0;
  always #5 clk = ~clk;

  function automatic void report(string msg, int verbosity = 1, string tag = "TB");
    $display("[%0t] [%s] (v%0d) %s", $time, tag, verbosity, msg);
  endfunction

  task automatic wait_cycles(int n = 1);
    repeat (n) @(posedge clk);
  endtask

  initial begin
    report("one");
    report("two", 3);
    report("three", 2, "DRV");
    report("four", , "MON");
    report(.tag("SCB"), .msg("five"));
    report("six", .tag("GEN"));

    wait_cycles();          // default: 1 cycle
    report("after wait_cycles()");
    wait_cycles(3);
    report("after wait_cycles(3)");
    $finish;
  end

endmodule
```

```output
[0] [TB] (v1) one
[0] [TB] (v3) two
[0] [DRV] (v2) three
[0] [MON] (v1) four
[0] [SCB] (v1) five
[0] [GEN] (v1) six
[5] [TB] (v1) after wait_cycles()
[35] [TB] (v1) after wait_cycles(3)
```

**Line by line**

| Line | Explanation |
|---|---|
| `int verbosity = 1, string tag = "TB"` | Two arguments with defaults. `msg` has none and is mandatory. |
| `report("four", , "MON");` | The empty second position selects the default for `verbosity`. |
| `report(.tag("SCB"), .msg("five"));` | Named binding: order is free, and `verbosity` is simply not mentioned. |
| `wait_cycles();` | Uses `n` = 1: returns at the edge at time 5. |
| `wait_cycles(3);` | Edges at 15, 25 and 35. |

### Why this matters in real testbenches

- **Backward compatibility.** A new argument with a default can be added to a widely used task without editing any existing call.
- **Constructors.** `function new(string name = "alu_txn");` is the standard UVM constructor form. A constructor whose arguments all have defaults can be called as `new()`.
- **Readable calls.** `write_reg(.addr(8'h10), .data(32'h1), .check(0));` cannot be misread, whereas `write_reg(8'h10, 32'h1, 0);` relies on remembering the order.

> **Common mistake:** Changing the order or meaning of positional arguments in a shared task. Every positional call silently passes its values to the wrong arguments if the types happen to be compatible. Named binding protects against this.

> **Interview trap:** "A function is declared `f(int a, int b = 5, int c)`. Is `f(1, , 3)` legal? Is `f(1)`?" The first is legal: `b` takes its default. The second is an error: `c` has no default and was not supplied.

### Interview questions

**Q1. What are default argument values?**
Values written in the declaration (`int n = 1`) that are used when the caller omits that argument.

**Q2. How do you skip an argument in the middle of the list?**
Leave its position empty, `f(1, , 3)`, or use named binding, `f(.a(1), .c(3))`.

**Q3. What is argument binding by name?**
Supplying arguments as `.formal_name(value)`. The order then does not matter and omitted arguments take their defaults.

**Q4. Can positional and named arguments be mixed in one call?**
Yes, but all positional arguments must come before the named ones.

## 4.5 Passing Arrays, Strings and Structs

### Declaring array arguments

The formal argument is declared like a variable of the array type.

```systemverilog
function automatic int sum_fixed (int arr [4]);            // fixed-size, exactly 4 elements
function automatic int sum_dyn   (int arr []);             // dynamic array formal
function automatic int sum_queue (int q [$]);              // queue formal
function automatic int count_keys(int aa [string]);        // associative array formal
function automatic void fill     (ref bit [7:0] mem [256], input bit [7:0] value);
```

| Formal | Accepted actuals (pass by value) |
|---|---|
| Fixed-size `int arr [4]` | An array of the same element type and the same size |
| Dynamic `int arr []` | A dynamic array, a queue, or a fixed-size one-dimensional array with the same element type; the formal takes the size of the actual |
| Queue `int q [$]` | A queue, dynamic array or fixed-size one-dimensional array with the same element type |
| Associative `int aa [string]` | An associative array with the same element and index types |

For `ref` arguments the types must match exactly, so a fixed-size array cannot be passed to a `ref int arr[]` formal.

### Complete example

```systemverilog file=tb_array_args.sv
module tb_array_args;

  typedef struct {
    int       id;
    bit [7:0] payload [4];
  } pkt_t;

  // const ref: no copy, read-only
  function automatic int sum(const ref int arr[]);
    int s;
    s = 0;
    foreach (arr[i]) s += arr[i];
    return s;
  endfunction

  // ref: modifies the caller's array in place
  function automatic void scale(ref int arr[], input int factor);
    foreach (arr[i]) arr[i] *= factor;
  endfunction

  // input queue: a private copy that the function may consume freely
  function automatic int last_two_sum(int q[$]);
    int s;
    s  = q.pop_back();
    s += q.pop_back();
    return s;
  endfunction

  // struct by ref, string by value
  function automatic void stamp(ref pkt_t p, input string who);
    p.id++;
    foreach (p.payload[i]) p.payload[i] = p.payload[i] + 8'h10;
    $display("%s stamped packet %0d", who, p.id);
  endfunction

  int   values[];
  int   numbers[$] = {10, 20, 30, 40};
  pkt_t pkt;

  initial begin
    values = new[4];
    values = '{1, 2, 3, 4};

    $display("1. sum            = %0d", sum(values));
    scale(values, 10);
    $display("2. after scale    = %0d %0d %0d %0d",
             values[0], values[1], values[2], values[3]);
    $display("3. sum            = %0d", sum(values));

    $display("4. last_two_sum   = %0d", last_two_sum(numbers));
    $display("5. queue size is still %0d", numbers.size());

    pkt.id      = 6;
    pkt.payload = '{8'h01, 8'h02, 8'h03, 8'h04};
    stamp(pkt, "driver");
    $display("6. payload[0] = %h, payload[3] = %h", pkt.payload[0], pkt.payload[3]);
  end

endmodule
```

```output
1. sum            = 10
2. after scale    = 10 20 30 40
3. sum            = 100
4. last_two_sum   = 70
5. queue size is still 4
driver stamped packet 7
6. payload[0] = 11, payload[3] = 14
```

**Line by line**

| Line | Explanation |
|---|---|
| `sum(const ref int arr[])` | The dynamic array is not copied and cannot be changed. |
| `scale(ref int arr[], input int factor)` | `input` is written explicitly before `factor`. Without it, `factor` would inherit `ref` from the previous argument and the literal `10` could not be passed. |
| `last_two_sum(int q[$])` | Passed by value. The function pops two elements from **its copy** (40 and 30). The caller's queue still has four elements. |
| `stamp(ref pkt_t p, input string who)` | The struct is modified in place; a struct passed as `input` would be copied and the changes lost. |

> **Common mistake:** Forgetting that `ref` is inherited by the arguments that follow. `function void scale(ref int arr[], int factor)` makes `factor` a `ref int`, so `scale(values, 10)` fails to compile because a constant cannot be passed by reference.

> **Common mistake:** Writing an array formal as `int arr` or `int[] arr`. The dimension follows the name: `int arr[]`. To return an array, use a `typedef` (Module 1, Section 3.6).

### Interview questions

**Q1. How do you pass an array to a function without copying it?**
Declare the argument `ref` (or `const ref` if the function only reads it). The function must be automatic.

**Q2. A function receives a queue as `input` and deletes elements from it. Does the caller's queue change?**
No. The function has its own copy.

**Q3. In `function void f(ref int a[], int n);`, what is the direction of `n`?**
`ref`, inherited from the previous argument. Write `input int n` to make it an input.

**Q4. What is the most efficient way to pass a 1 MB memory array to a read-only checking function?**
`const ref`.
