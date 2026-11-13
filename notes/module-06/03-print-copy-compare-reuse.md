# Part 3: Printing, Copying, Comparing and Reusing Transactions

## 3.1 Transaction Printing

### In plain English

When a test fails, the first thing you read is the log file, not the waveform. A good log tells the story of the simulation in transactions: "generator created #17: SUB 5, 10", "monitor observed #17: result 1FB", "scoreboard: #17 PASS". For that, every transaction must be able to describe itself in one readable line.

### Technical definition

A print method is a member function of the transaction class that displays the values of its properties in a fixed, readable format. It is normally split in two:

- `convert2string()` returns the formatted text as a `string` and prints nothing.
- `print(tag)` displays that string, with the simulation time and a caller-supplied tag.

### Why two methods?

| Reason | Explanation |
|---|---|
| Reuse of the formatting | The same text is needed in `print`, in `$error` messages from the scoreboard, and sometimes in files. Building it once in `convert2string()` avoids three copies of the format string |
| Control of the output | The caller decides whether to display it, pass it to `$error`, write it to a file or ignore it |
| Extension | A derived class with one more field overrides `convert2string()`, calls `super.convert2string()` and appends its field; `print()` needs no change |

### Why not just use $display in each component?

Without a print method, the driver, monitor and scoreboard each contain their own `$display` with their own format. When a field is added to the transaction, each one has to be found and edited, and the log shows the same data in three different layouts. With a print method there is one format and one place to change it.

### Syntax

```systemverilog
virtual function string convert2string();
  return $sformatf("id=%0d op=%s a=0x%h b=0x%h result=0x%h", id, op.name(), a, b, result);
endfunction

virtual function void print(string tag = "");
  $display("[%0t] %s: %s", $time, tag, convert2string());
endfunction
```

`$sformatf` works like `$display` but returns the formatted text as a string instead of printing it (Module 3). The methods are `virtual` so that a derived transaction's version is used even when the object is reached through a base-class handle (Module 4).

### Complete example

```systemverilog file=tb_txn_print.sv
module tb_txn_print;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function string convert2string();
      return $sformatf("id=%0d op=%s a=0x%h b=0x%h result=0x%h",
                       id, op.name(), a, b, result);
    endfunction

    virtual function void print(string tag = "");
      $display("[%0t] %s: %s", $time, tag, convert2string());
    endfunction
  endclass

  alu_txn t;

  initial begin
    t    = new();
    t.id = 1;
    t.op = ALU_ADD;
    t.a  = 8'd200;
    t.b  = 8'd100;
    t.print("GEN");

    #10;
    t.result = 9'd300;
    t.print("MON");

    $display("SCB: unexpected result in {%s}", t.convert2string());
  end

endmodule
```

```output
[0] GEN: id=1 op=ALU_ADD a=0xc8 b=0x64 result=0xxxx
[10] MON: id=1 op=ALU_ADD a=0xc8 b=0x64 result=0x12c
SCB: unexpected result in {id=1 op=ALU_ADD a=0xc8 b=0x64 result=0x12c}
```

**Line by line**

| Line | Explanation |
|---|---|
| `$sformatf(...)` | Builds the string. `%s` with `op.name()` prints the opcode name; `%h` prints each field in hex at its full width (two digits for 8 bits, three for 9 bits). |
| `t.print("GEN");` | The tag identifies the component that printed. At time 0 the result has not been captured: the three hex digits are `xxx`, shown after the literal `0x`. |
| `#10; t.result = 9'd300;` | Stands in for the monitor capturing the DUT output. 300 is `12c` in hex. |
| `t.print("MON");` | Same object, same format, different tag and time. |
| Last `$display` | The scoreboard embeds the same text in its own message by calling `convert2string()` directly. |

### What a good print method includes

| Include | Reason |
|---|---|
| The transaction ID | To follow one transaction through the generator, driver, monitor and scoreboard lines |
| Enum fields by name | `ALU_SUB` is understood at a glance; `1` is not |
| Data in hex, counts in decimal | Convention; hex shows bit patterns and X clearly |
| Everything on one line | So that `grep` on the log returns complete transactions |
| A fixed field order and fixed labels | So that logs can be compared and searched |
| Simulation time and a component tag | Supplied by `print`, not by `convert2string` |

`$display("%p", t)` also prints the properties of an object in most simulators and is handy for a quick debug session, but its layout differs between tools and it cannot be customised, so it does not replace a print method.

> **Common mistake:** Printing every transaction unconditionally. A regression with a million transactions produces gigabytes of log and runs much slower. Real testbenches print through a verbosity control (for example `if (verbosity >= HIGH) t.print("DRV");`), which is one of the services UVM's reporting macros provide.

### Interview questions

**Q1. Why does a transaction class need a print method?**
So that every component reports transactions in one consistent, readable format, the format is maintained in one place, and logs can be used for debugging without opening waveforms.

