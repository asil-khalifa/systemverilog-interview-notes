# Intermediate Questions

These questions test whether you understand behaviour and can compare related features. Most answers include a small code fragment, because that is how you should answer them in an interview.

## Procedural Code and Arrays

**Q56. What is the difference between blocking and nonblocking assignment?**
A blocking assignment (`=`) evaluates the right-hand side and updates the left-hand side immediately, before the next statement runs. A nonblocking assignment (`<=`) evaluates the right-hand side immediately but schedules the update for the NBA region at the end of the time step, so every nonblocking assignment in the same time step sees the old values.

```systemverilog
a = b;  b = a;      // both end up with the old value of b
a <= b; b <= a;     // the values are swapped
```

Use nonblocking assignments for sequential logic (`always_ff`) and blocking assignments for combinational logic (`always_comb`) and for testbench variables. Never assign the same variable with both kinds.

**Q57. Compare the four unpacked array types and say when you would use each.**

| Property | Fixed-size | Dynamic | Associative | Queue |
|---|---|---|---|---|
| Declaration | `int a [8];` | `int d [];` | `int aa [string];` | `int q [$];` |
| Size | Fixed at compile time | Set with `new[]` at run time | Grows as entries are written | Grows and shrinks with push/pop |
| Index | 0..N-1, contiguous | 0..N-1, contiguous | Any type, sparse | 0..N-1, contiguous |
| Memory | All elements allocated | All elements allocated | Only written entries | Current elements |
| Insert/delete in the middle | No | Only by reallocating | Yes, by key | Yes |
| Typical use | Known-size data, RTL memories | Payload whose length is random per packet | Sparse memory model, lookup by ID or name | Expected-transaction list in a scoreboard, FIFO model |

**Q58. What does `b = a;` do when `a` and `b` are dynamic arrays?**
It copies all the elements. `b` is resized to the size of `a` and receives its own copy of the data, so a later change to `a[0]` does not affect `b[0]`. The same is true for queues and associative arrays. Arrays are not handles.

**Q59. What does `b = a;` do when `a` and `b` are arrays of class handles?**
The array is copied, but each element is a handle, so only the handles are copied. `a[0]` and `b[0]` refer to the same object. To get independent objects, each element must be copied: `foreach (a[i]) b[i] = a[i].copy();`.

**Q60. How do you delete elements from a queue while looping over it?**
Deleting inside a forward `foreach` shifts the following elements down, so the element after each deleted one is skipped. Loop backwards, or build the result with a locator method:

```systemverilog
for (int i = q.size() - 1; i >= 0; i--)
  if (q[i] % 2 == 0) q.delete(i);          // safe: indices below i are unaffected

q = q.find with (item % 2 != 0);            // alternative: keep only the odd values
```

**Q61. How do the array locator methods use the `with` clause?**
The `with` clause is an expression evaluated for each element; `item` is the element and `item.index` is its index. The method returns the elements (or indices) for which the expression is true.

```systemverilog
int q [$] = '{3, 8, 1, 8, 5};
int r [$];
r = q.find with (item > 4);                 // {8, 8, 5}
r = q.find_first_index with (item == 8);    // {1}
r = q.find_index with (item.index % 2 == 0);// {0, 2, 4}
r = q.find_last with (item < 5);            // {1}
```

`find`, `find_index`, `find_first` and the other `find_` methods require a `with` clause. `min`, `max`, `unique`, `sum`, `sort` accept one optionally.

**Q62. An array is declared `bit [7:0] b [4]` and holds 200, 100, 50, 10. What does `b.sum()` return, and how do you get 360?**
104. `sum()` returns a value of the element type, here 8 bits, so 360 wraps to 360 - 256 = 104. Widen each element in a `with` clause: `b.sum() with (int'(item))` returns 360. The same trap applies to `product()` and to counting matches: `b.sum() with (int'(item > 60))` counts the elements greater than 60 (without the cast the count is 1 bit wide).

