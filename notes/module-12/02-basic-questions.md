# Basic Questions

These are the questions asked in the first minutes of an interview to check that you know the vocabulary. The answers are deliberately short: say this much, then stop and let the interviewer ask for more.

## Language and Data Types

**Q1. What is functional verification and why is it needed?**
Functional verification is the process of proving, by simulation and other methods before manufacturing, that the RTL design behaves as its specification says. It is needed because a bug found in silicon costs a new mask set and months of delay, and because the number of possible input scenarios is far too large to be checked by inspection.

**Q2. What is the difference between the DUT and the testbench?**
The DUT (design under test) is the synthesizable RTL that will become hardware. The testbench is simulation-only code that generates stimulus for the DUT, observes its outputs and checks them. The testbench is never synthesized, so it may use the whole language.

**Q3. Which built-in types are two-state and which are four-state, and where do you use each?**
Two-state (0, 1): `bit`, `byte`, `shortint`, `int`, `longint`. Four-state (0, 1, X, Z): `logic`, `reg`, `integer`, `time` and all nets such as `wire`. Four-state types are used for anything connected to the DUT so that X and Z stay visible; two-state types are used for testbench data such as random fields, counters and indices because they are faster and never need X or Z. `reg` and `logic` are the same type; `wire` is a net, required when a signal has several drivers.

**Q4. Why can a `logic` signal not be used for a bidirectional bus?**
`logic` declares a variable, and a variable may have only one driver. A bidirectional bus has several drivers that take turns, so it needs a net such as `wire`, whose value is resolved from all its drivers.

## Arrays

**Q5. What is the difference between a fixed-size array and a dynamic array?**
The size of a fixed-size (static) array is given in the declaration and never changes: `int a [8];`. The size of a dynamic array is set at run time with `new[]` and can be changed later: `int d []; d = new[8];`.

**Q6. What is a queue?**
A variable-size ordered list declared with `[$]`, for example `int q [$];`. Elements can be added and removed at both ends in constant time and anywhere in the middle. It grows and shrinks automatically.

**Q7. What is an associative array and when is it used?**
An array whose index can be of any type (integer, string, enum, class handle) and which allocates storage only for the entries that are written: `int mem [bit [31:0]];`. It is used for sparse data such as a memory model with a large address space, and as a lookup table keyed by a string or an ID.

**Q8. How do you allocate a dynamic array and how do you resize it while keeping the contents?**
`d = new[10];` allocates ten elements with default values. `d = new[20](d);` allocates twenty elements and copies the old ten into the first ten positions. `d.delete();` empties the array.

**Q9. Name the queue methods.**
`size()`, `insert(index, item)`, `delete()` (all elements) or `delete(index)`, `push_back(item)`, `push_front(item)`, `pop_back()`, `pop_front()`. The array manipulation methods (`find`, `sort`, `sum` and so on) also work on queues.

**Q10. What do `exists()`, `num()` and `delete()` do on an associative array?**
`exists(key)` returns 1 if an entry with that key is present. `num()` (or `size()`) returns the number of entries. `delete(key)` removes one entry and `delete()` removes all entries.

**Q11. What is `foreach`?**
A loop that visits every element of an array and declares the loop index automatically: `foreach (a[i]) a[i] = i;`. It works on all array types, in index order, and for an associative array it visits only the entries that exist.

**Q12. What do the array locator methods return?**
A queue. `find()`, `find_first()`, `find_last()`, `min()`, `max()` and `unique()` return a queue of elements; `find_index()`, `find_first_index()`, `find_last_index()` and `unique_index()` return a queue of indices. Even the methods that find at most one item return a queue (with zero or one element).

## Tasks and Functions

**Q13. What is the difference between a function and a task?**
A function executes in zero simulation time, cannot contain delays or event controls, and can return a value, so it can be used inside an expression. A task may consume simulation time, has no return value (it passes results back through `output`, `inout` or `ref` arguments), and is called as a statement. A task can call functions and tasks; a function can call only functions.

