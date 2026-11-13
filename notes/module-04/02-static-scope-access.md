# Part 2: Class Members in Depth

## 2.1 The Scope Resolution Operator (::)

### In plain English

The dot operator reaches inside an **object**: `p.addr` means "the `addr` of the object that `p` refers to". The double-colon operator reaches inside a **named scope**, such as a class or a package, without needing any object: `packet::count` means "the item called `count` that belongs to the class `packet` itself".

### Technical definition

The scope resolution operator `::` identifies a name within a specified scope. The left operand is the name of a class, a package, a covergroup type or a typedef name; the right operand is an item declared in that scope.

### Where it is used

| Use | Example | Covered in |
|---|---|---|
| Static property of a class | `packet::count` | Section 2.2 |
| Static method of a class | `id_gen::get_id()` | Section 2.3 |
| Type, enum label, `parameter` or `localparam` declared inside a class | `packet::dir_e`, `packet::WRITE`, `packet::HEADER_BYTES` | This section |
| Item in a package | `alu_pkg::alu_op_e`, `import alu_pkg::*;` | Module 11 |
| Body of an `extern` method written outside the class | `function void packet::print();` | Section 2.4 |
| Member of a parameterized class specialisation | `stack #(int)::depth` | Module 11 |
| Base-class member from a derived class | `base_txn::MAX` (for calling an overridden base *method* use `super.`) | Part 4 |
| Disambiguation in inline constraints | `local::addr` | Module 5 |
| Compilation-unit scope | `$unit::name` | Module 11 |

### Dot versus double colon

| | `.` (dot) | `::` (scope resolution) |
|---|---|---|
| Left operand | A handle (an object), an instance, a struct variable | A class name, package name or type name |
| Needs an object to exist | Yes (for non-static members) | No |
| Reaches | Members of one particular object | Items that belong to the scope itself: static members, types, parameters, package items |
| Example | `p.addr` | `packet::count` |

Static members may be reached either way (`p.count` or `packet::count`), but `::` is the clearer style because it shows that the member belongs to the class.

### Complete example

```systemverilog file=tb_scope_resolution.sv
package cfg_pkg;
  parameter int MAX_LEN = 16;
  typedef enum {LOW, HIGH} level_e;
endpackage

module tb_scope_resolution;

  class packet;
    typedef enum {READ, WRITE} dir_e;        // a type declared inside the class
    localparam int HEADER_BYTES = 2;         // a constant declared inside the class
    static int count = 0;                    // a static property
    dir_e dir;

    static function int get_count();         // a static method
      return count;
    endfunction
  endclass

  packet::dir_e    d;                        // type from the class scope
  cfg_pkg::level_e lvl;                      // type from the package scope

  initial begin
    d   = packet::WRITE;                     // enum label from the class scope
    lvl = cfg_pkg::HIGH;                     // enum label from the package scope
    packet::count = 3;                       // static property: no object exists

    $display("%s %s %0d %0d %0d",
             d.name(), lvl.name(), packet::HEADER_BYTES, cfg_pkg::MAX_LEN,
             packet::get_count());
  end

endmodule
```

```output
WRITE HIGH 2 16 3
```

**Line by line**

| Line | Explanation |
|---|---|
| `typedef enum {READ, WRITE} dir_e;` inside the class | The type and its labels live in the scope of the class. Outside the class they are `packet::dir_e`, `packet::READ`, `packet::WRITE`. This avoids name clashes between classes. |
| `localparam int HEADER_BYTES = 2;` | A class may declare constants. |
| `packet::dir_e d;` | A module-level variable whose type is taken from the class. |
| `packet::count = 3;` | No `packet` object has been created anywhere in this example. Static members exist without objects. |
| `cfg_pkg::MAX_LEN` | The same operator selects an item from a package without an `import`. |

> **Common mistake:** Using the dot with a class name (`packet.count`) or the double colon with a handle (`p::count`). The dot follows a handle; the double colon follows a class or package name.

### Interview questions

**Q1. What is the scope resolution operator and where is it used?**
`::` selects a name inside a named scope. It is used to access static properties and methods of a class, types and parameters declared in a class, items in a package, and to define `extern` methods outside the class body.

**Q2. What is the difference between `.` and `::`?**
The dot accesses a member of a specific object through a handle. The double colon accesses an item that belongs to a class or package as a whole and needs no object.

