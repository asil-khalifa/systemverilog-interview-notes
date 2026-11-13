# Part 6: Module 3 Revision and Practice

## 6.1 Revision Summary

### Procedural blocks

| Block | Runs | Timing controls | Use |
|---|---|---|---|
| `initial` | Once, from time 0 | Allowed | Stimulus, test start |
| `always` | For ever, from time 0 | Required (or it hangs) | Clocks, legacy RTL, monitors |
| `always_comb` | At time 0 and on input change | Not allowed | Combinational logic, `=` |
| `always_ff` | On the clock/reset edge | Only the edge list | Flip-flops, `<=` |
| `always_latch` | At time 0 and on input change | Not allowed | Latches |
| `final` | Once, at the end | Not allowed | Summary report |

- All blocks are concurrent processes. Order between blocks at the same time is undefined.
- A process runs without interruption until it reaches a timing control.

### Assignments and regions

- `=` updates immediately; `<=` evaluates the right-hand side now and updates in the NBA region.
- Sequential logic: `<=`. Combinational logic and testbench variables: `=`. Never mix on one variable.
- Region order: Preponed → Active → Inactive → NBA → Observed → Reactive → Postponed.
- `$display` prints at once (Active). `$strobe` and `$monitor` print in Postponed, after NBA updates.
- `#0` moves a process to the Inactive region: later than active processes, earlier than NBA updates.

### Functions and tasks

| | Function | Task |
|---|---|---|
| Time | Zero, always | May consume time |
| `#`, `@`, `wait`, blocking calls | Illegal | Legal |
| Returns | One value or `void` | Nothing |
| In an expression | Yes | No |
| Calls a task | No (only inside `fork`...`join_none`) | Yes |
| Calls a function | Yes | Yes |
| Default return type | 1-bit `logic` | — |
| Synthesizable | Yes | Only without timing |

- Return with `return expr;` or by assigning to the function name; with neither, the type's default is returned.
- `void'(f())` discards a result deliberately.
- A subroutine that never waits should be a function (void if it returns nothing).
- A function cannot consume time because it is an operand of an expression, and expressions are evaluated atomically.

### Arguments

| Direction | Copy in | Copy out | Caller sees changes | Notes |
|---|---|---|---|---|
| `input` (default) | Yes | No | Never | Actual may be any expression |
| `output` | No | At return | At return | Formal starts at the type default |
| `inout` | Yes | At return | At return | |
| `ref` | — | — | Immediately | Automatic only; actual is a variable of the same type; not a net |
| `const ref` | — | — | Read-only | No copy, cannot be modified |

- Default direction `input`, default type `logic`. Direction and type are inherited from the previous argument; writing a direction without a type gives `logic`.
- Arrays, queues and structs passed by value are copied in full. Use `ref` / `const ref`.
- A class handle passed by value still refers to the same object.
- Default values: `int n = 1`. Skip with an empty position or use `.name(value)` binding; positional arguments come first.

### Lifetime

| Declared in | Default lifetime |
|---|---|
| Module, interface, program, package | Static |
| Class | Automatic (fixed) |

- Static: one copy, keeps its value, initialised once before time 0.
- Automatic: one copy per call, re-initialised on each entry.
- Static task + delay + two callers = corrupted arguments. Fix: `automatic`.
- Recursion requires `automatic` and a base case.
- `ref` requires `automatic`. Nonblocking assignment to an automatic variable is illegal.
- In a class, `static function` means a class-level method, not static lifetime.

### One-line answers

| Question | Answer |
|---|---|
| Can a function have a delay? | No |
| Can a function call a task? | No |
| Can a function have output arguments? | Yes |
| Can a function contain `fork`...`join_none`? | Yes |
| Can a task return a value? | No, only through arguments |
| Can a task be used in an expression? | No |
| Must a task consume time? | No |
| Default return type of a function? | 1-bit `logic` |
| Default argument direction? | `input` |
| Default lifetime in a module? | Static |
| Default lifetime in a class? | Automatic |
| Is `new()` a function or a task? | A function |
| Are objects copied when passed to a method? | No, only the handle |

## 6.2 Interview Questions and Answers

These are in addition to the questions at the end of each section.

### Basic level

**Q1. What is a subroutine and what kinds does SystemVerilog have?**
A named block of code that can be called from several places. SystemVerilog has functions (zero time, return a value) and tasks (may consume time, no return value).