**Q14. What is a void function?**
A function declared with return type `void`. It returns nothing and is called as a statement, like a task, but it is still not allowed to consume time. To discard the return value of a non-void function, write `void'(f());`.

**Q15. What is the difference between `automatic` and `static` lifetime?**
A static task or function has one copy of its arguments and local variables, shared by every call. An automatic task or function allocates new storage for each call, so it is re-entrant and can be recursive. Tasks and functions in modules, interfaces and packages are static by default; methods of a class are always automatic.

**Q16. What is the difference between passing an argument by value and by reference?**
By value (`input`, `output`, `inout`) the argument is copied into the routine at the call and, for `output` and `inout`, copied back when the routine returns. By reference (`ref`) no copy is made: the routine works directly on the caller's variable, so changes are visible immediately and large arrays are not copied.

**Q17. What are default argument values?**
Values written in the declaration that are used when the caller omits the argument: `task send(int n = 1, bit verbose = 0);`. The call `send();` uses 1 and 0. Arguments can also be passed by name: `send(.verbose(1));`.

## Classes and OOP

**Q18. What is the difference between a class, an object and a handle?**
A class is a type: a description of properties (data) and methods (tasks and functions). An object is an instance of the class, created at run time with `new`. A handle is a variable that refers to an object. Declaring `alu_txn t;` creates only a handle with the value `null`; `t = new();` creates the object.

**Q19. What does `new()` do?**
It allocates memory for an object, initialises the properties to their default or declared values, runs the constructor function `new` of the class (after the constructors of its base classes), and returns a handle to the object.

**Q20. What is a null handle and what happens if you use one?**
A handle that does not refer to any object; `null` is the default value of every class handle. Accessing a non-static property or calling a non-static method through a null handle is a fatal run-time error (null object access).

**Q21. What is `this`?**
A predefined handle, available inside non-static class methods, that refers to the object on which the method was called. It is most often used when an argument has the same name as a property: `this.addr = addr;`.

**Q22. What is `super`?**
A keyword used inside a derived class to refer to the members of its base class, for example `super.new()` to call the base constructor or `super.print()` to call the base version of an overridden method.

**Q23. What is a static property?**
A class property declared with `static`. There is one copy shared by all objects of the class, it exists even when no object has been created, and it can be accessed with the class name: `alu_txn::count`. A typical use is counting objects or giving each one a unique ID.

**Q24. What is the difference between `local` and `protected`?**
A `local` member can be accessed only by the methods of the class that declares it. A `protected` member can also be accessed by the methods of derived classes. Neither can be accessed from outside. Members without a qualifier are public.

**Q25. What is inheritance?**
Creating a new class from an existing one with `extends`. The derived class gets all properties and methods of the base class and can add new ones or override existing ones. SystemVerilog allows only one base class per class.

**Q26. What is polymorphism?**
The ability of one base-class handle to refer to objects of different derived classes, with a call to a virtual method executing the version that belongs to the actual object. It lets testbench code be written once for the base type and work for every extension.

**Q27. What is a virtual method?**
A method declared with `virtual`. When it is called through a handle, the implementation is selected at run time from the type of the object, not the type of the handle. Without `virtual`, the type of the handle decides.

**Q28. What is an abstract class and a pure virtual method?**
An abstract class is declared `virtual class`. It cannot be constructed; it exists to be extended. A pure virtual method (`pure virtual function ...;`) is a prototype with no body inside an abstract class; every non-abstract derived class must implement it.

## Randomization

**Q29. What is the difference between `rand` and `randc`?**
A `rand` variable gets a value chosen uniformly from its legal values on every call, so values may repeat. A `randc` variable is random-cyclic: it does not repeat a value until every legal value has been used once, then a new cycle starts.

**Q30. What does `randomize()` return?**
1 if the solver found values that satisfy all active constraints and assigned them, 0 if it failed. On failure the variables keep their old values. The result must always be checked, for example `if (!t.randomize()) $fatal(1, "randomize failed");`.