**Q2. What is the difference between `print()` and `convert2string()`?**
`convert2string()` returns the formatted contents as a string without displaying anything. `print()` displays it. `print()` is normally implemented by calling `convert2string()`.

**Q3. What is the difference between `$display`, `$sformatf` and `$sformat`?**
`$display` prints to the log. `$sformatf` is a function that returns the formatted string. `$sformat` is a task that writes the formatted string into a string variable given as its first argument.

**Q4. How do you print an enum field by name?**
With its `name()` method and `%s`.

**Q5. Why are the print methods declared `virtual`?**
So that when a derived transaction with additional fields is handled through a base-class handle, the derived class's version runs and the additional fields are printed.

## 3.2 Transaction Copying

### In plain English

A class variable does not contain an object. It contains a **handle**, a reference to an object (Module 4). The assignment `t2 = t1;` therefore does not make a second transaction; it makes a second name for the same transaction. Change a field through `t2` and `t1` sees the change, because there is only one object.

In a testbench, transactions are handed from component to component and stored in queues and mailboxes. If two places hold a handle to the same object and one of them modifies it, the other is corrupted. A **copy** method creates a genuinely separate object with the same field values, so that each holder has its own.

### Technical definition

A copy method is a member function that constructs a new object of the class, assigns the value of every property of the current object to it, and returns the handle of the new object.

```systemverilog
virtual function alu_txn copy();
  alu_txn c = new();
  c.a      = a;
  c.b      = b;
  c.op     = op;
  c.result = result;
  c.id     = id;
  return c;
endfunction
```

### How it works internally

```text
   Handle assignment           t2 = t1;

      t1 ----+
             +---->  [ object:  id=1  op=ADD  a=200  b=100 ]      ONE object, two handles
      t2 ----+


   Copy                        t2 = t1.copy();

      t1 --------->  [ object:  id=1  op=ADD  a=200  b=100 ]      TWO objects
      t2 --------->  [ object:  id=1  op=ADD  a=200  b=100 ]      same contents, independent
```

### The three ways to "copy", compared

| Operation | Syntax | What is created | Fields that are handles to other objects | Use |
|---|---|---|---|---|
| Handle assignment | `t2 = t1;` | Nothing; a second reference | Not applicable | Passing an object on when the sender will not touch it again |
| Shallow copy | `t2 = new t1;` | A new object; every property copied as it is | The **handle** is copied, so the inner object is shared | Classes with no handle properties |
| Deep copy (user-written `copy()`) | `t2 = t1.copy();` | A new object | The method also copies each inner object | Any class; the standard choice for transactions |

For `alu_txn`, which contains only plain values, the shallow copy `new t1` and the hand-written `copy()` produce the same result. A `copy()` method is still written, for three reasons: it is the place where inner objects get copied when the class grows; it can be made `virtual` so that it works through a base handle; and it gives every transaction class the same interface.

A transaction that contains another object needs the deep copy:

```systemverilog
class frame_txn;
  rand bit [7:0] payload [];      // dynamic array: copied by value on assignment
  hdr_txn        hdr;             // handle to another object

  virtual function frame_txn copy();
    frame_txn c = new();
    c.payload = payload;          // arrays are copied element by element
    c.hdr     = hdr.copy();       // the inner object is copied, not shared
    return c;
  endfunction
endclass
```

Dynamic arrays, queues and associative arrays are **not** handles: assigning one to another copies the elements. Only class handles need the explicit inner `copy()`.

### Where copies are needed in a testbench

| Place | Why a copy is needed |
|---|---|
| Generator that re-randomizes one blueprint object | Each transaction sent to the driver must be a separate object, otherwise the next `randomize()` changes a transaction the driver has not finished with |
| Monitor that reuses one object to collect pin values | Each observed transaction sent to the scoreboard must be a separate object |
| Scoreboard storing expected transactions in a queue | The stored object must not change when the sender reuses or modifies its own |
| Any component that modifies a received transaction | It should modify its own copy, not the object other components still hold |
| One transaction sent to two receivers (scoreboard and coverage) | If either may modify it, each needs its own |

### Complete example: the shared-handle bug

```systemverilog file=tb_txn_copy.sv
module tb_txn_copy;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      return c;
    endfunction
  endclass

  alu_txn t;
  alu_txn q_bad  [$];
  alu_txn q_good [$];

  initial begin
    t = new();
    for (int i = 0; i < 3; i++) begin
      t.id = i;
      t.a  = 10 * i;
      q_bad.push_back(t);             // BUG : the same handle is stored three times
      q_good.push_back(t.copy());     // GOOD: three separate objects are stored
    end

    foreach (q_bad[i])
      $display("q_bad [%0d]: id=%0d a=%0d", i, q_bad[i].id, q_bad[i].a);
    foreach (q_good[i])
      $display("q_good[%0d]: id=%0d a=%0d", i, q_good[i].id, q_good[i].a);

    $display("q_bad[0]  and q_bad[2]  are the same object: %0d", q_bad[0]  == q_bad[2]);
    $display("q_good[0] and q_good[2] are the same object: %0d", q_good[0] == q_good[2]);
  end

endmodule
```

