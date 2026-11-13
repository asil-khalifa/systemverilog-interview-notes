# Part 5: Polymorphism and Abstraction

## 5.1 Upcasting: Base Handles and Derived Objects

### In plain English

Every write transaction is a bus transaction. So wherever a bus transaction is expected, a write transaction can be supplied. In code: a handle whose type is the base class may refer to an object of any class derived from it. Assigning a derived object to a base-class handle is called **upcasting**, because in the usual drawing of a class hierarchy the base class is at the top.

### Technical definition

**Upcasting** is the assignment of a derived-class handle to a base-class handle: `base_h = derived_h;`. It is always legal, needs no cast, and is checked at compile time. The object is not changed, copied or truncated; only the *view* of it is narrower. Through the base-class handle the compiler allows access only to members declared in the base class.

### How it works internally

```text
   write_txn w = new();        base_txn b;        b = w;         // upcast

        w  (type write_txn) ----+
                                +--> +--------------------------+
        b  (type base_txn)  ----+    |  base_txn part   addr    |  <- visible via b and w
                                     |--------------------------|
                                     |  write_txn part  data    |  <- visible through w only
                                     +--------------------------+

   b.addr   legal
   b.data   COMPILE ERROR: base_txn has no member "data"
            (the data is still in the object; the handle type simply cannot see it)
```

### Two types for every handle

To reason about any OOP question, keep two types apart.

| | Static type (handle type) | Dynamic type (object type) |
|---|---|---|
| What it is | The class the handle variable was declared with | The class of the object the handle currently refers to |
| Known at | Compile time | Run time |
| Can change | Never | Every time the handle is assigned |
| Decides | Which member **names** are legal; which **property** and which **non-virtual** method is selected | Which **virtual** method executes; whether a `$cast` succeeds |

### Why upcasting is needed

- **Generic containers.** One queue, array or mailbox of `base_txn` handles can hold read, write and burst transactions together.
- **Generic code.** A driver written for `base_txn` can process every present and future derived transaction without modification.
- **Substitution.** A test can replace the transaction a generator creates with a derived one, and the rest of the environment never notices.

All three depend on virtual methods (next section) to be useful: without them, the generic code would always execute base-class behaviour.

### Interview questions

**Q1. What is upcasting?**
Assigning a derived-class handle (or object) to a base-class handle. It is implicit and always legal.

**Q2. After `base_h = derived_h;`, can `base_h` access a property that exists only in the derived class?**
No. The compiler uses the handle type to check names, so only base-class members are accessible. The property still exists in the object; to reach it, the handle must be cast back to the derived type with `$cast`.

**Q3. Does upcasting create a new object or lose data?**
No. Both handles refer to the same, complete derived object.

## 5.2 Virtual Methods and Dynamic Binding

### In plain English

Section 4.5 ended with a problem: when a write transaction was printed through a base-class handle, the base-class `print()` ran. The compiler looked at the handle, saw `base_txn`, and wired the call to `base_txn::print` on the spot.

Declaring the method `virtual` changes the rule. The compiler no longer decides. At run time, at the moment of the call, the simulator looks at the **actual object** and runs the version belonging to the object's class.

### Technical definition

- A **virtual method** is a function or task declared with the keyword `virtual` in a class. A call to a virtual method is resolved at run time according to the class of the object the handle refers to, not the class of the handle.
- **Binding** is the association of a method call with the code that will execute.
  - **Static (early) binding:** done by the compiler from the handle type. Used for non-virtual methods.
  - **Dynamic (late) binding:** done at run time from the object type. Used for virtual methods.

### Syntax

```systemverilog
class base_txn;
  virtual function void print();       // virtual in the base class
    ...
  endfunction
endclass

class write_txn extends base_txn;
  virtual function void print();       // override; "virtual" optional but recommended
    ...
  endfunction
endclass
```

### Rules

