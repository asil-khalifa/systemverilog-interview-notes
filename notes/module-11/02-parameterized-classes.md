# Part 2: Generic Code

## 2.1 Parameterized Classes

### In plain English

Suppose you write a class that is a stack of integers. Next week you need a stack of strings, then a stack of transactions. The logic (push, pop, full, empty) is identical every time; only the **type of the thing stored** changes. Copying the class and editing the type by hand gives three classes to maintain.

A **parameterized class** is a class written with a blank in it. The blank is filled in when the class is used: "a stack of `int`", "a stack of `string`, at most 16 deep". You write the logic once.

You have already used one: `mailbox #(alu_txn)` from M7 is the built-in `mailbox` class with its type blank filled in by `alu_txn`.

### Technical definition

A parameterized class is a class declared with a **parameter port list** `#( ... )`. Parameters are of two kinds:

- a **value parameter**, a compile-time constant such as a width or a depth: `int DEPTH = 8`;
- a **type parameter**, introduced by the keyword `type`, which stands for a data type: `type T = int`.

Supplying actual values for the parameters is called **specialising** the class. Each distinct combination of parameter values produces a distinct class type, called a **specialisation**. The parameterized class itself is called a **generic class**; it is a template, not a type.

### Why it is needed

| Need | Without parameters | With parameters |
|---|---|---|
| Same container for different element types | One copy of the class per type | `stack #(int)`, `stack #(string)`, `stack #(alu_txn)` |
| Same component for different bus widths | One copy per width, or the widest width everywhere | `bus_driver #(32)`, `bus_driver #(64)` |
| Type safety | A typeless container accepts anything; mistakes appear at run time | The compiler rejects a wrong type at compile time |
| Reusable verification libraries | Impossible without knowing the user's types | The user's transaction type is passed as a parameter. All of UVM's TLM ports, `uvm_driver`, `uvm_sequencer` and `uvm_config_db` are parameterized classes |

### Syntax

```systemverilog
// Declaration
class stack #(type T = int, int DEPTH = 8);
  T items [$];
  ...
endclass

// Use (specialisation)
stack #(byte, 16)            s1;    // parameters by position
stack #(.T(string))          s2;    // parameters by name; DEPTH keeps its default (8)
stack #()                    s3;    // all defaults: T = int, DEPTH = 8
stack                        s4;    // also the default specialisation, when every
                                    // parameter has a default
typedef stack #(alu_txn, 32) txn_stack_t;      // a short name for a specialisation
txn_stack_t                  s5;
```

Rules:

- Parameters are constants fixed at compile (elaboration) time. They cannot be changed at run time and cannot depend on run-time values.
- A parameter without a default value must be supplied in every specialisation.
- Inside the class, a type parameter is used exactly like a type name, and a value parameter exactly like a `localparam`.
- The keyword `parameter` is optional in the list: `#(parameter type T = int)` and `#(type T = int)` are the same.

### How it works internally

```text
   Source                                     What the compiler creates
   ------                                     -------------------------
   class stack #(type T = int,                (a template: no code is generated for it)
                 int DEPTH = 8); ...

   stack #(int, 8)     a;   ----+
   stack               b;   ----+----->   class stack#(int,8)      one static "instances"
   stack #()           c;   ----+

   stack #(string, 2)  d;   ---------->   class stack#(string,2)   its own "instances"

   stack #(int, 16)    e;   ---------->   class stack#(int,16)     its own "instances"

   - Same parameter values  -> the SAME class type  -> handles are assignment compatible.
   - Different values       -> DIFFERENT, unrelated class types -> handles NOT compatible.
   - Static members exist once PER SPECIALISATION, not once for the generic class.
```

The compiler generates a separate class for every distinct set of parameter values that the code uses, as if you had written each one by hand. This has three consequences that interviewers probe:

1. **Specialisations are unrelated types.** `stack #(int)` and `stack #(string)` have no common base class. A handle of one cannot be assigned to, or `$cast` to, the other.
2. **Static members are per specialisation.** A `static int instances` in the generic class becomes one variable in `stack #(int, 8)` and a different variable in `stack #(string, 2)`.
3. **Errors may appear only when a specialisation is created.** If the class body calls `item.print()`, the generic class compiles, `stack #(alu_txn)` compiles (the transaction has `print`), and `stack #(int)` fails, because an `int` has no methods.

### Complete example

