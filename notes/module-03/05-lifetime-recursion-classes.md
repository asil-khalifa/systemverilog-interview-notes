# Part 5: Lifetime, Recursion and Class Methods

## 5.1 Automatic and Static Lifetime

### In plain English

Every variable needs somewhere to live. The question of **lifetime** is: when is that storage created, and when is it thrown away?

- A **static** variable is created once, before the simulation starts, and exists until the simulation ends. There is exactly one copy. Whatever value it was left with after one call of a subroutine is still there at the next call.
- An **automatic** variable is created each time execution enters the subroutine (or block) that declares it, and is discarded when execution leaves. Each call gets its own fresh copy.

Think of a meeting room. Static is a single whiteboard fixed to the wall: every group that uses the room sees what the last group wrote, and two groups in the room at the same time write over each other. Automatic is a fresh notepad handed to each group as it enters and collected as it leaves.

### Technical definition

| | Static lifetime | Automatic lifetime |
|---|---|---|
| Storage allocated | Once, at elaboration (before time 0) | On each entry to the task, function or block |
| Storage released | At the end of simulation | When that invocation ends (and no spawned process still uses it) |
| Number of copies | One, shared by all calls and all calling processes | One per active invocation |
| Initialiser in the declaration | Executed once, before time 0 | Executed on every entry |
| Value at the start of a call | Whatever the previous call left | The initialiser, or the type's default |

Lifetime applies to the **arguments** of a subroutine as well as to its local variables. In a static task the formal arguments are a single shared set of variables.

### Why both exist

Verilog was designed to describe hardware, and hardware is static: a flip-flop exists for ever. So Verilog made everything static, including the variables inside tasks and functions. That choice is wrong for software-style code, where a subroutine may be active several times at once (called from parallel processes, or calling itself). SystemVerilog added automatic lifetime for that purpose and made it the only option inside classes, but kept static as the default in modules for backward compatibility.

### The defaults

| Where the subroutine or variable is declared | Default lifetime | Can it be changed? |
|---|---|---|
| Task or function in a `module`, `interface`, `program` or `package` | **Static** | Yes: `task automatic`, `function automatic` |
| All tasks and functions of a module, interface, program or package at once | Static | Yes: `module automatic m;`, `program automatic p;`, `package automatic pkg;` |
| Task or function in a `class` (a method) | **Automatic** | No. Class methods cannot have static lifetime |
| Variable declared directly in a module, interface, program or package | Static | No |
| Variable declared in an `initial` or `always` block of a module | Static | Yes: `automatic int x;` |
| Local variable or argument of a static subroutine | Static | Locals: yes, with `automatic`. Arguments follow the subroutine |
| Local variable of an automatic subroutine | Automatic | Yes: `static int x;` |
| Loop variable declared in the header: `for (int i = 0; ...)` | Automatic | — |
| Class property | Created with each object | `static` makes one copy for the whole class (Module 4) |

### Syntax

```systemverilog
function automatic int f(int x);     // lifetime keyword goes after "function" / "task"
  int        a;                      // automatic (follows the function)
  static int calls = 0;              // explicitly static inside an automatic function
  ...
endfunction

task static t();                     // explicitly static (same as the default in a module)
  int           a;                   // static
  automatic int b = 0;               // explicitly automatic inside a static task
  ...
endtask

module automatic tb;                 // every task/function in this module is automatic
  ...
endmodule
```

> **Key point:** The explicit-keyword rule from Section 1.2 applies here. In a static subroutine or block, a variable declaration **with an initialiser** must say `static` or `automatic` explicitly. `int count = 0;` on its own inside a static task is flagged by strict tools, because it is ambiguous to the reader: is it reset on each call (no) or set once before time 0 (yes)?

### How it works internally

```text
   STATIC function f                          AUTOMATIC function f

   one fixed block of storage                 a new block per call (a "stack frame")

   +-----------------------+                  call 1:  +-----------+
   | x | a | return value  |  <- call 1                | x | a | r |  discarded at return
   +-----------------------+  <- call 2                +-----------+
                              <- call 3       call 2:  +-----------+
   every call reads and writes the                     | x | a | r |  discarded at return
   same cells; values persist                          +-----------+
   between calls                              two calls active at once -> two blocks
```