| Rule | Detail |
|---|---|
| Once virtual, always virtual | A method declared `virtual` in a class is virtual in every class derived from it. Repeating the keyword in the derived classes is optional; write it anyway for clarity |
| Signature must match | An override of a virtual method must have the same return type and the same number, types, directions and names of arguments as the base prototype. A mismatch is a compile error |
| Functions and tasks | Both can be virtual |
| Not allowed to be virtual | Static methods and the constructor `new` |
| Properties | Cannot be virtual. Property access always follows the handle type |
| Calling the base version | `super.method()` is always statically bound to the base class's implementation |
| Default argument values | Taken from the prototype of the handle's class at compile time. Keep the defaults identical in every override |
| Access through any handle type | A derived handle calling a virtual method also gets the object's version; "virtual" matters most when the handle type is a base class |

### How it works internally: the virtual method table

Simulators typically implement dynamic binding with one **virtual method table** ("vtable") per class. The table lists, for each virtual method, the implementation that applies to that class. Every object carries a hidden reference to the table of its own class, set when the object is constructed.

```text
   class base_txn;
     virtual function void print();  ... endfunction     // virtual
     function void show();           ... endfunction     // NOT virtual
   endclass
   class write_txn extends base_txn;
     virtual function void print();  ... endfunction     // override
     function void show();           ... endfunction     // hides base show()
   endclass

   vtable of base_txn                     vtable of write_txn
   +---------+---------------------+      +---------+----------------------+
   | print   | base_txn::print     |      | print   | write_txn::print     |
   +---------+---------------------+      +---------+----------------------+
   (show is not virtual: it is in no table)

   base_txn b;   write_txn w = new();   b = w;

        b ----> +---------------------+
                | vtable --> write_txn's table
                | addr                |
                | data                |
                +---------------------+

   b.print();   1. follow b to the object
                2. follow the object's vtable reference       -> write_txn's table
                3. look up "print"                            -> write_txn::print
                4. call it                                         (dynamic binding)

   b.show();    not virtual: the compiler already emitted a direct call to
                base_txn::show, because b is declared as base_txn  (static binding)
```

A virtual call costs one extra table look-up. That cost is negligible, which is why nearly every method in a verification class library is virtual.

### Complete example

```systemverilog file=tb_virtual.sv
module tb_virtual;

  class base_txn;
    function void show();                              // non-virtual
      $display("   base_txn::show   (non-virtual)");
    endfunction

    virtual function void print();                     // virtual
      $display("   base_txn::print  (virtual)");
    endfunction
  endclass

  class write_txn extends base_txn;
    function void show();
      $display("   write_txn::show  (non-virtual)");
    endfunction

    virtual function void print();
      $display("   write_txn::print (virtual)");
    endfunction
  endclass

  base_txn  b;
  write_txn w;

  initial begin
    w = new();
    b = w;                       // base handle -> write_txn object

    $display("1. base handle, write_txn object:");
    b.show();
    b.print();

    $display("2. write_txn handle, write_txn object:");
    w.show();
    w.print();

    b = new();                   // base handle -> base_txn object
    $display("3. base handle, base_txn object:");
    b.show();
    b.print();
  end

endmodule
```

```output
1. base handle, write_txn object:
   base_txn::show   (non-virtual)
   write_txn::print (virtual)
2. write_txn handle, write_txn object:
   write_txn::show  (non-virtual)
   write_txn::print (virtual)
3. base handle, base_txn object:
   base_txn::show   (non-virtual)
   base_txn::print  (virtual)
```

**Line by line**

| Call | Handle type | Object type | Virtual? | Decided by | Runs |
|---|---|---|---|---|---|
| 1. `b.show()` | `base_txn` | `write_txn` | No | Handle | `base_txn::show` |
| 1. `b.print()` | `base_txn` | `write_txn` | Yes | Object | `write_txn::print` |
| 2. `w.show()` | `write_txn` | `write_txn` | No | Handle | `write_txn::show` |
| 2. `w.print()` | `write_txn` | `write_txn` | Yes | Object | `write_txn::print` |
| 3. `b.show()` | `base_txn` | `base_txn` | No | Handle | `base_txn::show` |
| 3. `b.print()` | `base_txn` | `base_txn` | Yes | Object | `base_txn::print` |