```output
q_bad [0]: id=2 a=20
q_bad [1]: id=2 a=20
q_bad [2]: id=2 a=20
q_good[0]: id=0 a=0
q_good[1]: id=1 a=10
q_good[2]: id=2 a=20
q_bad[0]  and q_bad[2]  are the same object: 1
q_good[0] and q_good[2] are the same object: 0
```

**Line by line**

| Line | Explanation |
|---|---|
| `t = new();` | One object is created, **outside** the loop. |
| `q_bad.push_back(t);` | Stores the handle. After three iterations the queue holds three handles, all referring to the one object. |
| `q_good.push_back(t.copy());` | `copy()` creates a new object holding the current values, and that new object's handle is stored. |
| `q_bad` output | Every entry shows the values from the last iteration (`id=2`, `a=20`), because every entry is the same object and that is what it now contains. |
| `q_good` output | Each entry kept the values it had when it was copied. |
| `q_bad[0] == q_bad[2]` | Comparing two handles with `==` asks "is this the same object?". For the bad queue the answer is 1. |

This is the single most common bug in hand-written generators: every transaction received by the driver is identical to the last one generated. It is asked about in interviews in many forms.

> **Interview trap:** "The generator randomizes ten transactions and puts them in a mailbox, but the driver receives the same transaction ten times. Why?" The generator created one object before the loop and put the same handle into the mailbox ten times. By the time the driver reads them, the object holds the values from the last `randomize()`. Fix: construct a new object inside the loop, or put `t.copy()` into the mailbox.

> **Common mistake:** Adding a field to the transaction and forgetting to add it to `copy()` (and to `compare()` and `convert2string()`). The copy then silently has the default value for that field. Whenever a field is added, update all three methods.

> **Common mistake:** Declaring `copy()` in a derived class without `virtual` in the base class. Calling `copy()` through a base-class handle then runs the base version and the derived fields are lost.

### Interview questions

**Q1. What is the difference between `t2 = t1;` and `t2 = t1.copy();`?**
`t2 = t1;` copies the handle: both variables refer to the same object. `t2 = t1.copy();` creates a second object with the same field values; the two are independent afterwards.

**Q2. What is the difference between a shallow copy and a deep copy?**
A shallow copy (`new t1`) copies every property as it is, so a property that is a handle still refers to the same inner object in both copies. A deep copy also creates copies of the inner objects, so nothing is shared.

**Q3. Why does a testbench need to copy transactions?**
Because objects are passed by handle. If a sender keeps using or re-randomizing an object after passing its handle on, the receiver's data changes underneath it. Copying gives each holder a separate object.

**Q4. Does `copy()` need to handle dynamic arrays specially?**
No. Assigning a dynamic array, queue or associative array copies its elements. Only properties that are class handles need their own `copy()` call.

**Q5. Write a copy method for a transaction with fields `addr`, `data` and `write`.**
`virtual function bus_txn copy(); bus_txn c = new(); c.addr = addr; c.data = data; c.write = write; return c; endfunction`

## 3.3 Transaction Comparison

### In plain English

The scoreboard holds two transactions for each operation: what the DUT **should** have produced (expected) and what the monitor **saw** it produce (actual). It needs to ask "are these the same?". Comparing the two handles is useless, because they are two different objects and the answer is always "no". What must be compared is the **contents**, field by field.

### Technical definition

A compare method is a member function that takes a handle to another object of the same class and returns 1 if every field that is relevant for checking has the same value in both objects, and 0 otherwise.

```systemverilog
virtual function bit compare(alu_txn rhs);
  if (rhs == null) return 0;
  return (a      ==  rhs.a)  &&
         (b      ==  rhs.b)  &&
         (op     === rhs.op) &&
         (result === rhs.result);
endfunction
```

`rhs` stands for "right-hand side": the call `lhs.compare(rhs)` reads like `lhs == rhs`.

### Design decisions inside a compare method

| Decision | Choice for `alu_txn` | Reason |
|---|---|---|
| Which fields are compared? | `a`, `b`, `op`, `result` | These define the operation and its outcome |
| Which fields are ignored? | `id` | Bookkeeping. The expected and actual objects may be numbered by different components |
| Which operator for four-state fields? | `===` | With `==`, an X in `result` makes the comparison X; the function would return 0 here, but only by luck of the conversion to `bit`, and an `if (exp.result != act.result)` written elsewhere would miss the X entirely. `===` gives a definite answer (Module 1, Section 4.5) |
| Which operator for two-state fields? | `==` | No X is possible, so `==` and `===` are equivalent |
| What if `rhs` is `null`? | Return 0 | Accessing a field through a null handle is a fatal run-time error. The check turns a crash into a clean mismatch |
| Should it print? | No, it only returns the verdict | The scoreboard decides what to report. A variant that reports the differing fields is shown below |

