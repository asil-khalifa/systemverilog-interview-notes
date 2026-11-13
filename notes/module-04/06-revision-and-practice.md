# Part 6: Module 4 Revision and Practice

## 6.1 Revision Summary

### Vocabulary on one page

| Term | Meaning |
|---|---|
| Class | User-defined type containing properties and methods |
| Object | An instance of a class, created at run time by `new()` |
| Handle | A variable of class type that refers to an object, or is `null` |
| Property | A variable declared in a class |
| Method | A function or task declared in a class (always automatic lifetime) |
| Constructor | `function new(...)`; no return type; one per class; runs when an object is created |
| `this` | Handle to the current object |
| `super` | Refers to the immediate base class's members |
| `::` | Scope resolution: static members, class-scoped types, packages, extern bodies |
| Static property | One copy per class, exists without objects |
| Static method | Called on the class; no `this`; only static members; cannot be virtual |
| `local` / `protected` / public | Own class only / own class and subclasses / everywhere (default) |
| `const` | Global constant (initialised in the declaration) or instance constant (assigned once in `new`) |
| `extern` | Prototype in the class, body outside as `class_name::method` |
| `typedef class x;` | Forward declaration |
| Shallow copy | `new h`: one level; nested objects shared; constructor not run |
| Deep copy | User-written `copy()`: nested objects duplicated too |
| Inheritance | `class d extends b;` |
| Overriding | Derived class redefines a base method |
| Overloading | Same name, different arguments, same class: **not supported** |
| Virtual method | Bound at run time by object type |
| Upcast | `base_h = derived_h;` always legal |
| Downcast | `$cast(derived_h, base_h)`; checked at run time |
| Abstract class | `virtual class`; cannot be instantiated |
| Pure virtual method | Prototype only; must be implemented by concrete derived classes |

### Rules to remember

**Objects and handles**

- Declaring a handle creates no object. `new()` creates the object. A handle is `null` until then.
- Using a null handle for a non-static member is a fatal run-time error, never a compile error.
- `h2 = h1` copies the reference. Passing an object to a method, returning it, or putting it in a mailbox or queue also copies only the reference.
- `h1 == h2` compares references, not contents.
- Objects are reclaimed automatically when unreachable. There is no `delete` and no destructor.

**Construction order**

1. Memory allocated.
2. `super.new()` (base initialisers, then base constructor body).
3. This class's property initialisers.
4. This class's constructor body.

`super.new(...)` must be the first statement; it is inserted automatically with no arguments if you do not write it.

**Which method or property is selected?**

| Member | Selected by |
|---|---|
| Property | Handle type |
| Non-virtual method | Handle type (compile time) |
| Virtual method | Object type (run time) |
| Static member via `class::` | The named class |
| `super.method()` | Always the base class's version |

**Copying**

| | New outer object | Nested objects | Constructor runs |
|---|---|---|---|
| `p2 = p1;` | No | Shared | No |
| `p2 = new p1;` | Yes | Shared | No |
| `p2 = p1.copy();` | Yes | Duplicated | Yes |

**Casting between class handles**

- Derived → base: implicit, always succeeds.
- Base → derived: `$cast` required; succeeds only if the *object* is of the destination class or a subclass.
- `$cast` as a function returns 0/1 silently; as a task it raises a run-time error. A failed cast leaves the destination unchanged.

**Abstract classes**

- `virtual class`: handles yes, objects no.
- `pure virtual`: no body; only in abstract or interface classes; concrete subclasses must implement all of them.
- An abstract class may have a constructor, properties and ordinary methods.

**The keyword `virtual` has three unrelated uses:** virtual method, virtual class, virtual interface.

**The keyword `static` has two positions:** `static function` (static method, legal) and `function static` (static lifetime, illegal in a class).

### The four pillars

| Pillar | Mechanism | One-line example |
|---|---|---|
| Encapsulation | `class`, `local`, `protected` | `fifo_model` hides `mem` behind `push`/`pop` |
| Inheritance | `extends`, `super` | `write_txn extends base_txn` |
| Polymorphism | `virtual` methods through base handles | `txns[i].print()` |
| Abstraction | `virtual class`, `pure virtual` | `component` with `pure virtual task run();` |

## 6.2 Interview Questions and Answers

The questions at the end of each section cover the direct definitions. These are additional.

### Basic level

**Q1. What are the main features of OOP?**
Encapsulation, inheritance, polymorphism and abstraction.

