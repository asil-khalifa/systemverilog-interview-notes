# Module 11 Overview

Modules 1 to 10 taught the language features and used them to build a complete layered testbench for the ALU, with coverage and assertions. This last teaching module does three things:

1. It covers the features that make a testbench **organised and reusable**: packages, the scope resolution operator, and parameterized (generic) classes.
2. It covers the remaining **advanced language features** that interviewers ask about: fine-grained process control, `randcase` and `randsequence`, the Direct Programming Interface (DPI) to C, and the system tasks and functions you use every day.
3. It introduces **UVM** at a high level, by showing that every UVM concept is something you have already built by hand in Module 9.

UVM is deliberately not the focus. The aim is that when an interviewer asks "how does a UVM driver get its transactions?" you can answer by relating it to the mailbox between `alu_generator` and `alu_driver`, which you fully understand.

### How this module is organised

| Part | Sections | Syllabus topics |
|---|---|---|
| 1. Packages and scope | 1.1 to 1.3 | Packages, importing packages, scope resolution operator |
| 2. Generic code | 2.1 to 2.4 | Parameterized classes, generic reusable classes, virtual interfaces (advanced recap), clocking blocks (advanced recap) |
| 3. Process control | 3.1 to 3.5 | Process control, named blocks, named fork blocks, process class and process handles, watchdog patterns |
| 4. Random sequences, C and system tasks | 4.1 to 4.4 | `randcase`, `randsequence`, DPI introduction, simulator system tasks |
| 5. UVM introduction | 5.1 to 5.9 | Introduction to UVM, SystemVerilog OOP and UVM, UVM components, SystemVerilog versus UVM |
| 6. Revision and practice | 6.1 to 6.7 | Summary, questions, exercises, checklist |

### What you need from earlier modules

| Topic in this module | Builds on |
|---|---|
| Packages, `typedef`, enums | M1 (the `alu_pkg` package) |
| Parameterized classes, static members, `extern` | M4 (classes, static properties, inheritance) |
| Process control | M7 (`fork`...`join`, `join_any`, `join_none`, `disable fork`, `wait fork`) |
| Virtual interfaces and clocking blocks | M8 |
| `randcase`, `randsequence` | M5 (randomization and `dist`) |
| UVM mapping | M9 (the layered testbench) and M10 (coverage) |

### Naming used in this module

The same names are used as in the rest of the course: the DUT is `alu` with the package `alu_pkg` and the opcode type `alu_op_e`; the interface is `alu_if` with clocking blocks `drv_cb` and `mon_cb`; the transaction class is `alu_txn`; the testbench components are `alu_generator`, `alu_driver`, `alu_monitor`, `alu_scoreboard`, `alu_env` and `alu_test`, collected in the package `alu_tb_pkg`; the mailboxes are `gen2drv_mbx` and `mon2scb_mbx`.

> **Note:** As in the other modules, the "Expected output" blocks were derived by hand from the rules of IEEE 1800-2017 and were not captured from a simulator run. Examples that use random constructs show a "Sample output" whose values differ for every seed and simulator. A few constructs in this module (`randsequence`, `process` suspend and resume, DPI) are supported unevenly by tools; the text says so where it applies.

# Part 1: Packages and Scope

## 1.1 Packages

### In plain English

A testbench is made of many files: the DUT, the interface, a dozen classes, the top module. Several of them need the same definitions. The ALU opcode type `alu_op_e` is needed by the DUT, by the interface, by the transaction class and by the scoreboard. If each file wrote its own copy of the definition, the copies would drift apart, and (as Module 1 showed) two identical-looking `typedef`s are not even the same type.

A **package** is a named box in which you put shared definitions **once**. Any file that needs them opens the box by name.

### Technical definition

A `package` is a top-level SystemVerilog construct that provides a **declarative scope** (a namespace) for sharing declarations among modules, interfaces, programs, classes and other packages. A package is not instantiated. It exists exactly once in a simulation, and everything declared in it has a single copy.

### Why it is needed

