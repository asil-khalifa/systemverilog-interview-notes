# Part 4: The OOP Pillars, Encapsulation and Inheritance

## 4.1 The Four Pillars of OOP

Object-oriented programming rests on four ideas. Interviewers expect you to name all four, define each in one or two sentences, and give a SystemVerilog example of each.

| Pillar | One-sentence definition | SystemVerilog mechanism | Testbench example |
|---|---|---|---|
| **Encapsulation** | Keep data and the methods that operate on it together in one unit, and hide the internal details | `class`, `local`, `protected` | `alu_txn` holds its fields with `print`, `copy`, `compare`; a scoreboard hides its expected-queue behind `write()` |
| **Inheritance** | Build a new class from an existing one, reusing its members and adding or changing only what differs | `extends`, `super` | `class alu_arith_txn extends alu_txn` adds a constraint; `class smoke_test extends base_test` |
| **Polymorphism** | One handle type, many object types: the same method call does different things depending on the actual object | `virtual` methods, base-class handles | The driver calls `txn.print()` on an `alu_txn` handle and the derived class's version runs |
| **Abstraction** | Define *what* must be done without saying *how*; expose only the essential interface | `virtual class`, `pure virtual` methods | A base component declares `pure virtual task run();` and every component implements it |

```text
                         +--------------------+
                         |   Encapsulation    |   data + methods in one unit, details hidden
                         +--------------------+
                                   |
                         +--------------------+
                         |    Inheritance     |   new classes built from existing classes
                         +--------------------+
                            |              |
              +----------------------+  +----------------------+
              |    Polymorphism      |  |     Abstraction      |
              | same call, behaviour |  | interface without    |
              | chosen by the object |  | implementation       |
              +----------------------+  +----------------------+

   Polymorphism and abstraction both depend on inheritance; inheritance depends on classes.
```

> **How to say it in an interview:** "Encapsulation is bundling data and methods in a class and controlling access with local and protected. Inheritance is deriving a new class from a base class with extends, so that common code is written once. Polymorphism is calling a virtual method through a base-class handle and getting the behaviour of the actual derived object. Abstraction is defining a common interface in a virtual class with pure virtual methods and leaving the implementation to the derived classes."

The rest of this part covers encapsulation and inheritance. Part 5 covers polymorphism and abstraction.

## 4.2 Encapsulation

### In plain English

Encapsulation has two halves.

1. **Bundling.** The data and the code that works on that data are put in one unit, the class. A packet knows how to print, copy and compare itself.
2. **Information hiding.** The class decides which of its members the outside world may touch. The rest is private. The outside world uses the object only through the methods the class offers.

### Technical definition

Encapsulation is the binding of properties and methods into a class together with the restriction of direct access to some of them, using the access qualifiers `local` and `protected` (Section 2.6). The public methods form the class's **interface**; the hidden properties and helper methods form its **implementation**.

### Why it is needed

| Benefit | Explanation |
|---|---|
| Data integrity | Hidden data can only change through methods that enforce the rules (for example, a FIFO model that refuses to pop when empty) |
| Freedom to change the implementation | If users depend only on the public methods, the internal data structure can be replaced without editing any user code |
| Simpler use | A user needs to learn a handful of public methods, not every internal variable |
| Easier debugging | When hidden data is wrong, the fault must be in one of the few methods of the class that can write it |

### Complete example

A reference model of a small FIFO for a scoreboard. The storage is hidden; only `push`, `pop` and the status functions are public.