```systemverilog file=tb_param_class.sv
class stack #(type T = int, int DEPTH = 4);

  static int instances = 0;
  local  T   items [$];

  function new();
    instances++;
  endfunction

  function bit push(T item);
    if (items.size() >= DEPTH) return 0;      // full
    items.push_back(item);
    return 1;
  endfunction

  function bit pop(output T item);
    if (items.size() == 0) return 0;          // empty
    item = items.pop_back();
    return 1;
  endfunction

  function int size();
    return items.size();
  endfunction

endclass

module tb_param_class;

  typedef stack #(string, 2) str_stack_t;

  stack           int_stk;      // default specialisation: T = int, DEPTH = 4
  stack #(int, 4) int_stk2;     // the same type as int_stk
  str_stack_t     str_stk;

  int    i;
  string s;

  initial begin
    int_stk  = new();
    int_stk2 = new();
    str_stk  = new();

    for (int k = 1; k <= 5; k++)
      if (!int_stk.push(k * 10)) $display("1. push(%0d) rejected: stack is full", k * 10);

    void'(int_stk.pop(i));
    $display("2. popped %0d, size is now %0d", i, int_stk.size());

    void'(str_stk.push("alpha"));
    void'(str_stk.push("beta"));
    if (!str_stk.push("gamma")) $display("3. push(gamma) rejected: DEPTH is 2");
    void'(str_stk.pop(s));
    $display("4. popped %s", s);

    $display("5. stack #(int, 4)::instances = %0d", stack #(int, 4)::instances);
    $display("6. str_stack_t::instances     = %0d", str_stack_t::instances);

    int_stk2 = int_stk;         // legal: both handles have the same specialisation
    // str_stk = int_stk;       // ILLEGAL: different specialisations are different types
  end

endmodule
```

```output
1. push(50) rejected: stack is full
2. popped 40, size is now 3
3. push(gamma) rejected: DEPTH is 2
4. popped beta
5. stack #(int, 4)::instances = 2
6. str_stack_t::instances     = 1
```

**Line by line**

| Code | Explanation |
|---|---|
| `class stack #(type T = int, int DEPTH = 4);` | One type parameter and one value parameter, both with defaults. |
| `static int instances = 0;` | A static counter. It exists once per specialisation. |
| `local T items [$];` | A queue whose element type is the parameter. `local` hides it from users of the class (M4). |
| `function bit push(T item);` | The argument type is the parameter. For `stack #(string)` this is `push(string item)`. |
| `if (items.size() >= DEPTH) return 0;` | The value parameter is used like a constant. |
| `function bit pop(output T item);` | Returns the status as the function value and the popped element through an `output` argument. |
| `typedef stack #(string, 2) str_stack_t;` | A name for the specialisation "stack of strings, depth 2". |
| `stack int_stk;` and `stack #(int, 4) int_stk2;` | Both are the specialisation `T = int, DEPTH = 4` (the second one just writes the defaults out), so they are the same type. |
| The `for` loop, line 1 | Pushes 10, 20, 30, 40. The fifth push finds four items and `DEPTH` = 4, so it returns 0. |
| Line 2 | A stack is last-in first-out: the last value pushed, 40, comes out. Three remain. |
| Lines 3 and 4 | The string stack has `DEPTH` = 2, so the third push is rejected. `beta` was pushed last and is popped first. |
| Line 5 | Two objects of the `(int, 4)` specialisation were constructed (`int_stk` and `int_stk2`), so its counter is 2. |
| Line 6 | One object of the `(string, 2)` specialisation was constructed. Its counter is separate. |
| `int_stk2 = int_stk;` | Allowed because the types are identical. |
| `// str_stk = int_stk;` | Would be a compile error: the two classes are unrelated. |

### The unadorned-name rule for ::

Inside a declaration, the bare name `stack` means the default specialisation. With the scope resolution operator it does not: from outside the class, `stack::instances` is illegal, because the compiler cannot tell which specialisation is meant.

```systemverilog
stack #()::instances              // legal: the default specialisation, written explicitly
stack #(int, 4)::instances        // legal
str_stack_t::instances            // legal: through a typedef
// stack::instances               // ILLEGAL outside the class
```

### Parameterized classes and inheritance

```systemverilog
class base_item;                                  // an ordinary class
endclass

// 1. A parameterized class derived from an ordinary class.
//    Every specialisation shares the base, so base_item handles can refer to any of them.
class typed_item #(type T = int) extends base_item;
  T value;
endclass

// 2. A parameterized class derived from a parameterized class; parameters are passed up.
class bounded_stack #(type T = int, int DEPTH = 8) extends stack #(T, DEPTH);
endclass

// 3. An ordinary class derived from one specialisation.
class int_stack extends stack #(int, 16);
endclass

// 4. The base class itself is a parameter (a "mixin").
class with_logging #(type BASE = base_item) extends BASE;
  function void log(string msg);  $display("[LOG] %s", msg);  endfunction
endclass
```

