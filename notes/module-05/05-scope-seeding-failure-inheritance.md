## 4.5 std::randomize(), System Random Functions and Seeding

### std::randomize(): randomizing without a class

`obj.randomize()` needs a class with `rand` properties. For a quick random value in a module, a task or a testbench method, declaring a class is excessive. The **scope randomize function** `std::randomize()` randomizes ordinary variables that are visible in the current scope.

```systemverilog
int       a, b;
bit [3:0] nib;
bit       ok;

ok = std::randomize(a);                                   // any 32-bit value
ok = std::randomize(a, b) with { a inside {[1:10]}; b == a * 2; };
ok = std::randomize(nib) with { nib > 12; };
```

| Property | `obj.randomize()` (class method) | `std::randomize(vars)` (scope function) |
|---|---|---|
| What is randomized | The object's `rand`/`randc` properties | The variables listed as arguments |
| `rand` keyword needed | Yes | No. Any integral variable in scope can be listed |
| Constraints | Class constraint blocks plus optional `with` | Only the `with` block |
| `randc` behaviour | Supported | Not available |
| `pre_randomize()` / `post_randomize()` | Called | Not called |
| `constraint_mode()` / `rand_mode()` | Available | Not applicable |
| Reuse through inheritance | Yes | No |
| Return value | 1 or 0 | 1 or 0 |
| Typical use | Transactions and configuration objects | One-off random values in procedural code |

Inside a class method, an unqualified `randomize()` means `this.randomize()`. To randomize a local variable of the method, `std::randomize(local_var)` must be written explicitly.

### $urandom, $urandom_range and $random

| Function | Returns | Notes |
|---|---|---|
| `$urandom()` | Unsigned 32-bit | `$urandom(seed)` also sets the seed of the calling thread's generator |
| `$urandom_range(max, min)` | Unsigned, in [min, max] inclusive | `min` defaults to 0. If `max` is less than `min` the two are swapped, so `$urandom_range(1, 5)` and `$urandom_range(5, 1)` are the same |
| `$random()` | **Signed** 32-bit | Legacy Verilog. `$random % 10` gives -9 to 9, not 0 to 9 |

```systemverilog
delay = $urandom_range(10, 1);        // 1 to 10
idx   = $urandom % 8;                 // 0 to 7
bad   = $random % 8;                  // -7 to 7 : a classic bug when used as an index
ok    = {$random} % 8;                // 0 to 7 : concatenation makes the value unsigned
```

### Seeds and random stability (awareness level)

Random numbers come from a pseudo-random generator (RNG). Three facts matter in practice.

**1. Every thread and every object has its own RNG.** A value drawn in one thread does not disturb the sequence seen by another thread or object. This property is called **random stability**. It keeps a test reproducible when unrelated parts of the testbench change how many random numbers they consume.

**2. Seeds are handed down hierarchically.**

```text
   simulation seed (command line)
        |
        v
   each initial block / top-level thread gets its own RNG, seeded from the simulation seed
        |
        +--> when a thread executes  new()  : the new OBJECT's RNG is seeded with the
        |                                     next random value of the creating thread
        |
        +--> when a thread executes  fork   : each CHILD THREAD's RNG is seeded with the
                                              next random value of the parent thread
```

Because seeds are drawn in order of creation, **inserting a new `new()` or `fork` before existing ones shifts the seeds of everything created after it** in that thread. This is why a small, harmless-looking testbench edit can change the random stimulus of a whole test, and why a failure sometimes "disappears" after adding debug code that creates an object.

**3. Seeds can be set by hand.**

| Mechanism | Effect |
|---|---|
| Simulator command-line option | Sets the simulation seed. The option name is tool-specific: for example `+ntb_random_seed=<n>` (VCS), `-sv_seed <n>` (Questa), `-svseed <n>` (Xcelium). Check your tool's documentation |
| `obj.srandom(seed)` | Seeds the RNG of one object |
| `process::self().srandom(seed)` | Seeds the RNG of the current thread |
| `obj.get_randstate()` / `obj.set_randstate(str)` | Saves and restores the RNG state of an object as a string |