**Q2. Which keywords end a function and a task?**
`endfunction` and `endtask`.

**Q3. How many values can a function return?**
One, through its return value. Additional values can be passed back through `output`, `inout` or `ref` arguments, or by returning a struct, array or class handle.

**Q4. What is the difference between `return;` and `return expr;`?**
`return;` leaves a task or a void function. `return expr;` leaves a non-void function and sets its result.

**Q5. Is `begin`...`end` required inside a task or function?**
No. In SystemVerilog several statements may be written directly between the header and `endtask`/`endfunction`.

**Q6. What does `automatic` mean?**
Each call of the subroutine gets its own freshly allocated copy of the arguments and local variables, which is released when the call ends.

**Q7. Can a task have zero arguments? Can a function?**
Yes to both.

**Q8. What is the difference between `$display` and `$strobe`?**
`$display` prints immediately. `$strobe` prints at the end of the current time step, after nonblocking assignments have been applied.

**Q9. Where can a function be called from that a task cannot?**
From any expression, a continuous assignment, an `always_comb` block, a constraint, another function, a constructor and a `final` block.

**Q10. What is the difference between a blocking and a nonblocking assignment in one sentence each?**
Blocking (`=`): the variable is updated before the next statement runs. Nonblocking (`<=`): the new value is computed now but the variable is updated at the end of the time step.

**Q11. What does `void'(...)` do?**
It discards the return value of a function call so that the function can be used as a statement without a warning.

**Q12. How do you pass an argument by reference?**
Declare the formal argument with the `ref` keyword in an automatic subroutine.

### Intermediate level

**Q13. Why can a task with no delay still not be called from a function?**
The language decides legality from the kind of subroutine, not from its body. Any task is allowed to consume time, so no task may be called from a function. If it does not need time, it should be declared as a void function.

**Q14. A task has an `output` argument and takes 100 ns. When does the caller's variable change?**
At the end of the 100 ns, when the task returns. To see intermediate values, use a `ref` argument.

**Q15. What is the difference between `task automatic` in a module and a task in a class?**
None in lifetime: both are automatic. The class task additionally has access to the object's properties through the implicit `this` handle and can be `virtual`.

**Q16. What is wrong with `function int f(input int a, output b);`?**
`b` has a written direction but no type, so it is a 1-bit `logic`, not an `int`. Results wider than one bit are truncated.

**Q17. How do you write a function that modifies a queue owned by the caller?**
`function automatic void f(ref int q[$]);`. With an `input` queue the function would modify a copy.

**Q18. Why is `const ref` preferred over `input` for a large array?**
`input` copies the whole array on every call. `const ref` passes a reference, so nothing is copied, and the `const` prevents accidental modification.

**Q19. A function has both `foo = 5;` (assignment to its name) and later `return 7;`. What is returned?**
7. The `return` statement sets the result and ends the function.

**Q20. Can `always_comb` call a function that reads module-level signals not passed as arguments? What about `always @*`?**
Yes. `always_comb` is sensitive to signals read inside the functions it calls. `always @*` is sensitive only to signals that appear in the block itself, so a change in a signal read only inside the function does not trigger it. This is one reason to use `always_comb`.

**Q21. What is the difference between `disable` and `return` for ending a task?**
`return` ends the current invocation cleanly and copies outputs back. `disable task_name` terminates every active invocation of that task, from any process, and the values of its outputs are not guaranteed.

**Q22. What happens to a `static` local variable in an `automatic` function?**
It is allocated once and shared by all calls; its initialiser runs once before time 0. It is used for things like call counters and ID generators.

**Q23. Can default argument values depend on other variables?**
Yes. The default is an expression evaluated at each call, in the scope where the subroutine is declared.

**Q24. Why do testbench drive tasks use nonblocking assignments or clocking blocks?**
The task and the DUT both act on the same clock edge. With a blocking assignment the DUT might sample either the old or the new value, depending on process order. A nonblocking assignment (or a clocking block drive) updates the signal after the DUT has sampled, removing the race.

### Advanced and scenario-based

**Q25. A bus-write task in an interface works when called from one test thread, but data is corrupted when two threads use it. Give two possible causes.**
(1) The task is static, so both calls share one set of arguments and locals; the second call overwrites the first while it is waiting. Fix: `automatic`. (2) Even with an automatic task, both calls drive the same interface signals at the same time. Fix: protect the bus with a semaphore so that only one transfer is in progress.