### Complete example

```systemverilog file=tb_lifetime.sv
module tb_lifetime;

  // Automatic function, automatic local: re-created and re-initialised on each call
  function automatic int count_auto();
    int n = 0;
    n++;
    return n;
  endfunction

  // Automatic function with an explicitly static local: one copy, initialised once
  function automatic int count_static_var();
    static int n = 0;
    n++;
    return n;
  endfunction

  // Static function (the module default): its locals are static
  function int count_static_func();
    int n;                 // static, starts at 0, keeps its value between calls
    n++;
    return n;
  endfunction

  initial begin
    $display("call  auto  static_var  static_func");
    for (int i = 1; i <= 3; i++)
      $display("%0d     %0d     %0d           %0d",
               i, count_auto(), count_static_var(), count_static_func());
  end

endmodule
```

```output
call  auto  static_var  static_func
1     1     1           1
2     1     2           2
3     1     3           3
```

**Line by line**

| Line | Explanation |
|---|---|
| `count_auto` | `n` is created and set to 0 on every call, incremented, returned and destroyed. Always 1. |
| `static int n = 0;` in `count_static_var` | One copy for the whole simulation; the `= 0` is executed once before time 0. The value survives between calls: 1, 2, 3. |
| `function int count_static_func();` | No `automatic`, so the function and its local `n` are static. Same behaviour as the explicit `static`. The declaration has no initialiser, which avoids the explicit-keyword rule. |
| `for (int i = 1; ...)` | The loop variable is automatic regardless of the surrounding block. |

### What automatic variables cannot do

| Restriction | Reason |
|---|---|
| Cannot be assigned with a nonblocking assignment (`<=`) | The update happens later in the time step, when the variable may no longer exist |
| Cannot be driven by a continuous assignment or used in `force` | Same reason |
| Cannot be referenced hierarchically (`tb.my_task.x`) | There may be zero or many copies |
| Cannot be used in `$monitor` or dumped to a waveform by `$dumpvars` | Same reason. This makes automatic variables harder to see in a wave viewer |
| An automatic subroutine's variables do not hold values between calls | By definition; use a `static` local or a module/class variable when persistence is wanted |

### Static versus automatic

| Property | Static | Automatic |
|---|---|---|
| Copies | One | One per call |
| Keeps its value between calls | Yes | No |
| Safe when called from parallel processes | No | Yes |
| Recursion | Does not work | Works |
| `ref` arguments | Not allowed | Allowed |
| Nonblocking assignment to locals | Allowed | Not allowed |
| Visible in waveforms | Yes | Usually not |
| Default in modules, interfaces, programs, packages | Yes | |
| Default in classes | | Yes (the only choice) |
| Models hardware storage | Yes | No |

### The keyword static has two meanings

Inside a class, `static` in front of a method or property means "belongs to the class, not to an object" (Module 4). It says nothing about lifetime.

| Declaration (inside a class) | Meaning |
|---|---|
| `static function int get_count();` | A **static method**: can be called without an object as `alu_txn::get_count()`. Its lifetime is automatic, like every class method |
| `function static int f();` | A method with **static lifetime**: illegal in a class |
| `static int count;` | A static property: one copy shared by all objects |

The position of the keyword tells them apart: before `function`/`task` it is the class qualifier; after it is the lifetime.

> **Interview trap:** "What is the default lifetime of a task in a module? In a class? In a package?" Static, automatic, static. Functions declared in a package are static unless marked `automatic`, even though packages are mostly used by class-based code.

> **Common mistake:** Assuming `int count = 0;` at the top of a module-level task resets `count` on each call. In a static task the initialisation happens once, before simulation starts. The counter keeps increasing across calls.

> **Verification application:** Testbench code should be automatic everywhere: declare `module automatic tb_top;` or write `automatic` on each subroutine, and declare utility packages as `package automatic`. Class-based code gets this for free. Deliberate static locals are used for things that must persist, such as a unique-ID counter: `static int unsigned next_id = 0; return next_id++;`.

### Interview questions