**Q63. How do you sort a queue of transaction objects by one field?**
With the `with` clause of `sort` or `rsort`: `txn_q.sort() with (item.id);` sorts in ascending order of `id`; `rsort` gives descending order. Several keys can be combined with a concatenation: `sort() with ({item.op, item.a})`.

**Q64. How do you iterate over an associative array?**
With `foreach`, or with `first()` and `next()`, which take the index variable by reference and return 0 when there is no (further) entry:

```systemverilog
int    score [string];
string name;
if (score.first(name))
  do $display("%s = %0d", name, score[name]);
  while (score.next(name));
```

Entries are visited in ascending index order (numeric order for integral indices, lexical order for strings). `last()` and `prev()` iterate backwards.

## Tasks and Functions

**Q65. What is the difference between `ref` and `const ref`, and why does `ref` need an automatic routine?**
A `ref` argument is a reference to the caller's variable: reads and writes act on the original. `const ref` passes the reference but forbids writing, which gives the speed of no copying with the safety of an input. A `ref` argument is allowed only in a routine with automatic lifetime (a class method, or a task or function declared `automatic`), because a static routine has one permanent copy of its arguments and could keep a reference to a variable that no longer exists.

**Q66. Two threads call the same task at the same time and the results are corrupted. What is the likely cause?**
The task is static (the default in a module, interface or package), so both calls share one copy of the arguments and local variables. The second call overwrites the arguments of the first while it is waiting at a delay. Declaring the task `automatic` gives each call its own storage.

```systemverilog
task automatic send(input int id, input int delay);
  #delay $display("[%0t] id=%0d", $time, id);
endtask
```

**Q67. Can a function call a task? Can a function consume time?**
No to both. A function must return in zero time, so it may not contain `#`, `@`, `wait`, or a call to a task (which might contain them). The one exception: a function may start a time-consuming thread with `fork`...`join_none`, because the function itself still returns immediately.

**Q68. In what ways can a function return a value?**
(1) `return expr;`. (2) By assigning to the function name: `my_func = expr;` (the Verilog style). (3) Through `output`, `inout` or `ref` arguments, which is how a function returns more than one value. If no value is assigned, the function returns the default of its return type.

## Classes

**Q69. What is the difference between a shallow copy and a deep copy?**
A shallow copy, `b = new a;`, creates a new object and copies every property of `a` into it. Properties that are handles are copied as handles, so the nested objects are shared between `a` and `b`. A deep copy also creates new copies of the nested objects, so nothing is shared. A deep copy must be written by hand in a `copy()` method:

```systemverilog
function alu_pkt copy();
  alu_pkt c = new();
  c.len = this.len;            // plain property: copy the value
  c.hdr = this.hdr.copy();     // handle property: copy the object it refers to
  return c;
endfunction
```

**Q70. What is the difference between `b = a;` and `b = new a;` for class handles? When is an object destroyed?**
`b = a;` copies the handle: there is still one object, now with two handles. `b = new a;` creates a second object (shallow copy). SystemVerilog has no `delete` for objects; an object's memory is reclaimed automatically when no handle refers to it any more, for example after `a = null; b = null;`.

**Q71. In what order do constructors run in an inheritance chain, and what is the rule for `super.new()`?**
The base-class constructor runs first, then the property initialisers of the derived class, then the body of the derived constructor. If the derived constructor calls `super.new(...)` explicitly, that call must be the first statement. If it does not, the compiler inserts `super.new()` with no arguments, which is an error if the base constructor has arguments without defaults.

**Q72. What are the rules for virtual methods?**
(1) Once a method is declared `virtual` in a class, it is virtual in all derived classes, whether or not they repeat the keyword. (2) An overriding method must have the same return type, argument types and argument count as the base method. (3) The call is resolved from the type of the object when made through a handle. (4) Constructors and static methods cannot be virtual. (5) Properties are never virtual.