**Q26. A function is called millions of times and the simulation is slow. The profile points at the call itself. What do you look for?**
Large arguments passed by value: arrays, queues, associative arrays, structs or strings being copied on every call. Change them to `const ref` (or `ref`).

**Q27. Why does the standard allow `fork`...`join_none` in a function but not `fork`...`join`?**
With `join` and `join_any` the parent waits for at least one child, which may take time. With `join_none` the parent continues immediately, so the function still returns in zero time; the children run later as separate processes.

**Q28. Your scoreboard's `check()` was written as a task. A colleague wants to call it from a covergroup sample function. What is the problem and the fix?**
A function cannot call a task. `check()` does not need to wait, so change it to a void function.

**Q29. Explain why `wait_for(input bit done)` can hang, and give two correct designs.**
The input is a copy taken at the call, so the task never sees `done` change. Correct designs: take the flag by `ref` in an automatic task, or let the task read the signal directly (through a virtual interface or because it is visible in the enclosing scope) instead of receiving it as an argument.

**Q30. In a package you write `function int next_id(); int id; id++; return id; endfunction`. Is `id` reset on each call?**
No. Package functions are static by default, so `id` is static, starts at 0 once and keeps counting: 1, 2, 3... This happens to be the intended behaviour here, but it should be written explicitly as `function automatic int next_id(); static int id; ...` so that the intent is clear.

**Q31. What is printed, and why? `initial begin a = 0; a <= 1; #0 $display(a); end`**
0. `#0` reschedules the process in the Inactive region, which is processed before the NBA region, so the nonblocking update has not yet happened.

**Q32. Why does UVM split a component's work into function phases and task phases?**
Phases that only construct and connect the testbench (`build_phase`, `connect_phase`) or report results must complete in zero time and in a fixed order, so they are functions. The `run_phase` drives and monitors the DUT over simulation time, so it is a task. It is the same function/task rule applied to a whole methodology.

**Q33. Can a function modify a variable that is not one of its arguments?**
Yes. A function can read and write any variable visible in its scope (module variables, class properties). Such side effects are legal but make the function unusable as a constant function and can make `always_comb` behaviour confusing; prefer functions that depend only on their arguments in RTL.

**Q34. Two `always @(posedge clk)` blocks each call the same static function with different arguments. Can they corrupt each other?**
No. Each call runs to completion without interruption, because a function cannot suspend. The second call starts only after the first has returned. Concurrency corruption needs a subroutine that suspends, which means a task.

**Q35. A recursive automatic function works for small inputs and crashes the simulator for large ones. Why?**
Each level of recursion allocates a new frame. A very deep recursion exhausts the simulator's stack. Rewrite it as a loop, or reduce the depth (for example by halving the problem instead of decrementing it).

**Q36. What is the difference between passing a struct and passing a class handle as an `input`?**
The struct is copied member by member; changes inside the subroutine are lost. The handle is copied but refers to the same object; changes to the object's properties are seen by the caller.

## 6.3 Output-Prediction Questions

Work out each answer on paper before reading it.

**P1.**

```systemverilog
module p1;
  task automatic t(input int a, output int b, inout int c);
    b = b + a;
    c = c + a;
    a = 0;
  endtask
  int x = 3, y = 10, z = 20;
  initial begin
    t(x, y, z);
    $display("%0d %0d %0d", x, y, z);
  end
endmodule
```

Answer: `3 3 23`. `a` is a copy, so `x` stays 3. The output formal `b` starts at 0, not 10, so `b` = 0 + 3. The inout formal `c` starts at 20 and returns 23.

**P2.**

```systemverilog
module p2;
  function automatic f(int a);
    return a + 1;
  endfunction
  initial $display("%0d %0d", f(4), f(5));
endmodule
```

Answer: `1 0`. No return type means 1-bit `logic`. 5 is `...101` → 1; 6 is `...110` → 0.

**P3.**

```systemverilog
module p3;
  function int bump();
    int v;
    v += 2;
    return v;
  endfunction
  function automatic int bump_a();
    int v;
    v += 2;
    return v;
  endfunction
  initial begin
    void'(bump());   void'(bump());
    void'(bump_a()); void'(bump_a());
    $display("%0d %0d", bump(), bump_a());
  end
endmodule
```

