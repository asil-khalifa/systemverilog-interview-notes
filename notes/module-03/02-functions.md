# Part 2: Functions

## 2.1 Why Subroutines Exist

### In plain English

Suppose a testbench needs to compute the expected ALU result in the scoreboard, again in a coverage model, and again in a debug message. Writing the same `case` statement three times means three places to update when an operation is added, and three chances to make a mistake. A **subroutine** is a named piece of code written once and executed ("called") from as many places as needed, each time with different input values.

SystemVerilog has two kinds of subroutine:

| | Function | Task |
|---|---|---|
| One-line description | Computes something and returns immediately | Performs an activity that may take simulation time |
| Analogy | A calculator: you get the answer at once | A job: "send this packet", which takes several clock cycles |

### Why they are needed

| Benefit | Example |
|---|---|
| Reuse | One `alu_model()` function used by the scoreboard and by coverage |
| Readability | `reset_dut(); drive_op(...); check(...);` reads like the test plan |
| One place to change | A protocol change is made in one `drive` task |
| Abstraction | A test calls `write_reg(addr, data)` and does not care about the pin-level sequence |
| Building block of OOP | Class methods are functions and tasks (Module 4) |

Parts 2 and 3 describe functions and tasks separately. Part 4 describes arguments, which work the same way for both.

## 2.2 Functions in SystemVerilog

### In plain English

A function takes some inputs, computes a result, and gives that result back to the place where it was called. It does this **instantly**: no simulation time passes between the call and the return. Because of that, a function call can be used inside an expression just like a variable: `y = max(a, b) + 1;`.

### Technical definition

A function is a subroutine that

- executes in **zero simulation time** (it may not contain `#`, `@`, `wait` or any other blocking statement),
- **returns a single value** of a declared type, or is declared `void` and returns nothing,
- can be called as an operand in an expression,
- may have any number of arguments, including none, with directions `input`, `output`, `inout` and `ref`.

### Syntax

```systemverilog
function [lifetime] [return_type] function_name ([arguments]);
  [local declarations]
  statements
  return expression;
endfunction [: function_name]
```

| Element | Meaning | If omitted |
|---|---|---|
| `lifetime` | `automatic` or `static` | `static` in a module, interface, program or package; always automatic in a class (Section 5.1) |
| `return_type` | Any data type, or `void` | **1-bit `logic`** |
| arguments | `direction type name`, comma separated | Direction defaults to `input`; type defaults to `logic` |

Three equivalent ways of writing the same function:

```systemverilog
// 1. SystemVerilog (ANSI) style: preferred
function automatic int add(input int x, input int y);
  return x + y;
endfunction

// 2. Same, relying on defaults: direction defaults to input, y inherits "int" from x
function automatic int add(int x, y);
  return x + y;
endfunction

// 3. Verilog-1995 style: arguments declared in the body, result assigned to the function name
function integer add;
  input integer x;
  input integer y;
  begin
    add = x + y;
  end
endfunction
```

`begin`...`end` inside a function or task is optional in SystemVerilog; several statements may be written directly between `function` and `endfunction`.

### How it works internally

```text
   y = add(3, 4) + 1;

   1. The caller evaluates the actual arguments:        3, 4
   2. Storage for the function's variables is obtained:  x, y, and an implicit variable
        - automatic function: a fresh set for this call
        - static function   : the single permanent set shared by all calls
   3. Input arguments are copied in:                     x = 3, y = 4
   4. The body executes. No timing control is possible, so nothing else in the
      simulation runs in between.
   5. "return x + y" stores 7 as the function's result and ends the function.
   6. Output/inout arguments (if any) are copied back to the caller.
   7. The call "add(3, 4)" in the expression is replaced by 7:   y = 7 + 1 = 8
```

Inside every non-void function there is an implicit variable with the **same name as the function** and the return type. Assigning to it sets the return value. That is how Verilog functions returned values, and it still works.

### Complete example