```systemverilog file=tb_encapsulation.sv
module tb_encapsulation;

  class fifo_model;
    local bit [7:0] mem [$];            // hidden storage
    local int       depth;              // hidden configuration
    local int       overflow_count;     // hidden statistics

    function new(int depth = 16);
      this.depth = depth;
    endfunction

    function bit push(bit [7:0] value);
      if (is_full()) begin
        overflow_count++;
        return 0;                       // rejected: the model stays consistent
      end
      mem.push_back(value);
      return 1;
    endfunction

    function bit pop(output bit [7:0] value);
      if (is_empty()) return 0;
      value = mem.pop_front();
      return 1;
    endfunction

    function bit is_full();   return mem.size() == depth; endfunction
    function bit is_empty();  return mem.size() == 0;     endfunction
    function int used();      return mem.size();          endfunction
    function int overflows(); return overflow_count;      endfunction
  endclass

  fifo_model fifo;
  bit [7:0]  v;
  bit        ok;

  initial begin
    fifo = new(2);                                   // a 2-entry model

    ok = fifo.push(8'h11);  $display("push 11: ok=%0d used=%0d", ok, fifo.used());
    ok = fifo.push(8'h22);  $display("push 22: ok=%0d used=%0d", ok, fifo.used());
    ok = fifo.push(8'h33);  $display("push 33: ok=%0d used=%0d", ok, fifo.used());

    ok = fifo.pop(v);       $display("pop    : ok=%0d value=%h", ok, v);
    ok = fifo.pop(v);       $display("pop    : ok=%0d value=%h", ok, v);
    ok = fifo.pop(v);       $display("pop    : ok=%0d (empty)", ok);

    $display("overflows=%0d", fifo.overflows());
    // fifo.mem.push_back(8'hFF);                    // ILLEGAL: mem is local
    // fifo.depth = 100;                             // ILLEGAL: depth is local
  end

endmodule
```

```output
push 11: ok=1 used=1
push 22: ok=1 used=2
push 33: ok=0 used=2
pop    : ok=1 value=11
pop    : ok=1 value=22
pop    : ok=0 (empty)
overflows=1
```

**Line by line**

| Line | Explanation |
|---|---|
| `local bit [7:0] mem [$];` | The queue is an implementation detail. It could be replaced by a fixed array with read and write pointers without changing any code outside the class. |
| `function bit push(bit [7:0] value);` | The only way to add data. It refuses when the model is full, so `mem` can never exceed `depth`. |
| `function bit pop(output bit [7:0] value);` | Returns a status and delivers the data through an `output` argument (Module 3). |
| `is_full()`, `is_empty()`, `used()`, `overflows()` | Read-only "getter" methods. There is no setter for `overflow_count`: nobody outside can falsify the statistics. |
| Third push | The model holds 2 entries, so the push is rejected and counted. |
| The two commented lines | Direct access to the internals is rejected by the compiler. |

### Encapsulation versus abstraction

These two are often confused in interviews.

| | Encapsulation | Abstraction |
|---|---|---|
| Question it answers | How are the details *protected*? | Which details are *shown* at all? |
| Focus | Hiding the implementation inside a class | Presenting a simplified interface that many classes share |
| Mechanism | `class`, `local`, `protected` | `virtual class`, `pure virtual` methods |
| Level | Inside one class | Across a family of classes |
| Example | `mem` is `local` in `fifo_model` | Every component has `run()`; callers do not know which component it is |

> **Common mistake:** Saying "encapsulation means making everything local". Encapsulation is about a deliberate interface. In transaction classes most fields stay public, because randomization constraints, drivers and scoreboards all need them; what is encapsulated is the *behaviour* (`print`, `copy`, `compare`) together with the data.

### Interview questions

**Q1. What is encapsulation?**
Binding data and the methods that operate on it into a single unit (a class), and restricting direct access to the internal data using `local` and `protected`, so that the object is used only through its public methods.

**Q2. How is encapsulation achieved in SystemVerilog?**
By declaring a class, marking implementation details `local` or `protected`, and providing public methods as the interface.

**Q3. What is the difference between encapsulation and abstraction?**
Encapsulation hides the implementation inside a class and protects its data. Abstraction defines a common, simplified interface (typically in an abstract base class) and leaves the implementation to derived classes.

## 4.3 Inheritance

### In plain English

Suppose you have a working class for a bus transaction and now need a "write" transaction that is the same but also carries data. You could copy the class and edit the copy; then every future bug fix has to be made twice. Inheritance lets you say instead: "a write transaction **is a** bus transaction, plus this". The new class automatically has everything the old one has.

### Technical definition

Inheritance is the mechanism by which a new class (the **derived**, **child**, **sub** or **extended** class) is defined from an existing class (the **base**, **parent** or **super** class) using the keyword `extends`. The derived class inherits all properties and methods of the base class and may

- **add** new properties and methods,
- **override** (redefine) inherited methods,
- **add or override** constraints (Module 5).

The base class is not modified.

### Terminology

| Term | Meaning |
|---|---|
| Base class / parent class / super class | The class being extended |
| Derived class / child class / subclass / extended class | The class that extends another |
| "is-a" relationship | A derived object is also a base object: a `write_txn` is a `base_txn` |
| "has-a" relationship (composition) | A class contains a handle to another class: a `packet` has a `header`. This is not inheritance |
| Class hierarchy | The tree formed by all the `extends` relationships |