**Q1. What is the difference between static and automatic lifetime?**
A static variable is allocated once and exists for the whole simulation, so all calls share it and it keeps its value between calls. An automatic variable is allocated on each entry to its subroutine or block and released on exit, so every call has its own copy.

**Q2. What is the default lifetime of tasks and functions?**
Static in modules, interfaces, programs and packages. Automatic in classes.

**Q3. How do you make all subroutines in a module automatic?**
Declare the module as `module automatic name;`. The same works for `program`, `interface` and `package`.

**Q4. Can an automatic function contain a static variable?**
Yes, by declaring it with the `static` keyword. It is shared by all calls and initialised once.

**Q5. Why can a nonblocking assignment not be made to an automatic variable?**
The assignment takes effect later, in the NBA region; by then the subroutine may have returned and the variable may no longer exist.

**Q6. What is the difference between `static task foo();` and `task static foo();` in a class?**
The first declares a static method (called on the class, automatic lifetime). The second requests static lifetime, which is not allowed for class methods.

## 5.2 The Shared-Variable Bug in Static Tasks

### In plain English

Because a static task has only one copy of its arguments and local variables, two processes that are inside the task at the same time are using the same variables. The second caller's arguments overwrite the first caller's. The first caller, when it wakes up from its delay, carries on with the second caller's values.

A function cannot be "inside" for any length of time, so two processes can never be in the same function simultaneously. The bug therefore needs a task with a timing control (or recursion, Section 5.3). It is the most asked question about lifetime.

### Complete example

```systemverilog file=tb_static_task_bug.sv
module tb_static_task_bug;

  // Static by default: ONE copy of id and dly for all callers
  task send_static(input int id, input int dly);
    #dly;
    $display("[%0t] static   : finished id=%0d", $time, id);
  endtask

  // Automatic: each call has its own id and dly
  task automatic send_auto(input int id, input int dly);
    #dly;
    $display("[%0t] automatic: finished id=%0d", $time, id);
  endtask

  initial begin
    fork
      send_static(1, 10);
      send_static(2, 5);
    join

    fork
      send_auto(1, 10);
      send_auto(2, 5);
    join
  end

endmodule
```

```output
[5] static   : finished id=2
[10] static   : finished id=2
[15] automatic: finished id=2
[20] automatic: finished id=1
```

The output assumes that the two branches of each `fork` start in the order in which they are written, which is what the common simulators do. The standard does not guarantee the order; if the second branch started first, the static task would print `id=1` twice instead. Either way the static version reports the same ID twice.

### What happened, step by step

```text
   time 0   branch 1 calls send_static(1, 10)
              shared variables:   id = 1   dly = 10
              "#dly" is evaluated: wake up at time 10.  Branch 1 suspends.

   time 0   branch 2 calls send_static(2, 5)
              shared variables:   id = 2   dly = 5      <-- branch 1's values are overwritten
              "#dly" is evaluated: wake up at time 5.   Branch 2 suspends.

   time 5   branch 2 resumes:  prints id = 2            correct
   time 10  branch 1 resumes:  prints id = 2            WRONG, it was called with id = 1
```

With `send_auto`, each call has a private `id` and `dly`. Branch 1 keeps `id` = 1 for the whole call. The second `fork` starts at time 10, so its messages appear at 15 (branch 2, delay 5) and 20 (branch 1, delay 10).

### Where this bug appears in practice

| Situation | Symptom |
|---|---|
| A module-level BFM task (`write(addr, data)`) called from two parallel test threads | A transfer goes out with the other thread's address or data |
| A static task with a local loop counter, called concurrently | Loops end early or never, because both calls share the counter |
| A recursive function declared without `automatic` | Wrong result (Section 5.3) |
| A static task with `int count = 0;` | The counter is not reset on each call |
| Tasks in a package or interface used by class-based code | The same corruption, harder to find because the callers are in different classes |

### How to avoid it

1. Declare every testbench task and function `automatic`, or the whole module/package/program `automatic`.
2. Put testbench code in classes, where methods are always automatic.
3. Remember that `automatic` only protects the task's **own** arguments and locals. If two calls drive the same module signals or interface pins, they still collide. That is a resource-sharing problem and needs a semaphore (Module 7).