### Handle comparison versus content comparison

| Expression | Question it answers | Result for two separate objects with equal fields |
|---|---|---|
| `t1 == t2` | Do both handles refer to the same object? | 0 |
| `t1.compare(t2)` | Do the two objects hold the same values? | 1 |

### Complete example

```systemverilog file=tb_txn_compare.sv
module tb_txn_compare;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a = a;  c.b = b;  c.op = op;  c.result = result;  c.id = id;
      return c;
    endfunction

    virtual function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a      ==  rhs.a)  &&
             (b      ==  rhs.b)  &&
             (op     === rhs.op) &&
             (result === rhs.result);
    endfunction
  endclass

  alu_txn exp, act, same, none;

  initial begin
    exp        = new();
    exp.id     = 1;
    exp.op     = ALU_ADD;
    exp.a      = 8'd200;
    exp.b      = 8'd100;
    exp.result = 9'd300;

    act  = exp.copy();
    same = exp;

    $display("1. exp == act  (handles)       : %0d", exp == act);
    $display("2. exp == same (handles)       : %0d", exp == same);
    $display("3. exp.compare(act)            : %0d", exp.compare(act));

    act.id = 99;
    $display("4. different id                : %0d", exp.compare(act));

    act.result = 9'd301;
    $display("5. different result            : %0d", exp.compare(act));

    act.result = 'x;
    $display("6. result is X                 : %0d", exp.compare(act));
    $display("7. X with == gives %b, with === gives %b",
             exp.result == act.result, exp.result === act.result);

    $display("8. compare with a null handle  : %0d", exp.compare(none));
  end

endmodule
```

```output
1. exp == act  (handles)       : 0
2. exp == same (handles)       : 1
3. exp.compare(act)            : 1
4. different id                : 1
5. different result            : 0
6. result is X                 : 0
7. X with == gives x, with === gives 0
8. compare with a null handle  : 0
```

**Line by line**

| Line | Explanation |
|---|---|
| 1 | `act` is a copy: a different object. Handle equality is 0 even though the contents are identical. |
| 2 | `same = exp;` copied the handle, so both refer to one object: 1. |
| 3 | Content comparison of the copy: all four compared fields match. |
| 4 | `id` is deliberately not compared, so changing it does not cause a mismatch. |
| 5 | 300 versus 301: mismatch. |
| 6 | The DUT output is X. `===` compares X literally against the expected bits and reports a mismatch. |
| 7 | The same comparison with `==` evaluates to X. Inside an `if`, that X would count as false, which is how a scoreboard written with `!=` lets an X output pass. |
| 8 | `none` was never constructed, so it is `null`. The guard at the top of `compare()` returns 0 instead of crashing. |

### A compare method that reports what differs

For debugging it helps to know *which* field mismatched. A common variant returns the verdict and also fills in a message:

```systemverilog
virtual function bit compare_report(alu_txn rhs, output string msg);
  msg = "";
  if (rhs == null) begin
    msg = "rhs is null";
    return 0;
  end
  if (op !== rhs.op)
    msg = {msg, $sformatf(" op: %s vs %s;", op.name(), rhs.op.name())};
  if (a != rhs.a)
    msg = {msg, $sformatf(" a: 0x%h vs 0x%h;", a, rhs.a)};
  if (b != rhs.b)
    msg = {msg, $sformatf(" b: 0x%h vs 0x%h;", b, rhs.b)};
  if (result !== rhs.result)
    msg = {msg, $sformatf(" result: 0x%h vs 0x%h;", result, rhs.result)};
  return (msg == "");
endfunction
```

`{msg, ...}` concatenates strings. The function returns 1 only if no difference was recorded.

> **Interview trap:** "The scoreboard compares `if (exp == act)` and always reports a mismatch, although the waveform is correct. Why?" `exp` and `act` are handles to two different objects, so `==` is always 0. The fields must be compared, with a `compare()` method.

> **Common mistake:** Comparing fields that legitimately differ, such as timestamps or IDs assigned by different components, which produces false failures; or leaving out a field that matters, which produces false passes. Decide field by field, and write the decision down as a comment in the method.

> **Verification application:** In the Module 9 scoreboard the check is three lines: compute `exp_result = alu_predict(act);`, then `if (act.result !== exp_result) $error(...)`, else count a pass. When the expected value is a whole transaction produced by a reference model, the check is `if (!exp.compare(act)) $error(...)`.

### Interview questions

**Q1. Why can two transaction objects not be compared with `==`?**
`==` on class handles tests whether they refer to the same object. Two separate objects with identical contents are not equal by that test. A user-written `compare()` method compares the fields.

**Q2. Which fields would you leave out of `compare()`?**
Bookkeeping that is not part of the functional behaviour: IDs, timestamps, delay fields, debug strings.

