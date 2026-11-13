# Part 4: Controlling Randomization

Parts 2 and 3 described constraints written once, inside the class. A test also needs to change the behaviour of a class **from outside**, call by call: switch a constraint off, freeze a variable, add one extra rule for one call, run code just before or just after the solver. This part covers those controls, then failure debugging and inheritance.

## 4.1 pre_randomize() and post_randomize()

### In plain English

`randomize()` cannot be modified, but it calls two empty "hook" functions that you can fill in:

- `pre_randomize()` runs **just before** the solver starts. Use it to prepare: set knobs, allocate arrays, switch constraints.
- `post_randomize()` runs **just after** the solver has written the new values. Use it to finish: compute fields that depend on the random values, print, update history.

### Technical definition

Every class has two built-in methods:

```systemverilog
function void pre_randomize();
function void post_randomize();
```

They are called automatically by `randomize()`. By default they do nothing (apart from calling the same hook in the base class). A class may define its own versions.

| Property | `pre_randomize()` | `post_randomize()` |
|---|---|---|
| Called | Before the solver runs | After the solver has assigned the values |
| Called when randomization fails | Yes (it has already run) | **No** |
| Sees | The old values of the random variables | The new values |
| Type | `function void`, no arguments | `function void`, no arguments |
| Can consume time | No (it is a function) | No |
| For `rand` member objects | Their `pre_randomize()` is also called | Their `post_randomize()` is also called |
| With `randomize(null)` or all `rand_mode` off | Still called | Called if the check succeeds |

### Execution flow

```text
   obj.randomize()
        |
        +--> obj.pre_randomize()         user code: prepare
        |
        +--> solver                      (failure: return 0 here, nothing else happens)
        |
        +--> values assigned to obj
        |
        +--> obj.post_randomize()        user code: derive, print, record
        |
        +--> return 1
```

### Typical uses

| In `pre_randomize()` | In `post_randomize()` |
|---|---|
| Set state variables (knobs, limits) that constraints refer to | Compute derived, non-random fields: CRC, parity, checksum, length field |
| Turn constraints or variables on and off with `constraint_mode()` / `rand_mode()` | Apply effects that are easier to code procedurally: sort or shuffle an array, corrupt a field for error injection |
| Construct the objects of a `rand` array of handles | Record the chosen value in a history queue (to avoid repeats next time) |
| Print or check the state before solving (debug) | Print the transaction; assign an ID; collect coverage |

### Complete example

```systemverilog file=tb_pre_post.sv
module tb_pre_post;

  class pkt;
    rand bit [3:0] len;
    rand bit [7:0] payload[];
    bit [7:0]      checksum;          // derived: not random
    int            max_len = 4;       // knob
    int            n_calls;

    constraint len_c { len inside {[1:max_len]}; payload.size() == len; }

    function void pre_randomize();
      n_calls++;
      $display("pre  : call %0d, max_len=%0d", n_calls, max_len);
    endfunction

    function void post_randomize();
      checksum = 0;
      foreach (payload[i]) checksum ^= payload[i];
      $display("post : len=%0d payload=%p checksum=%h", len, payload, checksum);
    endfunction
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    status = p.randomize();
    $display("status=%0d", status);

    p.max_len = 0;                    // makes len_c impossible: [1:0] is an empty range
    status = p.randomize();
    $display("status=%0d", status);
  end

endmodule
```

**What to expect.** The sequence of lines is fixed; only the random values vary. `len` is 1 to 4, the payload has exactly `len` elements, and `checksum` is the XOR of them. In the second call `pre` prints but `post` does not, because the randomization fails. A simulator failure message may appear before the final line. Sample output; the payload values differ per seed and simulator:

```text
pre  : call 1, max_len=4
post : len=3 payload='{'h5c, 'ha1, 'h0f} checksum=f2
status=1
pre  : call 2, max_len=0
status=0
```

**Line by line**