```systemverilog file=tb_function_basic.sv
module tb_function_basic;

  // 1. Return with the return statement
  function automatic int add(int x, int y);
    return x + y;
  endfunction

  // 2. Return by assigning to the function name (Verilog style)
  function automatic int max3(int x, int y, int z);
    max3 = x;
    if (y > max3) max3 = y;
    if (z > max3) max3 = z;
  endfunction

  // 3. Return type omitted: the function returns ONE BIT of type logic
  function automatic add_one_bit(int x, int y);
    return x + y;
  endfunction

  // 4. A function with no arguments
  function automatic string banner();
    return "=== ALU test ===";
  endfunction

  // 5. A function that never sets its return value
  function automatic int forgot_return(int x);
    int unused;
    unused = x * 2;
  endfunction

  int r;

  initial begin
    r = add(3, 4);                 $display("1. add(3, 4)            = %0d", r);
    r = add(add(1, 2), 10) * 2;    $display("2. add(add(1, 2), 10)*2 = %0d", r);
    r = max3(7, 42, 19);           $display("3. max3(7, 42, 19)      = %0d", r);
    r = add_one_bit(3, 4);         $display("4. add_one_bit(3, 4)    = %0d", r);
    $display("5. %s", banner());
    r = forgot_return(5);          $display("6. forgot_return(5)     = %0d", r);
  end

endmodule
```

```output
1. add(3, 4)            = 7
2. add(add(1, 2), 10)*2 = 26
3. max3(7, 42, 19)      = 42
4. add_one_bit(3, 4)    = 1
5. === ALU test ===
6. forgot_return(5)     = 0
```

**Line by line**

| Line | Explanation |
|---|---|
| `function automatic int add(int x, int y);` | Returns an `int`. Two `int` inputs. `automatic` gives each call its own storage; use it by default (Section 5.1). |
| `return x + y;` | Sets the result and leaves the function immediately. |
| `max3 = x;` | Assigns to the implicit variable named after the function. The function continues executing; the value held by `max3` when `endfunction` is reached is returned. |
| `function automatic add_one_bit(...)` | No return type, so it is `logic` (1 bit). The sum 7 is `...0111`; only the least significant bit, 1, is returned. |
| Output line 2 | A function call is an expression, so calls can be nested and combined with operators: (3 + 10) × 2 = 26. |
| `banner()` | A function without arguments. It can be called with or without the empty parentheses; writing them makes it clear that it is a call. |
| `forgot_return` | Neither `return` nor an assignment to the name was executed, so the implicit variable keeps its default: 0 for `int`. For a `logic` return type it would be X. |

### Where functions are used

| Place | Example | Notes |
|---|---|---|
| Right-hand side of any assignment | `exp = alu_model(a, b, op);` | |
| Continuous assignment | `assign parity = calc_parity(data);` | Synthesizable when the function is |
| `always_comb` | `always_comb y = encode(x);` | `always_comb` is sensitive to signals the function reads |
| Conditions | `if (is_valid(pkt)) ...` | |
| Constraints | `constraint c { len == calc_len(kind); }` | Function is evaluated before solving (Module 5) |
| Class methods | `txn.print();` `t2 = t1.copy();` | Module 4 |
| Parameters and constants | `localparam int W = clog2_fn(DEPTH);` | Only "constant functions": automatic or static, no side effects, all inputs constant |

### Synthesis

A function is synthesizable when it contains only synthesizable statements, which is naturally the case for most: no delays are possible anyway. It becomes a block of combinational logic, duplicated at every place it is called. Functions should be declared `automatic` in RTL so that simulation matches the synthesised logic.

> **Interview trap:** "What does a function return if you leave out the return type?" One bit of `logic`. A function `function sum(int a, int b)` silently truncates its result to the LSB.

> **Common mistake:** Using both styles in one function. After `return expr;` the function ends, so later assignments to the function name are never reached. And a value assigned to the function name is discarded if a `return other_value;` follows. Choose one style: `return`.

> **Common mistake:** Assuming `return` is needed at the end of a function that assigns to its own name. It is not; reaching `endfunction` returns the current value of the implicit variable.

> **Verification application:** The scoreboard's reference model is a function: `function logic [8:0] alu_model(bit [7:0] a, b, alu_op_e op);`. It has no timing, depends only on its inputs, and is called once per observed transaction. Keeping the model in one function means that the scoreboard, a coverage sampler and a debug printout all agree on the expected value.

### Interview questions

**Q1. What is a function?**
A subroutine that executes in zero simulation time, cannot contain timing controls, and returns a single value (or is `void`). It can be used inside expressions.

**Q2. What is the default return type of a function?**
A 1-bit `logic`.

**Q3. How can a function return its value?**
With `return expression;`, or by assigning to the implicit variable that has the function's name. If neither happens, the default value of the return type is returned.

**Q4. Can a function have `output` arguments?**
Yes. SystemVerilog functions can have `input`, `output`, `inout` and `ref` arguments. (Verilog functions allowed only inputs.) Such a function cannot be called where side effects are not allowed: in a continuous assignment or any other expression outside procedural code, or in an event expression.