Pattern 1 is the standard answer to "specialisations are unrelated, so how do I store them in one array?": give them a common **non-parameterized base class** and declare the array with the base type. UVM uses this everywhere; for example every `uvm_sequencer #(REQ)` extends the non-parameterized `uvm_sequencer_base`.

### Static utility methods

A parameterized class with only static methods acts as a generic function library. No object is ever created; the methods are called through the specialisation name.

```systemverilog
class math_util #(type T = int);
  static function T max(T a, T b);
    return (a > b) ? a : b;
  endfunction
  static function T min(T a, T b);
    return (a < b) ? a : b;
  endfunction
endclass

// usage
int  m = math_util #(int)::max(3, 7);           // 7
real r = math_util #(real)::min(2.5, 1.5);      // 1.5
```

This is exactly the shape of UVM's `uvm_config_db #(T)::set(...)` and `uvm_config_db #(T)::get(...)` (Section 5.6): a parameterized class used only for its static methods.

### Value parameter versus type parameter

| Property | Value parameter | Type parameter |
|---|---|---|
| Declared as | `int WIDTH = 8`, `bit SIGNED = 0` | `type T = int` |
| Stands for | A constant value | A data type |
| Used inside the class as | A constant (array bounds, widths, limits) | A type (variables, arguments, return types, queue elements) |
| Typical use | Bus width, depth, number of channels | Transaction type, element type, base class |
| Example specialisation | `bus_driver #(32)` | `mailbox #(alu_txn)` |

### Parameterized class versus related constructs

| Construct | What varies | Decided | Example |
|---|---|---|---|
| Parameterized module | Widths, depths, types of hardware | Elaboration | `fifo #(.DEPTH(16)) u_fifo (...)` |
| Parameterized class | Types and constants of a class | Compile / elaboration | `stack #(alu_txn)` |
| Inheritance and polymorphism (M4) | Behaviour, through virtual methods | Run time (which object the handle refers to) | `base_txn h = new_derived;` |
| `typedef` | Nothing; it only names a type | Compile | `typedef stack #(alu_txn) txn_stack_t;` |

Parameterization and polymorphism solve different problems. Parameterization gives **the same code for different types**, fixed at compile time. Polymorphism gives **different code behind the same handle type**, chosen at run time. Real libraries use both together.

> **Interview trap:** "A parameterized class has `static int count`. `C #(int)` is constructed three times and `C #(bit)` twice. What is `count`?" There is no single `count`. `C #(int)::count` is 3 and `C #(bit)::count` is 2. If one shared counter is wanted, put it in a non-parameterized base class.

> **Interview trap:** "Can a `stack #(int)` handle be assigned to a `stack #(byte)` handle with `$cast`?" No. They are different classes with no inheritance relationship, so the cast always fails. `$cast` only succeeds along an inheritance chain.

> **Common mistake:** Forgetting the `#` and writing `stack (int) s;`, or writing `mailbox (alu_txn) m;`. The parameter list always starts with `#(`.

> **Common mistake:** Writing a `typedef` in two places with different parameter spellings and expecting different types. `stack #(int, 4)` and `stack #(.DEPTH(4), .T(int))` and `stack` are all the same type; what counts is the final parameter values.

> **Verification application:** The scoreboard, the mailboxes and the analysis FIFOs of a testbench are written once and parameterized by the transaction type, so the same code checks the ALU (`#(alu_txn)`), a FIFO (`#(fifo_txn)`) and a bus (`#(apb_txn)`). A driver for a bus that exists in 32-bit and 64-bit versions is parameterized by the address and data widths.

### Interview questions

**Q1. What is a parameterized class?**
A class declared with a parameter list `#(...)` containing value parameters and/or type parameters. It is a template from which the compiler generates a concrete class for each set of actual parameter values used.

**Q2. What is the difference between a value parameter and a type parameter?**
A value parameter is a compile-time constant such as a width or depth. A type parameter, declared with the keyword `type`, represents a data type that is supplied when the class is used.

**Q3. What is a specialisation?**
A parameterized class together with a specific set of parameter values, for example `stack #(string, 2)`. Each distinct set of values is a distinct class type.

**Q4. Are `stack #(int)` and `stack #(byte)` compatible types?**
No. Different specialisations are separate, unrelated classes. Handles cannot be assigned between them, even with `$cast`.

**Q5. How do static members behave in a parameterized class?**
Each specialisation gets its own copy of every static property. They are not shared between specialisations.

**Q6. How would you keep objects of different specialisations in one queue?**
Derive the parameterized class from a common non-parameterized base class and declare the queue with the base class type. Virtual methods in the base give access to the specialised behaviour.