| Line | Explanation |
|---|---|
| `bit [7:0] checksum;` | Not `rand`. A checksum is a consequence of the payload, not an independent random choice. |
| `len inside {[1:max_len]};` | `max_len` is a state variable. Its value at the time of the call is used. |
| `function void pre_randomize();` | Redefines the hook. It runs on every `randomize()` call of this object, including failing ones. |
| `function void post_randomize();` | Runs only after a successful solve. All `rand` fields already hold their new values, so the checksum is computed from the final payload. |
| `p.max_len = 0;` | The range `[1:0]` is empty, so no legal `len` exists. |
| Second call | `pre` runs, the solver fails, `post` is skipped, `status` is 0. |

### Using the hooks with inheritance

```systemverilog
class err_pkt extends pkt;
  rand bit corrupt;

  function void post_randomize();
    super.post_randomize();               // base-class hook first: computes the checksum
    if (corrupt) checksum = ~checksum;    // then inject the error
  endfunction
endclass
```

If a derived class defines `pre_randomize()` or `post_randomize()`, the base-class version is **not** called automatically any more. Call `super.pre_randomize()` / `super.post_randomize()` explicitly, otherwise the base class's preparation or derived-field calculation is silently lost.

> **Note:** The standard does not declare these two functions `virtual`. They nevertheless behave polymorphically, because they are called from inside `randomize()`, which is virtual: the hooks of the actual object's class are the ones that run.

### Pre-randomization versus post-randomization

| Question | `pre_randomize()` | `post_randomize()` |
|---|---|---|
| Can it influence what the solver generates? | Yes: by changing state variables and modes | No: the solver has finished |
| Can it change the generated values? | Its changes to `rand` variables are overwritten by the solver | Yes, and nothing checks the constraints afterwards |
| Is it reached on failure? | Yes | No |
| Main purpose | Set up the randomization | Complete the object |

> **Interview trap:** "Is `post_randomize()` called when `randomize()` fails?" No. `pre_randomize()` has already been called by then.

> **Interview trap:** "If `post_randomize()` changes a `rand` variable to an illegal value, does `randomize()` fail?" No. Constraints are not re-checked after `post_randomize()`. This is exactly how error injection is done, and it is also a way to break your own constraints by accident.

> **Common mistake:** Declaring a derived field such as `crc` as `rand` and constraining it with a function. Compute it in `post_randomize()`.

> **Common mistake:** Putting delays or blocking calls in the hooks. They are functions and cannot consume simulation time.

> **Verification application:** In a packet class, `pre_randomize()` constructs the `rand` sub-objects (headers, extension blocks), and `post_randomize()` fills in `length`, computes the CRC over the packed bytes, and, if an `inject_crc_err` knob is set, flips a bit of the CRC.

### Interview questions

**Q1. What are `pre_randomize()` and `post_randomize()`?**
Built-in void functions that `randomize()` calls automatically before the solver runs and after it has successfully assigned the values. Users redefine them to add set-up and completion code.

**Q2. Give one typical use of each.**
`pre_randomize()`: set a constraint knob or disable a constraint depending on the test mode; allocate objects for a `rand` array of handles. `post_randomize()`: compute a CRC or parity field from the randomized data.

**Q3. Can they be tasks?**
No. They are functions with no arguments and no return value, so they cannot contain timing controls.

**Q4. If a derived class overrides `post_randomize()`, is the base-class version still executed?**
Only if the derived version calls `super.post_randomize()`.

**Q5. Where would you calculate a CRC field, and why not with a constraint?**
In `post_randomize()`. The CRC is fully determined by the other fields, it is expensive or impossible for a solver to work through, and nothing needs to be solved "backwards" from it.

## 4.2 Turning Constraints On and Off: constraint_mode()

### In plain English

A transaction class contains the constraints for normal, legal traffic. An error-injection test needs to break one of those rules; a corner-case test needs to replace a default. `constraint_mode()` is a switch on each constraint block: off means the solver ignores the block.