**Q3. Why use `===` for the result field?**
The result is sampled from the DUT and may contain X or Z. `===` treats X and Z as values and returns a definite 0 or 1, so an unknown output is reported as a mismatch. `==` would return X.

**Q4. What should `compare()` do if the argument is `null`?**
Return 0 (not equal) before touching any field, to avoid a null-handle run-time error.

**Q5. What is the difference between `copy()` and `compare()` in terms of where they are used?**
`copy()` is used by producers (generator, monitor) to hand out independent objects. `compare()` is used by the checker (scoreboard) to decide pass or fail.

## 3.4 Transaction Reuse

### In plain English

One ALU test wants completely random operations. Another wants only additions that overflow. A third wants only shifts. A fourth, written next year for a wider ALU, needs one extra field. If each of these required editing `alu_txn`, or editing the generator, the testbench would be rewritten for every test and every project.

Reuse means: write the transaction (and the components that use it) **once**, and obtain each new behaviour by **adding** something, never by editing what already works.

### The three levels of reuse

| Level | What is reused | Mechanism |
|---|---|---|
| Across components | One class is used by the generator, driver, monitor, scoreboard and coverage | All components import the same package |
| Across tests | The same environment runs different stimulus | A derived transaction class adds or replaces constraints; the test hands an object of that class to the generator |
| Across projects | The transaction, and the agent built around it, is used wherever the same interface appears | The class is kept free of anything project-specific (no pins, no hierarchy paths, no hard-coded test knowledge) |

### Reuse across tests: inheritance and polymorphism

Three things from Modules 4 and 5 combine here.

1. **A derived class inherits every property, method and constraint** of its base class and may add more.
2. **A constraint block in a derived class with the same name as one in the base class replaces it.** A block with a new name is added to the inherited ones.
3. **A base-class handle can refer to a derived-class object**, and `randomize()` is virtual: called through the base handle, it applies the constraints of the **actual object**.

```systemverilog
// Adds a constraint: all inherited constraints still apply
class alu_carry_txn extends alu_txn;
  constraint carry_c { op == ALU_ADD; a + b > 255; }
endclass

// Replaces a constraint: same block name as in the base class
class alu_shift_txn extends alu_txn;
  constraint op_dist_c { op inside {ALU_SHL, ALU_SHR}; }
endclass
```

In `a + b > 255` the literal `255` is 32 bits wide, so the sum is evaluated in 32 bits and the carry is not lost (Module 1, Section 4.4).

### The blueprint pattern

The generator is written against the base class only. It owns a handle called the **blueprint**. For every transaction it randomizes the blueprint and sends a copy.

```text
   test                                 generator (never edited)
   ----                                 -----------------------------------------------
   alu_carry_txn c = new();             alu_txn blueprint;        // base-class handle
   gen.blueprint = c;      ---------->  repeat (n) begin
                                          blueprint.randomize();  // constraints of the
                                                                  // actual object apply
                                          send(blueprint.copy()); // independent object
                                        end
```

- With a plain `alu_txn` as blueprint, the generator produces the default stimulus.
- With an `alu_carry_txn` as blueprint, the **same generator code** produces only carry-generating additions.

The test changed the behaviour of the whole environment by supplying a different object. This idea, in a more automated form, is the UVM factory override.

### Complete example

```systemverilog file=tb_txn_reuse.sv
module tb_txn_reuse;
  import alu_pkg::*;

  // ---------------- base transaction: written once ----------------
  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
                ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
    }

    virtual function string convert2string();
      return $sformatf("id=%0d op=%s a=0x%h b=0x%h", id, op.name(), a, b);
    endfunction

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a = a;  c.b = b;  c.op = op;  c.result = result;  c.id = id;
      return c;
    endfunction
  endclass

  // ---------------- test-specific transactions: added later ----------------
  class alu_carry_txn extends alu_txn;
    constraint carry_c { op == ALU_ADD; a + b > 255; }           // added
  endclass

  class alu_shift_txn extends alu_txn;
    constraint op_dist_c { op inside {ALU_SHL, ALU_SHR}; }       // replaces the base block
  endclass

  // ---------------- "generator": knows only the base class ----------------
  function automatic void make_stimulus(alu_txn blueprint, int unsigned n,
                                        ref alu_txn out_q[$]);
    for (int unsigned i = 0; i < n; i++) begin
      if (!blueprint.randomize()) $fatal(1, "randomize() failed");
      blueprint.id = i;
      out_q.push_back(blueprint.copy());
    end
  endfunction

  alu_txn       q[$];
  alu_carry_txn carry_bp;
  alu_shift_txn shift_bp;
  int unsigned  n_ok;

  initial begin
    // Test 1: additions with carry
    carry_bp = new();
    make_stimulus(carry_bp, 50, q);
    n_ok = 0;
    foreach (q[i]) if (q[i].op == ALU_ADD && (q[i].a + q[i].b) > 255) n_ok++;
    $display("carry test: %0d of %0d transactions are ADD with carry", n_ok, q.size());
    $display("  first   : %s", q[0].convert2string());

    // Test 2: shifts only
    q.delete();
    shift_bp = new();
    make_stimulus(shift_bp, 50, q);
    n_ok = 0;
    foreach (q[i]) if (q[i].op inside {ALU_SHL, ALU_SHR}) n_ok++;
    $display("shift test: %0d of %0d transactions are shifts", n_ok, q.size());
    $display("  first   : %s", q[0].convert2string());
  end

endmodule
```