**Q5. Is a function synthesizable?**
Yes, provided its body is synthesizable. It is implemented as combinational logic.

**Q6. Can a function be called without using its return value?**
The standard expects the result to be used. To discard it deliberately, cast the call to void: `void'(my_func(x));`. Without the cast, simulators issue a warning.

## 2.3 Returning Values and Void Functions

### Returning different kinds of value

A function returns exactly one value, but that value can be of any data type, including aggregates:

| Return type | Declaration | Notes |
|---|---|---|
| Scalar or vector | `function logic [8:0] alu_model(...);` | |
| Enum, packed struct | `function alu_op_e next_op(alu_op_e op);` | Any user-defined type name |
| Unpacked struct | `function item_t make_item(...);` | Through a `typedef` name |
| Unpacked array, dynamic array, queue | `function buf_t make_ramp(...);` | The array type must be a `typedef` (Module 1, Section 3.6) |
| `string` | `function string to_str();` | Very common: `convert2string` in UVM |
| `real` | `function real average(int q[$]);` | Simulation-only |
| Class handle | `function alu_txn copy();` | Returns a handle to an object (Module 4) |
| Nothing | `function void print();` | Void function |

To return **more than one** value there are three options: return a struct, add `output` arguments, or add `ref` arguments. A common pattern is to return a status bit and deliver the data through an `output` argument.

### Void functions

**In plain English.** Sometimes a subroutine does not compute anything to give back; it just does something, such as printing a message or updating a counter, and it does so instantly. That is a **void function**.

**Technical definition.** A function declared with return type `void` returns no value. It is called as a statement, not inside an expression. It keeps every restriction of a function: zero time, no blocking statements.

**Why not use a task for that?** A task is allowed to consume time, so the compiler must assume that it might. That has two consequences. First, a function cannot call a task, so a helper written as a task cannot be used from any function, from `always_comb`, or from a constraint. Second, a reader cannot tell from the call whether a task blocks. Declaring the helper as `void function` guarantees, and documents, that it returns immediately, and lets it be called from anywhere.

> **Key point:** Rule used across the industry and in UVM: **if a subroutine does not need to consume time, make it a function** (`void` if it has nothing to return). Use a task only when the subroutine must wait for something.

### Discarding a return value with void'()

```systemverilog
void'(txn.randomize());          // legal, but a bad habit: the result reports failure
void'(mbx.try_get(txn));         // "I do not care whether an item was available"
```

A non-void function call written as a bare statement draws a warning; the `void'()` cast states that discarding the result is intentional. Be careful with what you discard. Throwing away the result of `randomize()` hides randomization failures (Module 5).

### Complete example

```systemverilog file=tb_function_return.sv
module tb_function_return;

  typedef struct {
    int quotient;
    int remainder;
  } divmod_t;

  int unsigned error_count;

  // Void function: acts, returns nothing
  function automatic void report(string msg, bit is_error = 0);
    if (is_error) begin
      error_count++;
      $display("ERROR: %s", msg);
    end
    else $display("INFO : %s", msg);
  endfunction

  // Two results, method 1: return a struct
  function automatic divmod_t divmod(int x, int y);
    divmod_t r;
    r.quotient  = x / y;
    r.remainder = x % y;
    return r;
  endfunction

  // Two results, method 2: status as the return value, data through an output argument
  function automatic bit safe_div(input int x, input int y, output int q);
    if (y == 0) return 0;      // q keeps its default value
    q = x / y;
    return 1;
  endfunction

  // A void function may use "return;" to leave early
  function automatic void print_if_odd(int x);
    if (x % 2 == 0) return;
    $display("%0d is odd", x);
  endfunction

  divmod_t dm;
  int      q;

  initial begin
    report("starting");
    dm = divmod(17, 5);
    $display("17 / 5 = %0d remainder %0d", dm.quotient, dm.remainder);

    if (safe_div(20, 4, q))  $display("20 / 4 = %0d", q);
    if (!safe_div(20, 0, q)) report("division by zero rejected", 1);

    print_if_odd(4);
    print_if_odd(7);

    void'(safe_div(9, 3, q));
    $display("q = %0d, errors = %0d", q, error_count);
  end

endmodule
```

```output
INFO : starting
17 / 5 = 3 remainder 2
20 / 4 = 5
ERROR: division by zero rejected
7 is odd
q = 3, errors = 1
```