**Q7. How do you access a static member of a parameterized class?**
Through an explicit specialisation, `stack #(int)::instances` or `stack #()::instances` for the default, or through a typedef of the specialisation. The bare generic name with `::` is not allowed outside the class.

**Q8. Give examples of parameterized classes you have used.**
`mailbox #(alu_txn)` is the built-in example. In UVM: `uvm_driver #(REQ)`, `uvm_sequence #(REQ)`, `uvm_sequencer #(REQ)`, `uvm_analysis_port #(T)`, `uvm_tlm_analysis_fifo #(T)` and `uvm_config_db #(T)`.

**Q9. Can the parameters of a class be changed at run time?**
No. They are elaboration-time constants. A run-time choice is made with polymorphism or with ordinary class properties, not with parameters.

## 2.2 Generic Reusable Classes

### In plain English

"Generic" means "written without knowing the exact type it will work on". The stack in Section 2.1 is generic. This section builds two generic classes of the kind that appear in real testbenches, a FIFO and a scoreboard, and discusses what a generic class may assume about the type it is given.

### What a generic class can do with a value of type T

Inside the class, the compiler knows nothing about `T` until a specialisation is made. The class may therefore only use operations that the eventual type supports:

| Operation in the generic class | Works when T is | Fails when T is |
|---|---|---|
| Assignment `x = item;`, storing in a queue or array | Any type | |
| `==`, `!=` | Integral types, strings, unpacked structs and arrays (compares contents); class handles (compares **handles**, not contents) | |
| `<`, `>`, `+` | Integral and real types | Class handles, unpacked structs |
| `item.compare(other)`, `item.print()`, `item.copy()` | A class that has those methods | `int`, structs, any class without them |
| `$display("%p", item)` | Any type | |

Two design styles follow from this table:

- **Value-type generic classes** use only assignment and `==`. They work for integers, strings and structs. They also compile for class handles, but then `==` compares handle identity, which is rarely what a scoreboard wants.
- **Object-type generic classes** require that `T` is a class with an agreed set of methods (`compare`, `copy`, `print`). This agreement is an informal interface: the generic class will not compile for a type that lacks the methods.

### Generic FIFO

```systemverilog file=tb_generic_fifo.sv
class generic_fifo #(type T = int, int DEPTH = 4);

  protected T q [$];

  function bit is_full();   return (q.size() == DEPTH);  endfunction
  function bit is_empty();  return (q.size() == 0);      endfunction
  function int level();     return q.size();             endfunction

  function bit push(T item);
    if (is_full()) return 0;
    q.push_back(item);
    return 1;
  endfunction

  function bit pop(output T item);
    if (is_empty()) return 0;
    item = q.pop_front();
    return 1;
  endfunction

endclass

module tb_generic_fifo;

  typedef struct {
    bit [7:0] addr;
    bit [7:0] data;
  } bus_item_t;

  generic_fifo #(bit [7:0], 3) byte_fifo;
  generic_fifo #(bus_item_t)   item_fifo;

  bit [7:0]  b;
  bus_item_t it;

  initial begin
    byte_fifo = new();
    item_fifo = new();

    for (int i = 0; i < 4; i++) begin
      b = 8'hA0 + i;
      if (!byte_fifo.push(b)) $display("1. push of %h refused, FIFO full", b);
    end
    $display("2. level = %0d, full = %b", byte_fifo.level(), byte_fifo.is_full());

    while (byte_fifo.pop(b)) $display("3. popped %h", b);
    $display("4. empty = %b", byte_fifo.is_empty());

    void'(item_fifo.push('{addr: 8'h10, data: 8'hAA}));
    void'(item_fifo.push('{addr: 8'h14, data: 8'hBB}));
    void'(item_fifo.pop(it));
    $display("5. item: addr=%h data=%h, %0d left", it.addr, it.data, item_fifo.level());
  end

endmodule
```

```output
1. push of a3 refused, FIFO full
2. level = 3, full = 1
3. popped a0
3. popped a1
3. popped a2
4. empty = 1
5. item: addr=10 data=aa, 1 left
```

**Line by line**

| Code | Explanation |
|---|---|
| `protected T q [$];` | The storage is a queue of `T`. `protected` lets a derived class reach it while hiding it from outside users. |
| `push` / `pop` | `push_back` and `pop_front` give first-in first-out order (the stack used `pop_back`). |
| `generic_fifo #(bit [7:0], 3) byte_fifo;` | A type parameter can be any type expression, including a vector type written in place. |
| `generic_fifo #(bus_item_t) item_fifo;` | The same code storing structs. `DEPTH` takes its default, 4. |
| The `for` loop, line 1 | Three pushes succeed (`a0`, `a1`, `a2`). The fourth (`a3`) finds the FIFO full and `push` returns 0. |
| `while (byte_fifo.pop(b))` | Pops until the function returns 0. Values come out in the order they went in. |
| `'{addr: 8'h10, data: 8'hAA}` | An assignment pattern passed directly as the argument; the formal type `bus_item_t` gives it its context. |