Block 1 is the important one: the same handle `b`, the same object, two calls, and the two calls go to different classes. The only difference is the keyword `virtual`.

### Virtual versus non-virtual method

| Property | Non-virtual method | Virtual method |
|---|---|---|
| Keyword | None | `virtual` |
| Binding | Static (compile time) | Dynamic (run time) |
| Selected by | Type of the handle | Type of the object |
| Override must match signature | No | Yes |
| Enables polymorphism | No | Yes |
| Cost | Direct call | One table look-up |
| When to use | Small helper that derived classes must never change | Anything a derived class may want to specialise: in practice, almost every method |

### The three meanings of the keyword virtual

| Usage | Meaning | Where covered |
|---|---|---|
| `virtual function` / `virtual task` | Method resolved at run time by object type | This section |
| `virtual class` | Abstract class: cannot be instantiated | Section 5.5 |
| `virtual interface` (`virtual alu_if vif;`) | A handle that refers to an interface instance, so that a class can reach DUT signals | Module 8 |

They share a keyword and nothing else. "Explain the different uses of `virtual` in SystemVerilog" is a standard interview question.

> **Interview trap:** "The base class declares `virtual function void print();`. The derived class overrides it but leaves out the word `virtual`. Is the derived method virtual?" Yes. Once a method is virtual in a base class it is virtual in all derived classes.

> **Interview trap:** "The base class method is *not* virtual, and the derived class declares the same method *with* `virtual`. What happens through a base handle?" The base version runs. Virtual dispatch starts at the class where the method is first declared virtual; a call through a handle of a class above that point is still statically bound.

> **Common mistake:** Forgetting `virtual` in the base class and then wondering why a derived test's or transaction's override "is never called". When an override seems to be ignored, the first thing to check is whether the base-class method is virtual.

> **Common mistake:** Calling a virtual method from a base-class constructor and expecting derived properties to be ready. In SystemVerilog the derived override *is* called, but the derived class's property initialisers and constructor body have not run yet (Section 4.4), so the override sees default values. Avoid calling virtual methods from constructors.

### Interview questions

**Q1. What is a virtual method?**
A method declared with `virtual`. Calls to it are bound at run time to the implementation in the class of the actual object, regardless of the type of the handle used.

**Q2. What is the difference between static and dynamic binding?**
Static binding is done at compile time from the handle's declared type; it applies to non-virtual methods and to properties. Dynamic binding is done at run time from the object's type; it applies to virtual methods.

**Q3. Why do we need virtual methods?**
So that code written in terms of a base class (a driver, a scoreboard, a generator, a container of base handles) automatically executes the specialised behaviour of whatever derived object it is given. Without `virtual`, a base handle would always run base-class code.

**Q4. Can a constructor or a static method be virtual?**
No.

**Q5. Does the override of a virtual method need the same arguments?**
Yes. The return type and argument list must match the base-class declaration.

**Q6. What are the uses of the keyword `virtual` in SystemVerilog?**
Virtual methods (run-time binding), virtual classes (abstract classes), and virtual interfaces (handles to interface instances).

## 5.3 Polymorphism

### In plain English

"Polymorphism" means "many forms". One line of code, `txn.print()`, takes many forms at run time: it prints a read transaction, a write transaction or a burst transaction, depending on what `txn` happens to refer to at that moment. The code that makes the call does not know and does not care which one it is.

### Technical definition

Polymorphism is the ability of a single base-class handle to refer to objects of different derived classes, and of a single method call through that handle to execute different implementations depending on the object's actual class. In SystemVerilog it requires three ingredients:

1. **Inheritance:** a base class and one or more derived classes.
2. **Virtual methods:** declared in the base class and overridden in the derived classes.
3. **A base-class handle referring to a derived object** (upcasting).

Remove any one of the three and there is no polymorphism.

### Complete example