### Syntax

```systemverilog
class base_txn;
  ...
endclass

class write_txn extends base_txn;      // single inheritance
  ...
endclass

class burst_txn extends write_txn;     // multilevel inheritance
  ...
endclass
```

### What is inherited

| Member of the base class | Inherited by the derived class? | Accessible in the derived class's code? |
|---|---|---|
| Public properties and methods | Yes | Yes |
| `protected` properties and methods | Yes | Yes |
| `local` properties and methods | Yes, they exist in the object | **No**, not by name; only through inherited base-class methods |
| Static properties and methods | Yes, shared with the base class (one copy for the whole hierarchy) | Yes, unless `local` |
| Constraints | Yes | Can be overridden by name (Module 5) |
| The constructor `new` | **Not inherited.** Each class has its own; the derived constructor calls the base constructor (Section 4.4) | |

### How it works internally

A derived object contains a complete base-class part followed by the members added by each level of derivation.

```text
   class base_txn;                    bit [7:0] addr;   endclass
   class write_txn extends base_txn;  bit [7:0] data;   endclass
   class burst_txn extends write_txn; int       len;    endclass

   one burst_txn object:
   +---------------------------------------------+
   |  base_txn part      addr                    |  <- everything declared in base_txn
   |---------------------------------------------|
   |  write_txn part     data                    |  <- what write_txn added
   |---------------------------------------------|
   |  burst_txn part     len                     |  <- what burst_txn added
   +---------------------------------------------+

   class hierarchy:        base_txn
                               ^
                               |   extends
                           write_txn
                               ^
                               |   extends
                           burst_txn
```

### Kinds of inheritance

| Kind | Meaning | Supported in SystemVerilog? |
|---|---|---|
| Single | One class extends one base class | Yes |
| Multilevel | A extends B, B extends C; any depth | Yes |
| Hierarchical | Several classes extend the same base class | Yes |
| Multiple | One class extends two or more base classes | **No.** A class can `extends` only one class. (Since IEEE 1800-2012 a class may additionally `implements` several *interface classes*, which contain only pure virtual method prototypes; see Section 5.5) |

### Complete example: single and multilevel inheritance

```systemverilog file=tb_inheritance.sv
module tb_inheritance;

  class base_txn;
    bit [7:0] addr;

    function new();
      $display("   base_txn::new");
    endfunction

    function void print();
      $display("addr=%h", addr);
    endfunction
  endclass

  class write_txn extends base_txn;           // single inheritance
    bit [7:0] data;

    function new();
      $display("   write_txn::new");
    endfunction

    function void print_all();
      print();                                // inherited method, used directly
      $display("data=%h", data);
    endfunction
  endclass

  class burst_txn extends write_txn;          // multilevel inheritance
    int len;

    function new();
      $display("   burst_txn::new");
    endfunction
  endclass

  burst_txn b;

  initial begin
    $display("creating a burst_txn:");
    b = new();

    b.addr = 8'h10;       // declared in base_txn
    b.data = 8'hCD;       // declared in write_txn
    b.len  = 4;           // declared in burst_txn

    b.print_all();        // method from write_txn, which calls print() from base_txn
    $display("len=%0d", b.len);
  end

endmodule
```

```output
creating a burst_txn:
   base_txn::new
   write_txn::new
   burst_txn::new
addr=10
data=cd
len=4
```

**Line by line**

| Line | Explanation |
|---|---|
| `class write_txn extends base_txn;` | `write_txn` has `addr` and `print()` without declaring them. |
| `class burst_txn extends write_txn;` | `burst_txn` has everything from both classes above it. |
| The three `new` functions | None of them calls the base constructor explicitly, yet all three messages appear. The compiler inserts a call to the base-class constructor at the start of each derived constructor (Section 4.4). |
| Order of the messages | Base first, most-derived last. The object is built from the inside out, so that when a derived constructor runs, the inherited part is already initialised. |
| `b.addr`, `b.data`, `b.len` | One object, three levels of properties, all accessed the same way. |
| `print()` inside `print_all()` | An inherited method is called like a method of the class itself. |

### Inheritance versus composition