### Syntax

```systemverilog
obj.block_name.constraint_mode(0);        // task form: switch one block OFF
obj.block_name.constraint_mode(1);        // switch it ON again
obj.constraint_mode(0);                   // switch ALL blocks of the object off
obj.constraint_mode(1);                   // switch ALL blocks on

int state = obj.block_name.constraint_mode();   // function form: returns 1 (on) or 0 (off)
```

| Form | Kind | Meaning |
|---|---|---|
| `obj.c.constraint_mode(0 or 1)` | Task call | Set the mode of block `c` in this object |
| `obj.constraint_mode(0 or 1)` | Task call | Set the mode of every block in this object, including inherited ones |
| `obj.c.constraint_mode()` | Function call, returns `int` | Query the mode of block `c`. The function form needs a block name |

### Rules

| Rule | Detail |
|---|---|
| Default | Every constraint block is on |
| Scope | Per **object**. Switching a block off in one object does not affect other objects of the class |
| `static constraint` | The mode is shared: one call changes it for all objects |
| Persistence | The mode stays until it is changed again. It is not reset by `randomize()` |
| Granularity | A whole block. One expression inside a block cannot be switched off, which is why constraints should be split into small named blocks |
| Unknown block name | Compile error |
| An "off" block | Is ignored completely: it is not checked either |

### Complete example

```systemverilog file=tb_constraint_mode.sv
module tb_constraint_mode;

  class pkt;
    rand bit [7:0] len;
    constraint small_c { len < 10; }
    constraint big_c   { len > 200; }
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    $display("1. initial modes : small_c=%0d big_c=%0d",
             p.small_c.constraint_mode(), p.big_c.constraint_mode());

    status = p.randomize();
    $display("2. both on       : status=%0d", status);

    p.big_c.constraint_mode(0);
    status = p.randomize();
    $display("3. big_c off     : status=%0d len<10: %s", status, (p.len < 10) ? "yes" : "NO");

    p.small_c.constraint_mode(0);
    p.big_c.constraint_mode(1);
    status = p.randomize();
    $display("4. small_c off   : status=%0d len>200: %s", status, (p.len > 200) ? "yes" : "NO");

    p.constraint_mode(0);
    status = p.randomize();
    $display("5. all off       : status=%0d modes: small_c=%0d big_c=%0d",
             status, p.small_c.constraint_mode(), p.big_c.constraint_mode());
  end

endmodule
```

```output
1. initial modes : small_c=1 big_c=1
2. both on       : status=0
3. big_c off     : status=1 len<10: yes
4. small_c off   : status=1 len>200: yes
5. all off       : status=1 modes: small_c=0 big_c=0
```

A simulator failure message accompanies line 2.

**Line by line**

| Line | Explanation |
|---|---|
| 1 | The function form reports that both blocks start in the "on" state. |
| 2 | `len < 10` and `len > 200` contradict each other. With both active the call fails. |
| 3 | With `big_c` off, only `small_c` applies. |
| 4 | The modes are swapped: only `big_c` applies. |
| 5 | `p.constraint_mode(0)` switches every block off. `len` is now completely unconstrained (0 to 255). |

> **Common mistake:** Forgetting to switch a constraint back on. The object keeps the mode. If the same object is reused for later transactions, they are all generated without the constraint.

> **Common mistake:** Putting all constraints of a class in one big block. Then nothing can be disabled individually.

> **Verification application:** An error test: `txn.legal_len_c.constraint_mode(0);` followed by `txn.randomize() with { len > MAX_LEN; };` generates over-length packets from the same transaction class that normal tests use.

### Interview questions

**Q1. How do you disable a constraint?**
`obj.constraint_name.constraint_mode(0);`. To disable all constraints of an object: `obj.constraint_mode(0);`.

**Q2. What does `constraint_mode()` return when called as a function?**
1 if the named constraint block is active, 0 if it is inactive.