```systemverilog file=tb_seed.sv
module tb_seed;

  class item;
    rand bit [15:0] v;
  endclass

  item a, b;
  bit  same = 1;

  initial begin
    a = new();
    b = new();
    a.srandom(123);                   // give both objects the same seed
    b.srandom(123);
    repeat (5) begin
      void'(a.randomize());
      void'(b.randomize());
      if (a.v != b.v) same = 0;
    end
    $display("two objects with the same seed produced the same 5 values: %s",
             same ? "yes" : "NO");
  end

endmodule
```

```output
two objects with the same seed produced the same 5 values: yes
```

Two objects of the same class, seeded identically and randomized identically, produce identical sequences. The values themselves depend on the simulator; the equality does not.

> **Key point:** To reproduce a failing random test you need the same seed, the same source code, the same simulator and version, and the same command-line options. Regression systems therefore log the seed of every run.

> **Common mistake:** Using `$random % N` as an array index or a delay. The result can be negative.

> **Common mistake:** Running a regression of 100 jobs with the default seed. All 100 jobs then generate identical stimulus. Each job must receive a different (and logged) seed.

### Interview questions

**Q1. What is `std::randomize()`?**
The scope randomize function. It randomizes the variables passed as arguments, which need not be class members or declared `rand`, optionally under inline constraints in a `with` block. It returns 1 on success.

**Q2. What is the difference between `randomize()` and `std::randomize()`?**
`obj.randomize()` is the class method: it randomizes the object's `rand` properties under the class constraints and calls `pre_randomize()` and `post_randomize()`. `std::randomize()` works on arbitrary variables in the current scope with inline constraints only.

**Q3. What range does `$urandom_range(3, 7)` return?**
3 to 7 inclusive. If the first argument is smaller than the second, they are swapped.

**Q4. What is random stability?**
The property that each thread and each object has its own random number generator, so the random values in one are not affected by random calls in another. It keeps simulations repeatable when unrelated code changes.

**Q5. A test fails with seed 12345. After you add a debug object in the environment constructor, it passes with the same seed. Why?**
The new object is created before others in the same thread and takes a seed from the thread's RNG. All objects and threads created afterwards receive different seeds, so the stimulus changed.

**Q6. How do you set the seed of one object?**
`obj.srandom(seed);`

## 4.6 Randomization Failure and Constraint Debugging

### What a failure is

A randomization **fails** when no combination of values for the active random variables satisfies all active hard constraints together with the current values of the state variables. The solution space is empty.

| On failure | Behaviour |
|---|---|
| Return value | 0 |
| Random variables | All keep their previous values. Nothing is partially updated |
| `pre_randomize()` | Has already been executed |
| `post_randomize()` | Not executed |
| Simulation | **Continues.** The language itself raises no error |
| Message | Most simulators print a warning or error naming the conflicting constraints; the detail and the options that control it are tool-specific |

Because the simulation continues with stale values, an unchecked failure typically shows up much later as "the same packet is sent twice" or "the test never reaches the corner case". Always check the return value.

### Causes of failure

| Cause | Example |
|---|---|
| Two hard constraints contradict each other | `len < 10;` and `len > 200;` |
| A base-class constraint conflicts with one added in a derived class | Base `len inside {[1:10]}`, derived `len > 50` under a different block name |
| An inline constraint conflicts with a class constraint | `randomize() with { addr == 150; }` while the class has `addr < 100` |
| A state variable has an unexpected value | `len <= max_len` with `max_len` never initialised (0) |
| `rand` was forgotten | The variable is a state variable that violates its own constraint |
| A variable was frozen with `rand_mode(0)` at an illegal value | Section 4.3 |
| The requested value does not fit the variable's width | `rand bit [3:0] x; constraint c { x == 20; }` |
| Signed/unsigned or expression-width effects | `rand bit [3:0] a[10]; a.sum() == 50;` |
| An implicit ordering picked a dead end | Array size chosen first; function argument chosen first; `randc` chosen first |
| `unique` or `randc` has run out of values | Five `unique` 2-bit variables |
| Index out of range in a constraint | `foreach (d[i]) d[i] < d[i+1];` |
| An empty set | `x inside {empty_queue};` or `[hi:lo]` with reversed bounds, or all `dist` weights zero |
| X or Z in a state variable used by a constraint | An uninitialised `logic` knob |

### A debugging procedure