| | Inheritance ("is-a") | Composition ("has-a") |
|---|---|---|
| Syntax | `class b extends a;` | `class b; a a_h; endclass` |
| Relationship | `b` is a kind of `a` | `b` contains or uses an `a` |
| Access to the other class's members | Direct (public and protected) | Through the handle, public members only |
| A `b` handle can be assigned to an `a` handle | Yes | No |
| Examples | `alu_arith_txn extends alu_txn`; `error_test extends base_test` | `alu_env` has an `alu_driver`, an `alu_monitor` and an `alu_scoreboard` |

> **Key point:** Use inheritance when the new class really is a specialised version of the old one and should be usable wherever the old one is. Use composition when one object merely uses or owns another. An environment *has* a driver; it is not a driver.

> **Verification application:** Inheritance is how tests are written without touching the environment. A base transaction is randomized by the generator; a test defines `class alu_arith_txn extends alu_txn` with an extra constraint that allows only `ALU_ADD` and `ALU_SUB`, and tells the generator to create that class instead. Likewise `class error_test extends base_test` overrides one method to inject errors. No existing file is edited.

### Interview questions

**Q1. What is inheritance?**
Creating a new class from an existing class with `extends`. The derived class gets all properties and methods of the base class and can add new ones or override existing ones.

**Q2. Which kinds of inheritance does SystemVerilog support?**
Single, multilevel and hierarchical. Multiple inheritance of classes is not supported; a class can extend only one class (but may implement several interface classes).

**Q3. Are `local` members inherited?**
They are part of the derived object and are used by the inherited base-class methods, but the derived class's own code cannot refer to them by name.

**Q4. Is the constructor inherited?**
No. Each class has its own constructor. The derived-class constructor calls the base-class constructor, explicitly with `super.new(...)` or implicitly.

**Q5. In which order do constructors run when a derived object is created?**
From the base class down to the most-derived class.

**Q6. What is the difference between inheritance and composition?**
Inheritance models an "is-a" relationship using `extends`. Composition models a "has-a" relationship by holding a handle to another class as a property.

## 4.4 The super Keyword

### In plain English

Inside a derived class, `super` means "the part of me that comes from my parent class". It is used when the derived class has redefined something and still needs the parent's version, and to pass arguments to the parent's constructor.

### Technical definition

`super` is a keyword, usable inside a derived class, that refers to the members of the immediate base class. It is used to

1. call the base-class constructor: `super.new(arguments);`
2. call a base-class method that the derived class has overridden: `super.print();`
3. access a base-class property that the derived class has hidden by declaring a property of the same name: `super.kind`.

### this versus super

| | `this` | `super` |
|---|---|---|
| Refers to | The current object, starting the name search in the current class | The same object, but starting the name search in the immediate base class |
| Typical use | `this.addr = addr;` | `super.new(name);` `super.print();` |
| Available in | Any non-static method | Non-static methods of a derived class |
| Can be passed as a handle or returned | Yes | No, `super` is not a handle; it can only be followed by `.member` |

### Rules for super.new()

| Rule | Detail |
|---|---|
| Position | `super.new(...)` must be the **first executable statement** of the derived constructor |
| Implicit call | If the derived constructor does not call `super.new`, the compiler inserts `super.new();` (with no arguments) at its start. The same happens if the derived class has no constructor at all |
| Base constructor with required arguments | The implicit call has no arguments, so it does not compile. The derived class **must** define a constructor that calls `super.new(...)` with the arguments |
| Alternative form | Arguments for the base constructor may be given in the class header: `class write_txn extends base_txn(8'h10);` |
| No `super.super` | Only the immediate base class can be named. To reach a grandparent's method, the parent's method must itself call `super.method()` |

### Order of construction in a derived class

```text
   d = new();     // class derived extends base

   1. memory for the whole object (base part + derived part) is allocated
   2. super.new() executes:
        a. base-class property initialisers
        b. base-class constructor body
   3. derived-class property initialisers
   4. the rest of the derived-class constructor body
```

Step 3 comes after step 2. A derived property initialiser can therefore use values the base constructor has set, and a base constructor cannot rely on derived properties being initialised yet.

### Complete example