**Q2. Why is OOP used in verification?**
Testbenches need objects created at run time (transactions), reuse through inheritance (new tests and transactions derived from existing ones), generic components that work with any derived transaction (polymorphism), and randomization with constraints, which exists only in classes.

**Q3. What is the difference between a property and a method?**
A property is a data member (variable) of a class. A method is a function or task of the class that operates on the properties.

**Q4. What is the name of the constructor, and how many can a class have?**
`new`. Exactly one, because there is no overloading.

**Q5. What is `null`?**
The value of a handle that refers to no object. It is the default value of every handle.

**Q6. What keyword is used to derive a class?**
`extends`.

**Q7. What is the default access level of class members?**
Public.

**Q8. Can a function inside a class call a task inside the same class?**
No. A function cannot call a task, inside or outside a class, because a task may consume time and a function must return immediately (Module 3). A task can call functions and other tasks.

**Q9. How do you call a static method?**
`class_name::method_name(arguments)`. It may also be called through a handle.

**Q10. What is a base class and what is a derived class?**
The base class is the existing class that is extended. The derived class is the new class that inherits from it and adds or overrides members.

**Q11. Can you create an object of an abstract class?**
No. You can only declare handles of it and create objects of concrete derived classes.

**Q12. What does `super.new()` do?**
Calls the constructor of the base class, so that the inherited part of the object is initialised.

### Intermediate level

**Q13. What is the difference between `new()` and `new h`?**
`new()` constructs a new object by running the constructor. `new h` (no parentheses) makes a shallow copy of the object that `h` refers to, without running the constructor.

**Q14. A class contains a queue of `int` and a handle to another object. After a shallow copy, what is shared?**
Only the nested object. The queue is a value and is duplicated; the handle is copied, so both objects refer to the same nested object.

**Q15. What happens if a derived class does not define a constructor and the base class constructor has a required argument?**
Compile error. The implicit derived constructor calls `super.new()` with no arguments, which does not match. The derived class must define `new` and call `super.new(arg)`, or the base argument needs a default.

**Q16. Can a derived class access a `local` member of its base class? A `protected` one?**
Not the local one. The protected one, yes.

**Q17. Why can a `compare(rhs)` method read `rhs`'s local properties?**
Access control is per class, not per object. Code inside a class may access local members of any object of that same class.

**Q18. If a base method is non-virtual and the derived class overrides it, which runs when called via a derived handle? Via a base handle to the same object?**
Via the derived handle, the derived method. Via the base handle, the base method.

**Q19. Is the keyword `virtual` required in the derived-class override?**
No. A method that is virtual in the base class stays virtual in all derived classes. Writing the keyword again is recommended for readability.

**Q20. Can a static method be overridden?**
A derived class can declare a static method with the same name, which hides the base one for calls through the derived class name. There is no dynamic dispatch, so it is hiding, not polymorphic overriding.

**Q21. Can a virtual method be `local` or `protected`?**
Yes. The access qualifier and `virtual` are independent. Protected virtual methods are common: "hooks" that only subclasses are meant to override and only the base class calls.

**Q22. What is the difference between `this.x` and `super.x`?**
`this.x` searches for `x` starting in the current class. `super.x` starts the search in the base class, skipping any `x` declared in the current class.

**Q23. Why are transaction fields usually public while component internals are local or protected?**
Transaction fields must be visible to constraints written in tests, to drivers, monitors, scoreboards and coverage. Component internals (queues, counters, state) are implementation details that other code should not depend on.

**Q24. What is the difference between a class handle passed as an `input` argument and as a `ref` argument?**
With `input`, the handle is copied: the method can modify the object, and the caller sees those modifications, but if the method assigns a new object to its argument, the caller's handle is unaffected. With `ref`, the method works on the caller's handle variable itself, so assigning a new object inside the method changes the caller's handle too.

**Q25. How do you make sure a class can never be instantiated directly?**
Declare it as `virtual class`.

**Q26. Can an abstract class be derived from a concrete class?**
Yes. Any class can be extended by a virtual class.

### Advanced and scenario-based

**Q27. A generator puts 10 transactions into a mailbox. The driver prints 10 transactions with identical values. What is the likely bug?**
The generator constructs the transaction once, outside its loop, and puts the same handle in the mailbox each time. All ten mailbox entries refer to one object, which holds the values of the last randomization by the time the driver reads it. Fix: `txn = new();` inside the loop, or put `txn.copy()` into the mailbox.

**Q28. A scoreboard stores expected transactions in a queue. By the time it compares, the stored values have changed. Why?**
It stored handles to objects that some other component later modified or reused (often a monitor that keeps one object and overwrites it per transfer). The scoreboard, or the sender, must make a copy.