**Q73. What is downcasting and why does it need `$cast`?**
Assigning a base-class handle to a derived-class handle. It is legal only if the object really is of the derived type (or a type derived from it), which is known only at run time, so a plain assignment is a compile error and `$cast` performs the check.

```systemverilog
base  b;
child c1 = new(), c2;
b = c1;                         // upcast: always legal, no cast needed
if (!$cast(c2, b)) $error("b does not refer to a child object");
```

**Q74. What is the difference between overriding and overloading? Does SystemVerilog support both?**
Overriding is redefining a base-class method in a derived class with the same name and signature. Overloading is having several methods with the same name but different argument lists in one scope. SystemVerilog supports overriding but not overloading: two methods with the same name in one class are an error. Default argument values give a similar convenience.

**Q75. What are the restrictions on a static method?**
It can be called without an object (`alu_txn::get_count()`), so it has no `this`. It can access only static properties and call only static methods of its class, and it cannot be virtual. Note the difference from `static task` in a module-level sense: `static function` in a class makes the method belong to the class, while `function static` would make its variables static.

**Q76. What is an `extern` method?**
A method whose prototype is declared inside the class with `extern` and whose body is written outside the class using the scope operator: `function void alu_txn::print(); ... endfunction`. It keeps the class declaration short and readable.

**Q77. What is a parameterised class?**
A class with parameters for values or types, so one definition serves many types: `class stack #(type T = int, int DEPTH = 8);`. Each distinct set of parameter values is a separate specialisation, a different type: `stack #(alu_txn) s;`. `mailbox #(T)` is a built-in example.

## Randomization and Constraints

**Q78. What is the difference between the implication operator and `if`-`else` in a constraint? Are they one-directional?**
`a -> b` means "if `a` is true then `b` must be true". `if (a) b; else c;` is the same as `(a -> b) && (!a -> c)`; the `else` gives a constraint for the false case as well. Neither is one-directional: constraints are relations solved together, so `a -> b` also means that if `b` is false then `a` must be false. With `mode == 1 -> len < 10`, a solution with `len == 20` forces `mode != 1`.

**Q79. What does `solve`...`before` do?**
It changes the order in which the solver picks values, and therefore the probability of each solution. It does not change which solutions are legal. In `constraint c { flag -> data == 0; solve flag before data; }` with a 1-bit `flag` and an 8-bit `data`, without the ordering `flag == 1` appears in only 1 of 257 solutions; with it, `flag` is chosen first and is 1 half of the time.

**Q80. How does a soft constraint get overridden?**
Any hard constraint that contradicts it wins, and the soft constraint is dropped without a failure. Among soft constraints, the one with higher priority wins: constraints in a `randomize() with {}` block have priority over those in the class, a derived class over its base class, and a later declaration over an earlier one. `disable soft x;` discards all lower-priority soft constraints on `x`.

**Q81. What does the `unique` constraint do?**
It forces a group of variables or all elements of an array to have different values: `constraint u_c { unique {arr}; }` or `unique {a, b, c};`. It replaces the nested `foreach` loops that were needed before IEEE 1800-2012.

**Q82. What is the difference between restricting a variable with `inside` and with `dist`?**
`inside` only defines the legal set; all values in it are equally likely (subject to other constraints). `dist` defines the legal set and a weight for each value or range, so some values are generated more often. A value with weight 0 or not listed in the `dist` is never generated. `dist` cannot be applied to a `randc` variable.

**Q83. What is `randomize() with` and what is `local::` for?**
`randomize() with { ... }` adds constraints for one call only, on top of the class constraints: `t.randomize() with { a < 10; op == ALU_ADD; }`. Names inside the braces are looked up in the object first. If a variable in the calling scope has the same name as a property, `local::` selects the one from the calling scope: `t.randomize() with { a == local::a; }`.