1. **Confirm it is a failure.** Check the return value and read the simulator's message. It normally lists the constraints (file and line) that cannot be satisfied together and the values of the state variables involved. Tools have options to make this report more detailed.
2. **Print the state.** Display all non-random variables used in constraints, and the `rand_mode()` of suspect variables, just before the call (or in `pre_randomize()`).
3. **Bisect with `constraint_mode()`.** Switch constraint blocks off one at a time and call `randomize()` again. The block whose removal makes the call succeed is part of the conflict.
4. **Check current values with `randomize(null)`.** Assign the values you expected to be legal and call `obj.randomize(null)`. If it returns 0, those values are not legal, and step 3 tells you which block rejects them.
5. **Simplify.** Copy the class into a small standalone test (like the `tb_` modules in these notes) with only the suspect constraints.
6. **Review widths and signs.** Check every literal and every arithmetic expression for truncation, wrap-around and signedness.
7. **Review the inheritance chain and inline constraints.** List every block the object actually has, including those of all base classes, and every `with` clause at the failing call.

### Complete example: locating a conflict

```systemverilog file=tb_debug_fail.sv
module tb_debug_fail;

  class bus_txn;
    rand bit [7:0] addr;
    rand bit [7:0] len;
    int unsigned   max_len = 16;

    constraint len_c   { len inside {[1:max_len]}; }
    constraint align_c { addr[1:0] == 2'b00; }           // word aligned
    constraint odd_c   { addr[0] == 1'b1; }              // added later by somebody else
  endclass

  bus_txn t;

  initial begin
    t = new();
    if (!t.randomize()) begin
      $display("randomize FAILED. State: max_len=%0d", t.max_len);

      t.len_c.constraint_mode(0);
      $display("  without len_c   : status=%0d", t.randomize());
      t.len_c.constraint_mode(1);

      t.align_c.constraint_mode(0);
      $display("  without align_c : status=%0d", t.randomize());
      t.align_c.constraint_mode(1);

      t.odd_c.constraint_mode(0);
      $display("  without odd_c   : status=%0d", t.randomize());
      t.odd_c.constraint_mode(1);

      t.addr = 8'h10;  t.len = 4;                         // values we believe are legal
      $display("  addr=10 len=4 legal? status=%0d", t.randomize(null));
    end
  end

endmodule
```

```output
randomize FAILED. State: max_len=16
  without len_c   : status=0
  without align_c : status=1
  without odd_c   : status=1
  addr=10 len=4 legal? status=0
```

Simulator failure messages appear between these lines for each failing call.

**Reading the result**

| Observation | Conclusion |
|---|---|
| Removing `len_c` does not help | `len_c` is not involved |
| Removing `align_c` helps, and removing `odd_c` helps | These two blocks conflict with each other |
| `randomize(null)` with a value we considered legal returns 0 | The object's constraints reject an aligned address, which points at `odd_c` |
| Inspecting the two blocks | `addr[1:0] == 0` requires bit 0 to be 0; `addr[0] == 1` requires it to be 1 |

### Debugging a distribution problem

Not every constraint problem is a failure. "It randomizes, but I never see value X" is as common.

| Symptom | Likely cause | Fix |
|---|---|---|
| A mode bit is almost always 0 | Implication with a wide dependent variable (Section 2.4) | `solve`...`before`, or a `dist` on the mode |
| A listed `dist` value never appears | It is excluded by another constraint, or its `:=` weight is tiny compared with a wide range | Check the other constraints; use `:/` for the range |
| Values are mostly huge or negative | Unbounded or signed variable | Bound both sides; use unsigned types |
| A soft default never takes effect | A hard constraint or a higher-priority soft constraint conflicts with it | Review priorities |
| The array is always empty | The size is not constrained | Constrain `size()` |
| `randc` values repeat | A new object is created each time | Keep the `randc` variable in a persistent object |
| The same values in every regression job | Same seed | Give each job its own seed |

The tool for these problems is measurement: randomize a few thousand times in a small test and print a histogram, or sample the variable in a covergroup (Module 10).

> **Interview trap:** "What happens when randomization fails? Does the simulation stop?" No. `randomize()` returns 0, the variables keep their old values, and execution continues. Only your own check (`$fatal`, `$error`) makes the failure visible.

> **Common mistake:** Trying to fix a failure with `solve`...`before`. Ordering never creates solutions.

### Interview questions

**Q1. When does `randomize()` fail?**
When the active hard constraints, together with the current values of the state variables, have no solution.