> **Interview trap:** "The task is automatic, so is it safe to call from two threads?" Only its local data is safe. If the task drives shared signals (`valid_in`, `a`, `b`), two simultaneous calls still fight over them. Automatic lifetime solves data corruption inside the task; mutual exclusion solves access to shared resources.

> **How to say it in an interview:** "In a module, tasks are static by default, so there is a single copy of the arguments and locals. If the task consumes time and is called from two concurrent processes, the second call overwrites the first call's arguments while the first is suspended, and the first resumes with the wrong values. Declaring the task `automatic` gives each call its own storage. Class methods are automatic by default, so this problem does not arise there."

### Interview questions

**Q1. What goes wrong when a static task with a delay is called from two parallel threads?**
Both calls use the same argument and local-variable storage. The later call overwrites the earlier call's values while the earlier call is waiting, so the earlier call continues with corrupted data.

**Q2. Can the same problem occur with a static function?**
Not through concurrency, because a function completes in zero time and cannot be interrupted. It can occur through recursion, where the nested call overwrites the outer call's variables.

**Q3. How do you fix it?**
Declare the task `automatic`.

**Q4. Does `automatic` make a task fully re-entrant?**
It makes the task's arguments and locals private to each call. Module-level variables and signals that the task reads or writes are still shared and must be protected separately.

## 5.3 Recursive Functions

### In plain English

A recursive function is a function that calls itself. It solves a problem by reducing it to a smaller version of the same problem, until the problem is so small that the answer is known directly. Factorial is the standard example: 5! is 5 × 4!, 4! is 4 × 3!, and so on, until 1!, which is 1.

### Technical definition

**Recursion** is a subroutine invoking itself, directly or through other subroutines. A correct recursive subroutine has

1. a **base case**: a condition under which it returns without calling itself, and
2. a **recursive case**: a call to itself with an argument that moves towards the base case.

In SystemVerilog a recursive subroutine must be **automatic**. Each nested call needs its own copy of the arguments and locals, which is exactly what automatic lifetime provides. Tasks may be recursive as well as functions.

### How it works internally

```text
   factorial(4)                       the "call stack": one frame per active call

   factorial(4):  n = 4   needs 4 * factorial(3)   ---------+
     factorial(3):  n = 3   needs 3 * factorial(2)   ------+ |   going down:
       factorial(2):  n = 2   needs 2 * factorial(1)   --+ | |   frames are created
         factorial(1):  n = 1   base case: returns 1     | | |
       factorial(2) returns 2 * 1 = 2   <----------------+ | |   coming back up:
     factorial(3) returns 3 * 2 = 6   <--------------------+ |   frames are destroyed
   factorial(4) returns 4 * 6 = 24  <------------------------+

   With automatic lifetime there are four separate variables called n, one per frame.
   With static lifetime there is ONE n: the inner calls overwrite it.
```

### Complete example

```systemverilog file=tb_recursion.sv
module tb_recursion;

  function automatic longint unsigned factorial(int unsigned n);
    if (n <= 1) return 1;                       // base case
    return n * factorial(n - 1);                // recursive case
  endfunction

  function automatic int fib(int n);
    if (n < 2) return n;                        // fib(0) = 0, fib(1) = 1
    return fib(n - 1) + fib(n - 2);
  endfunction

  function automatic int gcd(int x, int y);
    if (y == 0) return x;
    return gcd(y, x % y);
  endfunction

  // Sum of 1..n, automatic: correct
  function automatic int sum_auto(int n);
    int partial;
    if (n == 0) return 0;
    partial = sum_auto(n - 1);
    return partial + n;
  endfunction

  // The same code with static lifetime: broken
  function int sum_static(int n);
    int partial;
    if (n == 0) return 0;
    partial = sum_static(n - 1);
    return partial + n;
  endfunction

  // A recursive task that consumes time
  task automatic countdown(int n);
    if (n == 0) begin
      $display("[%0t] lift-off", $time);
      return;
    end
    $display("[%0t] %0d", $time, n);
    #10;
    countdown(n - 1);
  endtask

  initial begin
    $display("factorial(5)  = %0d", factorial(5));
    $display("factorial(20) = %0d", factorial(20));
    $display("fib(10)       = %0d", fib(10));
    $display("gcd(48, 18)   = %0d", gcd(48, 18));
    $display("sum_auto(3)   = %0d", sum_auto(3));
    $display("sum_static(3) = %0d", sum_static(3));
    countdown(3);
  end

endmodule
```