**Q84. How do you constrain the size and the elements of a dynamic array?**
Constrain `size()` and use `foreach` for the elements. The solver chooses the size first and then solves the elements.

```systemverilog
rand bit [7:0] payload [];
constraint payload_c {
  payload.size() inside {[1:16]};
  foreach (payload[i]) payload[i] != 8'h00;
}
```

Always constrain the size; an unconstrained size can be huge or zero.

**Q85. How do you randomize a variable that is not a class property?**
With the scope randomize function, `std::randomize(x) with { x inside {[1:9]}; };`, which works on any variables visible at the call and returns 1 or 0 like the class method. For simple cases use `$urandom()` (32-bit unsigned) or `$urandom_range(max, min)`. Avoid `$random`: it is signed and its sequence is not tied to the thread's random stability.

**Q86. How do constraints behave under inheritance?**
A derived class inherits all constraint blocks of its base class. A constraint block in the derived class with a new name is added to them. A block with the **same name** as a base-class block replaces (overrides) it. This is how a test narrows or changes stimulus: extend the transaction, override or add a constraint, and make the generator create the extended class.

## Inter-Process Communication

**Q87. Compare mailbox, semaphore and event.**

| | Mailbox | Semaphore | Event |
|---|---|---|---|
| Purpose | Pass data between processes | Control access to a shared resource | Signal that something happened |
| Carries data | Yes | No (only a key count) | No |
| Blocking calls | `put` (if full), `get`, `peek` | `get` | `@e`, `wait(e.triggered)` |
| Remembers what happened | Yes, items are stored | Yes, keys are stored | No (only `triggered`, for the current time step) |
| Typical use | Generator → driver, monitor → scoreboard | Two generators sharing one driver | "Generator done", "reset finished" |

**Q88. What is the difference between `@e` and `wait (e.triggered)`?**
`@e` waits for the next trigger after the statement starts executing. If the trigger happens in the same time step but before the `@e` is reached, it is missed and the process may wait forever. `e.triggered` is true from the trigger until the end of that time step, so `wait (e.triggered)` passes whether the trigger came just before or comes later. Use `wait (e.triggered)` when the trigger and the wait can occur in the same time step. Do not put `wait (e.triggered)` in a zero-delay loop: it stays true for the whole time step and the loop never advances time.

**Q89. What is the difference between `disable fork`, `disable` with a block name, and `wait fork`?**
`disable fork;` kills all active threads that were spawned by the calling process (and their descendants). `disable block_name;` kills the named block wherever it is running, including in other instances of the same task. `wait fork;` kills nothing: it blocks the calling process until all the threads it spawned have finished. A typical pattern is `fork ... join_any` followed by `disable fork;` to implement a timeout.

**Q90. What is the difference between `->` and `->>`?**
`-> e` triggers the event immediately; processes already waiting on it become ready at once. `->> e` is the nonblocking trigger: the event is triggered in the NBA region of the current time step. It is used to avoid a race when the trigger and the `@e` are executed in the same time step in unknown order, because by the NBA region every process has reached its `@e`.

**Q91. What is the difference between a bounded and an unbounded mailbox, and between a parameterised and a generic one?**
`new()` creates an unbounded mailbox: `put()` never blocks. `new(n)` creates a bounded one holding at most `n` items: `put()` blocks when it is full, which throttles the producer. `mailbox #(alu_txn) m;` is parameterised: it accepts only that type and type errors are found at compile time. A plain `mailbox m;` is generic and accepts any type; a `get()` into a variable of the wrong type is a run-time error.

**Q92. What is wrong with starting threads in a loop like this, and how is it fixed?**

```systemverilog
for (int i = 0; i < 3; i++)
  fork
    $display("thread %0d", i);
  join_none
```

Threads started by `join_none` do not run until the parent blocks, which is after the loop has finished, and they all share the single variable `i`, which is then 3. All three print 3. Declare an automatic copy inside the `fork`, which is initialised when the thread is created:

