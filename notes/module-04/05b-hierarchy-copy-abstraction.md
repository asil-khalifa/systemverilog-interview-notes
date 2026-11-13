## 5.6 Copying in a Class Hierarchy

Section 3.4 promised an explanation of why `copy()` is split in two when classes are extended. The problem and its solution use everything from this part: virtual methods, `super`, upcasting and `$cast`.

### The problem

A component holds a base-class handle and wants a copy of whatever object it refers to:

```systemverilog
base_txn t;          // may refer to a base_txn or to a write_txn
base_txn c;
c = t.copy();        // the copy must be of the SAME class as the object
```

If `copy()` is non-virtual, the base-class version runs, creates a `base_txn`, and the derived fields are lost. So `copy()` must be virtual. But a virtual override must match the signature of the base method, so the derived `copy()` is also declared to return a `base_txn` handle, even though the object it creates is a `write_txn`. (IEEE 1800 does allow an override to declare a derived class as its return type, but tool support for that has been uneven; returning the base type works everywhere and is what UVM does.)

### The solution

| Method | Virtual | Job |
|---|---|---|
| `copy()` | Yes | Creates a new object **of its own class** and returns it as a base-class handle |
| `copy_fields(rhs)` | Yes | Copies the fields declared in its own class from `rhs`, after calling `super.copy_fields(rhs)` for the inherited ones |

```systemverilog file=tb_virtual_copy.sv
module tb_virtual_copy;

  class base_txn;
    bit [7:0] addr;

    virtual function void copy_fields(base_txn rhs);
      this.addr = rhs.addr;
    endfunction

    virtual function base_txn copy();
      base_txn t = new();               // an object of THIS class
      t.copy_fields(this);
      return t;
    endfunction

    virtual function void print(string tag = "");
      $display("[%s] base_txn  addr=%h", tag, addr);
    endfunction
  endclass

  class write_txn extends base_txn;
    bit [7:0] data;

    virtual function void copy_fields(base_txn rhs);
      write_txn rhs_w;
      super.copy_fields(rhs);                        // inherited fields first
      if ($cast(rhs_w, rhs)) this.data = rhs_w.data; // then the fields added here
    endfunction

    virtual function base_txn copy();
      write_txn t = new();              // an object of THIS class
      t.copy_fields(this);
      return t;                         // upcast to the declared return type
    endfunction

    virtual function void print(string tag = "");
      $display("[%s] write_txn addr=%h data=%h", tag, addr, data);
    endfunction
  endclass

  base_txn  orig, dup;
  write_txn w, w_dup;

  initial begin
    w = new();
    w.addr = 8'h40;
    w.data = 8'h7E;

    orig = w;                           // all the caller has is a base handle
    dup  = orig.copy();                 // virtual: write_txn::copy runs
    dup.print("dup");

    w.data = 8'h00;                     // changing the original...
    dup.print("dup");                   // ...does not change the copy

    if ($cast(w_dup, dup))              // downcast to reach data directly
      $display("w_dup.data=%h  same object as w: %0d", w_dup.data, w_dup == w);
  end

endmodule
```

```output
[dup] write_txn addr=40 data=7e
[dup] write_txn addr=40 data=7e
w_dup.data=7e  same object as w: 0
```

**Line by line**

| Line | Explanation |
|---|---|
| `virtual function base_txn copy();` in `base_txn` | The polymorphic entry point. Its return type is the base class. |
| `write_txn t = new();` in `write_txn::copy` | Each class's `copy()` creates an object of its own class. This is the one line a constructor-based copy could never get right, because constructors are not virtual. |
| `return t;` | A `write_txn` handle returned through a `base_txn` return type: an implicit upcast. |
| `virtual function void copy_fields(base_txn rhs);` | The argument type must be `base_txn` in every class, because the override must match the base signature. |
| `super.copy_fields(rhs);` | Each level copies only what it declared and delegates the rest upward. Adding a third level needs no change to the first two. |
| `$cast(rhs_w, rhs)` | Inside `write_txn::copy_fields`, `rhs` is a base handle. A downcast is needed to read `rhs.data`. |
| `dup = orig.copy();` | `orig` is a `base_txn` handle to a `write_txn` object. Dynamic binding selects `write_txn::copy`, so `dup` refers to a new `write_txn`. The first output line proves it: the derived `print` runs and `data` is present. |
| `$cast(w_dup, dup)` | The caller downcasts the returned base handle when it needs derived-only members. |

This is, in miniature, exactly the `clone()` / `do_copy()` scheme of UVM, including the `$cast(rhs_, rhs)` line that begins every `do_copy`.

### Interview questions

**Q1. Why must `copy()` be virtual in a class hierarchy?**
So that calling it through a base-class handle creates an object of the actual derived class and copies the derived fields too. A non-virtual `copy()` would always create and copy only the base part.

**Q2. Why does the caller need `$cast` on the result of a virtual `copy()` or `clone()`?**
The method's return type is the base class (the override must keep the base signature), so the result is a base handle. To assign it to a derived handle a downcast is required.

## 5.7 Abstraction

### In plain English

When you drive a car you use a steering wheel, pedals and a gear lever. Those are the same in a petrol car and an electric car, although what happens underneath is completely different. The controls are an **abstraction**: a small, stable set of operations that hides the mechanism and is the same for every implementation.

### Technical definition

Abstraction is the practice of exposing only the essential behaviour of an entity through a well-defined interface while hiding how that behaviour is implemented. In SystemVerilog it is expressed with abstract classes and pure virtual methods: the abstract base class states **what** operations exist; each derived class decides **how** to perform them.

### How it shows up in verification

| Abstraction | What is exposed | What is hidden |
|---|---|---|
| Transaction (Module 6) | "Add 200 and 100" as an object with fields `a`, `b`, `op` | The clock cycles and pin wiggles needed to perform it |
| Driver | `drive(txn)` | The signal-level protocol |
| Abstract base component | `run()` | Whether the component drives, monitors or checks |
| Abstract reference-model operation | `calc(a, b)` | The arithmetic for each opcode (Exercise 4 in Part 6) |
| Virtual interface (Module 8) | A handle `vif` with named signals | Which physical interface instance, and where in the hierarchy it is |
| UVM | `build_phase`, `run_phase`, `write()`, `get_next_item()` | Everything the base classes and the scheduler do |

Each row lets the code above the abstraction be written once and reused while the code below it changes.

### The four pillars in one example

Looking back at `tb_abstract.sv` in Section 5.5:

| Pillar | Where it appears |
|---|---|
| Encapsulation | Each component class bundles its `name` with `run`, `kind` and `report` |
| Inheritance | `demo_driver` and `demo_monitor` extend `component` and reuse `name`, the constructor logic and `report()` |
| Polymorphism | `comps[i].run()` and the `kind()` call inside `report()` execute the derived class's code through a `component` handle |
| Abstraction | `component` is a virtual class with pure virtual `run()` and `kind()`: it defines what a component is without implementing one |

### Interview questions

**Q1. What is abstraction?**
Showing only the essential interface of something and hiding its implementation. In SystemVerilog it is implemented with abstract (virtual) classes and pure virtual methods.

**Q2. How is abstraction different from encapsulation?**
Encapsulation hides the data and implementation *inside one class* behind its public methods. Abstraction defines a common interface *for a family of classes* and defers the implementation to the derived classes.

**Q3. Give an example of abstraction in a testbench.**
A transaction class abstracts pin-level activity into a single object; a base component class with a pure virtual `run()` task abstracts "something that can be started"; a driver's `drive(txn)` task abstracts the bus protocol.