Sample output; the two lines beginning with "first" differ per seed and simulator. The two count lines are the same on every run.

```output
carry test: 50 of 50 transactions are ADD with carry
  first   : id=0 op=ALU_ADD a=0xd3 b=0x9a
shift test: 50 of 50 transactions are shifts
  first   : id=0 op=ALU_SHR a=0x47 b=0xe0
```

**Line by line**

| Line | Explanation |
|---|---|
| `class alu_carry_txn extends alu_txn;` | Inherits `a`, `b`, `op`, `result`, `id`, `op_dist_c`, `convert2string()` and `copy()`. Adds one constraint block. |
| `constraint carry_c { op == ALU_ADD; a + b > 255; }` | A new name, so it is solved **together with** the inherited `op_dist_c`. They are compatible because ADD has a non-zero weight there. |
| `constraint op_dist_c { op inside {ALU_SHL, ALU_SHR}; }` | The same name as the base block, so the base block is replaced. If it were only added, it would still work here, but the 2:1 weighting of ADD would be pointless. |
| `function automatic void make_stimulus(alu_txn blueprint, ...)` | The argument type is the base class. The function contains no reference to any derived class. A function with a `ref` argument must be `automatic`. |
| `blueprint.randomize()` | `randomize()` is virtual: the constraints of the object that `blueprint` actually refers to are used. |
| `out_q.push_back(blueprint.copy());` | A separate object for each transaction (Section 3.2). `copy()` here returns a base-class object carrying the randomized values, which is all that the driver needs. |
| `make_stimulus(carry_bp, 50, q);` | A derived handle is passed where a base handle is expected. This upcast is always legal and needs no `$cast`. |
| Count lines | The testbench checks its own stimulus: all 50 satisfy the test's constraint. |

### Extending a transaction with a new field

When a derived transaction adds a field, it overrides the methods and calls the base version with `super` so that nothing is duplicated:

```systemverilog
class alu_delay_txn extends alu_txn;
  rand int unsigned delay;                       // idle cycles before driving
  constraint delay_c { delay inside {[0:5]}; }

  virtual function string convert2string();
    return {super.convert2string(), $sformatf(" delay=%0d", delay)};
  endfunction

  virtual function alu_txn copy();
    alu_delay_txn c = new();
    c.a = a;  c.b = b;  c.op = op;  c.result = result;  c.id = id;
    c.delay = delay;
    return c;                                    // returned through a base-class handle
  endfunction
endclass
```

Because `copy()` and `convert2string()` are virtual, a generator that holds this object through an `alu_txn` handle copies and prints the extra field correctly. A driver that wants to use `delay` obtains a derived handle with `$cast` (Module 4).

### Rules for a reusable transaction

| Rule | Why |
|---|---|
| Declare `copy`, `compare`, `print`, `convert2string` as `virtual` | Derived versions must run through base handles |
| Give each constraint block one purpose and a clear name | Tests override or disable by name |
| Keep only always-true constraints hard in the base class | Anything narrower blocks future tests |
| Use `soft` for defaults that tests may want to change | A test's hard constraint then wins without `constraint_mode` calls |
| No pin names, no hierarchical paths, no interface handles | The class must compile in any environment |
| Put the class in a package | Every component and every test imports the same definition |
| Make the constructor callable with no arguments | Generic code can create it |

> **Common mistake:** Editing the base transaction for each new test ("just add an `if (test_mode == 3)` to the constraint"). After a few tests the base class is a tangle of special cases and a change for one test breaks another. Extend; do not edit.

> **Common mistake:** A derived constraint that contradicts an inherited one. If the base class has `a < 128` and the derived class adds `a > 200` under a **different** block name, both apply and `randomize()` fails. Either replace the base block by using the same name, or switch it off.

### Interview questions

**Q1. How do you create a new test without changing the generator or driver?**
Extend the transaction class, add or replace constraints in the derived class, and have the test give an object of the derived class to the generator as its blueprint. The generator works through a base-class handle, so its code does not change.

**Q2. What happens when a derived class declares a constraint block with the same name as one in the base class?**
The derived block replaces the base block. A block with a different name is added to the inherited constraints.

**Q3. What is the blueprint pattern?**
The generator holds one base-class handle, randomizes that object repeatedly, and sends a copy each time. A test replaces the blueprint object with a derived-class object to change what is generated.