**Q3. Does disabling a constraint in one object affect other objects?**
No, unless the constraint is declared `static`.

**Q4. Can you disable a single expression inside a constraint block?**
No. The unit is the block. Split the block, or guard the expression with a state variable: `enable_x -> (expression);`.

**Q5. What are the alternatives to `constraint_mode()` for removing a default?**
Declare the default as a `soft` constraint and override it inline; override the block in a derived class; or guard it with a knob variable.

## 4.3 Turning Random Variables On and Off: rand_mode()

### In plain English

`rand_mode()` is the matching switch for **variables**. Switching a `rand` variable off freezes it: `randomize()` no longer changes it, and it keeps whatever value it has. It is used to hold one field at a chosen value while the rest of the object is randomized around it.

### Syntax

```systemverilog
obj.var_name.rand_mode(0);        // task form: this variable is no longer random
obj.var_name.rand_mode(1);        // random again
obj.rand_mode(0);                 // all random variables of the object off
obj.rand_mode(1);                 // all on

int state = obj.var_name.rand_mode();   // function form: 1 (random) or 0 (not random)
```

### Rules

| Rule | Detail |
|---|---|
| Applies to | Properties declared `rand` or `randc` only. Using it on a non-random property is a compile error |
| Default | On |
| Scope and persistence | Per object, until changed again |
| A variable that is switched off | Becomes a **state variable**. It keeps its current value, and that value is still used in every constraint that mentions it |
| Arrays | The whole array can be switched (`obj.arr.rand_mode(0)`), and for unpacked arrays a single element as well |
| Object handles | Switching off a `rand` handle stops the randomization of the object it refers to |

> **Key point:** Switching a variable off does **not** switch off the constraints on it. The frozen value must still satisfy them. If it does not, `randomize()` fails.

### Complete example

```systemverilog file=tb_rand_mode.sv
module tb_rand_mode;

  class pkt;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    constraint addr_c { addr < 16; }
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    $display("1. modes: addr=%0d data=%0d", p.addr.rand_mode(), p.data.rand_mode());

    p.addr.rand_mode(0);              // freeze addr
    p.addr = 8'h05;
    repeat (3) begin
      status = p.randomize();
      $display("2. frozen at 05   : status=%0d addr=%h", status, p.addr);
    end

    p.addr = 8'hF0;                   // a frozen value that violates addr_c
    status = p.randomize();
    $display("3. frozen at F0   : status=%0d addr=%h", status, p.addr);

    p.addr_c.constraint_mode(0);      // remove the violated constraint
    status = p.randomize();
    $display("4. constraint off : status=%0d addr=%h", status, p.addr);

    p.rand_mode(0);                   // nothing is random any more
    $display("5. modes: addr=%0d data=%0d", p.addr.rand_mode(), p.data.rand_mode());
  end

endmodule
```

```output
1. modes: addr=1 data=1
2. frozen at 05   : status=1 addr=05
2. frozen at 05   : status=1 addr=05
2. frozen at 05   : status=1 addr=05
3. frozen at F0   : status=0 addr=f0
4. constraint off : status=1 addr=f0
5. modes: addr=0 data=0
```

A simulator failure message accompanies line 3. `data` (not printed) receives a new random value in every successful call.

**Line by line**

| Line | Explanation |
|---|---|
| `p.addr.rand_mode(0);` | `addr` is now a state variable. |
| `p.addr = 8'h05;` | A procedural assignment chooses the frozen value. 5 satisfies `addr < 16`. |
| Line 2 | Three successful calls. `addr` never changes; only `data` is randomized. |
| `p.addr = 8'hF0;` | 240 violates `addr < 16`. The solver may not change `addr`, so no solution exists. |
| Line 3 | `status` is 0. |
| Line 4 | With the constraint switched off, the frozen value is acceptable again. |
| Line 5 | `p.rand_mode(0)` switched every random variable off. |

### rand_mode() versus constraint_mode()