**Q2. How do you debug a constraint failure?**
Check the return value and read the simulator's conflict report; print the state variables used in constraints; disable constraint blocks one by one with `constraint_mode(0)` to find the conflicting set; use `randomize(null)` to test whether specific values are legal; reduce the problem to a small standalone class; and check widths, signs, inheritance and inline constraints.

**Q3. Name five causes of randomization failure.**
Contradictory constraints; a conflict between base-class and derived-class or inline constraints; a state variable with an unexpected value; a variable frozen with `rand_mode(0)` at an illegal value; a forgotten `rand`; a value that does not fit the variable width; an out-of-range index in a `foreach` constraint; an implicit ordering such as array size or a function argument.

**Q4. The randomization succeeds but one value never occurs. How do you investigate?**
Check whether another constraint excludes it; check the solution-count effect of implications and whether `solve before` or `dist` is needed; check `dist` weights and the use of `:=` versus `:/`; then measure with a histogram over many calls.

**Q5. Why is `if (!obj.randomize()) $fatal(...)` used in testbenches?**
Because a failure is otherwise silent: the object keeps its previous contents and the test continues with wrong stimulus.

## 4.7 Constraint Inheritance, Overriding and Extension

### In plain English

A derived class receives everything its base class has, including the random variables and the constraint blocks. The derived class can then do two things with constraints:

- **Add** a block with a **new name**. The new block applies **in addition to** all inherited ones.
- **Override** a block by declaring one with the **same name**. The new block **replaces** the inherited one.

This is how one transaction class becomes a family: `short_txn`, `long_txn`, `err_txn`, each a few lines long.

### Rules

| Rule | Detail |
|---|---|
| Inheritance | A derived class inherits all `rand` variables and all constraint blocks of its base classes |
| New block name | Adds a constraint. It must be consistent with the inherited constraints, otherwise randomization fails |
| Same block name | Overrides: the base-class block of that name is completely replaced in the derived class. There is no way to call the base version (no `super` for constraints) |
| Polymorphism | `randomize()` is virtual. Through a base-class handle that refers to a derived object, the **derived** object's constraints are used |
| Soft constraints | A soft constraint in a derived class has higher priority than a soft constraint in the base class |
| Modes | `constraint_mode()` and `rand_mode()` work on inherited blocks and variables exactly as on local ones |
| Abstract classes | A virtual class may declare `pure constraint name;`. Every non-abstract derived class must then provide a constraint block with that name |

```text
   class base_txn                         class long_txn extends base_txn
   +-----------------------------+        +----------------------------------+
   | rand len                    |        | (inherits len)                   |
   | constraint len_c  {1..10}   | -----> | constraint len_c  {100..110}     |  REPLACED
   | constraint even_c {len even}| -----> | (inherits even_c unchanged)      |
   +-----------------------------+        | constraint extra_c {...}         |  ADDED
                                          +----------------------------------+
```

### Complete example

```systemverilog file=tb_constraint_inherit.sv
module tb_constraint_inherit;

  class base_txn;
    rand bit [7:0] len;
    constraint len_c  { len inside {[1:10]}; }
    constraint even_c { len[0] == 1'b0; }
  endclass

  class long_txn extends base_txn;                 // OVERRIDE: same block name
    constraint len_c { len inside {[100:110]}; }
  endclass

  class tiny_txn extends base_txn;                 // EXTEND: new block name
    constraint tiny_c { len < 3; }
  endclass

  class bad_txn extends base_txn;                  // EXTEND with a conflicting constraint
    constraint big_c { len > 50; }
  endclass

  base_txn b, h;
  long_txn l;
  tiny_txn t;
  bad_txn  x;
  int      status;

  initial begin
    b = new();  l = new();  t = new();  x = new();

    status = b.randomize();
    $display("1. base_txn : status=%0d even and in 1..10: %s", status,
             (b.len inside {2, 4, 6, 8, 10}) ? "yes" : "NO");

    status = l.randomize();
    $display("2. long_txn : status=%0d even and in 100..110: %s", status,
             (l.len inside {100, 102, 104, 106, 108, 110}) ? "yes" : "NO");

    status = t.randomize();
    $display("3. tiny_txn : status=%0d len=%0d", status, t.len);

    status = x.randomize();
    $display("4. bad_txn  : status=%0d", status);

    h = l;                                         // base handle, derived object
    status = h.randomize();
    $display("5. base handle to long_txn : status=%0d len>=100: %s", status,
             (h.len >= 100) ? "yes" : "NO");
  end

endmodule
```