```output
factorial(5)  = 120
factorial(20) = 2432902008176640000
fib(10)       = 55
gcd(48, 18)   = 6
sum_auto(3)   = 6
sum_static(3) = 0
[0] 3
[10] 2
[20] 1
[30] lift-off
```

**Line by line**

| Line | Explanation |
|---|---|
| `function automatic longint unsigned factorial(...)` | The result grows fast: 13! already exceeds 32 bits, so the return type is 64-bit. 20! is the largest factorial that fits in 64 bits. |
| `if (n <= 1) return 1;` | The base case. Without it the function would call itself for ever. |
| `return n * factorial(n - 1);` | The function is suspended in the middle of this expression while the nested call runs; its own `n` is preserved in its own frame. |
| `fib` | Two recursive calls per invocation. Simple but exponentially slow; `fib(10)` already makes 177 calls. |
| `gcd(48, 18)` | Euclid's algorithm: gcd(48, 18) → gcd(18, 12) → gcd(12, 6) → gcd(6, 0) → 6. |
| `sum_auto(3)` | 3 + 2 + 1 + 0 = 6. |
| `sum_static(3)` | The same statements give 0. See the trace below. |
| `countdown` | A recursive task. Each level waits 10 time units before calling the next, so the calls are spread over simulation time. |

### Why the static version returns 0

```text
   sum_static has ONE variable n and ONE variable partial.

   sum_static(3):  n = 3;  calls sum_static(2)
     n = 2;  calls sum_static(1)
       n = 1;  calls sum_static(0)
         n = 0;  base case: returns 0
       back in the call that was made with 1:  partial = 0;  return partial + n
                                               but n is now 0  ->  returns 0
     back in the call that was made with 2:    partial = 0;  n is still 0  ->  returns 0
   back in the call that was made with 3:      partial = 0;  n is still 0  ->  returns 0
```

Every level adds the shared `n`, which the innermost call left at 0. Some simulators warn about recursion in a static function; all of them compute a wrong answer.

### Rules and cautions

| Point | Detail |
|---|---|
| Must be `automatic` | In a module or package. Class methods are automatic already |
| Must have a reachable base case | Otherwise infinite recursion: the simulator runs out of stack and crashes or reports a stack overflow |
| Depth is limited | Each level uses stack memory; tens of thousands of levels may exceed the simulator's limit. Prefer a loop for long linear recursions |
| Zero time for functions | A recursive function still completes in zero time however deep it goes |
| Synthesis | Recursive functions are generally not synthesizable. Some tools accept recursion whose depth is fixed by constants at elaboration time |
| Indirect recursion | `a` calls `b` and `b` calls `a`: also recursion, also needs `automatic` on both |

### Recursion versus iteration

| Property | Recursion | Loop |
|---|---|---|
| Code for naturally recursive problems (trees, divide and conquer, nested structures) | Short and clear | Needs an explicit stack |
| Speed and memory | A call and a frame per level | Usually faster, constant memory |
| Risk | Stack overflow, missing base case | Infinite loop |
| Synthesizable | Rarely | Yes, with constant bounds |

> **Interview trap:** "Write a factorial function." The most common errors are: forgetting `automatic`; forgetting the base case for 0; and returning `int`, which overflows at 13!. Mention all three even if you are not asked.

> **Verification application:** Recursion appears in testbenches when walking nested data: printing a tree of components, flattening a hierarchical register map, generating all combinations of a set of options for exhaustive stimulus. UVM uses recursive calls to traverse the component hierarchy in each phase.

### Interview questions

**Q1. What is a recursive function and what does it need to work in SystemVerilog?**
A function that calls itself. It needs a base case that ends the recursion, and it must be declared `automatic` so that each call has its own arguments and local variables.