**Q3. How do you refer to an enum declared inside a class from outside it?**
With the class name as prefix: `class_name::enum_type` for the type and `class_name::LABEL` for a label.

## 2.2 Static Properties

### In plain English

Normal properties belong to each object: every packet has its own address. A **static** property belongs to the class as a whole: there is exactly one copy, shared by every object of the class. If one object changes it, all objects see the new value. It is like a notice board in the lobby of a block of flats: each flat has its own furniture, but there is one notice board for everybody.

### Technical definition

A property declared with the keyword `static` has a single storage location associated with the class, not with any object. It is created and initialised once, at the start of simulation (before any `initial` block runs), and exists even if no object of the class is ever created. It can be accessed with the class scope operator (`class_name::property`) or through any handle of the class.

### Why it is needed

| Requirement | Solution with a static property |
|---|---|
| Count how many objects (transactions) have been created | `static int count;` incremented in `new()` |
| Give every object a unique ID | Copy the counter into a per-object `id` in `new()` |
| Share one configuration object, one virtual interface or one mailbox between all objects of a class | `static cfg_t cfg;` |
| Keep statistics for the whole class (total errors, total bytes) | `static int error_count;` |
| A value that all objects must agree on, without using a global variable | Static property, which is a global variable *scoped inside the class* |

### How it works internally

```text
   class packet;
     static int count;      // one copy, belongs to the class
     int        id;         // one copy per object
   endclass

                         +----------------------+
     class packet        |  count = 3           |   static storage: exists from time 0,
                         +----------------------+   exists with zero objects
                            ^        ^        ^
                            |        |        |      every object reaches the same count
            +---------------+   +----+----+   +---------------+
            |                   |         |                   |
      +-----------+       +-----------+       +-----------+
   p1 |  id = 1   |    p2 |  id = 2   |    p3 |  id = 3   |    one id per object
      +-----------+       +-----------+       +-----------+
```

### Syntax

```systemverilog
class packet;
  static int count = 0;          // static property, initialised once
  int        id;                 // ordinary (instance) property
endclass

packet::count = 5;               // access through the class name (preferred)
p1.count      = 5;               // access through a handle (legal, same variable)
```

### Complete example

```systemverilog file=tb_static_property.sv
module tb_static_property;

  class packet;
    static int count = 0;        // shared by all packet objects
    int        id;               // unique to each object

    function new();
      count++;
      id = count;
    endfunction
  endclass

  packet p1, p2, p3;

  initial begin
    $display("1. before any object exists: count=%0d", packet::count);

    p1 = new();
    p2 = new();
    p3 = new();
    $display("2. ids: p1=%0d p2=%0d p3=%0d", p1.id, p2.id, p3.id);
    $display("3. count seen from: class=%0d p1=%0d p3=%0d",
             packet::count, p1.count, p3.count);

    p2.count = 10;               // written through one handle...
    $display("4. after p2.count = 10: class=%0d p1=%0d", packet::count, p1.count);
  end

endmodule
```

```output
1. before any object exists: count=0
2. ids: p1=1 p2=2 p3=3
3. count seen from: class=3 p1=3 p3=3
4. after p2.count = 10: class=10 p1=10
```

**Line by line**

| Line | Explanation |
|---|---|
| `static int count = 0;` | One variable for the whole class, initialised once before time 0. The initialiser is **not** re-applied when objects are created. |
| `count++; id = count;` | Each construction increments the shared counter and copies it to the object's private `id`. |
| Output 1 | The static property is readable before any object exists. |
| Output 2 | Each object kept the value of the counter at the time it was built. |
| Output 3 | Whichever way it is accessed, it is the same variable. |
| Output 4 | A write through `p2` is seen by the class and by `p1`. |

### Static versus instance property