```output
1. base_txn : status=1 even and in 1..10: yes
2. long_txn : status=1 even and in 100..110: yes
3. tiny_txn : status=1 len=2
4. bad_txn  : status=0
5. base handle to long_txn : status=1 len>=100: yes
```

A simulator failure message accompanies line 4.

**Line by line**

| Line | Explanation |
|---|---|
| 1 | The base class: both of its blocks apply. |
| 2 | `long_txn` declares `len_c` again. The base `len_c` no longer exists for this class, so 100 to 110 does not conflict with 1 to 10. The inherited `even_c` still applies. |
| 3 | `tiny_txn` adds `tiny_c`. All three blocks apply: 1 to 10, even, less than 3. The only solution is 2, so this line is fully determined. |
| 4 | `bad_txn` adds `len > 50` under a new name. The inherited `len_c` (1 to 10) still applies. No solution: failure. The author probably meant to override and should have named the block `len_c`. |
| 5 | The handle type is `base_txn` but the object is a `long_txn`. `randomize()` is virtual, so the object's own constraints (100 to 110) are used. |

### Ways for a derived class or a test to change inherited behaviour

| Goal | Technique |
|---|---|
| Tighten an inherited rule | Add a block with a new name |
| Replace an inherited rule | Declare a block with the same name |
| Remove an inherited rule | Override it with an empty block: `constraint len_c { }`, or call `constraint_mode(0)` |
| Replace a default without knowing its block name | The base class declares the default `soft`; the derived class or the inline constraint simply states the new requirement |
| Force derived classes to supply a rule | `pure constraint` in an abstract base class |

> **Note:** The 2023 revision of the standard adds optional specifiers that let a class state explicitly whether a constraint block is new, extends or finalises an inherited one. Tool support is still arriving, and these are not expected in interviews; the name-based rules above are what you need.

### Overriding versus extending

| | Override (same name) | Extend (new name) |
|---|---|---|
| Base-class block | Replaced | Still active |
| Result | Only the derived block's rule applies | Both rules apply together |
| Risk | Accidentally discarding a rule the base class needed | Accidental contradiction with the base rule, causing failure |
| Use when | The derived class needs different values from the base | The derived class needs a subset of the base's values |

> **Interview trap:** "A derived class adds `constraint c2 { x > 100; }` while the base has `constraint c1 { x < 50; }`. What happens?" Both apply and `randomize()` fails. Only a block named `c1` in the derived class would override the base constraint.

> **Interview trap:** "A base-class handle points to a derived-class object. Whose constraints are used?" The derived object's, because `randomize()` is virtual and constraints belong to the object, not to the handle type.

> **Common mistake:** Reusing a base-class block name by accident in a derived class. The base rule disappears without any warning.

> **Verification application:** Factory-style test writing. The generator holds a `base_txn` handle called the blueprint. A test replaces the blueprint with a derived object (`long_txn`, `err_txn`). The generator's code does not change, yet every `randomize()` now obeys the derived constraints. UVM formalises this as the factory override (Module 11).

### Interview questions

**Q1. Are constraints inherited?**
Yes. A derived class inherits all constraint blocks and random variables of its base class.

**Q2. How do you override a constraint in a derived class?**
Declare a constraint block with the same name as the base-class block. It replaces the inherited one.

**Q3. What happens if the derived class declares a constraint with a different name?**
It is added. The object must then satisfy both the inherited and the new constraints; if they contradict each other, randomization fails.

**Q4. Can a derived class refer to the base-class constraint, like `super.c`?**
No. There is no `super` for constraints. To build on a base constraint, leave it inherited and add another block.

**Q5. If a base handle refers to a derived object, which constraints does `randomize()` use?**
Those of the derived object, including overrides.

**Q6. How do you remove a base-class constraint in a derived class?**
Override it with an empty block of the same name, or disable it with `constraint_mode(0)`, typically in the derived class's constructor.

**Q7. What is a pure constraint?**
A constraint prototype declared with `pure constraint name;` in a virtual (abstract) class. It has no body; every concrete derived class must define a constraint of that name.