```systemverilog file=tb_polymorphism.sv
module tb_polymorphism;

  class bus_txn;
    bit [7:0] addr;

    function new(bit [7:0] addr);
      this.addr = addr;
    endfunction

    virtual function void print();
      $display("BUS   addr=%h", addr);
    endfunction

    virtual function int size_in_bytes();
      return 1;
    endfunction
  endclass

  class read_txn extends bus_txn;
    function new(bit [7:0] addr);
      super.new(addr);
    endfunction

    virtual function void print();
      $display("READ  addr=%h", addr);
    endfunction
  endclass

  class write_txn extends bus_txn;
    bit [7:0] data;

    function new(bit [7:0] addr, bit [7:0] data);
      super.new(addr);
      this.data = data;
    endfunction

    virtual function void print();
      $display("WRITE addr=%h data=%h", addr, data);
    endfunction

    virtual function int size_in_bytes();
      return 2;
    endfunction
  endclass

  // Generic code: written once, for the base class only
  function automatic void process(bus_txn t);
    t.print();
    $display("      size=%0d byte(s)", t.size_in_bytes());
  endfunction

  bus_txn   txns [3];          // an array of base-class handles
  read_txn  r;
  write_txn w;

  initial begin
    r = new(8'h10);
    w = new(8'h20, 8'hAB);

    txns[0] = new(8'h00);      // a bus_txn object
    txns[1] = r;               // a read_txn object  (upcast)
    txns[2] = w;               // a write_txn object (upcast)

    foreach (txns[i]) process(txns[i]);
  end

endmodule
```

```output
BUS   addr=00
      size=1 byte(s)
READ  addr=10
      size=1 byte(s)
WRITE addr=20 data=ab
      size=2 byte(s)
```

**Line by line**

| Line | Explanation |
|---|---|
| `virtual function void print();` in `bus_txn` | Establishes the polymorphic interface. |
| `class read_txn extends bus_txn;` | Overrides `print` only. It inherits `size_in_bytes` unchanged, so a read reports 1. |
| `function new(bit [7:0] addr); super.new(addr); endfunction` | Needed because the base constructor has a required argument. |
| `class write_txn` | Overrides both virtual methods. |
| `function automatic void process(bus_txn t);` | This function knows only `bus_txn`. It was written without any knowledge of `read_txn` or `write_txn`. |
| `bus_txn txns [3];` | One array holds three different kinds of object, because each element is a base-class handle. |
| `foreach (txns[i]) process(txns[i]);` | The same two calls inside `process` produce three different behaviours. |

If a `burst_txn extends write_txn` is added next month, `process` and the loop work with it unchanged. That is the practical value of polymorphism: **new behaviour is added by writing new classes, not by editing existing code**.

### Without polymorphism

For comparison, the same task without virtual methods needs a type field and a `case` statement in every piece of generic code:

```systemverilog
case (t.kind)
  KIND_READ : print_read(t);
  KIND_WRITE: print_write(t);
  // every new kind of transaction means editing this statement, everywhere it appears
endcase
```

### Polymorphism in a testbench

| Where | How polymorphism is used |
|---|---|
| Generator | Holds an `alu_txn` handle (a "blueprint"). A test assigns a derived-class object to it; the generator's `randomize()` call then applies the derived class's constraints, because `randomize` is virtual (Module 5) |
| Driver | Receives `alu_txn` handles from the mailbox and calls virtual methods such as `print()`; derived transactions print their extra fields |
| Tests | `base_test` has virtual tasks; `error_test extends base_test` overrides one. `tb_top` holds a `base_test` handle and calls `run()` |
| Callbacks | A driver calls `cb.pre_drive(txn)` on a base callback handle; tests register derived callback objects that inject errors or delays |
| UVM | The factory, phases (`build_phase`, `run_phase`), `do_copy`, `do_compare` and sequences all rely on virtual methods called through base-class handles |

> **How to say it in an interview:** "Polymorphism means the same method call behaves differently depending on the object. In SystemVerilog I get it by declaring the method virtual in the base class, overriding it in derived classes, and calling it through a base-class handle that points to a derived object. The method is then chosen at run time by the object type, which is dynamic binding."

### Interview questions

**Q1. What is polymorphism?**
The ability of one base-class handle to refer to objects of different derived classes and of one method call to execute the implementation belonging to the actual object.