### Generic scoreboard for value types

```systemverilog file=tb_generic_scoreboard.sv
class inorder_scoreboard #(type T = int);

  protected T  expected_q [$];
  int unsigned matches;
  int unsigned mismatches;
  string       name;

  function new(string name);
    this.name = name;
  endfunction

  function void add_expected(T item);
    expected_q.push_back(item);
  endfunction

  function void check_actual(T actual);
    T exp;
    if (expected_q.size() == 0) begin
      mismatches++;
      $display("[%s] FAIL: item %0d was not expected", name, matches + mismatches);
      return;
    end
    exp = expected_q.pop_front();
    if (actual == exp) matches++;
    else begin
      mismatches++;
      $display("[%s] FAIL: item %0d does not match", name, matches + mismatches);
    end
  endfunction

  function void report();
    $display("[%s] matches=%0d mismatches=%0d still expected=%0d",
             name, matches, mismatches, expected_q.size());
  endfunction

endclass

module tb_generic_scoreboard;

  typedef struct {
    bit [7:0] addr;
    bit [7:0] data;
  } bus_item_t;

  inorder_scoreboard #(int)        int_sb;
  inorder_scoreboard #(bus_item_t) bus_sb;
  bus_item_t item;

  initial begin
    int_sb = new("int_sb");
    bus_sb = new("bus_sb");

    int_sb.add_expected(5);
    int_sb.add_expected(6);
    int_sb.add_expected(7);
    int_sb.check_actual(5);
    int_sb.check_actual(9);
    int_sb.report();

    item = '{addr: 8'h10, data: 8'hAA};
    bus_sb.add_expected(item);
    bus_sb.check_actual(item);
    item.data = 8'hAB;
    bus_sb.check_actual(item);
    bus_sb.report();
  end

endmodule
```

```output
[int_sb] FAIL: item 2 does not match
[int_sb] matches=1 mismatches=1 still expected=1
[bus_sb] FAIL: item 2 was not expected
[bus_sb] matches=1 mismatches=1 still expected=0
```

**Line by line**

| Code | Explanation |
|---|---|
| `class inorder_scoreboard #(type T = int);` | "In-order" means the actual items must arrive in the same order as the expected items. |
| `add_expected` | Called by whatever predicts the DUT output; appends to the queue. |
| `T exp;` | A local variable of the parameter type. |
| `if (expected_q.size() == 0)` | An actual item arrived with nothing expected: that is an error too. |
| `if (actual == exp) matches++; else ...` | The comparison is written so that the failing path is the `else`. If `T` is four-state and the actual value contains X, `==` gives X, the `if` is not taken, and the item is counted as a mismatch (see M1, Section 4.5). |
| `int_sb.check_actual(5);` | 5 equals the first expected value: match. |
| `int_sb.check_actual(9);` | 9 is compared with 6: mismatch on the second item. One expected value (7) is left in the queue. |
| `bus_sb` | The same class checking structs. `==` on unpacked structs compares member by member. The first check matches. The second arrives when the queue is empty, so it is reported as unexpected. |

### Generic scoreboard for transaction objects

For class types, `==` would compare handles. An object-type scoreboard calls the transaction's own `compare` method instead (M6 gave `alu_txn` the methods `print`, `copy` and `compare`):

```systemverilog
class txn_scoreboard #(type T = alu_txn);

  mailbox #(T) exp_mbx;        // from the reference model
  mailbox #(T) act_mbx;        // from the monitor
  int unsigned n_pass, n_fail;

  function new(mailbox #(T) exp_mbx, mailbox #(T) act_mbx);
    this.exp_mbx = exp_mbx;
    this.act_mbx = act_mbx;
  endfunction

  task run();
    T exp, act;
    forever begin
      act_mbx.get(act);
      exp_mbx.get(exp);
      if (act.compare(exp)) n_pass++;        // requires: T has function bit compare(T rhs)
      else begin
        n_fail++;
        act.print("ACTUAL  ");               // requires: T has function void print(string)
        exp.print("EXPECTED");
      end
    end
  endtask

endclass
```

`txn_scoreboard #(alu_txn)` compiles because `alu_txn` provides `compare` and `print`. `txn_scoreboard #(int)` does not compile. The comments "requires:" document the contract.