**Q4. Why must `copy()` be virtual?**
The generator calls `copy()` through a base-class handle. If `copy()` were not virtual, the base version would run even for a derived object, and any fields added by the derived class would not be copied.

**Q5. What makes a transaction class reusable in another project?**
It describes only the operation on its interface: no pins, no hierarchy, no project-specific assumptions. Its methods are virtual, its constraints are separated by purpose, and it lives in a package.

## 3.5 The Complete alu_txn Class

This is the final version of the transaction, combining everything from Parts 1 to 3. It is the class used by the layered testbench in Module 9.

### The file

The class is written in a file of its own. The file contains only the class (and the reference-model function described below), and is pulled into a package with `` `include ``. This is the normal industry layout: one class per file, one package that includes them all.

```systemverilog file=alu_txn.sv
// alu_txn.sv
// Not compiled by itself: it is `included inside package alu_tb_pkg,
// which has already imported alu_pkg.

class alu_txn;

  // ---------------- stimulus ----------------
  rand bit [7:0] a;
  rand bit [7:0] b;
  rand alu_op_e  op;

  // ---------------- response ----------------
  logic [8:0]    result;

  // ---------------- bookkeeping ----------------
  int unsigned   id;

  // ---------------- constraints ----------------
  constraint op_dist_c {
    op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
              ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
  }

  constraint corner_c {
    a dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
    b dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
  }

  // ---------------- methods ----------------
  function new();
    op     = ALU_ADD;      // a legal opcode instead of the default X
    result = 'x;           // no response captured yet
  endfunction

  function void post_randomize();
    result = 'x;
  endfunction

  function bit is_unary();
    return op inside {ALU_NOT, ALU_SHL, ALU_SHR};
  endfunction

  virtual function string convert2string();
    return $sformatf("id=%0d op=%s a=0x%h b=0x%h result=0x%h",
                     id, op.name(), a, b, result);
  endfunction

  virtual function void print(string tag = "");
    $display("[%0t] %s: %s", $time, tag, convert2string());
  endfunction

  virtual function alu_txn copy();
    alu_txn c = new();
    c.a      = a;
    c.b      = b;
    c.op     = op;
    c.result = result;
    c.id     = id;
    return c;
  endfunction

  // id is bookkeeping and is deliberately not compared
  virtual function bit compare(alu_txn rhs);
    if (rhs == null) return 0;
    return (a      ==  rhs.a)  &&
           (b      ==  rhs.b)  &&
           (op     === rhs.op) &&
           (result === rhs.result);
  endfunction

endclass