| Problem without packages | How a package solves it |
|---|---|
| The same `typedef`, enum or parameter is repeated in many files | Declared once, imported everywhere |
| Two identical `typedef`s in two files are different types and cannot be connected | One declaration means one type |
| `` `define `` macros are global text substitutions with no scope, so names collide | Package names are scoped: `alu_pkg::WIDTH` and `fifo_pkg::WIDTH` can coexist |
| Classes declared outside any scope land in the compilation unit scope (`$unit`), whose contents depend on how the tool was invoked | Classes in a package have a fixed, portable home |
| Hard to deliver a verification component to another team | The component is delivered as one package (for example the whole of UVM is `uvm_pkg`) |

### What may and may not be placed in a package

| Allowed in a package | Not allowed in a package |
|---|---|
| `typedef`, `enum`, `struct`, `union` types | Module, interface or program **definitions** |
| `parameter`, `localparam`, `const` | **Instances** of modules or interfaces |
| Functions and tasks | `always`, `always_ff`, `always_comb`, `initial`, `final` blocks |
| Class definitions | Continuous assignments (`assign`) |
| Variables (one shared static copy) and nets | Hierarchical references to anything outside the package (`tb_top.clk`) |
| `import` of other packages, `export` | Another package definition (packages cannot be nested) |
| DPI `import` and `export` declarations (Section 4.3) | |
| Covergroup, `property`, `sequence` and `let` declarations | |

The reasoning behind the right-hand column: a package is a collection of *declarations*. It contains no hardware and no processes of its own, and it must be compilable by itself, before and independently of the modules that use it. So it cannot refer to those modules.

### How it works internally

```text
   Compilation order                         What the compiler builds
   -----------------                         ------------------------
   1. alu_pkg.sv          ----------->       scope "alu_pkg"   { alu_op_e, ALU_ADD, ... }
   2. alu.sv              (import alu_pkg)   module alu        looks names up in alu_pkg
   3. alu_if.sv           (import alu_pkg)   interface alu_if  looks names up in alu_pkg
   4. alu_tb_pkg.sv       (import alu_pkg)   scope "alu_tb_pkg" { alu_txn, alu_driver, ... }
   5. tb_top.sv           (import both)      module tb_top

   - A package must be compiled BEFORE every file that refers to it.
   - There is ONE alu_pkg in the simulation. A variable declared in it is shared by all.
   - Importing copies nothing. It only makes a name visible without the "pkg::" prefix.
```

Two consequences are worth stating explicitly:

- A package is **not** like a C header that is pasted into every file. It is a real scope that is compiled once.
- A variable in a package is effectively a global variable. Every module, interface and class that refers to it sees the same storage.

### Syntax

```systemverilog
package <package_name>;
  // declarations: types, parameters, functions, tasks, classes ...
endpackage : <package_name>        // the closing label is optional
```

There are three ways to use an item from a package. They are explained fully in Section 1.2.

```systemverilog
alu_pkg::alu_op_e op;          // 1. explicit reference with the scope resolution operator
import alu_pkg::alu_op_e;      // 2. explicit import of one name
import alu_pkg::*;             // 3. wildcard import of all names
```

### Complete example

```systemverilog file=tb_package_basic.sv
package util_pkg;

  parameter int DATA_W = 8;

  typedef logic [DATA_W-1:0]       data_t;
  typedef enum {LOW, MEDIUM, HIGH} level_e;

  int unsigned error_count = 0;            // ONE copy, shared by every user of the package

  function automatic data_t swap_nibbles(data_t d);
    return {d[3:0], d[7:4]};
  endfunction

  function automatic void report_error(string msg);
    error_count++;
    $display("ERROR %0d: %s", error_count, msg);
  endfunction

  class counter;
    static int created = 0;
    int        id;
    function new();
      created++;
      id = created;
    endfunction
  endclass

endpackage : util_pkg