Answer: `6 2`. `bump` is static: `v` persists and reaches 6 on the third call. `bump_a` is automatic: `v` starts at 0 on every call.

**P4.**

```systemverilog
module p4;
  int a = 1;
  initial begin
    a <= a + 1;
    a  = a + 10;
    $display("%0d", a);
    $strobe ("%0d", a);
  end
endmodule
```

Answer: `11` then `2`. The nonblocking statement evaluates `a + 1` = 2 immediately and saves it. The blocking statement makes `a` 11, which `$display` prints. In the NBA region `a` becomes 2, which `$strobe` prints at the end of the time step. (Mixing the two assignment types on one variable is bad practice; the question tests the scheduling.)

**P5.**

```systemverilog
module p5;
  logic clk = 0;
  always #5 clk = ~clk;
  task automatic t(int n);
    repeat (n) @(posedge clk);
    #2;
  endtask
  initial begin
    #7;
    t(2);  $display("%0t", $time);
    t(1);  $display("%0t", $time);
    $finish;
  end
endmodule
```

Answer: `27` then `37`. Rising edges are at 5, 15, 25, 35. From time 7 the next two edges are 15 and 25; plus 2 gives 27. From 27 the next edge is 35; plus 2 gives 37.

**P6.**

```systemverilog
module p6;
  function automatic int f(int a = 1, int b = 2, int c = 3);
    return a * 100 + b * 10 + c;
  endfunction
  initial $display("%0d %0d %0d %0d", f(), f(5), f(, 7), f(.c(9), .a(4)));
endmodule
```

Answer: `123 523 173 429`.

**P7.**

```systemverilog
module p7;
  function automatic void f1(int q[$]);      q.push_back(9); endfunction
  function automatic void f2(ref int q[$]);  q.push_back(9); endfunction
  int q[$] = {1, 2};
  initial begin
    f1(q);  $display("%0d", q.size());
    f2(q);  $display("%0d", q.size());
  end
endmodule
```

Answer: `2` then `3`. `f1` appends to a copy. `f2` appends to the caller's queue.

**P8.**

```systemverilog
module p8;
  task automatic p(int n);
    if (n == 0) return;
    $write("%0d ", n);
    p(n - 1);
    $write("%0d ", n);
  endtask
  initial begin
    p(3);
    $display("");
  end
endmodule
```

Answer: `3 2 1 1 2 3`. Each level prints its `n`, recurses, and prints its own `n` again on the way back. Because the task is automatic, each level still has its own `n` after the nested call returns.

**P9.**

```systemverilog
module p9;
  task show(input int v);
    #1 $display("%0d", v);
  endtask
  initial fork
    show(1);
    show(2);
    show(3);
  join
endmodule
```

Answer: the same number three times; `3 3 3` on simulators that start the branches in source order. The task is static, so all three calls share `v`, and the last call to start overwrites it before any of them prints.

**P10.**

```systemverilog
module p10;
  function automatic void f();
    fork
      #5 $display("B %0t", $time);
    join_none
    $display("A %0t", $time);
  endfunction
  initial begin
    f();
    $display("C %0t", $time);
    #10 $display("D %0t", $time);
  end
endmodule
```

Answer: `A 0`, `C 0`, `B 5`, `D 10`. The function returns in zero time; the forked statement runs in the background.

**P11.**

```systemverilog
module p11;
  int v;
  task automatic t(output int o);
    o = 1;
    #10;
    o = 2;
  endtask
  initial begin
    fork
      t(v);
    join_none
    #5  $display("%0d", v);
    #10 $display("%0d", v);
  end
endmodule
```

Answer: `0` then `2`. At time 5 the task is still running, and an output argument is copied back only at the return (time 10). The value 1 is never seen by the caller.

**P12.**

```systemverilog
module p12;
  int x;
  function automatic int twice(int v);
    x = x + 1;
    return 2 * v;
  endfunction
  initial begin
    x = 10;
    x = twice(x) + twice(x);
    $display("%0d", x);
  end
endmodule
```