**Q29. A test defines `class my_txn extends alu_txn` and overrides `print()`, but the driver still prints with the base format. Why?**
Either `print()` is not declared `virtual` in `alu_txn`, so the driver's `alu_txn` handle binds statically to the base method; or the generator is still creating `alu_txn` objects and the derived class is never instantiated.

**Q30. The simulation stops with "null object access" inside the driver's `run()` task. List the usual causes.**
(1) The component object was never constructed (`drv = new(...)` missing in the environment). (2) A handle the component needs was never assigned: the virtual interface or mailbox was not passed in, or was passed before it was created, so `null` was copied. (3) A nested object was not created in the constructor. (4) A `$cast` used as a function failed and its result was ignored, leaving the destination `null`. (5) `try_get` on a mailbox returned nothing and the transaction handle was used anyway.

**Q31. Explain what happens, in order, when `d = new();` executes for `class d_c extends b_c`.**
Memory for the whole object is allocated. `d_c::new` begins and its first action is `super.new()`: the base-class property initialisers are applied and the base constructor body runs. Then the derived-class property initialisers are applied, then the rest of the derived constructor body. Finally the handle is assigned to `d`.

**Q32. Why should you avoid calling a virtual method from a constructor?**
In SystemVerilog the call is dispatched to the derived override, but when a base-class constructor is running the derived class's property initialisers and constructor body have not yet executed. The override therefore runs on a partly initialised object and sees default values.

**Q33. How is the "factory" idea related to polymorphism?**
A factory is a function that creates and returns an object through a base-class handle, where the actual class created can be changed without editing the caller. It works only because the caller uses the object through virtual methods; the caller neither knows nor cares which derived class it received. UVM's `type_id::create()` is this pattern.

**Q34. What is a callback and which OOP features does it use?**
A callback is an object with virtual hook methods (for example `pre_drive(txn)`, `post_drive(txn)`) that a component calls at fixed points. The component holds a base-class callback handle; a test registers a derived object whose overrides inject errors, delays or coverage. It uses inheritance, virtual methods and upcasting, i.e. polymorphism.

**Q35. Two objects refer to each other and no other handle refers to either. Are they garbage-collected?**
Yes. Collection is based on reachability from live handles, and neither object is reachable.

**Q36. Can you have a queue or mailbox that holds both `read_txn` and `write_txn` objects? How do you get the derived fields back out?**
Yes: declare it with the common base type, for example `mailbox #(bus_txn)`. Derived objects are upcast implicitly on `put`. After `get`, call virtual methods directly, or use `$cast` to a derived handle when a derived-only property is needed.

**Q37. What is the difference between `$cast` on enums and `$cast` on class handles?**
The mechanism is the same (a run-time-checked assignment), but the check differs. For an enum it checks that the integral value is a declared member. For class handles it checks that the source object's class is the destination class or derived from it.

**Q38. Why does SystemVerilog not need (and not have) destructors?**
Memory is reclaimed automatically, which is the main job of a destructor in C++. Other end-of-life actions (reports, checks that queues are empty) are tied to the end of the simulation, not to the death of an object, and are done in explicit methods or in `final` blocks.

**Q39. A class has `static int count` and is extended by two derived classes. How many copies of `count` exist?**
One. A static property declared in a base class is shared by the base class and all classes derived from it. (This does not hold for parameterized classes, where each specialisation has its own statics; Module 11.)

**Q40. When would you choose composition over inheritance?**
When the relationship is "has-a" or "uses-a" and not "is-a". An environment has a driver and a scoreboard; a driver has a virtual interface and a mailbox. Extending a class only to reuse a few of its methods creates a false "is-a" relationship and couples the classes unnecessarily.

## 6.3 Output-Prediction Questions

Work out each output on paper, then check the answer, then run the code.

**P1. Handles**

```systemverilog
module p1;
  class c; int v; endclass
  c a, b;
  initial begin
    a = new();  a.v = 1;
    b = a;      b.v = 2;
    a = new();  a.v = 3;
    $display("%0d %0d", a.v, b.v);
  end
endmodule
```

Answer: `3 2`. `b` refers to the first object, whose `v` was changed to 2 through `b`. `a` was then re-pointed to a second object.

**P2. Static**

```systemverilog
module p2;
  class c;
    static int n;
    int id;
    function new();
      id = n;
      n++;
    endfunction
  endclass
  c x, y, z;
  initial begin
    x = new();  y = new();  z = new();
    $display("%0d %0d %0d %0d", x.id, y.id, z.id, c::n);
  end
endmodule
```