**Line by line**

| Line | Explanation |
|---|---|
| `function automatic void report(string msg, bit is_error = 0);` | A void function with a default argument (Section 4.4). It modifies the module variable `error_count`: a function may read and write variables outside itself. |
| `report("starting");` | Called as a statement. No `void'()` is needed because there is no return value. |
| `function automatic divmod_t divmod(...)` | The return type is a struct, so two numbers come back in one value. |
| `function automatic bit safe_div(input int x, input int y, output int q);` | Returns 1 for success. The quotient is delivered through the `output` argument. |
| `if (y == 0) return 0;` | Early return. The output `q` was never assigned, so the caller receives the default value of the formal argument, 0 (Section 4.1). |
| `if (x % 2 == 0) return;` | In a void function `return;` has no expression. |
| `void'(safe_div(9, 3, q));` | The status is deliberately ignored; `q` is still written. |

### Function versus void function

| Property | Function with a return type | Void function |
|---|---|---|
| Returns a value | Yes | No |
| Used in an expression | Yes | No, only as a statement |
| Called as a statement | Only with `void'()` (otherwise a warning) | Yes |
| `return` form | `return expr;` | `return;` |
| May consume time | No | No |
| Typical use | Calculations, queries, `copy()`, `compare()` | `print()`, `report()`, `connect()`, setters |

### Interview questions

**Q1. What is a void function?**
A function that returns no value. It is called as a statement and, like every function, executes in zero simulation time.

**Q2. When would you write a void function instead of a task?**
Whenever the subroutine does not need to consume time. A void function can be called from other functions and from contexts where tasks are illegal, and it guarantees to the reader that the call does not block.

**Q3. How do you return more than one value from a function?**
Return a struct (or an array or a class handle), or use `output` or `ref` arguments in addition to the return value.

**Q4. What does `void'(f())` mean?**
It calls the function `f` and explicitly discards its return value, which suppresses the warning for an unused function result.

**Q5. Can a function return an array?**
Yes, if the array type has a `typedef` name that is used as the return type.

## 2.4 Why a Function Cannot Consume Simulation Time

### The rule

A function must begin and end in the same simulation time step, and without suspending. Therefore the following are **illegal inside a function**:

| Illegal in a function | Why |
|---|---|
| `#delay` | Would advance time |
| `@(event)` | Would suspend until the event |
| `wait (condition)` | Might suspend |
| `fork`...`join`, `fork`...`join_any` | The parent would wait for child processes |
| A call to a task | The task **might** consume time, even if this particular one does not |
| Blocking calls such as `mailbox.get()`, `semaphore.get()` | They are tasks that can suspend |
| `wait_order`, `expect`, `##` cycle delay | Blocking statements |

Legal in a function: blocking assignments, `if`, `case`, loops, calls to other functions (including itself), system functions and non-blocking system tasks such as `$display`, non-blocking methods such as `mailbox.try_get()`, and `fork`...`join_none` (see below).

### The reason

A function call is an **operand of an expression**, and an expression must be evaluated atomically.

```text
   assign y = a + f(b);              continuous assignment: must settle "now"

   if (f(x) > g(y)) ...              the two operands must describe the same instant

   always_comb z = f(a) & c;         combinational logic has no notion of waiting

   constraint c { len == f(kind); }  the solver calls f() while solving; it cannot pause
```

Consider `y = a + f(b);`. The simulator reads `a`, then calls `f`. If `f` could wait for 10 ns, what would the expression mean? `a` was read at one time and `f(b)` finished at another; `a` and `b` might have changed in between; and in a continuous assignment or an `always_comb` block there is no process that *could* wait. An expression has a value at an instant. The language keeps that true by requiring every function to complete in zero time. Anything that must wait is a different kind of thing, and SystemVerilog gives it a different keyword: `task`.

The same guarantee is what makes functions synthesizable as pure combinational logic, and what allows a simulator to call them from regions and contexts where suspension is impossible (continuous assignments, constraint solving, `final` blocks, constructors, coverage sampling).

### Why even a task with no delays is forbidden

```systemverilog
task automatic no_delay_task();
  $display("no timing control in here");
endtask

function automatic void f();
  no_delay_task();       // ILLEGAL: a function cannot call a task
endfunction
```

The check is made on the **kind** of subroutine, not on its contents. Legality must be decidable at compile time from the declaration alone, and must not change when someone later edits the task body. With virtual methods (Module 4) the compiler cannot even know which task body will run. So the rule is absolute: no task calls in a function.