**Q2. What is required for polymorphism in SystemVerilog?**
Inheritance, a virtual method in the base class that is overridden in the derived class, and a base-class handle pointing to a derived-class object.

**Q3. Does SystemVerilog support compile-time polymorphism?**
Not through method overloading, which it lacks. Parameterized classes give a form of compile-time genericity. Run-time polymorphism through virtual methods is fully supported.

**Q4. How does polymorphism help in a verification environment?**
Components are written once against base classes. Tests change behaviour by supplying derived transactions, tests, callbacks or components, without modifying the environment. This is the basis of testbench reuse and of the UVM factory.

## 5.4 Downcasting and $cast

### In plain English

Upcasting is safe because every write transaction is a bus transaction. The reverse is not safe: a bus-transaction handle might be referring to a write transaction, a read transaction, or a plain bus transaction. Before you may treat it as a write transaction, somebody has to check what the object really is. The compiler cannot check, because the answer is known only at run time. `$cast` performs the check at run time.

### Technical definition

**Downcasting** is the assignment of a base-class handle to a derived-class handle. A direct assignment `derived_h = base_h;` is a **compile error**. It must be done with the dynamic cast `$cast(derived_h, base_h)`, which succeeds only if the object referred to by `base_h` is of the class of `derived_h` or of a class derived from that.

### Upcasting versus downcasting

| | Upcasting | Downcasting |
|---|---|---|
| Direction | Derived handle → base handle | Base handle → derived handle |
| Syntax | `base_h = derived_h;` | `$cast(derived_h, base_h)` |
| Checked at | Compile time | Run time |
| Can fail | Never | Yes, if the object is not of the destination class (or a subclass of it) |
| Purpose | Treat different objects uniformly | Regain access to derived-only members |

### Rules of $cast for class handles

`$cast(dest, src)` succeeds when the **object** `src` refers to could legally be assigned to `dest`:

| Object that `src` refers to | Type of `dest` | Result |
|---|---|---|
| A `write_txn` | `write_txn` | Succeeds |
| A `burst_txn` (which extends `write_txn`) | `write_txn` | Succeeds: a burst is a write |
| A plain `bus_txn` | `write_txn` | **Fails**: the object has no `write_txn` part |
| A `read_txn` (a sibling class) | `write_txn` | **Fails** |
| `src` is `null` | Any class type | Succeeds; `dest` becomes `null` |

As with enums (Module 1, Section 4.1), `$cast` can be called two ways:

| Called as | On success | On failure |
|---|---|---|
| Function: `if ($cast(d, b)) ...` | Assigns, returns 1 | Returns 0, `d` is left unchanged, no message |
| Task: `$cast(d, b);` | Assigns | Run-time error, `d` is left unchanged |

The static cast `write_txn'(b)` is not used for downcasting class handles; `$cast` is the tool for this job.

### Complete example

```systemverilog file=tb_downcast.sv
module tb_downcast;

  class bus_txn;
    bit [7:0] addr;
    virtual function void print();
      $display("BUS   addr=%h", addr);
    endfunction
  endclass

  class read_txn extends bus_txn;
    virtual function void print();
      $display("READ  addr=%h", addr);
    endfunction
  endclass

  class write_txn extends bus_txn;
    bit [7:0] data;
    virtual function void print();
      $display("WRITE addr=%h data=%h", addr, data);
    endfunction
  endclass

  bus_txn   b;
  read_txn  r;
  write_txn w, w2;

  initial begin
    w = new();
    w.addr = 8'h20;
    w.data = 8'hAB;

    b = w;                               // upcast: always legal
    // w2 = b;                           // COMPILE ERROR: base handle to derived handle
    // $display("%h", b.data);           // COMPILE ERROR: bus_txn has no member data

    if ($cast(w2, b))
      $display("1. cast to write_txn succeeded: data=%h, same object as w: %0d",
               w2.data, w2 == w);

    if (!$cast(r, b))
      $display("2. cast to read_txn failed: the object is a write_txn; r is null: %0d",
               r == null);

    b = new();                           // now b refers to a plain bus_txn
    if (!$cast(w2, b))
      $display("3. cast to write_txn failed: the object is only a bus_txn");
    $display("4. w2 is unchanged: data=%h", w2.data);

    // $cast(w2, b);                     // task form: this line would be a run-time error
  end

endmodule
```