module tb_package_basic;
  import util_pkg::*;

  data_t  d;
  level_e lvl;
  counter c1, c2;

  initial begin
    d = swap_nibbles(8'hA5);
    $display("1. swap_nibbles(A5) = %h, DATA_W = %0d", d, DATA_W);

    lvl = HIGH;
    $display("2. lvl = %s", lvl.name());

    report_error("first problem");
    util_pkg::report_error("second problem");
    $display("3. error_count = %0d", util_pkg::error_count);

    c1 = new();
    c2 = new();
    $display("4. c2.id = %0d, counter::created = %0d", c2.id, counter::created);
  end

endmodule
```

```output
1. swap_nibbles(A5) = 5a, DATA_W = 8
2. lvl = HIGH
ERROR 1: first problem
ERROR 2: second problem
3. error_count = 2
4. c2.id = 2, counter::created = 2
```

**Line by line**

| Code | Explanation |
|---|---|
| `package util_pkg;` | Opens the package scope. Everything up to `endpackage` belongs to `util_pkg`. |
| `parameter int DATA_W = 8;` | A constant visible to every user. A parameter in a package cannot be overridden per instance (there are no instances); it behaves like a `localparam`. |
| `typedef logic [DATA_W-1:0] data_t;` | A shared type, built from the shared parameter. |
| `typedef enum {LOW, MEDIUM, HIGH} level_e;` | A shared enum. The labels `LOW`, `MEDIUM`, `HIGH` are names in the package scope too. |
| `int unsigned error_count = 0;` | A package variable. There is one copy in the whole simulation. |
| `function automatic ...` | Package functions should be declared `automatic` so that each call gets its own storage (M3). Synthesis tools require this for functions used in RTL. |
| `class counter` | A class may be defined in a package. This is how testbench classes are normally organised. |
| `import util_pkg::*;` | Wildcard import inside the module: all the names above may now be used without a prefix. |
| `d = swap_nibbles(8'hA5);` | Calls the package function; `A5` becomes `5A`. |
| `lvl = HIGH;` | The enum label is visible through the wildcard import. |
| `report_error(...)` and `util_pkg::report_error(...)` | The same function called through the import and through an explicit prefix. Both increment the same `error_count`, which is why the second message is numbered 2. |
| `util_pkg::error_count` | The explicit prefix always works, whether or not the package was imported. |
| `counter::created` | `::` applied to a class name reaches a static member (Section 1.3). |

### How a real testbench package is organised

Each class is kept in its own file, and the files are pulled into the package with `` `include ``. This gives one class per file for readability and version control, and one package for scoping.

```systemverilog
// file: alu_tb_pkg.sv
package alu_tb_pkg;

  import alu_pkg::*;                 // the DUT's types (alu_op_e)

  typedef class alu_scoreboard;      // forward declarations, if any are needed

  `include "alu_txn.sv"              // order matters: declare a class before it is used
  `include "alu_generator.sv"
  `include "alu_driver.sv"
  `include "alu_monitor.sv"
  `include "alu_scoreboard.sv"
  `include "alu_env.sv"
  `include "alu_test.sv"

endpackage : alu_tb_pkg
```

```text
   Compile list (file list, in order):

      alu_pkg.sv        the design package
      alu.sv            the DUT
      alu_if.sv         the interface (not in a package: interfaces cannot be)
      alu_tb_pkg.sv     the testbench package; it `includes the class files itself
      tb_top.sv         the top module; imports alu_pkg and alu_tb_pkg

   The individual class files (alu_txn.sv ...) are NOT put on the compile list.
   They are compiled only as part of alu_tb_pkg, through `include.
```

### `include versus import

These two are confused constantly, and the difference is a standard interview question.

| Property | `` `include "file" `` | `import pkg::*;` |
|---|---|---|
| What it is | A compiler directive (preprocessor) | A language statement |
| What it does | Pastes the text of the file at that point, before parsing | Makes names of an already-compiled package visible in the current scope |
| Creates declarations? | Yes: whatever the pasted text declares is declared again, here | No: it creates nothing, it only gives access |
| Used twice | The declarations exist twice (two different types, or a redefinition error) | Harmless; the package still exists once |
| Typical use | Pulling class files into a package; macro definition files | Using a package from a module, interface, class file or another package |

> **Interview trap:** "If `alu_txn.sv` is `` `include ``d in package A and also in package B, can an `A::alu_txn` handle be assigned to a `B::alu_txn` handle?" No. The text was compiled twice, in two scopes, so there are two unrelated classes that merely have the same name. The simulator reports a type mismatch. A class file must be included in exactly one package, and everybody else must import that package.

### The compilation unit scope: $unit

Anything declared outside every module, interface, package and class is in the **compilation unit scope**, called `$unit`.

```systemverilog
typedef logic [7:0] byte_t;        // declared outside everything: lives in $unit

module m;
  byte_t        a;                 // visible here without any import
  $unit::byte_t b;                 // explicit reference to the compilation unit scope
endmodule
```

It looks convenient, but it should be avoided:

| Problem with `$unit` | Explanation |
|---|---|
| Its contents depend on the tool's command line | A simulator may treat all files on the command line as one compilation unit, or each file as a separate one. The same code can compile in one mode and fail in the other |
| No name to refer to from another unit | A `$unit` declaration in file A is invisible in file B when files are separate compilation units |
| Name pollution | Every `$unit` name is visible in every following scope of that unit; collisions are easy and hard to trace |
| Wildcard imports at `$unit` level affect everything after them | `import pkg::*;` written above a module, outside it, is an import into `$unit` |

> **Key point:** Put shared declarations in a named package. Put `import` statements inside the module, interface or package that needs them (or in the module header), not at file level.

The short examples in this course sometimes declare a class above the test module for brevity. That places the class in `$unit`. It is acceptable in a single-file demonstration and wrong in a project.

### Packages and synthesis

Packages are synthesizable when their content is: types, parameters, and `automatic` functions without timing. That is how RTL teams share bus structs, opcode enums and width parameters between blocks. Classes, package variables used as globals, and tasks with delays are simulation-only.

> **Common mistake:** Declaring a variable in a package to pass information between testbench components "because it is easy". It works, but it is a global variable: any code can change it, the order of updates is hard to follow, and two instances of the same environment cannot have different values. Use it for genuinely global things only (an error counter, a verbosity level); pass everything else through constructors or configuration objects.

> **Common mistake:** Leaving a package off the compile list or listing it after the files that use it. The error message is usually "package not found" or "undeclared identifier" at the first `import`. Packages are compiled first, in dependency order.

> **Verification application:** A verification IP block for a protocol is delivered as one package, for example `apb_agent_pkg`, containing the transaction, driver, monitor and coverage classes. An environment for a chip imports the packages of all the agents it uses. The design delivers `*_pkg.sv` files with its types and parameters, which the testbench packages import, so that DUT and testbench can never disagree about an encoding.

### Interview questions

**Q1. What is a package?**
A top-level, named declarative scope that holds declarations to be shared between modules, interfaces, programs, classes and other packages: types, parameters, functions, tasks, classes and so on. It is compiled once and exists once.

**Q2. What can a package not contain?**
Module, interface or program definitions or instances; procedural blocks such as `always` and `initial`; continuous assignments; hierarchical references to objects outside the package; and nested packages.

**Q3. Is a package synthesizable?**
Yes, if its contents are: typedefs, enums, structs, parameters and automatic functions without timing control. Classes and other verification constructs in a package are simulation-only.

**Q4. What is the difference between a package and a module?**
A module describes hardware or testbench structure: it has ports, can be instantiated many times, and contains processes. A package only holds declarations: it has no ports, cannot be instantiated, contains no processes, and exists as a single copy.

**Q5. If a package contains a variable and two modules import the package, how many copies of the variable exist?**
One. Both modules read and write the same variable.

**Q6. What is the difference between `` `include `` and `import`?**
`` `include `` is a preprocessor directive that pastes the text of a file into the current position, so whatever the file declares is declared there. `import` makes the names of a compiled package visible in the current scope without creating anything. Classes are normally `` `include ``d into one package, and that package is then imported wherever the classes are used.

**Q7. What is `$unit` and why is it discouraged?**
`$unit` is the compilation unit scope: the anonymous scope that holds declarations written outside any module, interface or package. It is discouraged because what belongs to one compilation unit depends on the tool and its options, so code relying on it is not portable, and because it pollutes the name space of every scope that follows.

**Q8. Why do packages have to be compiled before the modules that use them?**
Because an `import` or a `pkg::name` reference is resolved at compile time. The compiler must already know the package scope and the declarations inside it.

## 1.2 Importing Packages

### In plain English

Declaring something in a package does not make it visible anywhere else. A user of the package has three choices:

1. Write the full name every time: `alu_pkg::alu_op_e`.
2. Ask for one specific name to be made visible: `import alu_pkg::alu_op_e;`.
3. Ask for every name in the package to be made available when needed: `import alu_pkg::*;`.

The rules for what happens when names collide are different for choices 2 and 3, and those rules are the main interview topic here.

### Technical definition

| Form | Name | Effect |
|---|---|---|
| `pkg::name` | Explicit (qualified) reference | Uses the item directly. Nothing is added to the local scope. Always unambiguous |
| `import pkg::name;` | Explicit import | **Declares** `name` in the current scope as an alias of the package item. It is an error if `name` is already declared or explicitly imported in that scope |
| `import pkg::*;` | Wildcard import | Makes every name in the package a **candidate**. A candidate is actually imported only at the moment it is referenced and only if no local declaration or explicit import of that name is visible |

### How name lookup works

When the compiler meets an identifier `x` inside a scope, it searches in this order:

```text
   1. Declarations in the current scope that appear before this point
      (this includes names brought in by an EXPLICIT import in this scope)
   2. Names available through a WILDCARD import in the current scope
   3. Repeat steps 1 and 2 in the enclosing scope, then the next enclosing scope ...
   4. The compilation unit scope ($unit), including its imports
   5. Not found -> error (or, for a net in a port connection, an implicit wire; see M1)
```

From this order follow all the collision rules:

| Situation | Result |
|---|---|
| Local declaration of `x` and a wildcard import that also offers `x` | Legal. The local `x` wins (step 1 before step 2). The package's `x` is still reachable as `pkg::x` |
| Local declaration of `x` and an **explicit** import of `x` in the same scope | Error: `x` is declared twice in one scope |
| Two explicit imports of the same name from different packages | Error |
| Two wildcard imports whose packages both contain `x`, and `x` is **never used** | Legal. A candidate that is never referenced causes no problem |
| Two wildcard imports whose packages both contain `x`, and `x` **is used** without a prefix | Error: the reference is ambiguous. Fix with `pkg_a::x` |
| `x` is used through a wildcard import, and **later in the same scope** `x` is declared locally | Error: the use already imported `x` into the scope, so the later declaration collides |
| Explicit import of `x` and a wildcard import from another package that also offers `x` | Legal. The explicit import wins |

### Where an import may be placed

```systemverilog
// (a) In the module header: visible to the parameter list, the port list and the body.
module alu
  import alu_pkg::*;
(
  input  alu_op_e op,              // the port list can use the imported type
  ...
);

// (b) Inside the module body: visible to the body only, NOT to the port list.
module tb_top;
  import alu_pkg::*;
  import alu_tb_pkg::*;
  ...
endmodule

// (c) Inside an interface, a program, a package, a task, a function or a begin-end block.
package alu_tb_pkg;
  import alu_pkg::*;
  ...
endpackage

// (d) Outside any design unit: an import into $unit. Avoid.
import alu_pkg::*;
module bad_style;  ...  endmodule
```

| Placement | Scope of the import | Recommendation |
|---|---|---|
| Module / interface header | Whole design unit, including ports and parameters | Use when a port or parameter needs a package type |
| Inside the body | The body from that point on | The normal choice |
| Inside a package | That package only | Normal for a testbench package using a design package |
| At file level (`$unit`) | Everything that follows in the compilation unit | Avoid |

### Imports are not passed on: export

Importing package A into package B makes A's names visible **inside B only**. A module that imports B does not thereby see A's names.

```systemverilog
package alu_pkg;
  typedef enum logic [2:0] {ALU_ADD, ALU_SUB /* ... */} alu_op_e;
endpackage

package alu_tb_pkg;
  import alu_pkg::*;
  class alu_txn;
    rand alu_op_e op;                // fine: alu_op_e is visible inside alu_tb_pkg
  endclass
endpackage

module tb_top;
  import alu_tb_pkg::*;
  alu_txn  t;                        // fine
  // alu_op_e op;                    // ERROR: alu_op_e is not a name of alu_tb_pkg
  alu_pkg::alu_op_e op;              // fine: explicit reference
endmodule
```

If a package wants to pass imported names on to its own users, it uses `export`:

```systemverilog
package alu_tb_pkg;
  import alu_pkg::*;
  export alu_pkg::*;                 // re-export the alu_pkg names that this package uses
  // export *::*;                    // re-export everything imported from every package
  ...
endpackage
```

`export pkg::*` re-exports only those names of `pkg` that were actually imported, that is, referenced inside the exporting package. In practice most teams simply import both packages where both are needed.

### The enum label trap

An explicit import of an enum **type** does not import its **labels**. The labels are separate names in the package.

```systemverilog
module m1;
  import alu_pkg::alu_op_e;          // imports only the type name
  alu_op_e op;
  // initial op = ALU_ADD;           // ERROR: ALU_ADD is not visible
  initial op = alu_pkg::ALU_ADD;     // fine
endmodule

module m2;
  import alu_pkg::*;                 // type and labels are all candidates
  alu_op_e op;
  initial op = ALU_ADD;              // fine
endmodule
```

This is the main practical reason wildcard imports are the norm for packages that contain enums.

### Complete example

```systemverilog file=tb_import_rules.sv
package a_pkg;
  int x = 1;
  int y = 10;
  typedef enum {RED, GREEN} colour_e;
endpackage

package b_pkg;
  int x = 2;
  int z = 30;
endpackage

module tb_import_rules;
  import a_pkg::*;
  import b_pkg::*;

  int y = 99;       // a local declaration hides the wildcard candidate a_pkg::y

  initial begin
    // $display("%0d", x);   // ILLEGAL: x is offered by two wildcard imports (ambiguous)
    $display("1. a_pkg::x = %0d, b_pkg::x = %0d", a_pkg::x, b_pkg::x);
    $display("2. y = %0d (local), a_pkg::y = %0d", y, a_pkg::y);
    $display("3. z = %0d", z);
    $display("4. GREEN = %0d", GREEN);
  end

endmodule
```

```output
1. a_pkg::x = 1, b_pkg::x = 2
2. y = 99 (local), a_pkg::y = 10
3. z = 30
4. GREEN = 1
```

**Line by line**

| Code | Explanation |
|---|---|
| `import a_pkg::*; import b_pkg::*;` | Two wildcard imports. Both packages contain `x`. That alone is not an error. |
| `int y = 99;` | A local `y`. It was declared before any use of `y`, so it simply takes precedence over the candidate `a_pkg::y`. |
| The commented `$display` of `x` | Using the bare name `x` would be an error: the compiler finds it in two wildcard-imported packages and cannot choose. |
| Line 1 | The explicit prefix resolves the ambiguity. Both values remain accessible. |
| Line 2 | The bare `y` is the local one (99). The package's `y` is still reachable with the prefix (10). |
| Line 3 | `z` exists only in `b_pkg`, so the wildcard import supplies it. |
| Line 4 | The enum label `GREEN` is a name in `a_pkg` and comes in through the wildcard. Its value is 1. |

### Comparison of the three ways to use a package item

| Property | `pkg::name` | `import pkg::name;` | `import pkg::*;` |
|---|---|---|---|
| Typing effort | Most | Medium | Least |
| Adds a name to the local scope | No | Yes, immediately | Only when the name is referenced |
| Collision with a local declaration | Impossible | Compile error | Local declaration wins silently |
| Collision between two packages | Impossible | Compile error at the import | Error only if the name is used |
| Brings in enum labels | Each label must be prefixed | Only the names listed | Yes |
| Reader can see where a name comes from | Yes | Yes | Not directly |
| Typical use | One-off references, resolving ambiguity | Strict coding styles, RTL | Testbenches, packages with enums |

> **Interview trap:** "Module `m` does `import p::*;` and also declares its own `int count;`. Package `p` also has `count`. Is that an error?" No. The local declaration takes precedence over a wildcard import. It **would** be an error with `import p::count;`, because an explicit import is itself a declaration in the local scope.

> **Interview trap:** "Does `import pkg::*;` import everything?" It imports nothing by itself. It makes all names *candidates*; each name is imported at the point where it is first referenced, provided nothing local has that name.

> **Common mistake:** Placing `import alu_pkg::*;` inside the module body and then using `alu_op_e` in the port list. The port list comes before the body, so the type is unknown there. Put the import in the module header, between the module name and the port list.

> **Common mistake:** Expecting names to pass through a chain of imports. `tb_top` importing `alu_tb_pkg` does not see `alu_op_e` unless it also imports `alu_pkg` or `alu_tb_pkg` re-exports it.

### Interview questions

**Q1. What are the ways of accessing an item in a package?**
Three: an explicit reference `pkg::item`; an explicit import `import pkg::item;`; and a wildcard import `import pkg::*;`.

**Q2. What is the difference between an explicit import and a wildcard import?**
An explicit import declares that one name in the current scope immediately, so a clash with a local declaration or another explicit import is a compile error. A wildcard import only makes the package's names candidates; a name is imported when it is first referenced, and a local declaration of the same name takes precedence.

**Q3. Two packages contain a function with the same name and both are wildcard-imported. What happens?**
Nothing, until the function is called without a prefix. Then the reference is ambiguous and compilation fails. Calling it as `pkg_a::func()` resolves it.

**Q4. Where can an import statement be written?**
In a module, interface or program header (before the port list), in the body of a module, interface, program or package, inside tasks, functions and blocks, and at compilation-unit level. The header form is needed when ports or parameters use package types.

**Q5. Package B imports package A. Module M imports B. Can M use A's types without a prefix?**
No. Imports are not transitive. M must import A as well, or B must re-export the names with `export A::*;`.

**Q6. Why does `import alu_pkg::alu_op_e;` not let me write `ALU_ADD`?**
The explicit import brings in only the type name. Enum labels are separate identifiers in the package and must be imported explicitly, referenced as `alu_pkg::ALU_ADD`, or made available by a wildcard import.

**Q7. What does `export` do?**
It makes names that a package has imported from another package available to importers of the first package, as if they were declared there. `export pkg::*;` re-exports the names taken from `pkg`; `export *::*;` re-exports all imported names.

## 1.3 The Scope Resolution Operator (::)

### In plain English

Many things in SystemVerilog are containers of names: a package contains types and functions, a class contains properties, methods and types. The operator `::` means "the name on the right, **as declared inside** the container on the left". It is how you reach into a named scope from outside.

### Technical definition

`<scope>::<name>` is the **scope resolution operator**. The left side is a package name, a class name (or a class type, including a specialised parameterized class or a `typedef` of one), `$unit`, or the keyword `local`. The right side is an identifier declared in that scope. It is resolved at compile time and refers to the **declaration**, not to any particular object.

The dot operator `.` is different: its left side is an **instance** (an object handle, a struct variable, a module or interface instance), and it selects a member of that instance.

### Every use of :: in one table

| Use | Example | Covered in |
|---|---|---|
| Package item | `alu_pkg::alu_op_e`, `alu_pkg::ALU_ADD`, `util_pkg::report_error()` | Sections 1.1, 1.2 |
| Wildcard and explicit import | `import alu_pkg::*;` | Section 1.2 |
| Static property of a class | `alu_txn::count` | M4 |
| Static method of a class | `alu_txn::get_count()` | M4 |
| Type, enum label, parameter or constant declared inside a class | `packet::kind_e`, `packet::LONG`, `packet::HDR_LEN` | Below |
| Defining a method outside its class (`extern`) | `function void alu_txn::print();` | M4 |
| Defining a constraint outside its class | `constraint alu_txn::c_small { a < 16; }` | M5 |
| Reaching a hidden base-class member by class name | `base_txn::print()` from inside a derived class | M4 |
| Static member of a parameterized class specialisation | `stack #(int)::instances` | Section 2.1 |
| Compilation unit scope | `$unit::byte_t` | Section 1.1 |
| Built-in `std` package | `std::randomize(v)`, `std::process` | M5, Section 3.4 |
| Caller's scope inside `randomize() with {}` | `obj.randomize() with { a == local::a; }` | M5 |
| Covergroup type options and static coverage methods | `alu_cg::type_option.goal = 90;`, `alu_cg::get_coverage()` | M10 |
| UVM factory | `alu_seq_item::type_id::create("req")` | Section 5.5 |

The last row is the reason UVM code is full of `::`. `type_id` is a type declared inside the class (by a macro), and `create` is a static method of that type. So `alu_seq_item::type_id::create(...)` is simply "class scope, then nested class scope, then static method".

### How it works internally

```text
   p.len                       packet::count
   -----                       -------------
   1. take the handle p        1. find the class scope "packet" (compile time)
   2. follow it to the object  2. find the declaration "count" in that scope
   3. read member len of       3. it is static, so it has one storage location that belongs
      THAT object                 to the class itself: read it. No object is needed.

   Run-time operation;         Compile-time name resolution;
   fails if p is null.         works even if no object has ever been created.
```

Only things that exist without an object can be reached through a class name with `::` from outside the class: static properties, static methods, types, enum labels, parameters and constants. A non-static property has no storage until an object is constructed, so `packet::len` from a module is an error.

### Complete example

```systemverilog file=tb_scope_resolution.sv
package cfg_pkg;
  parameter int MAX_LEN = 16;
  function automatic int twice(int v);
    return 2 * v;
  endfunction
endpackage

class packet;
  typedef enum {SHORT, LONG} kind_e;      // a type declared inside the class
  localparam int HDR_LEN = 4;             // a constant declared inside the class
  static int count = 0;                   // one copy for the whole class

  kind_e kind;
  int    len;

  extern function new(kind_e kind, int len);
  extern function void print();

  static function int get_count();
    return count;
  endfunction
endclass

function packet::new(kind_e kind, int len);      // constructor defined outside the class
  this.kind = kind;
  this.len  = len;
  count++;
endfunction

function void packet::print();                    // method defined outside the class
  $display("   packet kind=%s len=%0d", kind.name(), len);
endfunction

module tb_scope_resolution;

  packet         p;
  packet::kind_e k;       // class-scoped type
  int            v;

  initial begin
    $display("1. cfg_pkg::MAX_LEN = %0d, cfg_pkg::twice(5) = %0d",
             cfg_pkg::MAX_LEN, cfg_pkg::twice(5));
    $display("2. packet::count = %0d, packet::HDR_LEN = %0d",
             packet::count, packet::HDR_LEN);

    k = packet::LONG;                   // class-scoped enum label
    p = new(k, 12);
    p = new(packet::SHORT, 3);
    p.print();
    $display("3. packet::get_count() = %0d", packet::get_count());

    void'(std::randomize(v) with { v inside {[1:3]}; });
    $display("4. v is in the range 1 to 3: %b", v inside {[1:3]});
  end

endmodule
```

```output
1. cfg_pkg::MAX_LEN = 16, cfg_pkg::twice(5) = 10
2. packet::count = 0, packet::HDR_LEN = 4
   packet kind=SHORT len=3
3. packet::get_count() = 2
4. v is in the range 1 to 3: 1
```

**Line by line**

| Code | Explanation |
|---|---|
| `cfg_pkg::MAX_LEN`, `cfg_pkg::twice(5)` | Package scope. No import was written, and none is needed with the prefix. |
| `typedef enum {SHORT, LONG} kind_e;` inside the class | The type and its labels belong to the class scope. Outside the class they must be written `packet::kind_e`, `packet::SHORT`. |
| `extern function new(...)`, `extern function void print();` | Prototypes only. The bodies are written outside the class. |
| `function packet::new(...)` | `packet::` tells the compiler which class this body belongs to. Inside the body the class scope applies, so `kind_e`, `count` and `this` are used without a prefix. |
| `packet::count`, `packet::HDR_LEN` on line 2 | A static property and a class constant read through the class name. No `packet` object exists yet, and `count` is 0. |
| `k = packet::LONG;` | The enum label, qualified by the class. |
| `p = new(k, 12); p = new(packet::SHORT, 3);` | Two objects are constructed; each constructor call increments the shared `count`. The first object is no longer referenced after the second assignment. |
| `p.print();` | The dot operator: `p` is a handle, `print` runs on the object it refers to (the second one). |
| `packet::get_count()` | A static method called through the class name. It returns 2. |
| `std::randomize(v) with {...}` | `std` is the built-in package that every SystemVerilog scope sees. `std::randomize` is the scope-level randomize function from M5. The value differs per run, but it always satisfies the constraint, so line 4 always prints 1. |

### :: versus .

| Property | `::` scope resolution | `.` member / hierarchy selection |
|---|---|---|
| Left operand | A scope name: package, class, `$unit`, `local` | An instance: object handle, struct or union variable, interface or module instance, virtual interface |
| Resolved | At compile time | Member selection on a handle happens at run time |
| Needs an object | No | Yes for class members (a null handle causes a run-time error) |
| Reaches | Static properties and methods, types, enum labels, parameters, package items | Any accessible member of the instance, static or not |
| Example | `alu_txn::count`, `alu_pkg::ALU_ADD` | `txn.a`, `vif.drv_cb.valid_in`, `tb_top.dut.result` |

A static member can be reached both ways: `packet::count` and `p.count` refer to the same storage. The `::` form is preferred because it shows the reader that the member is static and it does not depend on a handle being valid.

> **Interview trap:** "Can you call a non-static method with `::`?" From outside the class, no: `packet::print()` in a module is an error, because `print` needs an object. The one legitimate non-static use is *inside* a derived class, where `base_class::method()` selects the base-class version of a member that the derived class has hidden; it behaves like `super.method()` but can name any ancestor.

> **Common mistake:** Writing `packet.count` or `alu_pkg.ALU_ADD`. A class name or a package name is not an instance, so the dot operator does not apply to it.

> **Common mistake:** Forgetting the class prefix on the *return type* of an out-of-block method. In `function kind_e packet::get_kind();` the return type is read before the compiler sees `packet::`, so `kind_e` is unknown at that point. Write `function packet::kind_e packet::get_kind();`. Argument types come after `packet::` and do not need the prefix.

### Interview questions

**Q1. What is the scope resolution operator and where is it used?**
`::` selects a name from a named scope. It is used to access package items (`pkg::item`), static properties and methods of a class (`cls::member`), types, enum labels and parameters declared inside a class, to define `extern` methods and constraints outside the class body (`function void cls::method();`), to access `$unit` and the `std` package, and to name a specialisation's static members in a parameterized class.

**Q2. What is the difference between `::` and `.`?**
`::` works on a scope name and is resolved at compile time; it needs no object. `.` works on an instance (a handle, a struct, an interface instance) and selects a member of that instance.

**Q3. How do you access a static variable of a class without creating an object?**
`class_name::variable_name`.

**Q4. How do you define a class method outside the class?**
Declare the prototype inside the class with `extern`, then write the body outside as `function <return_type> <class_name>::<method_name>(<arguments>); ... endfunction`.

**Q5. A class declares `typedef enum {RD, WR} dir_e;`. How does a module declare a variable of that type and assign `WR`?**
`my_class::dir_e d; d = my_class::WR;`

**Q6. Explain `alu_seq_item::type_id::create("req")`.**
`alu_seq_item` is a class. `type_id` is a type declared inside that class by the UVM registration macro. `create` is a static method of `type_id`. The two `::` operators walk from the class scope into the nested type's scope and call its static method, which asks the UVM factory to construct the object.

**Q7. What does `local::` mean in `randomize() with { addr == local::addr; }`?**
Inside the `with` block, names are looked up first in the object being randomized. `local::addr` forces the name to be resolved in the scope that contains the `randomize()` call, so the constraint compares the object's `addr` with the caller's `addr`.