Answer: `42` if the operands are evaluated left to right, which is what simulators do: the first call receives 10, sets `x` to 11 and returns 20; the second receives 11, sets `x` to 12 and returns 22; the sum 42 is then assigned to `x`. The standard does not fix the evaluation order of operands, so a function with side effects on a variable used in the same expression is a bug to avoid, not a feature to rely on.

## 6.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
function automatic int delayed_add(int a, int b);
  #1;
  return a + b;
endfunction
```

A delay in a function. Remove the delay, or make it a task with an `output` argument.

**E2.**

```systemverilog
task automatic log_it(string s);
  $display("%s", s);
endtask
function automatic int f(int a);
  log_it("in f");
  return a;
endfunction
```

A function calling a task. Declare `log_it` as `function automatic void`.

**E3.**

```systemverilog
module m;
  task incr(ref int x);
    x++;
  endtask
endmodule
```

`ref` in a static task. Write `task automatic incr(ref int x);`.

**E4.**

```systemverilog
task automatic incr(ref int x);
  x++;
endtask
int a;
initial begin
  incr(5);
  incr(a + 1);
end
```

A `ref` actual must be a variable. A constant and an expression cannot be passed by reference. Call `incr(a);`.

**E5.**

```systemverilog
task automatic t();
  int x;
  x <= 1;
endtask
```

A nonblocking assignment to an automatic variable. Use `x = 1;`.

**E6.**

```systemverilog
task automatic get_val(output int v);
  v = 42;
endtask
int y;
initial y = get_val(y);
```

A task used in an expression. Call it as a statement: `get_val(y);`.

**E7.**

```systemverilog
function automatic void f();
  return 1;
endfunction
task automatic t();
  return 5;
endtask
```

A void function and a task cannot return a value. Use `return;`, or give the function a return type.

**E8.**

```systemverilog
function automatic void reset_all(const ref int arr[]);
  foreach (arr[i]) arr[i] = 0;
endfunction
```

Assignment to a `const ref` argument. Remove `const`.

**E9.**

```systemverilog
function automatic void incr(ref int x);
  x++;
endfunction
bit [7:0] b;
wire [31:0] w;
initial begin
  incr(b);
  incr(w);
end
```

Two errors. The type of a `ref` actual must match the formal exactly (`bit [7:0]` is not `int`), and a net cannot be passed by reference.

**E10.**

```systemverilog
function automatic int f(int a, int b = 2, int c);
  return a + b + c;
endfunction
initial $display("%0d", f(1));
```

`c` has no default and is not supplied. Call `f(1, , 3)` or give `c` a default.

**E11.**

```systemverilog
function automatic void scale(ref int arr[], int factor);
  foreach (arr[i]) arr[i] *= factor;
endfunction
int d[] = '{1, 2, 3};
initial scale(d, 10);
```

`factor` inherits `ref` from the previous argument, so the literal 10 cannot be passed. Declare it `input int factor`.

**E12.**

```systemverilog
class c;
  function new();
    @(posedge tb.clk);
  endfunction
endclass
```

The constructor is a function and cannot contain an event control. Move the wait into a task of the class.

### Run-time bugs (the code compiles)

**D1.**

```systemverilog
task write(input bit [7:0] addr, input bit [7:0] data);
  @(posedge clk);
  bus_addr <= addr;
  bus_data <= data;
endtask
initial fork
  write(8'h10, 8'hAA);
  write(8'h20, 8'hBB);
join
```

The task is static. The second call overwrites `addr` and `data` while the first is waiting for the clock, so one transfer is lost. Declare the task `automatic`, and add a semaphore so that the two transfers do not use the bus in the same cycle.

**D2.**

```systemverilog
task automatic wait_flag(input bit flag);
  wait (flag);
endtask
```

Hangs if `flag` is 0 at the call: the task waits on a private copy. Use `ref bit flag`.

**D3.**

```systemverilog
task automatic ramp(output logic [7:0] level);
  for (int i = 0; i < 8; i++) begin
    @(posedge clk);
    level = i;
  end
endtask
initial ramp(dut_level);
```

`dut_level` does not ramp. It is written once, with the final value 7, when the task returns. Use a `ref` argument, or assign the signal directly.

**D4.**

```systemverilog
always begin
  if (en) count++;
end
```

No timing control: a zero-delay infinite loop at time 0. Add `@(posedge clk)`.

**D5.**

```systemverilog
task check_burst();
  int errors = 0;
  // ... counts errors in this burst ...
  if (errors > 0) $display("%0d errors in burst", errors);