```output
1. cast to write_txn succeeded: data=ab, same object as w: 1
2. cast to read_txn failed: the object is a write_txn; r is null: 1
3. cast to write_txn failed: the object is only a bus_txn
4. w2 is unchanged: data=ab
```

**Line by line**

| Line | Explanation |
|---|---|
| `b = w;` | Upcast. `b` now refers to the `write_txn` object. |
| `// w2 = b;` | Rejected by the compiler. From the types alone it cannot know that `b` refers to a `write_txn`. |
| `// b.data` | Rejected by the compiler: name checking uses the handle type. |
| `$cast(w2, b)` (line 1) | At run time the object is found to be a `write_txn`. The cast succeeds and `w2` refers to the same object as `w`. Its `data` is reachable again. |
| `$cast(r, b)` (line 2) | The object is a `write_txn`, which is not a `read_txn`. The function returns 0 and `r` keeps its previous value, `null`. |
| `b = new();` | `b` is a `bus_txn` handle, so `new()` constructs a `bus_txn` object. |
| `$cast(w2, b)` (line 3) | The object is only a `bus_txn`; it has no `data`. The cast fails. |
| Line 4 | A failed cast leaves the destination untouched: `w2` still refers to the original write transaction. |

### What decides success: the object, not the handle

```text
   bus_txn b;                         bus_txn b;
   b = <a write_txn object>           b = <a bus_txn object>

   $cast(w2, b)  -> succeeds          $cast(w2, b)  -> fails
   the object contains a              the object has no write_txn part;
   write_txn part                     letting w2 refer to it would allow
                                      access to a "data" that does not exist
```

### Where downcasting is used

| Situation | Example |
|---|---|
| A generic component receives base handles but needs derived-only fields | A scoreboard gets `bus_txn` handles from a mailbox and must read `data` when the item is a write |
| A virtual `copy()`/`clone()` returns a base-class handle | `$cast(my_copy, original.copy());` (Section 5.6) |
| Checking the type of an object | `if ($cast(w, t)) ...` works as an "is this a write?" test |
| UVM | `$cast(req, item)` in drivers and sequences; `$cast(rhs_, rhs)` at the top of every `do_copy` and `do_compare`; the result of `clone()` and of factory `create_object_by_name()` |

> **Interview trap:** "Can you assign a base-class handle to a derived-class handle?" Not directly; it is a compile error. With `$cast` it compiles, and it succeeds at run time only if the base handle is actually pointing to an object of the derived class (or one of its subclasses).

> **Interview trap:** "`base_txn b = new(); derived_txn d; $cast(d, b);` Does it work?" It compiles and fails at run time. The object was created as a `base_txn`; no cast can turn it into a `derived_txn`. A cast never changes an object, it only changes the type of the handle through which the object is viewed.

> **Common mistake:** Calling `$cast` as a task in code where failure is a normal possibility (the simulation stops with an error), or calling it as a function and ignoring the result (the destination silently keeps its old value, often `null`, and the next line dies with a null access). Use the function form and handle both outcomes: `if (!$cast(w, t)) $fatal(1, "expected a write_txn");`.

### Interview questions

**Q1. What is the difference between upcasting and downcasting?**
Upcasting assigns a derived handle to a base handle; it is implicit and always safe. Downcasting assigns a base handle to a derived handle; it needs `$cast` and is checked at run time.

**Q2. Why is `$cast` required for downcasting?**
Whether the base handle refers to an object of the derived type is known only at run time. `$cast` performs that check; the compiler cannot.

**Q3. When does `$cast(derived_h, base_h)` fail?**
When the object `base_h` refers to is not of the type of `derived_h` or a subclass of it, for example a plain base object or an object of a sibling class.