Answer: `0 1 2 3`. Each object records the counter before incrementing it. The single static `n` ends at 3.

**P3. Shallow copy**

```systemverilog
module p3;
  class inner; int v = 5; endclass
  class outer;
    int   k = 1;
    inner sub = new();
  endclass
  outer a, b;
  initial begin
    a = new();
    b = new a;
    b.k     = 2;
    b.sub.v = 9;
    $display("%0d %0d %0d %0d", a.k, a.sub.v, b.k, b.sub.v);
  end
endmodule
```

Answer: `1 9 2 9`. `k` is duplicated by the shallow copy; the `inner` object is shared, so the change through `b.sub` is seen through `a.sub`.

**P4. Constructor chain**

```systemverilog
module p4;
  class A; function new(); $display("A"); endfunction endclass
  class B extends A; function new(); $display("B"); endfunction endclass
  class C extends B; endclass
  C c;
  initial c = new();
endmodule
```

Answer: `A` then `B`. `C` has no constructor, so the implicit one calls `B::new`, which implicitly calls `A::new` first.

**P5. Virtual call from a non-virtual method**

```systemverilog
module p5;
  class A;
    virtual function void f(); $display("A.f"); endfunction
    function void g(); $display("A.g"); f(); endfunction
  endclass
  class B extends A;
    function void f(); $display("B.f"); endfunction
    function void g(); $display("B.g"); endfunction
  endclass
  A a;
  B b;
  initial begin
    b = new();
    a = b;
    a.g();
  end
endmodule
```

Answer: `A.g` then `B.f`. `g` is non-virtual, so the handle type `A` selects `A::g`. Inside it, `f()` means `this.f()`, and `f` is virtual (still virtual in `B` without the keyword), so the object type `B` selects `B::f`.

**P6. Property hiding**

```systemverilog
module p6;
  class A;
    int x = 1;
    function int get(); return x; endfunction
  endclass
  class B extends A;
    int x = 2;
  endclass
  A a;
  B b;
  initial begin
    b = new();
    a = b;
    $display("%0d %0d %0d", a.x, b.x, b.get());
  end
endmodule
```

Answer: `1 2 1`. Properties follow the handle type. `get()` is inherited from `A` and was compiled inside `A`, where `x` means `A::x`.

**P7. $cast**

```systemverilog
module p7;
  class A; endclass
  class B extends A; endclass
  class C extends A; endclass
  A a;
  B b;
  C c;
  initial begin
    b = new();
    a = b;
    $display("%0d %0d", $cast(c, a), $cast(b, a));
    a = new();
    $display("%0d %0d", $cast(b, a), b == null);
  end
endmodule
```

Answer: `0 1` then `0 0`. The object is a `B`: casting to the sibling `C` fails, casting to `B` succeeds. Then `a` refers to a plain `A` object: the cast to `B` fails, and a failed cast leaves `b` unchanged, so it is not null.

**P8. Shadowing**

```systemverilog
module p8;
  class P;
    int v;
    function void set(int v);  v = v;       endfunction
    function void set2(int v); this.v = v;  endfunction
  endclass
  P p;
  initial begin
    p = new();
    p.set(5);   $display("%0d", p.v);
    p.set2(7);  $display("%0d", p.v);
  end
endmodule
```

Answer: `0` then `7`. In `set`, both names are the argument, so the property is untouched.

**P9. super chain**

```systemverilog
module p9;
  class A;
    virtual function void f(); $display("A"); endfunction
  endclass
  class B extends A;
    virtual function void f(); super.f(); $display("B"); endfunction
  endclass
  class C extends B;
    virtual function void f(); $display("C"); super.f(); endfunction
  endclass
  A a;
  C c;
  initial begin
    c = new();
    a = c;
    a.f();
  end
endmodule
```

Answer: `C`, `A`, `B`. Dynamic binding selects `C::f`, which prints `C` and calls `B::f`; that calls `A::f` first (prints `A`) and then prints `B`.

**P10. Initialiser order**

```systemverilog
module p10;
  class A;
    int x = 10;
    function new(); x = x + 1; endfunction
  endclass
  class B extends A;
    int y = x * 2;
    function new(); y = y + 1; endfunction
  endclass
  B b;
  initial begin
    b = new();
    $display("%0d %0d", b.x, b.y);
  end
endmodule
```

Answer: `11 23`. Base initialiser (`x` = 10), base constructor (`x` = 11), derived initialiser (`y` = 22), derived constructor (`y` = 23).