**Q2. What happens if a recursive function is not declared automatic?**
All levels share one set of variables. Inner calls overwrite the values that outer calls still need, and the result is wrong.

**Q3. Can a task be recursive?**
Yes, if it is automatic. Each level may consume time.

**Q4. What happens if the base case is missing?**
The function calls itself without end until the simulator's stack is exhausted, causing a crash or a stack-overflow error.

**Q5. Are recursive functions synthesizable?**
Generally no. Hardware cannot be created for a depth that is known only at run time.

**Q6. Write a recursive function to compute the sum of the digits of a number.**
`function automatic int digit_sum(int unsigned n); if (n < 10) return n; return (n % 10) + digit_sum(n / 10); endfunction`

## 5.4 Function and Task Declarations Inside Classes

This section is a preview. Classes are the subject of Module 4; here the aim is only to connect what you have learned about functions and tasks to the place where they are used most.

### In plain English

A class groups data together with the subroutines that work on that data. The data items are called **properties**; the subroutines are called **methods**. A method is an ordinary function or task, declared inside the class, that can read and write the properties of the object on which it is called.

### What stays the same and what changes

| Topic | In a module | In a class |
|---|---|---|
| Function versus task | Function: zero time. Task: may consume time | Identical |
| Argument directions, defaults, named binding | As in Part 4 | Identical |
| Default lifetime | Static | **Automatic**, always |
| `automatic` keyword | Needed | Not needed |
| What the body can access | Module variables and signals | The object's own properties (directly, or through `this`) |
| How it is called | `my_task(args);` | `handle.method(args);` |
| Special subroutine | — | `new`, the constructor: a function with no return type |
| Extra qualifiers | — | `static`, `virtual`, `pure virtual`, `local`, `protected`, `extern` |

### Method qualifiers at a glance

| Qualifier | Meaning | Module |
|---|---|---|
| (none) | Ordinary method, called through an object handle | 4 |
| `static` | Belongs to the class; called as `class_name::method()`; cannot access non-static properties | 4 |
| `virtual` | Can be overridden in a derived class; the version executed is chosen by the object's type at run time | 4 |
| `pure virtual` | Declared in an abstract class with no body; derived classes must implement it | 4 |
| `local`, `protected` | Restrict who may call the method | 4 |
| `extern` | The body is written outside the class as `function return_type class_name::method(...)` | 4 |

### Complete example

Compile with `alu_pkg.sv` from Module 1.

```systemverilog file=tb_class_methods.sv
module tb_class_methods;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    // Void function: prints the object. Zero time.
    function void print(string tag = "");
      $display("%s id=%0d op=%s a=%0d b=%0d result=%0d",
               tag, id, op.name(), a, b, result);
    endfunction

    // Function returning a handle to a new object with the same contents
    function alu_txn copy();
      alu_txn t;
      t        = new();
      t.a      = a;
      t.b      = b;
      t.op     = op;
      t.result = result;
      t.id     = id;
      return t;
    endfunction

    // Function returning a status bit; the argument is a handle to another object
    function bit compare(alu_txn rhs);
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction

    // Body written outside the class
    extern function logic [8:0] expected();
  endclass

  function logic [8:0] alu_txn::expected();
    case (op)
      ALU_ADD: return {1'b0, a} + {1'b0, b};
      ALU_SUB: return {1'b0, a} - {1'b0, b};
      default: return 'x;        // remaining operations omitted in this preview
    endcase
  endfunction

  class ticker;
    string name;

    function new(string name = "ticker");     // constructor: a function, zero time
      this.name = name;                       // this.name is the property, name the argument
    endfunction

    task run(int n, int period);              // a task: consumes time
      repeat (n) begin
        #period;
        $display("[%0t] %s tick", $time, name);
      end
    endtask
  endclass

  alu_txn t1, t2;
  ticker  tk;

  initial begin
    t1 = new();
    t1.id     = 1;
    t1.a      = 8'd200;
    t1.b      = 8'd100;
    t1.op     = ALU_ADD;
    t1.result = t1.expected();
    t1.print("[GEN]");

    t2    = t1.copy();
    t2.id = 2;
    t2.print("[CPY]");
    $display("compare before change: %b", t1.compare(t2));

    t2.b = 8'd50;
    $display("compare after  change: %b", t1.compare(t2));

    tk = new("clk_a");
    tk.run(2, 10);
  end

endmodule
```