```systemverilog
for (int i = 0; i < 3; i++)
  fork
    automatic int k = i;
    $display("thread %0d", k);
  join_none
```

**Q93. What happens if a process asks a semaphore for more keys than exist, or puts back keys it never took?**
`get(n)` blocks until `n` keys are available; if that never happens the process waits forever. `put(n)` simply adds `n` keys, even if this makes the count larger than the number the semaphore was created with. The semaphore does not track ownership, so a missing `put()` (deadlock) or an extra `put()` (two users at once) are bugs the language will not catch.

## Interfaces and the Testbench

**Q94. Why can a class not use an interface directly, and how does a virtual interface solve it?**
An interface instance is a static design element created at elaboration, like a module instance. A class object is created at run time. A class therefore cannot instantiate an interface or have ports. A virtual interface is a variable that holds a reference to an interface instance; the class declares it, the testbench top (static world) passes the instance in, and the class reads and drives signals through it.

**Q95. How does the virtual interface get from `tb_top` to the driver?**
`tb_top` instantiates `alu_if vif (clk);` and connects it to the DUT. It then passes the instance to the test, usually as a constructor argument: `test = new(vif);`. The test passes it to the environment, and the environment passes it to the driver and monitor, each storing it in its own `virtual alu_if vif;`. In UVM the same job is done by `uvm_config_db#(virtual alu_if)::set` in the top and `get` in the component.