## 6.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
class base_txn; endclass
class write_txn extends base_txn; endclass
base_txn  b = new();
write_txn w;
initial w = b;
```

A base handle cannot be assigned to a derived handle. Use `$cast(w, b)` (which will then fail at run time here, because the object is a `base_txn`).

**E2.**

```systemverilog
class account;
  local int balance;
endclass
account a = new();
initial a.balance = 100;
```

`balance` is local and cannot be accessed outside the class. Add a public method, or remove `local`.

**E3.**

```systemverilog
class counter;
  int count;
  static function void incr();
    count++;
  endfunction
endclass
```

A static method cannot access a non-static property. Make `count` static, or make `incr` non-static.

**E4.**

```systemverilog
virtual class shape;
  pure virtual function int area();
endclass
shape s = new();
```

An abstract class cannot be instantiated. Create an object of a concrete derived class.

**E5.**

```systemverilog
virtual class shape;
  pure virtual function int area();
endclass
class square extends shape;
  int side;
endclass
square sq = new();
```

`square` is concrete but does not implement the pure virtual method `area()`. Add `virtual function int area(); return side * side; endfunction`.

**E6.**

```systemverilog
class base_txn;
  function new(int size);
  endfunction
endclass
class write_txn extends base_txn;
  function new();
  endfunction
endclass
```

The implicit `super.new()` passes no argument to a constructor that requires one. Write `super.new(8);` (or any suitable value) as the first statement, or give `size` a default.

**E7.**

```systemverilog
class logger;
  function void log(string s);        endfunction
  function void log(string s, int v); endfunction
endclass
```

Overloading is not supported; `log` is declared twice. Use one method with a default argument, or two names.

**E8.**

```systemverilog
class write_txn extends base_txn;
  function new(string name);
    $display("creating %s", name);
    super.new(name);
  endfunction
endclass
```

`super.new` must be the first statement in the constructor. Move the `$display` after it.

**E9.**

```systemverilog
class packet;
  const int id;
  function new(int id);  this.id = id;  endfunction
  function void renumber(int id);  this.id = id;  endfunction
endclass
```

An instance constant may be assigned only in the constructor. `renumber` is illegal; remove it or drop `const`.

**E10.**

```systemverilog
class base_txn;
  virtual function void print(string tag);
  endfunction
endclass
class write_txn extends base_txn;
  virtual function int print();
    return 0;
  endfunction
endclass
```

The override of a virtual method must have the same return type and argument list as the base declaration.

**E11.**

```systemverilog
class id_gen;
  static int next_id;
  static function int get();
    return this.next_id;
  endfunction
endclass
```

`this` does not exist in a static method. Write `return next_id;`.

**E12.**

```systemverilog
class packet;
  function void new();
  endfunction
endclass
```

The constructor has no return type. Write `function new();`.

### Run-time bugs (the code compiles)

**D1.**

```systemverilog
alu_txn txn;
initial begin
  txn.a = 8'h10;
  txn.print();
end
```

`txn` was never constructed. Null object access at run time. Add `txn = new();`.

**D2.**

```systemverilog
alu_txn txn = new();
repeat (5) begin
  txn.a = $urandom_range(0, 255);
  gen2drv_mbx.put(txn);
end
```

One object, five references in the mailbox. Construct a new object in every iteration.

**D3.**

```systemverilog
class packet;
  header hdr;
  bit [7:0] data;
endclass
packet p = new();
initial p.hdr.id = 8'h01;
```

`hdr` is a handle property and is `null`: creating the packet does not create its header. Add `hdr = new();` in a constructor or as a declaration initialiser.

**D4.**

```systemverilog
expected = mon_txn;            // scoreboard keeps the handle it was given
...
if (actual == expected) $display("PASS");
```

Two problems. The scoreboard stores a handle to an object the monitor may reuse; it should store a copy. And `==` compares handles, not contents; use `actual.compare(expected)`.

**D5.**

```systemverilog
write_txn w;
void'($cast(w, base_h));
$display("%h", w.data);
```

The result of `$cast` is discarded. If `base_h` does not refer to a `write_txn`, `w` stays `null` and the next line is a null access. Test the return value.

**D6.**

```systemverilog
class base_test;
  task run();  $display("base test");  endtask
endclass
class error_test extends base_test;
  task run();  $display("error test");  endtask