```systemverilog file=tb_super.sv
module tb_super;

  class base_txn;
    string    name;
    bit [7:0] addr;
    int       x = 1;

    function new(string name, bit [7:0] addr);
      this.name = name;
      this.addr = addr;
      $display("   base_txn::new   x=%0d", x);
      x = 2;
    endfunction

    function void print();
      $display("%s: addr=%h", name, addr);
    endfunction
  endclass

  class write_txn extends base_txn;
    bit [7:0] data;
    int       y = x + 10;                       // initialiser uses an inherited property

    function new(string name, bit [7:0] addr, bit [7:0] data);
      super.new(name, addr);                    // must be first: builds the base part
      this.data = data;
      $display("   write_txn::new  x=%0d y=%0d", x, y);
    endfunction

    function void print();                      // overrides base_txn::print
      super.print();                            // reuse the base-class version
      $display("%s: data=%h", name, data);      // then add what is new
    endfunction
  endclass

  write_txn w;

  initial begin
    w = new("wr0", 8'h40, 8'h7E);
    w.print();
  end

endmodule
```

```output
   base_txn::new   x=1
   write_txn::new  x=2 y=12
wr0: addr=40
wr0: data=7e
```

**Line by line**

| Line | Explanation |
|---|---|
| `function new(string name, bit [7:0] addr);` in `base_txn` | The base constructor has two required arguments. An implicit `super.new()` would not compile, so the derived class must call it explicitly. |
| `super.new(name, addr);` | The first statement of the derived constructor. It initialises the inherited part of the object. |
| First output line | Inside the base constructor, `x` already has its declaration initialiser, 1. The constructor then changes it to 2. |
| `int y = x + 10;` | A derived-class initialiser. It runs **after** `super.new()` has returned, so it sees `x` = 2 and `y` becomes 12. |
| Second output line | Confirms the order: base initialisers, base body, derived initialisers, derived body. |
| `function void print();` in `write_txn` | Redefines the inherited method. |
| `super.print();` | Calls the version in `base_txn`. Without `super.`, the call `print()` would call the method itself and recurse for ever. |

> **Interview trap:** "The derived class has no constructor. Is the base constructor still called?" Yes. The compiler provides a default constructor for the derived class, which calls `super.new()`.

> **Interview trap:** "The base class constructor is `function new(int size);` with no default. What happens if I write `class child extends parent; endclass`?" Compile error: the implicit `super.new()` passes no argument. Either give `size` a default value, or write a constructor in `child` that calls `super.new(value)`.

> **Common mistake:** Putting a statement before `super.new(...)`. It is a compile error. Only declarations may precede it.

> **Common mistake:** Forgetting `super.` when extending a method. Writing `print();` inside `write_txn::print` calls `write_txn::print` again: infinite recursion and a stack overflow at run time.

> **Verification application:** Every UVM component constructor is `function new(string name, uvm_component parent); super.new(name, parent); endfunction`, and every overridden phase starts with `super.build_phase(phase);`. Forgetting the `super` call is a standard UVM bug: the base class's work (creating children, applying configuration) silently does not happen.

### Interview questions

**Q1. What is `super`?**
A keyword used in a derived class to refer to members of its immediate base class: the base constructor, an overridden method, or a hidden property.

**Q2. Why must `super.new()` be the first statement of a constructor?**
The base-class part of the object must be fully initialised before the derived class's code can safely use inherited members.

**Q3. When is an explicit `super.new(...)` call mandatory?**
When the base-class constructor has arguments without default values.

**Q4. Is `super.super.method()` allowed?**
No. `super` reaches only the immediate base class.

**Q5. What is the difference between `this` and `super`?**
`this` is a handle to the current object and starts name look-up in the current class. `super` refers to the same object but starts look-up in the base class; it is not a handle and cannot be stored or passed.

## 4.5 Method Overriding

### In plain English

A derived class inherits its parent's methods. If one of them does not do quite the right thing for the derived class, the derived class can declare a method with the **same name** and supply its own body. The new version replaces the inherited one for objects of the derived class. This is **overriding**.

### Technical definition

**Method overriding** is the redefinition, in a derived class, of a method that exists in a base class, using the same name. For a `virtual` method the signature (return type, number, types and directions of arguments) must also match. The same can be done with properties: a derived class may declare a property with the same name as a base-class property, which **hides** the base-class property.

### Which version runs?

This is the central question, and the answer depends on whether the method is `virtual`.

| Method declared in the base class as | Version chosen by | Decided at |
|---|---|---|
| Non-virtual (plain `function` / `task`) | The **type of the handle** used for the call | Compile time ("static binding") |
| `virtual` | The **type of the object** the handle refers to | Run time ("dynamic binding"), Section 5.2 |