**Q96. What are clocking block skews and what are the defaults?**
The input skew says how long before the clock event an input is sampled; the output skew says how long after the clock event an output is driven. The defaults are `input #1step` (sample the value the signal had just before the clock edge, in the Preponed region) and `output #0` (drive in the Re-NBA region of the clock's time step, after the DUT has sampled). They can be changed: `default input #2ns output #1ns;`.

**Q97. What is a program block and is it still used?**
A `program` is a testbench container whose code executes in the Reactive region, after the design has settled in the Active and NBA regions, which separates testbench and design activity. Simulation ends implicitly when all program blocks finish. Class-based testbenches and UVM normally do not use it; a module top with clocking blocks gives the same protection, and UVM guidance is to avoid program blocks.

**Q98. What is the difference between a driver and a monitor?**
The driver is active: it receives transactions, drives the DUT input signals and follows the protocol timing. The monitor is passive: it never drives anything; it samples the signals (inputs and outputs), rebuilds transactions and sends them to the scoreboard and coverage. The scoreboard must take its data from the monitor, not from the generator or driver, so that what is checked is what really appeared on the pins.

## Coverage and Assertions

**Q99. What is the difference between `ignore_bins` and `illegal_bins`?**
Both remove values from coverage. Values in `ignore_bins` are simply not counted and not required. Values in `illegal_bins` are also excluded, and in addition the simulator reports a run-time error if one of them is sampled. Use `ignore_bins` for cases that are not interesting, `illegal_bins` for cases that must never occur (though an assertion is the better place for such a check).

**Q100. How many automatic bins does a coverpoint get?**
If a coverpoint has no bins, one bin is created per value, up to `option.auto_bin_max`, whose default is 64. A coverpoint on a 4-bit variable gets 16 bins; a coverpoint on a 16-bit variable gets 64 bins, each covering 1024 values. A coverpoint on an enum gets one bin per named value.

**Q101. What is cross coverage and what is `binsof`?**
A cross counts the combinations of the bins of several coverpoints: `cross cp_op, cp_a_range;` with 8 and 3 bins has 24 cross bins. `binsof` selects bins of a coverpoint inside the cross in order to group or exclude combinations:

```systemverilog
cx: cross cp_op, cp_a {
  ignore_bins no_not = binsof(cp_op) intersect {ALU_NOT};
}
```

**Q102. Name some coverage options.**
`option.per_instance` (keep coverage separately per covergroup instance), `option.at_least` (hits needed to count a bin as covered, default 1), `option.auto_bin_max` (default 64), `option.weight`, `option.goal` (default 100), `option.comment`, `option.cross_auto_bin_max`. `type_option` holds the options that apply to the covergroup type as a whole, such as `type_option.merge_instances`.

**Q103. What are transition bins?**
Bins that count sequences of values on successive samples of a coverpoint: `bins start = (IDLE => FETCH);`, `bins loop3 = (EXEC [* 3]);` (three consecutive samples), `bins any = (IDLE => FETCH, EXEC);`. They are used to cover state-machine transitions and command sequences.

**Q104. What do `$rose`, `$fell`, `$stable`, `$changed` and `$past` do?**
They are sampled-value functions that compare the value of an expression at the current clock tick with its value at the previous tick. `$rose(x)` is true if the least significant bit of `x` changed to 1; `$fell(x)` if it changed to 0; `$stable(x)` if the whole value did not change; `$changed(x)` if it did. `$past(x, n)` returns the value `x` had `n` ticks earlier (default 1). All of them use values sampled just before the clock edge.

**Q105. What does `disable iff` do?**
It gives a condition, normally reset, under which the property is not checked: `assert property (@(posedge clk) disable iff (!rst_n) req |=> ack);`. While the condition is true, attempts in progress are abandoned and no failure is reported. The condition is asynchronous: it is not sampled on the clock.

**Q106. What is the difference between `assert`, `assume` and `cover`?**
`assert property` checks that the property holds and reports a failure if it does not. `assume property` states a condition on the environment: in simulation it is checked like an assertion, in formal verification it constrains the inputs. `cover property` does not check anything; it records that the described behaviour occurred at least once.

**Q107. What do the sequence operators `##n`, `[*n]`, `[->n]` and `[=n]` mean?**
`a ##2 b`: `b` is true two clock ticks after `a`. `a ##[1:3] b`: one to three ticks later. `a [*3]`: `a` true on three consecutive ticks. `a [->3]` (goto repetition): `a` true three times, not necessarily consecutively, the match ending at the third occurrence. `a [=3]` (non-consecutive repetition): `a` true three times, and the match may extend past the third occurrence while `a` stays false.

## Packages, DPI and UVM

**Q108. What is the difference between importing a package and using `` `include ``?**
`` `include `` pastes the text of a file at that point; the included declarations belong to whatever scope contains the directive, and including the same class file in two packages creates two different, incompatible types. A package is compiled once and defines one set of types that every importer shares. The usual practice is to `` `include `` the class files inside one package and `import` that package everywhere.

**Q109. What is DPI?**
The Direct Programming Interface: a way to call C functions from SystemVerilog and SystemVerilog functions and tasks from C without the complexity of PLI/VPI. `import "DPI-C" function int c_model(input int a);` makes a C function callable; `export "DPI-C" function sv_func;` makes a SystemVerilog function callable from C. It is used for reference models written in C or C++.

**Q110. How do the main UVM mechanisms map to plain SystemVerilog?**

| UVM | What it is built from |
|---|---|
| `uvm_component`, `uvm_object` | Base classes; your classes extend them (inheritance) |
| Factory (`type_id::create`, overrides) | Polymorphism: a base handle receives an object of a derived class chosen at run time |
| Phases (`build_phase`, `run_phase`...) | Virtual methods called in a fixed order by the library; `run_phase` tasks are forked in parallel |
| `uvm_config_db` | An associative-array database, used mainly to pass virtual interfaces and settings |
| Sequence → sequencer → driver | Generator → mailbox → driver, with a handshake (`get_next_item`, `item_done`) |
| TLM ports and analysis ports | Method calls between components, replacing direct mailbox handles |
| Objections | A counter that decides when the test ends, replacing the `gen_done` event |
| `uvm_agent` | Driver, monitor and sequencer for one interface, grouped for reuse |