endclass
base_test t;
error_test e = new();
initial begin  t = e;  t.run();  end
```

Prints "base test". `run` is not virtual, so the base handle selects the base task. Declare it `virtual task run();` in `base_test`.

**D7.**

```systemverilog
function packet copy();
  packet p = new();
  p.data = this.data;
  p.hdr  = this.hdr;
  return p;
endfunction
```

This is a shallow copy written by hand: both packets share one header. Use `p.hdr = this.hdr.copy();`.

**D8.**

```systemverilog
class write_txn extends base_txn;
  virtual function void print();
    print();
    $display("data=%h", data);
  endfunction
endclass
```

`print()` calls itself for ever. The intention was `super.print();`.

## 6.5 Coding Exercises with Solutions

Attempt each exercise before reading the solution. The solutions are in `examples/module-04/`.

### Exercise 1: an encapsulated stack

Write a class `int_stack` with hidden storage, a maximum depth given to the constructor, `push` (returns 0 when full), `pop` (returns 0 when empty) and `depth`.

```systemverilog file=ex01_stack.sv
module ex01_stack;

  class int_stack;
    local int items [$];
    local int max_depth;

    function new(int max_depth = 4);
      this.max_depth = max_depth;
    endfunction

    function bit push(int value);
      if (items.size() >= max_depth) return 0;
      items.push_back(value);
      return 1;
    endfunction

    function bit pop(output int value);
      if (items.size() == 0) return 0;
      value = items.pop_back();
      return 1;
    endfunction

    function int depth();
      return items.size();
    endfunction
  endclass

  int_stack s;
  int       v;
  bit       ok;

  initial begin
    s = new(3);
    ok = s.push(10);
    ok = s.push(20);
    ok = s.push(30);
    ok = s.push(40);   $display("push 40 accepted? %0d", ok);
    ok = s.pop(v);     $display("pop -> %0d", v);
    ok = s.pop(v);     $display("pop -> %0d", v);
    $display("depth = %0d", s.depth());
  end

endmodule
```

```output
push 40 accepted? 0
pop -> 30
pop -> 20
depth = 1
```

A stack is last-in first-out, so `pop_back` returns the most recent value. The fourth push is refused because the depth limit is 3. Outside code cannot touch `items` at all.

### Exercise 2: a linked list built from handles

Write a `node` class holding an `int` and a handle to the next node, and an `int_list` class with `append`, `sum` and `print`.

```systemverilog file=ex02_linked_list.sv
module ex02_linked_list;

  class node;
    int  value;
    node next;                         // a handle of the class's own type

    function new(int value);
      this.value = value;
    endfunction
  endclass

  class int_list;
    local node head;
    local node tail;
    local int  count;

    function void append(int value);
      node n = new(value);
      if (head == null) head = n;      // first node
      else              tail.next = n; // link after the current last node
      tail = n;
      count++;
    endfunction

    function int sum();
      int  total = 0;
      node n     = head;
      while (n != null) begin
        total += n.value;
        n = n.next;
      end
      return total;
    endfunction

    function void print();
      string s = "";
      node   n = head;
      while (n != null) begin
        s = {s, $sformatf("%0d ", n.value)};
        n = n.next;
      end
      $display("list: %s(count=%0d)", s, count);
    endfunction
  endclass

  int_list lst;

  initial begin
    lst = new();
    lst.append(5);
    lst.append(7);
    lst.append(9);
    lst.print();
    $display("sum = %0d", lst.sum());
  end

endmodule
```

```output
list: 5 7 9 (count=3)
sum = 21
```

Each `node` object stays alive because the previous node (or `head`) refers to it. Walking the list is a loop that follows `next` until it reaches `null`. If `head` were set to `null`, every node would become unreachable and be reclaimed.

### Exercise 3: shallow versus deep copy with an array and a nested object

A `frame` has a `header` object and a dynamic payload. Write `copy()` and `compare()`, then show the difference between a deep copy and `new f1`.

```systemverilog file=ex03_frame_copy.sv
module ex03_frame_copy;

  class header;
    bit [7:0] id;
    function header copy();
      header h = new();
      h.id = this.id;
      return h;
    endfunction
  endclass

  class frame;
    header    hdr;
    bit [7:0] payload [];

    function new(int size = 0);
      hdr     = new();
      payload = new[size];
    endfunction

    function frame copy();
      frame f = new();
      f.hdr     = this.hdr.copy();     // nested object: must be copied explicitly
      f.payload = this.payload;        // array: assignment copies all elements
      return f;
    endfunction

    function bit compare(frame rhs);
      if (rhs == null) return 0;
      return (hdr.id == rhs.hdr.id) && (payload == rhs.payload);
    endfunction
  endclass

  frame f1, f2, f3;

  initial begin
    f1 = new(3);
    f1.hdr.id  = 8'd7;
    f1.payload = '{8'd1, 8'd2, 8'd3};

    f2 = f1.copy();                                    // deep copy
    $display("after deep copy: equal=%0d", f1.compare(f2));

    f2.hdr.id     = 8'd8;
    f2.payload[0] = 8'd9;
    $display("f1: id=%0d payload[0]=%0d   f2: id=%0d payload[0]=%0d   equal=%0d",
             f1.hdr.id, f1.payload[0], f2.hdr.id, f2.payload[0], f1.compare(f2));

    f3 = new f1;                                       // shallow copy
    f3.payload[1] = 8'd50;                             // array was duplicated
    f3.hdr.id     = 8'd99;                             // header is shared
    $display("after shallow copy: f1.payload[1]=%0d f1.hdr.id=%0d",
             f1.payload[1], f1.hdr.id);
  end