| Property | Instance (non-static) property | Static property |
|---|---|---|
| Belongs to | Each object | The class |
| Number of copies | One per object | One in total |
| Memory allocated | When `new()` is called | At the start of simulation |
| Exists without an object | No | Yes |
| Accessed with | `handle.name` | `class_name::name` or `handle.name` |
| Access through a null handle | Fatal error | Legal (the handle's type is enough to find the class) |
| Declaration initialiser applied | For each new object | Once |
| Can be `rand` | Yes | Yes, but then every `randomize()` call changes the one shared value |
| Typical use | Transaction fields | Counters, shared configuration, shared resources |

> **Interview trap:** "If I create ten objects of a class with a static property, how many copies of the property exist?" One. "And if I create zero objects?" Still one.

> **Common mistake:** Expecting `static int count = 0;` to be reset to 0 in every new object. It is initialised once. If the constructor needs a fresh value per object, the property must not be static.

> **Verification application:** The classic use is a transaction counter: `static int unsigned next_id;` in the transaction class, with `id = next_id++`-style logic in the constructor, so that every transaction in the log has a unique number that can be traced from generator to scoreboard.

### Interview questions

**Q1. What is a static property?**
A property declared with `static`. It has one copy shared by all objects of the class, exists without any object, and can be accessed with `class_name::property`.

**Q2. When is a static property initialised?**
Once, at the start of simulation, before any procedural block executes.

**Q3. How do you count the number of objects created from a class?**
Declare `static int count;` and increment it in the constructor.

**Q4. Can a static property be accessed through a null handle?**
Yes. Static members do not need an object, so the access is legal even when the handle is `null`.

**Q5. What is the difference between a static property and a global variable?**
Functionally both have one copy for the whole simulation. A static property is scoped inside its class, so it does not pollute the global name space, can be made `local` or `protected`, and is clearly associated with the class that uses it.

## 2.3 Static Methods

### In plain English

A static method is a method that belongs to the class, not to an object. You call it with the class name, without creating anything. Because it is not called on an object, it has no "my own properties" to work with: it can use only static properties and other static methods.

### Technical definition

A method declared with `static` before the keyword `function` or `task` is a static method. It:

- can be called without an object: `class_name::method()`;
- has **no `this` handle**;
- can access only **static** properties and call only **static** methods of its class directly (it can still use non-static members of an object whose handle it is given as an argument or creates itself);
- **cannot be `virtual`**.

### Why it is needed

- To read or modify static properties that are `local` or `protected` without needing an object.
- For utility functions that logically belong to a class but need no object state (conversions, calculations, name look-ups).
- For "factory" and "singleton" patterns: a static method is the only way to obtain an object when the constructor is hidden. UVM uses this heavily (`my_class::type_id::create(...)`, `uvm_config_db#(T)::get(...)` are static method calls).

### Syntax

```systemverilog
class id_gen;
  local static int next_id = 100;

  static function int get_id();     // static METHOD
    int id;
    id = next_id;
    next_id++;
    return id;
  endfunction
endclass

x = id_gen::get_id();               // no object needed
```

### Complete example

```systemverilog file=tb_static_method.sv
module tb_static_method;

  class id_gen;
    local static int next_id = 100;       // hidden shared state
    int              calls;               // an ordinary, per-object property

    static function int get_id();
      int id;
      id = next_id;
      next_id++;
      // calls++;                         // ILLEGAL: non-static property in a static method
      // this.calls = 0;                  // ILLEGAL: no "this" in a static method
      return id;
    endfunction

    static function void reset(int start = 100);
      next_id = start;
    endfunction
  endclass

  id_gen g;                               // never constructed in this example

  initial begin
    $display("1. %0d", id_gen::get_id());
    $display("2. %0d", id_gen::get_id());
    $display("3. %0d", g.get_id());       // legal even though g is null
    id_gen::reset(500);
    $display("4. %0d", id_gen::get_id());
  end

endmodule
```

```output
1. 100
2. 101
3. 102
4. 500
```

**Line by line**

| Line | Explanation |
|---|---|
| `local static int next_id = 100;` | Shared state that nobody outside the class can touch directly. |
| `static function int get_id();` | Returns the current value and advances the counter. |
| The two commented lines | A static method has no object, so it cannot use a non-static property or `this`. Both would be compile errors. |
| `id_gen::get_id()` | Called through the class name. No `id_gen` object exists. |
| `g.get_id()` | A static method may also be called through a handle, even a null one, because only the handle's type is used. Prefer the `::` form. |
| `id_gen::reset(500);` | Another static method modifying the hidden state. |

### Static method versus static lifetime

The keyword `static` can appear in two different positions in a method declaration, with two different meanings. Interviewers like this question.

| Declaration | Meaning | Legal in a class? |
|---|---|---|
| `static function int f();` | **Static method**: belongs to the class, no `this`, called with `::`. Its arguments and local variables still have *automatic* lifetime | Yes |
| `function static int f();` | Function with **static lifetime**: its arguments and local variables are allocated once and shared by all calls (Module 3) | **No.** Class methods must be automatic |
| `function automatic int f();` | Automatic lifetime, stated explicitly | Yes (it is already the default in a class) |

### Static versus non-static method

| Property | Non-static method | Static method |
|---|---|---|
| Called on | An object: `h.method()` | The class: `class_name::method()` (or through a handle) |
| `this` available | Yes | No |
| Can access non-static properties | Yes | No (only via an explicit handle to some object) |
| Can access static properties | Yes | Yes |
| Can call non-static methods | Yes | No (only via an explicit handle) |
| Can be `virtual` | Yes | No |
| Works with a null handle | No, fatal error | Yes |

> **Interview trap:** "Can a static method call a non-static method?" Not directly, because it has no object. It can if it has a handle to an object: `static function void show(packet p); p.print(); endfunction` is legal.

> **Interview trap:** "Can a non-static method access static properties?" Yes. The restriction applies only in the other direction.

### Interview questions

**Q1. What is a static method?**
A method declared with `static` before `function`/`task`. It belongs to the class, can be called without an object using `::`, has no `this`, and can directly access only static members.

**Q2. Why can a static method not access non-static properties?**
Non-static properties exist only inside objects. A static method is not invoked on an object, so there is no object whose properties it could mean.

**Q3. What is the difference between `static function` and `function static`?**
`static function` declares a static method (class-level, no `this`). `function static` declares static *lifetime* for the arguments and local variables, which is not permitted for class methods.

**Q4. Can a static method be virtual?**
No. Virtual dispatch depends on the type of an object, and a static method has no object.

**Q5. Give a practical use of static methods.**
Unique-ID generators, object counters with a `get_count()` accessor, singleton `get()` methods for a shared configuration, and factory `create()` methods as in UVM.

## 2.4 Extern Methods

### In plain English

A class with many long methods is hard to read: you cannot see at a glance what the class offers. With `extern` you write only the *prototype* of a method (its name, return type and arguments) inside the class, and put the body somewhere else, after the class. The class declaration then reads like a table of contents.

### Technical definition

A method prototype declared with the keyword `extern` inside a class is an **out-of-block declaration**. Its body is defined outside the class body, in the same scope as the class, with the method name qualified by the class name and `::`.

### Syntax

```systemverilog
class packet;
  extern function new(bit [7:0] addr = 0);             // prototypes only
  extern function void print(string tag = "");
  extern task drive(int delay);
endclass

function packet::new(bit [7:0] addr);                  // bodies, outside the class
  this.addr = addr;
endfunction

function void packet::print(string tag);
  ...
endfunction

task packet::drive(int delay);
  ...
endtask
```

### Rules

| Rule | Detail |
|---|---|
| The body must match the prototype | Same return type, same argument names, types and directions |
| Qualifiers go in the prototype | `virtual`, `static`, `local`, `protected`, `pure` are written with the `extern` prototype, not repeated on the body |
| Default argument values | Written in the prototype. They may be left out of the body; if they are repeated there, they must be identical |
| Return type declared inside the class | In the body it must be qualified, because the return type is written before `packet::` puts the class in scope: `function packet::dir_e packet::get_dir();` |
| Location of the body | In the same scope (package, module, file) that contains the class declaration |
| Inside the body | Properties and `this` are used exactly as in an inline method |

### Complete example

```systemverilog file=tb_extern.sv
module tb_extern;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    extern function new(bit [7:0] addr = 8'h00, bit [7:0] data = 8'h00);
    extern function void print(string tag = "");
    extern function bit [7:0] checksum();
  endclass

  function packet::new(bit [7:0] addr, bit [7:0] data);
    this.addr = addr;
    this.data = data;
  endfunction

  function void packet::print(string tag);
    $display("[%s] addr=%h data=%h checksum=%h", tag, addr, data, checksum());
  endfunction

  function bit [7:0] packet::checksum();
    return addr ^ data;
  endfunction

  packet p;

  initial begin
    p = new(8'h0F, 8'hF1);
    p.print("p");
    p = new();
    p.print("default");
  end

endmodule
```

```output
[p] addr=0f data=f1 checksum=fe
[default] addr=00 data=00 checksum=00
```

**Line by line**

| Line | Explanation |
|---|---|
| `extern function new(...)` | Even the constructor can be declared `extern`. |
| The class body | Three lines tell a reader everything the class can do. |
| `function packet::new(bit [7:0] addr, bit [7:0] data);` | The body, written after the class. The default values come from the prototype. |
| `function void packet::print(string tag);` | `packet::` tells the compiler which class the body belongs to. |
| `checksum()` inside `print` | An extern method calls other methods and uses properties like any other method. |
| `8'h0F ^ 8'hF1` | `0000_1111` XOR `1111_0001` = `1111_1110` = `FE`. |

> **Verification application:** UVM-style code bases commonly write every method as `extern`, keeping the class declaration short, and put the bodies below the class in the same file. In a package, the class files are `` `include ``d into the package, so the extern bodies are in the package scope as required.

> **Common mistake:** Forgetting `class_name::` on the body. The compiler then sees an ordinary stand-alone function with the same name, and reports that the extern method has no body.

### Interview questions

**Q1. What is an extern method?**
A method whose prototype is declared inside the class with `extern` and whose body is written outside the class using `class_name::method_name`.

**Q2. Why use extern methods?**
Readability and maintainability: the class declaration shows only the interface, and the implementations are separated from it.

**Q3. Where do the qualifiers `virtual`, `local` and `static` go?**
In the prototype inside the class, together with `extern`. They are not repeated on the out-of-block body.

## 2.5 Constant Properties (const)

### In plain English

Some values must never change after they have been set: the ID of a transaction, the maximum packet length. Marking such a property `const` makes the compiler reject any later assignment to it.

### Technical definition

A class property declared with `const` is read-only. There are two kinds, distinguished by where the value is given.

| Kind | Declaration | Where the value is assigned | Same value in every object? |
|---|---|---|---|
| **Global constant** | `const int MAX_LEN = 64;` (initialiser in the declaration) | In the declaration only; it cannot be assigned anywhere else, not even in `new` | Yes |
| **Instance constant** | `const int id;` (no initialiser) | Exactly once, in the constructor `new` | No, each object may get a different value |

A global constant has the same value in all objects, so it is usually also declared `static` to store it once: `static const int MAX_LEN = 64;`. An instance constant cannot be `static`, because it is assigned in the constructor.

### Complete example

```systemverilog file=tb_const.sv
module tb_const;

  class packet;
    static const int MAX_LEN = 64;      // global constant: value fixed in the declaration
    const int        id;                // instance constant: value fixed in new()
    bit [7:0]        data;

    function new(int id);
      this.id = id;                     // the one permitted assignment
    endfunction
  endclass

  packet p1, p2;

  initial begin
    p1 = new(1);
    p2 = new(2);
    $display("p1.id=%0d p2.id=%0d MAX_LEN=%0d", p1.id, p2.id, packet::MAX_LEN);

    p1.data = 8'h5A;                    // ordinary property: writable
    // p1.id = 7;                       // ILLEGAL: assignment to a const property
    // packet::MAX_LEN = 128;           // ILLEGAL: assignment to a const property
  end

endmodule
```

```output
p1.id=1 p2.id=2 MAX_LEN=64
```

### const compared with related constructs

| Construct | Value fixed at | Can differ per object | Scope |
|---|---|---|---|
| `parameter` / `localparam` in a class | Compile / elaboration time | No | The class (accessed with `::`) |
| Global `const` property | Compile time (declaration) | No | The class or object |
| Instance `const` property | Run time, in the constructor | Yes | The object |
| `` `define `` macro | Text substitution before compilation | No | Global, no scope |

> **Interview trap:** "Can a `const` property be assigned in the constructor?" Only if its declaration has no initialiser (an instance constant). A `const` with an initialiser cannot be assigned anywhere.

> **Note:** `const` applied to a *handle* makes the handle constant, not the object: the handle cannot be made to refer to another object, but the properties of the object it refers to can still be modified.

### Interview questions

**Q1. What are the two kinds of constant class property?**
Global constants, initialised in the declaration and never assignable; and instance constants, declared without an initialiser and assigned exactly once in the constructor.

**Q2. What is the difference between `const` and `localparam` in a class?**
A `localparam` is an elaboration-time constant, identical for all objects, usable where a constant expression is required (for example as an array dimension). An instance `const` is set at run time in the constructor and may differ for each object.

## 2.6 Local, Protected and Public Access

### In plain English

By default anybody who holds a handle can read and write every property of the object. That is convenient and dangerous: any code anywhere in the testbench can put an object into an inconsistent state. Access qualifiers let the author of a class decide which members are for everybody and which are private details.

Think of a cash machine. The public part is the keypad and the screen. The cash box inside is not accessible; you can only change its contents by using the keypad, and the machine checks every request.

### Technical definition

| Qualifier | Keyword | Accessible from |
|---|---|---|
| **Public** | (none; it is the default) | Anywhere a handle to the object is available |
| **Protected** | `protected` | Inside the class itself and inside classes derived from it |
| **Local** | `local` | Inside the class itself only. Not in derived classes, not from outside |

The qualifiers apply to properties and to methods. They are checked at **compile time**. SystemVerilog has no `public` or `private` keyword: public is expressed by writing nothing, and `local` is SystemVerilog's word for what C++ and Java call private.

### Access matrix

| Where the access is written | Public | `protected` | `local` |
|---|---|---|---|
| A method of the same class | Yes | Yes | Yes |
| A method of a derived class | Yes | Yes | **No** |
| Outside the class (a module, another unrelated class) | Yes | **No** | **No** |

One more rule: access control is per **class**, not per object. A method of class `account` may access the `local` members of *any* `account` object it has a handle to, not only those of `this`. This is what makes `compare(rhs)` and `copy()` methods possible.

### Syntax

```systemverilog
class account;
  local     int balance;       // only methods of account
  protected int limit;         // methods of account and of its subclasses
  string    owner;             // public

  local function void audit(); // methods can be qualified too
    ...
  endfunction
endclass
```

### Complete example

This example uses a derived class (`extends`) to show `protected`. Inheritance itself is explained in Part 4; for now read `class premium_account extends account` as "a `premium_account` has everything an `account` has, plus more".

```systemverilog file=tb_access.sv
module tb_access;

  class account;
    local     int balance;                 // hidden
    protected int limit = 1000;            // visible to subclasses
    string    owner;                       // public

    function new(string owner, int balance);
      this.owner   = owner;
      this.balance = balance;
    endfunction

    function void deposit(int amount);
      if (amount > 0) balance += amount;   // the class guards its own data
    endfunction

    function bit withdraw(int amount);
      if (amount <= 0 || amount > balance) return 0;
      balance -= amount;
      return 1;
    endfunction

    function int get_balance();
      return balance;
    endfunction

    function bit richer_than(account other);
      return balance > other.balance;      // local member of ANOTHER account object: legal
    endfunction
  endclass

  class premium_account extends account;
    function new(string owner, int balance);
      super.new(owner, balance);
      limit = 5000;                        // protected member of the base class: legal
      // balance = 0;                      // ILLEGAL: balance is local to account
    endfunction

    function void show();
      $display("%s: limit=%0d balance=%0d", owner, limit, get_balance());
    endfunction
  endclass

  account         a;
  premium_account b;
  bit             ok;

  initial begin
    a = new("asha", 100);
    a.deposit(50);
    $display("1. balance=%0d", a.get_balance());
    ok = a.withdraw(500);
    $display("2. withdraw 500 ok? %0d   balance=%0d", ok, a.get_balance());
    ok = a.withdraw(100);
    $display("3. withdraw 100 ok? %0d   balance=%0d", ok, a.get_balance());

    b = new("ben", 900);
    b.show();
    $display("4. ben richer than asha? %0d", b.richer_than(a));

    a.owner = "asha k";                    // public: legal
    // a.balance = 1_000_000;              // ILLEGAL: local
    // a.limit   = 0;                      // ILLEGAL: protected
  end

endmodule
```

```output
1. balance=150
2. withdraw 500 ok? 0   balance=150
3. withdraw 100 ok? 1   balance=50
ben: limit=5000 balance=900
4. ben richer than asha? 1
```

**Line by line**

| Line | Explanation |
|---|---|
| `local int balance;` | Can be changed only by `deposit` and `withdraw`, which enforce the rules (positive amounts, no overdraft). |
| `protected int limit = 1000;` | Hidden from outside code, but a subclass may adjust it. |
| `return balance > other.balance;` | `other` is a different object, but it is of the same class, so its local member is accessible. |
| `limit = 5000;` in `premium_account` | A derived class may access protected members of its base class. |
| `// balance = 0;` in `premium_account` | A derived class may **not** access local members of its base class. |
| `get_balance()` in `show()` | The subclass must use the public accessor, like everybody else. |
| `ok = a.withdraw(500);` | The result is stored first and printed afterwards. Calling a method that changes the object inside the argument list of `$display`, next to another call that reads the object, would depend on the order in which the simulator evaluates the arguments. |
| Output 2 | 500 exceeds the balance of 150, so `withdraw` returns 0 and nothing changes. |
| The last two commented lines | Outside code can reach neither local nor protected members. |

### Comparison table

| Aspect | Public | `protected` | `local` |
|---|---|---|---|
| Keyword | None | `protected` | `local` |
| Same class | Yes | Yes | Yes |
| Derived class | Yes | Yes | No |
| Outside | Yes | No | No |
| Equivalent in C++/Java | `public` | `protected` | `private` |
| Typical use | Transaction fields that are randomized and read everywhere; the methods that form the class's interface | Internal helpers and state that subclasses are expected to extend | Implementation details nobody else should depend on |

> **Interview trap:** "What is the default access of a class member in SystemVerilog?" Public. (In C++ the default for a `class` is private, which is why this is asked.)

> **Interview trap:** "Can a `local` member be accessed through a different object of the same class?" Yes. Access is checked against the class in which the code is written, not against the object.

> **Common mistake:** Making transaction fields `local` and then being unable to constrain them in `randomize() with {...}` from a test or read them in the scoreboard. In verification, transaction data fields are normally public; `local` and `protected` are used mainly for the internal state of components.

> **Note:** A constructor can itself be declared `local` or `protected` (`local function new();`). Then code outside the class cannot call `new` for it, and objects can be obtained only through a static method of the class. This is the basis of the singleton pattern (Exercise 6 in Part 6).

### Interview questions

**Q1. What are the access qualifiers in SystemVerilog?**
`local`, `protected`, and public (the default, with no keyword).

**Q2. What is the difference between `local` and `protected`?**
A `local` member is accessible only within the class that declares it. A `protected` member is accessible within that class and within all classes derived from it. Neither is accessible from outside.

**Q3. When are access violations detected?**
At compile time.

**Q4. How do you read a local property from outside the class?**
Through a public method of the class (a "getter"), such as `get_balance()`.

**Q5. Why hide data at all?**
So that the object's state can change only through methods that keep it consistent, and so that the internal representation can be changed later without breaking code that uses the class. This is encapsulation (Section 4.2).

## 2.7 Forward Declaration with typedef class

### The problem

The compiler reads a file from top to bottom. A class name must be known before it is used as the type of a handle. When two classes refer to each other, there is no order in which both are declared before use:

```systemverilog
class demo_monitor;
  demo_driver drv;      // ERROR: demo_driver is not known yet
endclass

class demo_driver;
  demo_monitor mon;     // fine: demo_monitor was declared above
endclass
```

### The solution

A **forward declaration** tells the compiler "this name is a class; its definition comes later":

```systemverilog
typedef class demo_driver;
```

After that line, handles of type `demo_driver` may be declared. The full class definition must appear later in the same scope.

### Complete example

```systemverilog file=tb_forward_typedef.sv
module tb_forward_typedef;

  typedef class demo_driver;          // forward declaration

  class demo_monitor;
    string      name = "monitor";
    demo_driver drv;                  // legal because of the typedef above
  endclass

  class demo_driver;
    string       name = "driver";
    demo_monitor mon;
  endclass

  demo_monitor m;
  demo_driver  d;

  initial begin
    m = new();
    d = new();
    m.drv = d;                        // connect the two objects to each other
    d.mon = m;
    $display("%s knows %s", m.name, m.drv.name);
    $display("%s knows %s", d.name, d.mon.name);
  end

endmodule
```

```output
monitor knows driver
driver knows monitor
```

### When a forward declaration is needed

| Situation | Needed? |
|---|---|
| Two classes hold handles of each other (circular reference) | Yes |
| A class is used as a handle type before its definition appears in the file or package | Yes |
| A class holds a handle of its own type (`node next;` inside `class node`) | No, the class name is already known inside its own body |
| The forward-declared class is only used as a handle type before its definition | Fine |
| You try to call `new()` on it, access its members, or extend it before the definition | Not allowed: the compiler needs the full definition for these |

> **Verification application:** In UVM and in layered testbenches, circular references are common: an environment holds its agents and each agent may hold a handle back to a shared configuration or to its parent. Packages therefore often start with a list of `typedef class` lines.

### Interview questions

**Q1. What is a forward declaration and why is it needed?**
`typedef class name;` announces that `name` is a class defined later. It is needed when a class is referenced before its definition, most often when two classes contain handles to each other.

**Q2. Can you create an object of a forward-declared class before its definition?**
No. Only handle declarations are possible until the compiler has seen the full definition.

## 2.8 Object Lifetime and Garbage Collection

### In plain English

You create objects with `new()`. You never delete them. The simulator watches which objects can still be reached through some handle. When an object can no longer be reached by anybody, it is useless, and the simulator takes its memory back automatically. This is called **garbage collection**.

### Technical definition

- An object's lifetime begins when `new()` returns.
- An object remains alive as long as it is **reachable**: at least one live handle refers to it, directly or through a chain of other reachable objects (a handle in a variable, a class property, an array or queue element, a mailbox entry, an argument or local variable of a method that has not finished, including methods suspended in running threads).
- When an object becomes unreachable, the simulator may reclaim its memory at any time. SystemVerilog provides automatic memory management; there is no `delete` or `free` for objects and there are **no destructors**.

### How it works

```text
   p1 = new();          p2 = p1;              p1 = null;            p2 = null;

   p1 --> [obj]         p1 --+                p1 --> null           p1 --> null
   p2 --> null               +--> [obj]       p2 --> [obj]          p2 --> null
                        p2 --+
                                                                    [obj]  no handle left
   1 reference          2 references          1 reference           -> garbage, reclaimed
```

Ways in which an object loses a reference:

| Action | Example |
|---|---|
| The handle is set to `null` | `p = null;` |
| The handle is assigned another object | `p = new();` or `p = other;` |
| The handle variable ceases to exist | A local variable of a task that returns |
| The container entry is removed | `q.pop_front()`, `q.delete()`, `mbx.get(t)` followed by `t` going out of scope |
| The object holding the handle becomes garbage itself | An environment object is dropped, and with it everything only it referred to |

### Common pattern: one new object per loop iteration

```systemverilog
task alu_generator::run();
  alu_txn txn;
  repeat (num_txns) begin
    txn = new();                 // a NEW object every iteration
    void'(txn.randomize());
    gen2drv_mbx.put(txn);        // the mailbox now also refers to the object
  end                            // next iteration: txn is re-assigned, but the old
endtask                          // object stays alive because the mailbox holds it
```

Each object lives until the driver has taken it out of the mailbox and no component holds its handle any longer. Nobody frees anything explicitly. The opposite mistake, creating the object once outside the loop, is shown in Section 3.1.

### Facts worth knowing

| Fact | Detail |
|---|---|
| No destructor | There is no method that runs when an object is reclaimed. Clean-up that matters (closing files, final reports) must be called explicitly |
| You cannot force collection | Setting handles to `null` only makes an object *eligible* |
| Circular references | Two objects that refer only to each other, with no outside handle, are unreachable and are collected. The mechanism is defined by reachability, not by a simple reference count |
| Memory "leaks" still happen | If handles are kept forever in a queue, associative array or scoreboard that is never emptied, the objects are reachable and are never collected. Long simulations slow down and run out of memory this way |
| Threads keep objects alive | A task of an object that is still running in a `fork` branch keeps that object (through `this`) and its local handles alive |
| Static handles | An object referred to by a static property is alive for the whole simulation unless the property is cleared |

> **Interview trap:** "How do you delete an object in SystemVerilog?" You do not. You remove all references to it (for example by assigning `null`), and the simulator reclaims the memory automatically. There is no `delete` for objects and no destructor.

> **Verification application:** A scoreboard that stores every expected transaction in a queue and never removes matched entries is the usual cause of steadily growing memory in long regressions. Remove items when they have been compared.

### Interview questions

**Q1. How is memory for objects released in SystemVerilog?**
Automatically, by garbage collection. When no handle refers to an object any more, the simulator reclaims its memory.

**Q2. Does SystemVerilog have destructors?**
No.

**Q3. `p1 = new(); p2 = p1; p1 = null;` Is the object destroyed?**
No. `p2` still refers to it. It becomes eligible for collection only when `p2` is also changed.

**Q4. Can a class-based testbench have a memory leak?**
Not in the C sense of unreachable allocated memory, but effectively yes: objects kept in a growing queue, array or mailbox that is never drained stay reachable and are never freed.

**Q5. What happens to objects created inside a task when the task returns?**
If the only handles to them were the task's local variables, they become unreachable and are collected. If a handle was stored elsewhere (returned, put in a mailbox, saved in a property), the object lives on.