**Q31. What is a constraint block?**
A named block inside a class that lists Boolean expressions which the random variables must satisfy: `constraint addr_c { addr inside {[0:99]}; addr % 4 == 0; }`. All expressions in all active blocks must be true at the same time.

**Q32. What does the `inside` operator do?**
It tests whether a value is a member of a set of values and ranges: `x inside {1, 3, [10:20]}`. In a constraint it restricts a variable to that set, each member being equally likely. `!(x inside {...})` excludes the set.

**Q33. In a `dist` constraint, what is the difference between `:=` and `:/`?**
`:=` gives the weight to every value in the range; `:/` divides the weight among the values in the range. In `x dist {[1:4] := 40, 5 := 60}` each of 1 to 4 has weight 40 (total 220); in `x dist {[1:4] :/ 40, 5 := 60}` each of 1 to 4 has weight 10 (total 100).

**Q34. What is a soft constraint?**
A constraint marked `soft`, which the solver satisfies if it can and silently drops if it conflicts with a hard (normal) constraint or a higher-priority soft constraint. It is used for default values that a test may override: `constraint len_c { soft len == 4; }`.

**Q35. What are `pre_randomize()` and `post_randomize()`?**
Built-in functions that `randomize()` calls automatically, before solving and after a successful solve. `pre_randomize()` is used to set up state or switch constraints; `post_randomize()` is used to compute dependent fields such as a checksum. They are functions, so they cannot consume time.

**Q36. What is the difference between `constraint_mode()` and `rand_mode()`?**
`constraint_mode(0)` switches a constraint block off, so the solver ignores it. `rand_mode(0)` switches the randomness of a variable off, so the solver treats it as a fixed state value (and still checks it against the constraints). Both take 1 to switch back on, and both can be applied to one item (`t.addr_c.constraint_mode(0)`, `t.addr.rand_mode(0)`) or to the whole object.

## Verification Concepts

**Q37. What is a transaction?**
A high-level description of one operation on an interface, held in a class object: for the ALU, one set of `a`, `b`, `op` and the resulting `result`. Testbench components pass transactions to each other; only the driver and monitor deal with individual signals and clock edges.

**Q38. What is the difference between directed and constrained-random testing?**
In a directed test the engineer writes each stimulus value by hand to hit one scenario. In constrained-random testing the testbench generates many random stimuli limited to legal values by constraints, a scoreboard checks them automatically, and functional coverage records which scenarios occurred. Random testing finds cases nobody thought of; directed tests fill the last coverage holes.

**Q39. What is the difference between code coverage and functional coverage?**
Code coverage is collected automatically by the simulator and reports which parts of the RTL were exercised (lines, branches, conditions, toggles, FSM states). Functional coverage is written by the verification engineer with covergroups and reports which features and scenarios of the specification were exercised. 100% code coverage does not show that a required feature was implemented; 100% functional coverage does not show that all code was exercised. Both are needed.

## Inter-Process Communication

**Q40. What is a mailbox?**
A built-in class that works as a FIFO between processes. One process puts items in, another gets them out, and the mailbox synchronises them: `get()` blocks while the mailbox is empty. It is the standard way to pass transactions from the generator to the driver and from the monitor to the scoreboard.

**Q41. What are the mailbox methods?**
`new(bound)` creates it (no argument or 0 means unbounded). `put()` adds an item, blocking if a bounded mailbox is full. `get()` removes the first item, blocking if empty. `peek()` copies the first item without removing it, blocking if empty. `try_put()`, `try_get()` and `try_peek()` never block and return a status. `num()` returns the number of items.

**Q42. What is a semaphore?**
A built-in class that holds a number of keys. A process must `get()` a key before using a shared resource and `put()` it back afterwards; `get()` blocks while not enough keys are available. With one key it gives mutual exclusion, for example two sequences sharing one bus driver.