| Property | `rand_mode()` | `constraint_mode()` |
|---|---|---|
| Controls | Whether a **variable** is randomized | Whether a **constraint block** is applied |
| Applied to | A `rand`/`randc` property, or the whole object | A constraint block, or the whole object |
| Off means | The variable keeps its current value and is treated as a state variable | The block is ignored by the solver |
| Constraints on that variable | **Still enforced** against the frozen value | Not applicable |
| Can cause `randomize()` to fail | Yes, if the frozen value violates an active constraint | No. Removing constraints can only enlarge the solution space |
| Task form | `obj.v.rand_mode(0)`, `obj.rand_mode(0)` | `obj.c.constraint_mode(0)`, `obj.constraint_mode(0)` |
| Function form | `obj.v.rand_mode()` returns 0/1 | `obj.c.constraint_mode()` returns 0/1 |
| Typical use | Hold a field at a directed value | Remove a rule, for example for error injection |

> **Interview trap:** "I switched off `rand_mode` for `addr` and set it to an illegal value, but `randomize()` fails. Why?" Because constraints on a non-random variable are still checked. Either set a legal value or also switch off the constraint.

> **Interview trap:** "What does `randomize()` do when all variables have `rand_mode(0)`?" It still runs: it checks that the current values satisfy all active constraints and returns 1 or 0. Nothing is changed. This is the same as `randomize(null)` (Section 4.4).

> **Common mistake:** Calling `rand_mode()` on a property that is not declared `rand`. That is a compile error. To make a non-random property random for one call, pass it as an argument: `obj.randomize(prop)`.

### Interview questions

**Q1. What does `rand_mode(0)` do?**
It makes a `rand` or `randc` variable inactive: `randomize()` no longer assigns it, and it behaves as a state variable holding its current value.

**Q2. What is the difference between `rand_mode()` and `constraint_mode()`?**
`rand_mode()` enables or disables the randomization of variables; `constraint_mode()` enables or disables constraint blocks. A variable with `rand_mode` off is still checked against the constraints.

**Q3. How do you fix one field to a specific value and randomize the others?**
Either `obj.field.rand_mode(0); obj.field = value;` and then `obj.randomize()`, or more simply `obj.randomize() with { field == value; }`. The inline form is preferred because nothing has to be switched back afterwards.

**Q4. Can `rand_mode()` be used on a non-`rand` variable?**
No. It is a compile error.

## 4.4 Inline Constraints: randomize() with, and Conditional Randomization

### In plain English

Sometimes one particular call needs one extra rule: "this time the address must be `0x40`". Creating a derived class or a new constraint block for that is too heavy. `randomize() with { ... }` adds constraints **for this call only**.

### Syntax

```systemverilog
if (!txn.randomize() with { addr == 16'h0040; len inside {[1:4]}; })
  $fatal(1, "randomize failed");

txn.randomize() with { a > b; };                  // any constraint item is allowed
txn.randomize() with { soft len == 2; };          // soft inline constraint
txn.randomize() with { foreach (d[i]) d[i] != 0; };
txn.randomize(addr, len);                         // randomize only the listed variables
txn.randomize(addr) with { addr < 100; };         // both features together
txn.randomize(null);                              // randomize nothing: check only
```

### Rules for inline constraints

| Rule | Detail |
|---|---|
| Lifetime | Apply to that single call |
| Combination | They are **added** to the active class constraints. They do not replace them |
| Conflict with a hard class constraint | The call fails. To override a class constraint, disable it, make it soft, or override it in a derived class |
| Priority | A `soft` inline constraint outranks all `soft` class constraints |
| Content | Everything allowed in a constraint block: expressions, `inside`, `dist`, `->`, `if`-`else`, `foreach`, `unique`, `solve before`, `soft`, `disable soft` |
| Name lookup | Names inside the braces are looked up **first in the class of the object being randomized**, then in the scope containing the call |

### The name-lookup trap and local::