**Q4. What is the difference between `$cast` as a function and as a task?**
The function returns 1 or 0 and never issues an error. The task issues a run-time error when the cast is illegal. In both cases a failed cast leaves the destination unchanged.

**Q5. What happens if the source handle is null?**
The cast succeeds and the destination becomes `null`.

## 5.5 Abstract Classes and Pure Virtual Methods

### In plain English

Some classes exist only to be extended. "Component" is a useful idea (everything in a testbench that has a name and a `run()` task), but an object that is *only* a component, and not a driver or a monitor or a scoreboard, makes no sense: what would its `run()` do? Such a class is declared **abstract**: you cannot create objects of it. It serves as a contract. It lists the methods every real component must provide, and it can contain the code that all of them share.

A method that the abstract class requires but cannot sensibly implement is declared **pure virtual**: a prototype with no body. Each derived class must write the body.

### Technical definition

- A **virtual class** (abstract class) is a class declared with the keyword `virtual` before `class`. It **cannot be instantiated**: calling `new` for it is a compile error. Handles of its type can be declared and can refer to objects of derived classes.
- A **pure virtual method** is a method prototype declared with `pure virtual`, without a body and without `endfunction`/`endtask`. It may be declared only in an abstract class (or in an interface class).
- A non-abstract ("concrete") class derived from an abstract class **must override every pure virtual method** it inherits. If it does not, it is a compile error (or the derived class must itself be declared `virtual`).

### Syntax

```systemverilog
virtual class component;                       // abstract class
  string name;

  function new(string name);                   // may have a constructor
    this.name = name;
  endfunction

  pure virtual task run();                     // no body, no endtask
  pure virtual function string kind();         // no body, no endfunction

  function void report();                      // ordinary method with a body
    $display("%s is a %s", name, kind());
  endfunction
endclass
```

### What an abstract class may contain

| Item | Allowed in an abstract class? |
|---|---|
| Properties, including static ones | Yes |
| A constructor | Yes. It is called by derived constructors through `super.new()`, never directly |
| Ordinary (non-virtual) methods with bodies | Yes |
| Virtual methods with bodies (a default implementation) | Yes |
| Pure virtual methods | Yes, and only here (or in an interface class) |
| Zero pure virtual methods | Yes. `virtual class` alone is enough to forbid instantiation |
| Constraints, covergroups, typedefs | Yes |

### Complete example

```systemverilog file=tb_abstract.sv
module tb_abstract;

  virtual class component;
    string name;

    function new(string name);
      this.name = name;
    endfunction

    pure virtual task run();
    pure virtual function string kind();

    function void report();                       // shared code, written once
      $display("%s is a %s", name, kind());
    endfunction
  endclass

  class demo_driver extends component;
    function new(string name);
      super.new(name);
    endfunction

    virtual task run();
      #10 $display("[%0t] %s: driving", $time, name);
    endtask

    virtual function string kind();
      return "driver";
    endfunction
  endclass

  class demo_monitor extends component;
    function new(string name);
      super.new(name);
    endfunction

    virtual task run();
      #5 $display("[%0t] %s: monitoring", $time, name);
    endtask

    virtual function string kind();
      return "monitor";
    endfunction
  endclass

  component    comps [2];        // handles of the abstract type are allowed
  demo_driver  d;
  demo_monitor m;

  initial begin
    d = new("drv0");
    m = new("mon0");
    comps[0] = d;
    comps[1] = m;

    foreach (comps[i]) comps[i].report();
    foreach (comps[i]) comps[i].run();          // one after the other

    // comps[0] = new("x");                     // ILLEGAL: component is abstract
  end

endmodule
```

```output
drv0 is a driver
mon0 is a monitor
[10] drv0: driving
[15] mon0: monitoring
```

**Line by line**