**Q43. What is an event and how is it used?**
A synchronisation object with no data. One process triggers it with `-> e;` and other processes wait for it with `@e;` or `wait (e.triggered);`. It is used to signal that something happened, for example that the generator has finished.

**Q44. What is the difference between `fork`...`join`, `join_any` and `join_none`?**
All three start the statements inside as parallel threads. `join` blocks the parent until all threads finish. `join_any` blocks until the first thread finishes; the others keep running. `join_none` does not block at all; the threads start when the parent next blocks or finishes.

## Interfaces and Testbench

**Q45. What is an interface?**
A construct that bundles the signals connecting blocks into one named unit that is instantiated once and passed through ports as a single connection. It can also contain modports, clocking blocks, assertions, tasks and functions. It removes repeated port lists and is the connection point between the DUT and a class-based testbench.

**Q46. What is a modport?**
A named view of an interface that declares the direction of each signal for one kind of user: `modport DUT (input a, b, op, output result);`. Different modports give the DUT, the driver and the monitor different directions, so the compiler can report a component that drives a signal it should only read.

**Q47. What is a virtual interface?**
A variable (handle) that refers to an interface instance: `virtual alu_if vif;`. Classes cannot contain interface instances, so a class holds a virtual interface and accesses the DUT signals through it. The testbench top assigns the real interface instance to the handle.

**Q48. What is a clocking block?**
A block inside an interface that groups signals synchronous to one clock and defines when the testbench samples inputs and drives outputs relative to that clock edge (the skews). It removes races between the testbench and the DUT and makes the driver and monitor code cycle-based: `@(vif.drv_cb); vif.drv_cb.a <= 8'h10;`.

**Q49. What do the generator, driver, monitor, scoreboard, environment and test do?**
The generator creates and randomizes transactions. The driver takes transactions and converts them into pin-level activity on the interface. The monitor watches the interface and converts pin activity back into transactions. The scoreboard computes the expected result and compares it with what the monitor observed. The environment creates and connects these components. The test configures the environment (number of transactions, constraints) and starts it.

## Coverage, Assertions and Other Topics

**Q50. What is the difference between an immediate and a concurrent assertion?**
An immediate assertion is a procedural statement, `assert (expr) else $error(...);`, checked once at the moment it is executed, like an `if`. A concurrent assertion, `assert property (@(posedge clk) ...);`, is evaluated on every clock tick using sampled values and can describe behaviour that spans several cycles.

**Q51. What is the difference between `|->` and `|=>`?**
Both are implication operators: if the antecedent (left side) matches, the consequent (right side) must hold. With overlapped implication `|->` the consequent starts in the same clock tick in which the antecedent ends. With non-overlapped implication `|=>` it starts one tick later. `a |=> b` is the same as `a |-> ##1 b`.

**Q52. What are a covergroup, a coverpoint, bins and a cross?**
A covergroup is the container for a coverage model and defines when it is sampled. A coverpoint names a variable or expression to be covered. Bins divide the values of a coverpoint into the cases that are counted. A cross records combinations of the bins of two or more coverpoints.

**Q53. What is a package?**
A named scope that holds declarations to be shared: typedefs, parameters, functions, tasks and classes. Other code uses them with `import pkg::*;` or `pkg::name`. A package cannot contain modules, interfaces or wires.

**Q54. What is the difference between `$display`, `$write`, `$strobe` and `$monitor`?**
`$display` prints immediately and adds a newline. `$write` is the same without the newline. `$strobe` prints once at the end of the current time step, after nonblocking assignments have taken effect. `$monitor` is started once and then prints at the end of every time step in which one of its arguments changed.

**Q55. What is UVM?**
The Universal Verification Methodology: a standard class library (IEEE 1800.2) written in SystemVerilog, plus rules for using it. It provides base classes for the components of a layered testbench (driver, monitor, agent, scoreboard, environment, test), a factory for replacing classes, a configuration database, phases that order the simulation, and sequences for stimulus. It standardises the structure taught in M9 so that testbenches are reusable across projects and companies.