Properties are never virtual: `handle.property` always selects by the type of the handle.

This section demonstrates the non-virtual case, so that the need for `virtual` in Part 5 is clear.

### Complete example

```systemverilog file=tb_override.sv
module tb_override;

  class base_txn;
    int kind = 1;

    function void print();
      $display("base_txn::print   kind=%0d", kind);
    endfunction
  endclass

  class write_txn extends base_txn;
    int kind = 2;                              // hides base_txn::kind

    function void print();                     // overrides base_txn::print (non-virtual)
      $display("write_txn::print  kind=%0d  super.kind=%0d", kind, super.kind);
    endfunction
  endclass

  base_txn  b;
  write_txn w;

  initial begin
    w = new();
    w.print();                                 // called through a write_txn handle

    b = w;                                     // base handle, SAME write_txn object
    b.print();                                 // called through a base_txn handle

    $display("b.kind=%0d  w.kind=%0d", b.kind, w.kind);
  end

endmodule
```

```output
write_txn::print  kind=2  super.kind=1
base_txn::print   kind=1
b.kind=1  w.kind=2
```

**Line by line**

| Line | Explanation |
|---|---|
| `int kind = 2;` in `write_txn` | The object now contains **two** properties called `kind`: the one from `base_txn` (value 1) and the one from `write_txn` (value 2). Inside `write_txn`, the plain name means the derived one; `super.kind` reaches the base one. |
| `w.print();` | The handle type is `write_txn`, so `write_txn::print` runs. |
| `b = w;` | A base-class handle may refer to a derived object (upcasting, Section 5.1). No new object is created. |
| `b.print();` | The handle type is `base_txn` and `print` is not virtual, so the compiler binds the call to `base_txn::print`, **even though the object is a `write_txn`**. Inside that method, `kind` means `base_txn::kind`, which is 1. |
| `b.kind` and `w.kind` | Property access follows the handle type: 1 through `b`, 2 through `w`. Same object, different answers. |

The second output line is usually not what the programmer wanted. The object is a write transaction and should print itself as one, whichever handle is used. Making `print` virtual (Section 5.2) fixes exactly this.

### Rules and good practice

| Topic | Rule |
|---|---|
| Overriding a non-virtual method | Allowed with any signature; the derived method simply hides the base method for derived-type handles. Rarely what you want |
| Overriding a virtual method | The return type and the argument list must match the base-class prototype |
| Calling the base version | `super.method()` |
| Access qualifier | An override may be declared with a different qualifier, but keep it the same to avoid surprises |
| Hiding a property | Legal, but almost always a mistake. Do not reuse a base-class property name in a derived class |
| Constructors | Not overridden; they are chained with `super.new` |
| Static methods | Can be redefined in a derived class, but they are not virtual: `class_name::method()` always selects by the named class |

> **Interview trap:** "A base handle refers to a derived object and a non-virtual method is called. Which version executes?" The base-class version, because for non-virtual methods the handle type decides. Many candidates answer "the derived one".

> **Common mistake:** Re-declaring a property in the derived class "to change its default value", for example `int kind = 2;`. That creates a second, separate property. To change the default of an inherited property, assign it in the derived constructor: `kind = 2;`.

### Interview questions

**Q1. What is method overriding?**
Redefining, in a derived class, a method that already exists in the base class, with the same name (and, for virtual methods, the same signature), so that derived objects use the new implementation.

**Q2. How do you call the base-class version of an overridden method?**
`super.method_name(arguments)` from inside the derived class.

**Q3. What happens if a derived class declares a property with the same name as a base-class property?**
The object has both. The derived one hides the base one inside the derived class; the base one is still reachable with `super.name` or through a base-class handle. Which one `handle.name` selects depends on the type of the handle.

**Q4. Without `virtual`, which method is called through a base handle that points to a derived object?**
The base-class method.

## 4.6 Method Overloading and Its Limitations

### What overloading is

In C++ and Java, **overloading** means having several methods with the **same name in the same class**, distinguished by the number or types of their arguments. The compiler picks the right one for each call:

```text
   // C++ / Java style -- NOT legal SystemVerilog
   void log(string msg);
   void log(string msg, int value);
   void log(int value);
```

### SystemVerilog does not support it