A stricter way to state the contract is an abstract base class (M4): declare `virtual class base_txn` with `pure virtual` `compare` and `print`, make every transaction extend it, and write the scoreboard against `base_txn` handles. Then the compiler enforces the contract through inheritance instead of failing inside the generic class. UVM does this with `uvm_object`, whose `compare`, `copy`, `print` and `clone` every transaction inherits.

### The parameterized mailbox (recap from M7)

| Declaration | Meaning | Type checking |
|---|---|---|
| `mailbox mbx;` | Typeless mailbox: can carry values of any type | None at compile time. A `get` into a variable of the wrong type is a **run-time** error |
| `mailbox #(alu_txn) mbx;` | The built-in parameterized class specialised for `alu_txn` handles | A `put` or `get` with the wrong type is a **compile** error |
| `typedef mailbox #(alu_txn) alu_txn_mbx_t;` | A reusable name for that specialisation | |

`mailbox #(alu_txn)` and `mailbox #(fifo_txn)` are different types, exactly as for any parameterized class, so the handle a generator holds must be declared with the same specialisation as the handle the driver holds.

> **Common mistake:** Building a generic scoreboard with `==` and then specialising it with a class type. It compiles, and every comparison fails, because two different objects with identical contents have different handles. Use the object-type style with `compare()` for classes.

> **Common mistake:** Making every class parameterized "for reuse". Parameters spread: a parameterized transaction forces the driver, monitor, scoreboard, environment and test that use it to be parameterized or specialised too. Parameterize where types or widths really vary, and use `typedef`s to hide the specialisations.

> **Verification application:** Predictor-plus-comparator scoreboards, analysis FIFOs, register-model adapters and coverage collectors are all written generically and specialised by transaction type. Writing a small generic class on a whiteboard (a stack, a FIFO, a pair) is a common interview coding question.

### Interview questions

**Q1. What is a generic class?**
A class written in terms of type (and value) parameters instead of fixed types, so that the same code can be reused for many types by specialising it.

**Q2. Write a generic class that swaps two values of any type.**
`class swapper #(type T = int); static function void swap(ref T a, ref T b); T tmp = a; a = b; b = tmp; endfunction endclass`, used as `swapper #(string)::swap(s1, s2);`. The `ref` arguments (M3) let the function modify the caller's variables.

**Q3. A generic scoreboard uses `if (actual == expected)`. What happens when it is specialised with a transaction class?**
It compiles, but `==` on class handles compares whether both handles refer to the same object, not whether the contents are equal. Two separate objects with equal fields compare as different. The scoreboard should call a `compare()` method instead.

**Q4. How can a generic class require that its type parameter has certain methods?**
Informally, by calling them: a specialisation with a type lacking the method fails to compile. Formally, by writing the class against an abstract base class with pure virtual methods that every usable type must extend.

**Q5. What is the advantage of `mailbox #(alu_txn)` over a plain `mailbox`?**
Type safety at compile time. A plain mailbox accepts any type, and a type mismatch is only discovered at run time when `get` fails. The parameterized mailbox rejects a wrong type during compilation.

## 2.3 Virtual Interfaces: Advanced Recap

Module 8 introduced virtual interfaces in full. This section restates the essentials in the form an interviewer expects and adds the topics that belong with parameterization.

### The essentials

| Fact | Explanation |
|---|---|
| Why they exist | A class is created at run time; an interface instance is static hardware-like structure created at elaboration. A class cannot instantiate an interface or have ports. It needs a variable that can **refer to** an existing interface instance |
| What it is | `virtual alu_if vif;` declares a variable (a handle) that can refer to any instance of `alu_if`. The keyword `virtual` here has nothing to do with virtual methods |
| Default value | `null`. Using it before assignment is a run-time null-reference error |
| Assignment | In the top module, where the real instance exists: `env = new(alu_vif);` or `env.drv.vif = alu_vif;` |
| With a modport | `virtual alu_if.DRV vif;` restricts the class to the signals and directions of that modport |
| Access | `vif.rst_n`, `vif.drv_cb.a <= txn.a;`, `@(vif.drv_cb);` |
| Synthesizable | No. Testbench only |

```text
   tb_top (static, elaboration time)                 class world (dynamic, run time)

   alu_if alu_vif (clk);  <------------------------  virtual alu_if vif;   (in alu_driver)
        |      ^                                      virtual alu_if vif;   (in alu_monitor)
        |      |   the handles refer to the SAME interface instance
        v      |
   alu dut (.a(alu_vif.a), ...);
```

### Parameterized interfaces

If the interface has parameters, the virtual interface type must state them, and they must match the instance it is assigned from. A class that should work with any width must then be parameterized itself and pass its parameter on.