endtask
```

In a static task `errors` is initialised once, so the count accumulates over all bursts. (Strict tools also reject the declaration because the lifetime keyword is missing.) Declare the task `automatic`.

**D6.**

```systemverilog
function automatic checksum(bit [7:0] d[]);
  int s;
  s = 0;
  foreach (d[i]) s += d[i];
  return s;
endfunction
```

No return type: the checksum is truncated to one bit. Declare `function automatic int checksum(...)`. The array should also be `const ref`.

**D7.**

```systemverilog
function int depth(int n);
  if (n <= 1) return 0;
  return 1 + depth(n / 2);
endfunction
```

A recursive function without `automatic`. The result may be wrong and tools warn. Add `automatic`.

**D8.**

```systemverilog
task automatic drive(input logic [7:0] a, input logic [7:0] b);
  @(posedge clk);
  a = a;
  b = b;
endtask
```

The arguments have the same names as the signals the task should drive, so the assignments copy each argument to itself and the signals never change. Rename the arguments (`a_i`, `b_i`) or drive through a hierarchical or interface reference.

**D9.**

```systemverilog
task automatic wait_done();
  @(posedge done);
endtask
```

If `done` is already high when the task is called, the task waits for the next rising edge, possibly for ever. Use `wait (done);`.

**D10.**

```systemverilog
task automatic send(input logic [7:0] d);
  @(posedge clk);
  data  = d;
  valid = 1;
endtask
```

Blocking assignments at the active clock edge race with the DUT, which samples on the same edge. Use nonblocking assignments, drive on the opposite edge, or use a clocking block.

## 6.5 Coding Exercises with Solutions

### Exercise 1: reverse the bits of a byte

Write a function that returns its 8-bit argument with the bit order reversed.

```systemverilog file=ex01_reverse_bits.sv
module ex01_reverse_bits;

  function automatic bit [7:0] reverse8(bit [7:0] d);
    bit [7:0] r;
    for (int i = 0; i < 8; i++) r[i] = d[7 - i];
    return r;
  endfunction

  initial begin
    $display("%b -> %b", 8'b1011_0001, reverse8(8'b1011_0001));
    $display("%b -> %b", 8'b0000_0001, reverse8(8'b0000_0001));
  end

endmodule
```

```output
10110001 -> 10001101
00000001 -> 10000000
```

### Exercise 2: ceiling of log2

Write a function that returns the number of address bits needed for a memory of `n` locations (the ceiling of log2 `n`), without using `$clog2`.

```systemverilog file=ex02_clog2.sv
module ex02_clog2;

  function automatic int clog2(int unsigned n);
    int r;
    r = 0;
    while ((1 << r) < n) r++;
    return r;
  endfunction

  initial begin
    $display("clog2(1)=%0d clog2(2)=%0d clog2(16)=%0d clog2(17)=%0d clog2(1000)=%0d",
             clog2(1), clog2(2), clog2(16), clog2(17), clog2(1000));
  end

endmodule
```

```output
clog2(1)=0 clog2(2)=1 clog2(16)=4 clog2(17)=5 clog2(1000)=10
```

The loop finds the smallest `r` for which 2^r is at least `n`. The function has no side effects and its result depends only on its argument, so it could also be used to compute a `localparam`.

### Exercise 3: swap two variables

Write a task that swaps the values of two `int` variables of the caller.

```systemverilog file=ex03_swap.sv
module ex03_swap;

  task automatic swap(ref int x, ref int y);
    int tmp;
    tmp = x;
    x   = y;
    y   = tmp;
  endtask

  int a, b;

  initial begin
    a = 3;
    b = 7;
    swap(a, b);
    $display("a=%0d b=%0d", a, b);
  end