In SystemVerilog a name can be declared only once in a scope. Two methods with the same name in one class are a compile error, whatever their arguments. That includes constructors: a class has exactly one `new`.

```systemverilog
class logger;
  function void log(string msg);              endfunction
  function void log(string msg, int value);   endfunction   // ERROR: 'log' already declared
endclass
```

Why the language was designed this way: SystemVerilog converts freely and implicitly between integral types of different widths and signedness, between two-state and four-state types, and between integers and reals (Module 1, Section 4.1). Choosing "the best match" among several overloads would be ambiguous for a call such as `f(5)` when both `f(byte)` and `f(logic [31:0])` exist. The language avoids the problem by not allowing it. Default argument values cover most practical needs.

### Overloading versus overriding

| | Overloading | Overriding |
|---|---|---|
| Where | Same class (same scope) | Base class and derived class |
| Method name | Same | Same |
| Argument list | Must differ | Must be the same (for virtual methods) |
| Resolved at | Compile time, from the arguments | Run time for virtual methods, from the object type |
| Related pillar | Compile-time ("static") polymorphism | Run-time ("dynamic") polymorphism |
| Supported in SystemVerilog | **No** | **Yes** |

### Workarounds

| Need | SystemVerilog solution | Example |
|---|---|---|
| Optional arguments | Default argument values | `function void log(string msg, int value = -1);` |
| Different argument types | Different method names | `log_int(int v)`, `log_str(string s)`, `log_real(real r)` |
| Same algorithm for many types | Parameterized class (Module 11) | `class stack #(type T = int);` |
| Several ways to construct an object | One `new` with defaults, plus static "factory" functions | `static function packet make_read(bit [7:0] addr);` |
| Different behaviour per class | Overriding with virtual methods | Part 5 |

### Complete example: default arguments in place of overloading

```systemverilog file=tb_overload_workaround.sv
module tb_overload_workaround;

  class logger;
    string prefix;

    // One constructor serves "no argument" and "with argument"
    function new(string prefix = "LOG");
      this.prefix = prefix;
    endfunction

    // One method serves three calling styles
    function void log(string msg, int value = -1, string unit = "");
      if (value == -1) $display("%s: %s", prefix, msg);
      else             $display("%s: %s = %0d%s", prefix, msg, value, unit);
    endfunction

    // A static function used as a second, named way to build an object
    static function logger make_error_logger();
      logger l = new("ERROR");
      return l;
    endfunction
  endclass

  logger l1, l2;

  initial begin
    l1 = new();
    l1.log("start");
    l1.log("count", 5);
    l1.log("delay", 10, "ns");

    l2 = logger::make_error_logger();
    l2.log("mismatches", 3);
  end

endmodule
```

```output
LOG: start
LOG: count = 5
LOG: delay = 10ns
ERROR: mismatches = 3
```

**Line by line**

| Line | Explanation |
|---|---|
| `function new(string prefix = "LOG");` | Replaces the two constructors `new()` and `new(string)` that C++ would use. |
| `function void log(string msg, int value = -1, string unit = "");` | One method, three calling styles. The value -1 is used as "no value given", which works here because the logged counts are never negative. |
| `static function logger make_error_logger();` | A static method that builds and returns a pre-configured object: a "named constructor". |
| `logger::make_error_logger()` | Called on the class; no object is needed to call it. |

> **Interview trap:** "Does SystemVerilog support function overloading?" No. The follow-up is usually "then how do you get the same effect?": default arguments, distinct names, or parameterized classes. A second follow-up: "Is polymorphism still possible?" Yes, run-time polymorphism through virtual-method overriding is fully supported; only compile-time overloading is missing.

> **Common mistake:** Confusing the two words. Over**loading** is same name, different arguments, same class (not available). Over**riding** is same name, same arguments, in a derived class (available).

### Interview questions

**Q1. What is method overloading? Does SystemVerilog support it?**
Overloading is defining several methods with the same name but different argument lists in the same scope. SystemVerilog does not support it; each name may be declared once per class.

**Q2. What is the difference between overloading and overriding?**
Overloading: same class, same name, different arguments, resolved at compile time. Overriding: derived class redefines a base-class method with the same name and signature; with `virtual`, resolved at run time.

**Q3. Can a class have more than one constructor?**
No. Use default argument values in the single constructor, or static factory methods.

**Q4. How would you write a function that accepts either one or two arguments?**
Give the second argument a default value.