```systemverilog file=tb_param_vif.sv
interface bus_if #(parameter int W = 8) (input logic clk);
  logic [W-1:0] data;
  logic         valid;
endinterface

class bus_driver #(int W = 8);

  virtual bus_if #(W) vif;              // the class parameter selects the interface type

  function new(virtual bus_if #(W) vif);
    this.vif = vif;
  endfunction

  task send(logic [W-1:0] value);
    @(posedge vif.clk);
    vif.data  <= value;
    vif.valid <= 1'b1;
    @(posedge vif.clk);
    vif.valid <= 1'b0;
  endtask

endclass

module tb_param_vif;

  logic clk = 0;
  always #5 clk = ~clk;

  bus_if #(8)  if8  (clk);
  bus_if #(16) if16 (clk);

  bus_driver #(8)  drv8;
  bus_driver #(16) drv16;

  initial begin
    drv8  = new(if8);
    drv16 = new(if16);
    // drv8 = new(if16);    // ILLEGAL: virtual bus_if #(8) cannot refer to a bus_if #(16)

    fork
      drv8.send(8'hA5);
      drv16.send(16'hBEEF);
    join

    $display("[%0t] if8.data=%h (%0d bits)  if16.data=%h (%0d bits)",
             $time, if8.data, $bits(if8.data), if16.data, $bits(if16.data));
    $finish;
  end

endmodule
```

```output
[15] if8.data=a5 (8 bits)  if16.data=beef (16 bits)
```

**Line by line**

| Code | Explanation |
|---|---|
| `interface bus_if #(parameter int W = 8) (input logic clk);` | A parameterized interface: the data width is a parameter. |
| `class bus_driver #(int W = 8);` | The class carries the same parameter. |
| `virtual bus_if #(W) vif;` | The virtual interface type includes the parameter. `virtual bus_if #(8)` and `virtual bus_if #(16)` are different types. |
| `bus_if #(8) if8 (clk); bus_if #(16) if16 (clk);` | Two real instances with different widths. |
| `drv8 = new(if8); drv16 = new(if16);` | Each driver specialisation receives the instance with the matching width. |
| `fork ... join` | Both `send` tasks run in parallel. Each waits for the rising edge at time 5, drives its data, waits for the edge at 15, and removes `valid`. Both finish at 15. |
| The `$display` | Shows that one class definition drove an 8-bit and a 16-bit interface. |

Parameterized interfaces therefore push parameters into every class that touches them. Projects limit the spread in three ways:

| Technique | Idea |
|---|---|
| Maximum-width interface | The interface is declared with the widest possible signals; narrower DUTs use the low bits. No class parameters are needed |
| `typedef` in the testbench package | `typedef virtual bus_if #(32) bus_vif_t;` used everywhere, so the parameter is written once |
| Abstract class / concrete class in the interface | A non-parameterized abstract class declares driving tasks as pure virtual methods; a concrete class defined *inside* the interface implements them and has direct access to the signals. The testbench only holds the abstract handle. (This pattern is beyond what a fresher is expected to code, but it is worth knowing it exists.) |

### Other points that are asked

- **Arrays of virtual interfaces:** `virtual alu_if vifs [4];` with `vifs[i] = if_array[i];` assigned in a `generate` loop or one by one. Used when a DUT has several identical ports.
- **Where a virtual interface may be declared:** in classes, tasks, functions and modules as a variable; it cannot be a port, and an interface instance cannot be created through it.
- **Comparison and null check:** `if (vif == null) $fatal(1, "vif not set");` is the standard first line of a driver's `run()`.
- **How UVM passes it:** the top module stores the handle in the configuration database, and each component fetches it in its build phase (Section 5.6). The mechanism replaces the constructor argument used in M9; the concept is unchanged.

> **Interview trap:** "Is a virtual interface a copy of the interface?" No. It is a reference. Every class holding the handle reads and drives the single real instance, which is how the driver's writes reach the DUT pins.

> **Common mistake:** Declaring `virtual bus_if vif;` (default parameter, width 8) in the class and assigning a `bus_if #(16)` instance to it. The types do not match and elaboration fails. The specialisation must be written in the virtual interface declaration.

### Interview questions

**Q1. Why can a class not use an interface directly?**
An interface instance is a static design element created at elaboration; a class object is created dynamically at run time and has no ports or instances. The class needs a variable that can be made to refer to an existing interface instance, which is what a virtual interface is.

**Q2. What is the default value of a virtual interface, and what happens if it is used unassigned?**
`null`. Accessing a signal through it causes a run-time null-reference error.

**Q3. How do you declare a virtual interface for a parameterized interface?**
With the parameter values in the type: `virtual bus_if #(16) vif;`. The values must match those of the instance assigned to it. A class meant to work with several widths is parameterized and passes its own parameter: `virtual bus_if #(W) vif;`.