// Reference model: the expected result for the inputs held in a transaction.
// Written from the specification, not copied from the RTL.
function automatic logic [8:0] alu_predict(alu_txn t);
  case (t.op)
    ALU_ADD: return {1'b0, t.a} + {1'b0, t.b};
    ALU_SUB: return {1'b0, t.a} - {1'b0, t.b};
    ALU_AND: return {1'b0, t.a & t.b};
    ALU_OR : return {1'b0, t.a | t.b};
    ALU_XOR: return {1'b0, t.a ^ t.b};
    ALU_NOT: return {1'b0, ~t.a};
    ALU_SHL: return {t.a, 1'b0};
    ALU_SHR: return {2'b00, t.a[7:1]};
    default: return 'x;
  endcase
endfunction
```

```systemverilog file=alu_tb_pkg.sv
// alu_tb_pkg.sv : compile after alu_pkg.sv
package alu_tb_pkg;
  import alu_pkg::*;

  `include "alu_txn.sv"

endpackage
```

In Module 9 the generator, driver, monitor, scoreboard, environment and test classes are added to this package in the same way.

### The reference model function

`alu_predict` answers the question "given these inputs, what must the result be?". It is a first, small example of a **reference model**: an independent description of the DUT's function, written at a higher level and used by the scoreboard to produce the expected value. Section 4.10 discusses it further. Points to notice:

| Code | Explanation |
|---|---|
| `{1'b0, t.a} + {1'b0, t.b}` | Both operands are widened to nine bits, so the carry appears in bit 8, as the specification requires. |
| `{1'b0, t.a} - {1'b0, t.b}` | Nine-bit subtraction. When `a < b` the result wraps and bit 8 is 1, which is the borrow. |
| `{1'b0, ~t.a}` | The inversion is done on eight bits and then a zero is placed in bit 8. Writing `~{1'b0, t.a}` would set bit 8 to 1, which is wrong. |
| `default: return 'x;` | An unknown opcode gives an unknown prediction, so the comparison with `!==` reports it. |

### Using the class

```systemverilog file=tb_alu_txn_final.sv
// Compile order: alu_pkg.sv, alu_tb_pkg.sv (which includes alu_txn.sv), this file
module tb_alu_txn_final;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  int unsigned n;
  alu_txn      t, c;

  function automatic void show(alu_op_e op, bit [7:0] a, bit [7:0] b);
    alu_txn x = new();
    x.id     = n++;
    x.op     = op;
    x.a      = a;
    x.b      = b;
    x.result = alu_predict(x);
    x.print("EXP");
  endfunction

  initial begin
    show(ALU_ADD, 8'd200, 8'd100);
    show(ALU_SUB, 8'd5,   8'd10);
    show(ALU_AND, 8'hF0,  8'h3C);
    show(ALU_NOT, 8'h0F,  8'h00);
    show(ALU_SHL, 8'h81,  8'h00);
    show(ALU_SHR, 8'h81,  8'h00);

    t = new();
    $display("new object     : %s  unary=%0d", t.convert2string(), t.is_unary());

    if (!t.randomize() with { op == ALU_XOR; a == 8'hAA; b == 8'h0F; })
      $fatal(1, "randomize() failed");
    t.result = alu_predict(t);
    c = t.copy();
    $display("copy equal     : %0d", t.compare(c));
    c.result = 'x;
    $display("X result equal : %0d", t.compare(c));
    t.print("XOR");
  end

endmodule
```

```output
[0] EXP: id=0 op=ALU_ADD a=0xc8 b=0x64 result=0x12c
[0] EXP: id=1 op=ALU_SUB a=0x05 b=0x0a result=0x1fb
[0] EXP: id=2 op=ALU_AND a=0xf0 b=0x3c result=0x030
[0] EXP: id=3 op=ALU_NOT a=0x0f b=0x00 result=0x0f0
[0] EXP: id=4 op=ALU_SHL a=0x81 b=0x00 result=0x102
[0] EXP: id=5 op=ALU_SHR a=0x81 b=0x00 result=0x040
new object     : id=0 op=ALU_ADD a=0x00 b=0x00 result=0xxxx  unary=0
copy equal     : 1
X result equal : 0
[0] XOR: id=0 op=ALU_XOR a=0xaa b=0x0f result=0x0a5
```

**Checking the predictions by hand**

| Operation | Calculation | Result |
|---|---|---|
| ADD 200, 100 | 300 = `1_0010_1100` | `12c` (bit 8 = carry) |
| SUB 5, 10 | 5 - 10 = -5; in nine bits 512 - 5 = 507 = `1_1111_1011` | `1fb` (bit 8 = borrow) |
| AND F0, 3C | `1111_0000 & 0011_1100` = `0011_0000` | `030` |
| NOT 0F | `~0000_1111` = `1111_0000`, bit 8 = 0 | `0f0` |
| SHL 81 | `{1000_0001, 0}` = `1_0000_0010` | `102` |
| SHR 81 | `{00, 1000_000}` = `0_0100_0000` | `040` |
| XOR AA, 0F | `1010_1010 ^ 0000_1111` = `1010_0101` | `0a5` |

**Points to notice**

| Code | Explanation |
|---|---|
| `alu_txn x = new();` inside `show` | A declaration with an initialiser is safe here because the function is `automatic`: the initialiser runs on every call. |
| "new object" line | The constructor has set `op` to a legal value; `result` is X. |
| `randomize() with { op == ALU_XOR; a == 8'hAA; b == 8'h0F; }` | Inline constraints that pin every field. It shows that the class constraints (`op_dist_c`, `corner_c`) allow these values, and makes the output predictable. |
| `t.result = alu_predict(t);` | Must come **after** `randomize()`, because `post_randomize()` sets `result` to X. |
| "X result equal" | The copy's result is corrupted to X; `compare()` uses `===` and reports the difference. |

> **Common mistake:** Writing `alu_txn x = new();` as a declaration inside a `begin`...`end` block of an `initial` block in a module. Variables there are static by default, so the initialiser runs **once**, before time 0, and not each time the block is entered; a loop would then reuse one object (the shared-handle bug again), and some simulators reject the declaration unless `static` or `automatic` is written explicitly. In module-level code, declare the handle and call `new()` in a separate statement, or declare it `automatic`.

### Interview questions

**Q1. Describe the transaction class you would write for an ALU.**
`rand bit [7:0] a, b;` and `rand alu_op_e op;` for stimulus; `logic [8:0] result;` for the response; an `id` for tracking. Constraint blocks for the opcode distribution and corner-value bias. Methods: constructor, `convert2string`, `print`, `copy`, `compare`, all virtual, and `post_randomize` to clear the result.

**Q2. Why is the class placed in a package?**
So that there is exactly one definition, imported by the testbench top, the tests and every component. Classes declared separately in two scopes are different types even if their text is identical.

**Q3. What is a reference model?**
An independent, usually untimed, model of the DUT's function that computes the expected output from the same inputs the DUT received. The scoreboard compares its output with the actual DUT output.

**Q4. Why must the reference model not be copied from the RTL?**
If the same code, or the same misunderstanding, is in both, they agree with each other even when both are wrong, and the bug is not found. The model is written from the specification, preferably by a different person and in a different style.