endmodule
```

```output
a=7 b=3
```

`inout` arguments would also work here. `input` arguments would not: the task would swap its own copies. Because nothing in it consumes time, `swap` would be better declared as a void function; it is written as a task to show that `ref` works in both.

### Exercise 4: several results from one function

Write a function that computes the minimum, maximum and average of an array of any size, without copying the array.

```systemverilog file=ex04_array_stats.sv
module ex04_array_stats;

  function automatic void stats(const ref int arr[],
                                output    int lo,
                                output    int hi,
                                output    real avg);
    int sum;
    lo  = arr[0];
    hi  = arr[0];
    sum = 0;
    foreach (arr[i]) begin
      if (arr[i] < lo) lo = arr[i];
      if (arr[i] > hi) hi = arr[i];
      sum += arr[i];
    end
    avg = real'(sum) / arr.size();
  endfunction

  int  values[] = '{4, 9, 2, 7};
  int  lo, hi;
  real avg;

  initial begin
    stats(values, lo, hi, avg);
    $display("min=%0d max=%0d avg=%0.2f", lo, hi, avg);
  end

endmodule
```

```output
min=2 max=9 avg=5.50
```

`const ref` avoids the copy. Each `output` has its direction written explicitly; otherwise the arguments after `arr` would inherit `const ref`. The cast `real'(sum)` forces a real division (Module 1, Section 2.7): 22 / 4 as integers would give 5.

### Exercise 5: recursive palindrome check

Write a recursive function that reports whether a string reads the same forwards and backwards.

```systemverilog file=ex05_palindrome.sv
module ex05_palindrome;

  function automatic bit is_pal_range(string s, int lo, int hi);
    if (lo >= hi)       return 1;                 // base case: 0 or 1 characters left
    if (s[lo] != s[hi]) return 0;                 // base case: mismatch
    return is_pal_range(s, lo + 1, hi - 1);       // recursive case: the inner part
  endfunction

  function automatic bit is_palindrome(string s);
    return is_pal_range(s, 0, s.len() - 1);
  endfunction

  initial begin
    $display("level -> %b", is_palindrome("level"));
    $display("hello -> %b", is_palindrome("hello"));
    $display("noon  -> %b", is_palindrome("noon"));
  end

endmodule
```

```output
level -> 1
hello -> 0
noon  -> 1
```

The recursion has two base cases and moves both indices towards the middle on each call. `s[i]` is the i-th character of the string as a byte, and `s.len()` is the number of characters.

### Exercise 6: a unique-ID generator

Write a function that returns 0, 1, 2... on successive calls, without using a module-level variable.

```systemverilog file=ex06_next_id.sv
module ex06_next_id;

  function automatic int unsigned next_id();
    static int unsigned id = 0;     // one copy, initialised once
    id++;
    return id - 1;
  endfunction

  initial begin
    $display("%0d", next_id());
    $display("%0d", next_id());
    $display("%0d", next_id());
  end

endmodule
```

```output
0
1
2
```

A deliberate use of a static variable inside an automatic function. The function increments the stored value and returns the value it had before. Each `$display` contains one call, so the order of the calls is certain.

### Exercise 7: serial send and receive tasks

Write a task `send_serial` that sends a byte one bit per clock (LSB first) on `sdata`, with `svalid` high while the bits are valid, and a task `recv_serial` that receives it. Run them in parallel and check that the byte arrives.

```systemverilog file=ex07_serial.sv
module ex07_serial;

  logic clk    = 0;
  logic sdata  = 0;
  logic svalid = 0;

  always #5 clk = ~clk;

  task automatic send_serial(input bit [7:0] data);
    for (int i = 0; i < 8; i++) begin
      @(negedge clk);              // drive on the falling edge
      svalid = 1'b1;
      sdata  = data[i];
    end
    @(negedge clk);
    svalid = 1'b0;
  endtask

  task automatic recv_serial(output bit [7:0] data);
    int i;
    i = 0;
    while (i < 8) begin
      @(posedge clk);              // sample on the rising edge
      if (svalid) begin
        data[i] = sdata;
        i++;
      end
    end
  endtask

  bit [7:0] rx;

  initial begin
    fork
      send_serial(8'hA5);
      recv_serial(rx);
    join
    $display("[%0t] sent a5, received %h", $time, rx);
    $finish;
  end

endmodule
```

```output
[90] sent a5, received a5
```

The sender drives the eight bits at the falling edges 10, 20, ... 80 and removes `svalid` at 90. The receiver samples at the rising edges 15, 25, ... 85, each in the middle of a bit, and returns at 85; its `output` argument is copied to `rx` at that moment. The `fork`...`join` ends when both tasks have returned, at 90. Driving and sampling on opposite edges avoids any race between the two tasks. The receiver first samples at time 5, sees `svalid` = 0 and ignores that edge.