**Q4. Can two classes share one interface instance?**
Yes. The driver and the monitor normally hold virtual interface handles that refer to the same instance.

## 2.4 Clocking Blocks: Advanced Recap

Module 8 covered clocking blocks. The table and diagram below collect what must be at your fingertips; the UVM driver in Section 5.8 uses them unchanged.

### The essentials

| Fact | Explanation |
|---|---|
| What it is | A block declared inside an interface (or module/program) that groups signals which are synchronous to one clock, and defines **when** the testbench samples them and **when** it drives them relative to that clock |
| Why it exists | To remove races between the testbench and the DUT at the clock edge. Without it, whether the testbench sees the old or the new DUT output depends on the simulator's process ordering |
| Input skew | How long **before** the clock event an `input` is sampled. Default `#1step`: the value in the Preponed region, that is, the value the signal had just before the edge |
| Output skew | How long **after** the clock event an `output` is driven. Default `#0`: driven in the Re-NBA region of the same time step, after the DUT's flip-flops have sampled |
| Direction is from the testbench's view | In `drv_cb`, the DUT's inputs are `output`; the DUT's outputs are `input` |
| Driving | Only with the synchronous drive `vif.drv_cb.a <= value;` (the `<=` is required) |
| Sampling | Read `vif.mon_cb.result`. The value is the one captured at the most recent clocking event |
| Waiting | `@(vif.drv_cb);` waits for the clocking event. `##3;` waits three cycles of the *default* clocking block |

```text
                         clock edge (posedge clk)
                                  |
   time  ------------------------>|------------------------------------->
                                  |
            input skew            |            output skew
        <-------------------------|-------------------------->
        testbench SAMPLES here    |    testbench DRIVES here
        (#1step: Preponed region, |    (#0: Re-NBA region; or #N time units later)
         the "old", stable value) |
                                  |
                       DUT flip-flops sample
                       and update at the edge
```

### The ALU interface with its clocking blocks

This is the structure built in M8 and used by the M9 testbench, shown here in abridged form for reference:

```systemverilog
interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  clocking drv_cb @(posedge clk);            // the driver's view
    default input #1step output #1;
    output valid_in, a, b, op;
    input  valid_out, result;
  endclocking

  clocking mon_cb @(posedge clk);            // the monitor's view: everything is sampled
    default input #1step;
    input valid_in, a, b, op, valid_out, result;
  endclocking

  modport DUT (input  clk, rst_n, valid_in, a, b, op, output valid_out, result);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);
endinterface
```

### Points that interviewers add at this level

| Question | Answer |
|---|---|
| What exactly is `#1step`? | The smallest step of simulation time (one unit of the global time precision). Sampling "one step before" the edge means sampling in the Preponed region of the edge's time step, which gives the value from before any activity at the edge |
| What does input skew `#0` do? | The input is sampled in the Observed region of the same time step, after the DUT's nonblocking assignments, so the testbench sees the **new** value |
| Can a signal be both sampled and driven? | Yes, by declaring it `inout` in the clocking block |
| Does reading `vif.mon_cb.result` right after `@(posedge vif.clk)` give the right value? | It can be stale: the clocking block may not have updated its sample yet. Synchronise with `@(vif.mon_cb)`, not with the raw clock, when you use the clocking block |
| What happens if two drives to the same clocking output occur in one cycle? | The last one wins, as for nonblocking assignments |
| Clocking block versus modport | A modport sets the **direction** of signals for one user of the interface. A clocking block sets the **timing** of sampling and driving. They are used together: the modport exposes the clocking block |
| Are clocking blocks synthesizable? | No |

> **Common mistake:** Mixing styles in one component, for example waiting with `@(posedge vif.clk)` and then reading `vif.mon_cb.result`, or driving `vif.a = value` directly while also driving through `vif.drv_cb`. Use the clocking block for both the waiting and the access.

### Interview questions

**Q1. What problem does a clocking block solve?**
Race conditions between the testbench and the DUT at clock edges. By sampling inputs slightly before the edge and driving outputs slightly after it, the testbench always reads stable values and never changes a DUT input at the instant the DUT samples it.

**Q2. What are the default input and output skews?**
Input `#1step`, output `#0`.

**Q3. What is the difference between a modport and a clocking block?**
A modport defines signal directions for a particular user of the interface. A clocking block defines sampling and driving timing with respect to a clock. A modport can include a clocking block so that the user gets both.

**Q4. How is a signal driven through a clocking block?**
With a synchronous drive using `<=`: `vif.drv_cb.valid_in <= 1'b1;`. A blocking assignment `=` to a clocking block output is illegal.