endmodule
```

```output
after deep copy: equal=1
f1: id=7 payload[0]=1   f2: id=8 payload[0]=9   equal=0
after shallow copy: f1.payload[1]=2 f1.hdr.id=99
```

The last line is the instructive one. After the shallow copy, changing `f3`'s payload did not touch `f1` (arrays are values), but changing `f3`'s header changed `f1`'s header (handles are references).

### Exercise 4: a polymorphic reference model

Model three ALU operations as classes derived from an abstract `alu_operation` with a pure virtual `calc`. Evaluate all of them through an array of base handles.

```systemverilog file=ex04_alu_operations.sv
module ex04_alu_operations;

  virtual class alu_operation;
    pure virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
    pure virtual function string op_name();
  endclass

  class add_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a} + {1'b0, b};
    endfunction
    virtual function string op_name();
      return "ADD";
    endfunction
  endclass

  class sub_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a} - {1'b0, b};
    endfunction
    virtual function string op_name();
      return "SUB";
    endfunction
  endclass

  class xor_op extends alu_operation;
    virtual function bit [8:0] calc(bit [7:0] a, bit [7:0] b);
      return {1'b0, a ^ b};
    endfunction
    virtual function string op_name();
      return "XOR";
    endfunction
  endclass

  alu_operation ops [3];
  add_op        op_a;
  sub_op        op_s;
  xor_op        op_x;

  initial begin
    op_a = new();  op_s = new();  op_x = new();
    ops[0] = op_a;
    ops[1] = op_s;
    ops[2] = op_x;

    foreach (ops[i])
      $display("%s(200, 100) = %0d", ops[i].op_name(), ops[i].calc(8'd200, 8'd100));
    $display("%s(5, 10) = %0d", ops[1].op_name(), ops[1].calc(8'd5, 8'd10));
  end

endmodule
```

```output
ADD(200, 100) = 300
SUB(200, 100) = 100
XOR(200, 100) = 172
SUB(5, 10) = 507
```

200 is `1100_1000` and 100 is `0110_0100`; their XOR is `1010_1100` = 172. 5 - 10 in nine bits is `1_1111_1011` = 507, with bit 8 acting as the borrow, exactly as the DUT in Module 1 produces. Adding a new operation means adding one class; the loop does not change.

### Exercise 5: a test hierarchy

Write a `base_test` whose `run()` task calls two virtual "hook" functions, and an `error_test` that overrides the hooks. Run both through one base handle.

```systemverilog file=ex05_test_hierarchy.sv
module ex05_test_hierarchy;

  class base_test;
    string name = "base_test";

    virtual function int num_txns();
      return 2;
    endfunction

    virtual function string stimulus(int i);
      return $sformatf("normal txn %0d", i);
    endfunction

    virtual task run();
      $display("--- %s ---", name);
      for (int i = 0; i < num_txns(); i++) begin
        #10;
        $display("[%0t] %s", $time, stimulus(i));
      end
    endtask
  endclass

  class error_test extends base_test;
    function new();
      name = "error_test";               // change the inherited property's value
    endfunction

    virtual function int num_txns();
      return 3;
    endfunction

    virtual function string stimulus(int i);
      if (i == 1) return "ERROR injection";
      return super.stimulus(i);
    endfunction
  endclass

  base_test  t;
  base_test  b;
  error_test e;

  initial begin
    b = new();
    e = new();
    t = b;  t.run();
    t = e;  t.run();
  end

endmodule
```

```output
--- base_test ---
[10] normal txn 0
[20] normal txn 1
--- error_test ---
[30] normal txn 0
[40] ERROR injection
[50] normal txn 2
```

`error_test` does not override `run()` at all. The inherited `run()` calls `num_txns()` and `stimulus()` virtually, so the derived versions are used. The base class fixes the overall flow and the derived class changes only the details: this arrangement is called the *template method* pattern and is how UVM phases and `do_*` hooks work.

### Exercise 6: a singleton configuration object

Write a class `tb_config` of which only one object can ever exist. All components obtain it through a static method.

```systemverilog file=ex06_singleton.sv
module ex06_singleton;

  class tb_config;
    local static tb_config m_inst;      // the one and only object
    int num_txns = 10;
    bit verbose;

    local function new();               // nobody outside can call new
    endfunction

    static function tb_config get();
      if (m_inst == null) m_inst = new();
      return m_inst;
    endfunction
  endclass

  tb_config c1, c2;

  initial begin
    c1 = tb_config::get();              // first call creates the object
    c1.num_txns = 25;

    c2 = tb_config::get();              // later calls return the same object
    $display("c2.num_txns=%0d  same object=%0d", c2.num_txns, c1 == c2);

    // c1 = new();                      // ILLEGAL: the constructor is local
  end

endmodule
```

```output
c2.num_txns=25  same object=1
```

The static method is the only route to the object, and the static handle keeps the object alive for the whole simulation. This combines static properties, static methods, access control and handle semantics. UVM's `uvm_root` and its factory are singletons of this kind.

### Further practice (no solutions given)

1. Extend `alu_txn` from Section 3.6 with `class alu_arith_txn extends alu_txn` that adds a `bit expect_carry` field. Make `print`, `copy` and `compare` virtual in the base class and override them using the `copy_fields` scheme of Section 5.6.
2. Write a class `timer` with a static property counting the objects created and a static function returning the count. Create five objects in a loop and print the count without using any handle.
3. Write an abstract class `shape` with `pure virtual function real area();` and concrete classes `rectangle` and `circle`. Put objects of both in a queue of `shape` handles and print the total area.
4. Take `tb_override.sv` from Section 4.5, add `virtual` to the base `print`, and predict the new output before running it.
5. Write a function `function automatic int count_writes(bus_txn q[$]);` that uses `$cast` to count how many elements of a queue of base handles are `write_txn` objects.
6. Create a class with a constructor that prints a message. Make one object, one shallow copy and one deep copy (through a `copy()` method). Predict how many times the message is printed.
7. Write two classes that hold handles to each other, using a forward `typedef class`. Then set the only external handle to `null` and explain what happens to both objects.

## 6.6 Concepts You Must Understand Before Moving Forward

Do not start Module 5 until you can answer each of these without the notes.

**Classes, objects, handles**

- [ ] I can explain class, object and handle, and draw the memory picture of `p2 = p1;`.
- [ ] I know what `null` is and what happens on a null access.
- [ ] I can list what `new()` does, in order, for a base class and for a derived class.
- [ ] I can explain why `this.addr = addr;` needs `this`.
- [ ] I can explain why a new object must be constructed inside a generator loop.

**Class members**

- [ ] I can explain static properties and methods and the restriction on static methods.
- [ ] I can distinguish `static function` from `function static`.
- [ ] I know the access rules for `local`, `protected` and public members.
- [ ] I can write an `extern` method and a forward `typedef class`.
- [ ] I can explain how objects are freed.

**Copying**

- [ ] I can state the difference between handle assignment, shallow copy and deep copy, with a diagram.
- [ ] I can write `copy()` and `compare()` for a class with a nested object.
- [ ] I know why `==` on handles is not a content comparison.

**Inheritance and polymorphism**

- [ ] I can name and define the four pillars with a SystemVerilog example of each.
- [ ] I can explain `super.new()` and when it must be written explicitly.
- [ ] I can explain overriding versus overloading and why overloading is missing.
- [ ] Given a handle type, an object type and whether a method is virtual, I can say which method runs.
- [ ] I can explain upcasting, downcasting and when `$cast` fails.
- [ ] I can explain abstract classes and pure virtual methods, and the three uses of `virtual`.

## 6.7 What Comes Next

Module 5 adds randomization to classes: `rand` and `randc` properties, constraint blocks, `randomize()`, `pre_randomize()` and `post_randomize()`, and how constraints are inherited and overridden in derived classes. It uses the `alu_txn` class from Section 3.6 and depends directly on inheritance and virtual methods from this module, because `randomize()` is itself a virtual method.