```systemverilog
task automatic send(bit [7:0] addr);                       // a local variable named addr
  bus_txn t = new();
  void'(t.randomize() with { addr == addr; });             // WRONG
  void'(t.randomize() with { addr == local::addr; });      // RIGHT
endtask
```

In the first call both `addr` names are resolved in the class `bus_txn`. The constraint is `t.addr == t.addr`, which is always true and restricts nothing. `local::` forces the name to be resolved in the scope where `randomize()` is called, so `local::addr` is the task argument. The bug is silent: no error, no warning, just an address that is not the one requested.

### Randomizing only some variables: randomize(args)

| Call | Random variables in this call | Everything else |
|---|---|---|
| `obj.randomize()` | All `rand`/`randc` properties with `rand_mode` on | State |
| `obj.randomize(a, b)` | Exactly `a` and `b`, **even if they are not declared `rand`** | State, including the properties that are declared `rand` |
| `obj.randomize(null)` | None | State |

- The arguments must be properties of the object.
- All active constraints still apply. Variables not listed are treated as constants and must already satisfy them.
- `randomize(null)` turns `randomize()` into a **checker**: it returns 1 if the current values of the object satisfy all active constraints and 0 otherwise, without changing anything.

### Complete example

```systemverilog file=tb_inline.sv
module tb_inline;

  class bus_txn;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    bit [7:0]      tag;                       // not declared rand
    constraint addr_c { addr inside {[0:99]}; }
  endclass

  bus_txn t;
  int     status;

  task automatic send(bit [7:0] addr);
    status = t.randomize() with { addr == local::addr; };
    $display("2. local::addr=%0d  : status=%0d t.addr=%0d", addr, status, t.addr);
  endtask

  initial begin
    t = new();

    status = t.randomize() with { addr == 42; data == 8'hFF; };
    $display("1. inline         : status=%0d addr=%0d data=%h", status, t.addr, t.data);

    send(17);

    status = t.randomize() with { addr == 150; };
    $display("3. conflict       : status=%0d t.addr=%0d", status, t.addr);

    t.data = 8'hAA;
    status = t.randomize(addr) with { addr == 5; };
    $display("4. randomize(addr): status=%0d addr=%0d data=%h", status, t.addr, t.data);

    status = t.randomize(tag) with { tag == 8'h3C; };
    $display("5. randomize(tag) : status=%0d tag=%h addr=%0d", status, t.tag, t.addr);

    status = t.randomize(null);
    $display("6. check, addr=5  : status=%0d", status);
    t.addr = 150;
    status = t.randomize(null);
    $display("7. check, addr=150: status=%0d addr=%0d", status, t.addr);
  end

endmodule
```

```output
1. inline         : status=1 addr=42 data=ff
2. local::addr=17  : status=1 t.addr=17
3. conflict       : status=0 t.addr=17
4. randomize(addr): status=1 addr=5 data=aa
5. randomize(tag) : status=1 tag=3c addr=5
6. check, addr=5  : status=1
7. check, addr=150: status=0 addr=150
```

Simulator failure messages accompany lines 3 and 7.

**Line by line**

| Line | Explanation |
|---|---|
| 1 | Two inline constraints pin both fields. The class constraint `addr_c` also holds (42 is within 0 to 99). |
| 2 | `local::addr` is the task argument (17). Without `local::`, both names would mean `t.addr` and the address would be any value from 0 to 99. |
| 3 | `addr == 150` conflicts with the hard class constraint. The call fails and `t.addr` keeps its previous value, 17. |
| 4 | Only `addr` is randomized. `data` is a state variable in this call and keeps `AA`. |
| 5 | `tag` is not declared `rand`, but naming it as an argument makes it the random variable for this call. `addr` is state and stays 5. |
| 6 | `randomize(null)` only checks. `addr` = 5 satisfies `addr_c`. |
| 7 | `addr` = 150 violates `addr_c`: the check returns 0. Nothing is modified. |

### Conditional randomization: the complete toolbox