### The one exception: fork...join_none

A function may contain `fork`...`join_none`. The function does not wait: it spawns background processes and returns immediately, still in zero time. The spawned processes begin executing after the calling process next suspends, and **they** are free to use delays and call tasks.

```systemverilog file=tb_function_no_time.sv
module tb_function_no_time;

  // Legal: the function itself returns immediately; the forked thread runs later
  function automatic void start_watchdog(int timeout);
    fork
      begin
        #timeout;
        $display("[%0t] watchdog expired", $time);
      end
    join_none
    $display("[%0t] start_watchdog() returns", $time);
  endfunction

  // function automatic int bad(int x);
  //   #5;                      // ILLEGAL: delay in a function
  //   @(posedge clk);          // ILLEGAL: event control in a function
  //   return x;
  // endfunction

  initial begin
    $display("[%0t] calling function", $time);
    start_watchdog(20);
    $display("[%0t] back in the caller", $time);
    #30;
    $display("[%0t] done", $time);
  end

endmodule
```

```output
[0] calling function
[0] start_watchdog() returns
[0] back in the caller
[20] watchdog expired
[30] done
```

**Line by line**

| Line | Explanation |
|---|---|
| `fork ... join_none` | Creates a child process containing the `begin`...`end` block and continues **without waiting**. |
| `#timeout;` inside the fork | Legal: it is executed by the child process, not by the function. |
| First three output lines | All at time 0. The function printed and returned without any time passing. |
| `[20] watchdog expired` | The child process ran in the background after the `initial` block suspended at `#30`. |
| Commented `bad` function | Uncomment it to see the compile error your simulator gives for a timing control in a function. |

This pattern is used in real testbenches: a class constructor (`new` is a function) or a UVM function phase that needs to start a background monitor thread does it with `fork`...`join_none`. The standard requires the function to be called from procedural code that originates in an `initial` or `always`-type process, not from a continuous assignment.

### Nonblocking assignments and event triggers in functions

Recent revisions of IEEE 1800 allow a function to contain nonblocking assignments (`<=`) and event triggers (`->`), since neither suspends the function. Verilog-2001 did not allow nonblocking assignments in functions, some tools still restrict them, and such a function cannot be used where side effects are forbidden. For synthesizable code, functions should contain only blocking assignments to their own local variables and return value.

### What the question is really testing

| Question | Short answer |
|---|---|
| Can a function have a delay? | No |
| Can a function call a task? | No (except from inside a `fork`...`join_none` within it) |
| Can a task call a function? | Yes |
| Can a function call another function? | Yes, including itself (recursion) |
| Can a function contain `fork`...`join`? | No. Only `fork`...`join_none` |
| Can a function call `$display`? | Yes. It is a system task that does not block |
| Can a function call `mailbox.get()`? | No, `get()` is a blocking task. `try_get()` is a function and is allowed |
| Can a constructor `new()` contain a delay? | No. `new` is a function |
| Is `function void` allowed to consume time, since it returns nothing? | No. `void` only removes the return value |

> **Interview trap:** "The task contains no delay, so can my function call it?" No. The restriction is on calling a task at all, regardless of what is inside it. Convert the task into a void function.

> **How to say it in an interview:** "A function is used as an operand in expressions, in continuous assignments, in `always_comb` and in constraints. An expression must be evaluated in zero time, so a function is not allowed to contain any statement that could suspend it: no delays, no event controls, no waits and no task calls. A task has no return value and is called as a statement, so it is allowed to block. The only timing-related construct permitted in a function is `fork`...`join_none`, because the function still returns immediately."

### Interview questions

**Q1. Why can a function not contain a delay?**
Because a function call is part of an expression and must produce its value in the same time step in which it is called. A delay would suspend the evaluation of the expression, which is meaningless in a continuous assignment, combinational block or constraint.

**Q2. Can a function call a task? Can a task call a function?**
A function cannot call a task, because the task might consume time. A task can call any function.

**Q3. Is there any way for a function to start time-consuming activity?**
Yes: with `fork`...`join_none`. The function spawns a background process and returns immediately; the spawned process may contain delays and task calls.

**Q4. Can you use `wait` or `@` in a function if the condition is already true?**
No. The statement is illegal in a function whether or not it would actually block.

**Q5. Why is a constructor not allowed to wait for a clock edge?**
`new()` is a function. Object construction happens in zero time. Anything that must wait is placed in a task of the class, typically `run()`, which is called after construction.