```output
[GEN] id=1 op=ALU_ADD a=200 b=100 result=300
[CPY] id=2 op=ALU_ADD a=200 b=100 result=300
compare before change: 1
compare after  change: 0
[10] clk_a tick
[20] clk_a tick
```

**Line by line**

| Line | Explanation |
|---|---|
| `function void print(string tag = "");` | No `automatic` keyword: methods are automatic. The body uses `id`, `op`, `a`, `b`, `result` directly; they are the properties of the object the method was called on. |
| `t1.print("[GEN]");` | Calls `print` on the object that `t1` refers to. |
| `function alu_txn copy();` | Returns a class handle. `t` is declared and then assigned `new()`, which creates a second object; the fields are copied one by one. |
| `function bit compare(alu_txn rhs);` | `rhs` is an input handle to another object. `a` is this object's property; `rhs.a` is the other object's. `id` is deliberately not compared. `===` is used for the four-state `result`. |
| `extern function ... expected();` | Only the prototype is inside the class. The body follows the class and names its class with `alu_txn::`. This keeps a class declaration short enough to read as a summary. |
| `function new(string name = "ticker");` | The constructor. It has no return type, is called by `new(...)`, and being a function it cannot wait. |
| `this.name = name;` | The argument hides the property of the same name; `this.name` refers to the property. |
| `task run(int n, int period);` | A task method with delays. `tk.run(2, 10)` blocks the caller for 20 time units. |
| `t2 = t1.copy(); t2.id = 2;` | `t2` refers to a separate object, so changing `t2.id` and later `t2.b` does not affect `t1`. |

### Functions and tasks in the layered testbench

| Component | Method | Function or task | Why |
|---|---|---|---|
| `alu_txn` | `new`, `print`, `copy`, `compare` | Functions | Operate on data only |
| `alu_generator` | `run` | Task | Blocks on `gen2drv_mbx.put()` and between transactions |
| `alu_driver` | `run`, `drive` | Tasks | Wait for mailbox items and clock edges |
| `alu_monitor` | `run` | Task | Waits for clock edges, samples `vif` |
| `alu_scoreboard` | `run` | Task | Blocks on `mon2scb_mbx.get()` |
| `alu_scoreboard` | `predict` / reference model, `report` | Functions | Pure calculation and printing |
| `alu_env` | `new`, `build`/`connect` | Functions | Create and connect objects in zero time |
| `alu_env`, `alu_test` | `run` | Tasks | Start the components with `fork` and wait for the test to finish |

The rule from Part 3 holds throughout: a method is a task only when it has to wait.

> **Interview trap:** "Do you need to declare class methods `automatic`?" No. They are automatic by default and cannot be static-lifetime. "Then can the shared-variable bug happen in a class?" Not with the method's arguments or locals. It can still happen with class properties, since all calls on the same object share that object's properties.

> **Common mistake:** Putting time-consuming code in the constructor. `new` is a function, so `@(posedge vif.clk)` inside it is a compile error. Constructors only build and connect; waiting belongs in `run()`.

### Interview questions

**Q1. What is a method?**
A function or task declared inside a class. It operates on the properties of the object it is called on.

**Q2. What is the default lifetime of class methods?**
Automatic. It cannot be changed to static.

**Q3. Why is the constructor a function and not a task?**
Object creation must complete in zero time; `new` is used in expressions such as `t = new();`. Therefore it cannot contain timing controls.

**Q4. In a testbench, which methods are tasks and which are functions?**
Methods that wait for a clock, a mailbox or another component (`run`, `drive`) are tasks. Methods that only compute, copy, compare, print or build (`new`, `copy`, `compare`, `print`, the reference model) are functions.

**Q5. What does `extern` do?**
It lets the class contain only the method's prototype, with the body defined outside the class using the scope operator: `function void alu_txn::print(...)`.