"Conditional randomization" means that what is generated depends on a condition: a mode, a test phase, a previous value. SystemVerilog offers several ways. Choosing among them is a common design question.

| Technique | Where the condition lives | Example | Use when |
|---|---|---|---|
| Implication / `if`-`else` on a **random** variable | Inside the solve | `(kind == RD) -> (len == 0);` | The condition is itself part of the random choice |
| `if`-`else` on a **state** variable (knob) | Class property set by the test | `if (cfg_short) len < 8; else len < 64;` | A test or configuration object selects a mode |
| Weight knobs in a `dist` | Class property | `err dist {1 := err_pct, 0 := 100 - err_pct};` | The condition is "how often" |
| `constraint_mode()` | Call from the test or from `pre_randomize()` | `txn.legal_c.constraint_mode(0);` | A whole rule is switched for a test or a phase |
| `rand_mode()` | Call from the test | `txn.kind.rand_mode(0);` | A field must stay at a directed value |
| Inline `with` | At the call | `randomize() with { kind == WR; }` | A one-off requirement of a single call |
| Procedural selection | Around the call | `if (first) txn.randomize() with {...}; else txn.randomize();` | The condition depends on testbench state or history |
| Derived class with overriding constraints | Class hierarchy | `class err_txn extends txn;` | A reusable variant used by many tests (Section 4.7) |

```systemverilog
class cfg_txn;
  rand bit [7:0] len;
  rand bit       err;
  bit            cfg_short;                 // knob set by the test
  int unsigned   err_pct = 5;               // knob: percentage of errors

  constraint len_c { if (cfg_short) len inside {[1:8]}; else len inside {[1:64]}; }
  constraint err_c { err dist {1 := err_pct, 0 := 100 - err_pct}; }
endclass
```

> **Interview trap:** "Do inline constraints override class constraints?" No, they are added. A hard inline constraint that contradicts a hard class constraint causes a failure.

> **Interview trap:** "What does `obj.randomize() with { x == x; }` do when the calling scope also has a variable `x`?" Both names refer to `obj.x`, so the constraint is always true. `local::x` is needed to reach the outer variable.

> **Common mistake:** Using `obj.randomize(null)` and expecting random values. With `null`, nothing is randomized.

> **Verification application:** A directed-random test body in a generator: `repeat (20) begin txn = new(); if (!txn.randomize() with { op == ALU_ADD; a + b > 255; }) $fatal(1, "randomize failed"); gen2drv_mbx.put(txn); end`. It produces twenty additions that overflow, with everything else left random.

### Interview questions

**Q1. What is an inline constraint?**
A constraint supplied at the call with `randomize() with { ... }`. It applies to that call only and is solved together with the class's own active constraints.

**Q2. What happens if an inline constraint conflicts with a class constraint?**
If both are hard, `randomize()` returns 0. If the class constraint is soft, it is dropped and the inline constraint wins.

**Q3. What is `local::` used for?**
Inside a `with` block, names are resolved first in the randomized object's class. `local::name` forces resolution in the calling scope, which is needed when a local variable or argument has the same name as a class property.

**Q4. What does `obj.randomize(a)` do?**
It randomizes only the property `a`, treating all other properties as state variables for this call. `a` need not be declared `rand`.

**Q5. What does `obj.randomize(null)` do?**
It randomizes nothing and returns 1 if the object's current values satisfy all active constraints, otherwise 0. It is used as a checker.

**Q6. How would you generate 10 transactions where the first is a reset command and the rest are random?**
Procedurally: in the loop, for the first iteration call `randomize() with { kind == RESET; }`, and for the others plain `randomize()`. Or keep a state variable `is_first` in the class and write `is_first -> kind == RESET;`.

**Q7. How can a test change the percentage of error packets without modifying the transaction class?**
The class uses a non-random weight variable in a `dist`, for example `err dist {1 := err_pct, 0 := 100 - err_pct};`, and the test sets `err_pct`.