### Exercise 8: recursive conversion to a binary string

Write a recursive function that converts an unsigned number to a string of binary digits with no leading zeros.

```systemverilog file=ex08_to_bin.sv
module ex08_to_bin;

  function automatic string to_bin(int unsigned n);
    string digit;
    digit = (n % 2) ? "1" : "0";
    if (n < 2) return digit;                  // base case: a single digit
    return {to_bin(n / 2), digit};            // higher digits first, then this one
  endfunction

  initial begin
    $display("0   -> %s", to_bin(0));
    $display("10  -> %s", to_bin(10));
    $display("255 -> %s", to_bin(255));
  end

endmodule
```

```output
0   -> 0
10  -> 1010
255 -> 11111111
```

`{a, b}` with string operands concatenates strings. Each level contributes its own least significant digit after the digits produced by the deeper levels.

### Further practice (no solutions given)

1. Write `function automatic int count_ones(const ref bit [7:0] bytes[]);` that returns the total number of 1 bits in an array of bytes.
2. Write a task `pulse(ref logic sig, input int cycles = 1)` that sets `sig` high for the given number of clock cycles and then low. Explain why `output` would not work.
3. Rewrite `fib` without recursion and compare the number of iterations with the number of recursive calls for `n` = 20.
4. Extend `tb_alu_tasks` with the three operations that are not exercised (`ALU_OR`, `ALU_XOR`, `ALU_SHR`) and with a deliberately wrong expected value, and confirm that `check` reports the failure.
5. Write a function `alu_op_e random_op()` that returns a random opcode using `$urandom_range` and a cast. Which kind of cast is appropriate, and why?
6. Write a recursive function `power(base, exp)` that uses at most about log2(`exp`) multiplications.
7. Predict, then run: a static task with a `for (int i = 0; i < 3; i++) #1;` loop and a message at the end printing an input argument, called from three `fork` branches with different arguments.
8. Take any task from this module that contains no timing control and convert it to a void function. Then call it from another function.

## 6.6 Concepts You Must Understand Before Moving Forward

**Procedural code**

- [ ] I can explain the difference between `initial`, `always` and `final`, and why an `always` block needs a timing control.
- [ ] I can explain blocking and nonblocking assignments and predict the result of a swap written each way.
- [ ] I can list the main event regions in order and say where `$display`, `$strobe` and nonblocking updates happen.
- [ ] I know what `#0` does and why it does not reveal a nonblocking update.
- [ ] I can explain the difference between `@(posedge sig)` and `wait (sig)`.

**Functions and tasks**

- [ ] I can state at least four differences between a function and a task, starting with time.
- [ ] I can explain why a function cannot consume time, using expressions as the reason.
- [ ] I know the default return type of a function and the three ways a result is produced.
- [ ] I know when to use a void function instead of a task.
- [ ] I know who can call whom: function → function, task → both, function → task never (except `fork`...`join_none`).

**Arguments**

- [ ] I can describe copy-in and copy-out for `input`, `output` and `inout`.
- [ ] I know that an `output` formal starts at the type's default and is copied back only at the return.
- [ ] I can explain `ref` and `const ref`, their restrictions, and when each is needed.
- [ ] I can explain what happens when an array, a struct and a class handle are passed as `input`.
- [ ] I can use default values, empty positions and named binding.
- [ ] I know how direction and type are inherited by following arguments.

**Lifetime and recursion**

- [ ] I know the default lifetime in modules, packages and classes.
- [ ] I can reproduce and explain the shared-variable bug of a static task called from two threads.
- [ ] I know the explicit-keyword rule for initialised variables in static contexts.
- [ ] I can write a recursive function with a base case and explain why it must be automatic.

**Classes (preview)**

- [ ] I know that methods are functions and tasks with automatic lifetime, and that `new` is a function.
- [ ] For each component of the layered testbench I can say which methods are tasks and which are functions.

## 6.7 What Comes Next

Module 4 covers classes and object-oriented programming: declaring classes, creating objects with `new`, handles and null handles, `this`, static properties and methods, access control, shallow and deep copy, inheritance, `super`, virtual methods, polymorphism, abstract classes and `$cast` between handles. The functions and tasks of this module become the methods of those classes, with the argument-passing and lifetime rules unchanged. The `alu_txn` class previewed in Section 5.4 is developed there in full.