| Line | Explanation |
|---|---|
| `virtual class component;` | Abstract: no object of exactly this class can exist. |
| `pure virtual task run();` | A requirement, not an implementation. Every concrete component must have a `run` task with this prototype. |
| `function void report();` | Shared, concrete code in the abstract class. It calls `kind()`, which does not exist here; at run time the call binds to the derived class's `kind()`. |
| `class demo_driver extends component;` | A concrete class: it implements both pure virtual methods, so it can be instantiated. |
| `component comps [2];` | Declaring handles of an abstract type is legal and is the whole point: generic code is written against the abstract type. |
| `comps[i].run();` | The tasks are called in sequence in one thread, so the times add up: the driver finishes at 10, the monitor at 15. (Module 7 shows how to start them in parallel with `fork`.) |
| The commented line | `new` applied to an abstract handle type is rejected at compile time. |

### Virtual method versus pure virtual method

| Property | Virtual method | Pure virtual method |
|---|---|---|
| Declaration | `virtual function void f(); ... endfunction` | `pure virtual function void f();` |
| Has a body in the declaring class | Yes (a default implementation) | No |
| Derived class must override | Optional | Mandatory for a concrete class |
| Allowed in | Any class | Abstract classes and interface classes only |
| Purpose | Allow specialisation | Force every derived class to provide an implementation |

### Abstract class versus concrete class

| Property | Abstract (`virtual class`) | Concrete class |
|---|---|---|
| Can be instantiated with `new` | No | Yes |
| Can have pure virtual methods | Yes | No |
| Can declare handles of its type | Yes | Yes |
| Can be extended | Yes; that is its purpose | Yes |
| Purpose | Common interface and shared code for a family of classes | Objects that actually exist |

### Interface classes (awareness level)

IEEE 1800-2012 added the **interface class**: a class-like declaration that contains only pure virtual method prototypes, type declarations and parameters, with no properties and no method bodies. A class can `implements` any number of interface classes in addition to `extends`-ing one ordinary class, which gives the useful part of multiple inheritance without its ambiguities.

```systemverilog
interface class printable;
  pure virtual function void print();
endclass

class packet implements printable;
  virtual function void print();
    $display("packet");
  endfunction
endclass
```

Do not confuse an `interface class` (an OOP construct) with an `interface` (a bundle of signals, Module 8) or a `virtual interface`. Support for interface classes is good in current versions of the major simulators but was absent in older ones, and the feature is used in UVM 1.2 and later for TLM-style connections; knowing the idea is enough for most interviews.

> **Interview trap:** "Can an abstract class have a constructor?" Yes. It cannot be called directly with `new`, but derived classes call it with `super.new()`.

> **Interview trap:** "Can you declare a handle of an abstract class?" Yes. Only *construction* is forbidden.

> **Interview trap:** "Can an abstract class have non-virtual methods with bodies?" Yes. An abstract class is an ordinary class in every respect except that it cannot be instantiated and may contain pure virtual methods.

> **Common mistake:** Giving a pure virtual method a body or an `endfunction`. A pure virtual declaration is a prototype only and ends at the semicolon.

> **Verification application:** `uvm_component`, `uvm_object`, `uvm_driver` and most other UVM base classes are virtual classes: they are designed to be extended, never instantiated. In a hand-written testbench, a `virtual class base_component` with `pure virtual task run();` guarantees at compile time that every component in the environment can be started the same way.

### Interview questions

**Q1. What is an abstract class?**
A class declared with `virtual class`. It cannot be instantiated; it is meant to be extended. It can contain properties, a constructor, concrete methods and pure virtual methods.

**Q2. What is a pure virtual method?**
A method declared with `pure virtual` that has only a prototype and no body. Every concrete derived class must implement it.

**Q3. What is the difference between a virtual method and a pure virtual method?**
A virtual method has an implementation in the base class that derived classes may override. A pure virtual method has no implementation in the base class, can exist only in an abstract (or interface) class, and must be overridden.

**Q4. What happens if a derived class does not implement a pure virtual method?**
It is a compile error, unless the derived class is also declared abstract.

**Q5. Can an abstract class have no pure virtual methods?**
Yes. The `virtual` keyword on the class is sufficient to prevent instantiation.

**Q6. What is the difference between a virtual class and a virtual method?**
A virtual class is an abstract class that cannot be instantiated. A virtual method is a method whose implementation is selected at run time from the object's type.
