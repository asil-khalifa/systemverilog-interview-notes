# Part 4: Random Sequences, C Code and System Tasks

## 4.1 randcase

### In plain English

A `case` statement chooses a branch by comparing a value. A `randcase` statement chooses a branch **at random**, and you say how likely each branch is by giving it a weight. It is the quickest way to write "60 percent of the time do a write, 30 percent a read, 10 percent stay idle" in procedural code.

### Technical definition

`randcase` is a procedural statement that selects exactly one of its branches at random. Each branch is prefixed by a non-negative integer expression, its **weight**. The probability of a branch is its weight divided by the sum of all the weights.

### Syntax

```systemverilog
randcase
  <weight_1> : <statement_1>;
  <weight_2> : <statement_2>;
  ...
endcase
```

### Rules

| Rule | Detail |
|---|---|
| Weights are expressions | They may be constants or variables, evaluated each time the statement executes, so the mix can change at run time |
| Probability | weight / (sum of all weights). Weights 6, 3, 1 give 60 %, 30 %, 10 % |
| A weight of 0 | That branch is never selected |
| All weights 0 | No branch is taken; the simulator may issue a warning |
| Exactly one branch runs | There is no fall-through and no `default` |
| Random source | The random number generator of the current process (the same one `$urandom` uses), so the result is reproducible for a given seed and thread structure |
| Where it can be used | Any procedural code: tasks, functions, `initial` blocks, class methods. No class or `rand` variable is needed |
| Synthesizable | No |

### Complete example

```systemverilog file=tb_randcase.sv
module tb_randcase;

  int n_write, n_read, n_idle, n_never;

  initial begin
    repeat (1000) begin
      randcase
        6 : n_write++;
        3 : n_read++;
        1 : n_idle++;
        0 : n_never++;        // weight 0: never selected
      endcase
    end

    $display("write=%0d read=%0d idle=%0d never=%0d", n_write, n_read, n_idle, n_never);
    $display("total=%0d", n_write + n_read + n_idle + n_never);
  end

endmodule
```

```output
write=603 read=298 idle=99 never=0
total=1000
```

**Sample output; differs per seed and simulator.** What is guaranteed: `never` is 0, the total is exactly 1000 (one branch per execution), and the three counts are close to 600, 300 and 100.

**Line by line**

| Code | Explanation |
|---|---|
| `repeat (1000)` | The `randcase` is executed 1000 times; each execution makes one independent random choice. |
| `6 : n_write++;` | Weight 6 out of a total of 10: selected about 60 % of the time. |
| `0 : n_never++;` | A zero weight removes the branch from the choice. |
| The total | Always 1000, which shows that exactly one branch executes each time. |

### An industry-style use

```systemverilog
task alu_generator::run();
  alu_txn txn;
  repeat (num_txn) begin
    txn = new();
    randcase
      70 : assert (txn.randomize());                                    // fully random
      20 : assert (txn.randomize() with { a == 8'hFF; b == 8'hFF; });   // corner: maximum
      10 : assert (txn.randomize() with { op == ALU_SUB; a < b; });     // corner: borrow
    endcase
    gen2drv_mbx.put(txn);
  end
  -> gen_done;
endtask
```

The generator mixes plain random transactions with two families of corner cases in chosen proportions, without adding any constraint to the transaction class.

### randcase compared with related constructs

| Construct | Chooses | Weights | Where it is written | Works with constraints |
|---|---|---|---|---|
| `case` | The branch that matches a value | None | Procedural code | Not applicable |
| `randcase` | One **statement** at random | Per branch | Procedural code | No: it is not seen by the solver |
| `dist` in a constraint (M5) | A **value** for a `rand` variable | Per value or range | Inside a constraint | Yes: solved together with all other constraints |
| `randsequence` (Section 4.2) | A **sequence** of statements from a grammar | Per alternative | Procedural code | No |

> **Interview trap:** "What happens if every weight in a `randcase` is zero?" No branch is executed (and a warning may be printed). It is not an error and it does not pick a branch arbitrarily.

> **Common mistake:** Assuming weights must add up to 100. They are relative. Weights 1 and 3 give 25 % and 75 %.

### Interview questions

**Q1. What is `randcase`?**
A procedural statement that randomly executes one of several branches, with the probability of each branch proportional to its weight.

**Q2. What is the difference between `randcase` and a `dist` constraint?**
`randcase` selects which statement to execute in procedural code and is not part of constraint solving. `dist` assigns weighted probabilities to the values of a random variable inside a constraint and is solved together with the object's other constraints by `randomize()`.

**Q3. In `randcase 1: a(); 2: b(); 5: c(); endcase`, what is the probability of `b()`?**
2 / (1 + 2 + 5) = 25 %.

## 4.2 randsequence

### In plain English

`randcase` makes one random choice. `randsequence` generates a whole random **sequence of actions** that follows a set of rules. You describe the legal structure of a scenario in the same way a grammar describes legal sentences: "a test is a reset, then some traffic, then a finish; traffic is several operations; an operation is a write, a read or an idle". The simulator then walks through these rules, making random choices wherever there are alternatives, and executes the code attached to each rule.

### Technical definition

`randsequence` is a procedural statement that defines a set of **productions** (rules) in a notation similar to Backus-Naur Form (BNF). Execution starts at a named top production. A production expands into a list of other productions and code blocks, executed in order; where several alternatives are separated by `|`, one is chosen at random, optionally weighted with `:=`. Productions that contain only a code block are the terminals: they do the actual work.

### Syntax

```systemverilog
randsequence (<top_production>)
  <production> : <item> <item> ... ;                    // a sequence, run left to right
  <production> : <alt_1> | <alt_2> | <alt_3> ;          // alternatives: one is chosen
  <production> : <alt_1> := <w1> | <alt_2> := <w2> ;    // weighted alternatives
  <production> : { <statements> } ;                     // a code block (terminal)
endsequence
```

Further forms inside a production:

| Form | Meaning |
|---|---|
| `repeat (n) prod` | Execute `prod` n times |
| `if (cond) prod_a else prod_b` | Conditional production |
| `case (expr) v1: prod_a; v2: prod_b; default: prod_c; endcase` | Selection by value |
| `rand join prod_a prod_b` | Interleave the items of the two productions in random order |
| `break;` inside a code block | End the whole `randsequence` |
| `return;` inside a code block | End the current production only |
| Productions with arguments and return values | `gen(int n) : ...`; a production may be declared with a return type |

> **Note:** `randsequence` is part of the standard, but tool support is uneven, particularly for `rand join`, production arguments and return values. Basic sequences, alternatives, weights and `repeat` work in the major simulators. Check your tool before using the advanced forms, and expect many teams to use constraint-based sequences instead.

### How it works internally

```text
   randsequence (main)
     main    : do_reset traffic do_done ;
     traffic : repeat (4) one_op ;
     one_op  : do_write := 3 | do_read := 2 | do_idle := 1 ;
     ...

   Execution = a walk through the production tree:

                         main
            +-------------+--------------+
         do_reset       traffic        do_done
                           |
            +--------+-----+-----+--------+
          one_op   one_op      one_op   one_op          (repeat 4)
            |        |           |        |
          random   random      random   random          each picks write / read / idle
          choice   choice      choice   choice          with weights 3 : 2 : 1
```

### Complete example

```systemverilog file=tb_randsequence.sv
module tb_randsequence;

  int n_ops;

  initial begin
    randsequence (main)
      main     : do_reset traffic do_done ;
      traffic  : repeat (4) one_op ;
      one_op   : do_write := 3 | do_read := 2 | do_idle := 1 ;
      do_reset : { $display("RESET"); } ;
      do_write : { $display("  WRITE"); n_ops++; } ;
      do_read  : { $display("  READ");  n_ops++; } ;
      do_idle  : { $display("  IDLE");  n_ops++; } ;
      do_done  : { $display("DONE after %0d operations", n_ops); } ;
    endsequence
  end

endmodule
```

```output
RESET
  WRITE
  READ
  WRITE
  IDLE
DONE after 4 operations
```

**Sample output; differs per seed and simulator.** What is guaranteed: the first line is `RESET`, the last line is `DONE after 4 operations`, and between them there are exactly four lines, each one of `WRITE`, `READ` or `IDLE`, with `WRITE` the most likely.

**Line by line**

| Code | Explanation |
|---|---|
| `randsequence (main)` | Execution starts at the production named `main`. |
| `main : do_reset traffic do_done ;` | A sequence of three productions, executed in this order. The structure of the scenario is fixed here. |
| `traffic : repeat (4) one_op ;` | The production `one_op` is executed four times; each time a new random choice is made. |
| `one_op : do_write := 3 \| do_read := 2 \| do_idle := 1 ;` | Three alternatives with weights. `do_write` is chosen with probability 3/6, `do_read` 2/6, `do_idle` 1/6. Without `:=` all alternatives are equally likely. |
| `do_write : { ... } ;` | A terminal: its code block is ordinary procedural code, which may call tasks, drive an interface, or randomize and send a transaction. |
| `n_ops` | Counts the operations to demonstrate that exactly four are generated. |

In a real testbench the code blocks would call tasks such as `send_write()` and `send_read()` that create a transaction and put it in `gen2drv_mbx`.

### randcase versus randsequence versus constrained randomization

| Property | `randcase` | `randsequence` | `randomize()` with constraints |
|---|---|---|---|
| Randomises | The choice of one statement | The structure and order of a series of statements | The values of variables |
| Describes | A weighted choice | A grammar of legal scenarios | A set of legal values |
| Hierarchical | No | Yes: productions refer to productions | Through object composition |
| Solver involved | No | No | Yes |
| Typical use | Mixing a few kinds of stimulus | Generating protocol-level scenarios, instruction streams | Transaction contents |
| Tool support | Universal | Uneven for advanced features | Universal |
| Reuse / override in derived tests | Poor (hard-coded in a task) | Poor | Good (constraints are inherited and overridden) |

> **Common mistake:** Trying to make a `randsequence` choice depend on a constraint in a class. The two mechanisms are separate. Use `if` or `case` productions with ordinary variables to steer a `randsequence`.

> **Verification application:** Random instruction-stream generators for processors, and generators of legal command orders for a protocol ("configure, then enable, then any number of transfers, then disable"), are natural fits for a grammar. In UVM the same job is normally done with layered sequences, which is one reason `randsequence` is rare in modern testbenches. For interviews, know what it is, the meaning of `:=` and `|`, and be able to read a small one.

### Interview questions

**Q1. What is `randsequence`?**
A procedural construct that generates a random sequence of actions from a grammar of productions. Each production is a sequence of other productions, a weighted random choice between alternatives, or a code block.

**Q2. What do `|` and `:=` mean inside a `randsequence`?**
`|` separates alternatives of which one is chosen at random. `:=` assigns a weight to an alternative.

**Q3. When would you use `randsequence` instead of constraints?**
When the randomness is in the *order and structure* of operations (a scenario) and not in the *values* of fields: for example generating legal command sequences or instruction streams.

## 4.3 DPI Introduction

### In plain English

A great deal of useful code already exists in C: golden reference models from the architecture team, CRC and encryption routines, the firmware that will run on the chip. Rewriting it in SystemVerilog would be slow and would create a second version that could differ from the first. The **Direct Programming Interface (DPI)** lets SystemVerilog call a C function as if it were a SystemVerilog function, and lets C call a SystemVerilog function or task.

### Technical definition

DPI is the standard interface between SystemVerilog and a foreign programming language. The standard defines one foreign-language layer, for C, identified by the string `"DPI-C"`.

- An **import** declaration makes a C function callable from SystemVerilog.
- An **export** declaration makes a SystemVerilog function or task callable from C.

Arguments are passed directly, using a defined mapping between SystemVerilog types and C types. No simulator-specific API is needed for simple types.

### Why it is needed

| Use | Example |
|---|---|
| Reuse an existing C/C++ reference model in the scoreboard | The scoreboard calls `c_alu_model()` to obtain the expected result |
| Reuse algorithms | CRC, checksums, encryption, compression, floating-point maths |
| Performance | A heavy computation is faster in compiled C than in simulated SystemVerilog |
| Access to the operating system | Files, sockets, environment variables, shared memory |
| Hardware/software co-verification | Driver or firmware code written in C drives register reads and writes through exported SystemVerilog bus tasks |

Before DPI, Verilog offered the PLI and VPI. They are general but verbose: values are passed through API calls, and every C function must be registered with the simulator. DPI replaced them for the common case of "call this function with these arguments".

### Syntax

```systemverilog
// Import: C function callable from SystemVerilog
import "DPI-C" function int  c_add(input int a, input int b);
import "DPI-C" pure    function real c_scale(input real x);
import "DPI-C" context function void c_notify(input string msg);
import "DPI-C" context task          c_run_firmware();       // may call exported tasks

// Import under a different SystemVerilog name:  c_name = sv_name
import "DPI-C" crc32_table = function int unsigned crc32(input int unsigned data);

// Export: SystemVerilog function or task callable from C
export "DPI-C" function sv_log;         // only the name: no arguments, no parentheses
export "DPI-C" task     sv_bus_write;
```

Imports may be placed in a module, an interface, a program, a package or the compilation unit scope. Placing them in a package gives every user access to the C functions.

### Properties of an imported function

| Qualifier | Meaning | Restrictions |
|---|---|---|
| (none) | An ordinary C function | Must not call exported SystemVerilog code or simulator APIs that need a scope |
| `pure` | The result depends only on the input arguments and there are no side effects. The simulator may optimise calls away or reorder them | Must return a value (not `void`); no `output` or `inout` arguments; must not read or write anything outside itself (no files, no globals, no exported functions) |
| `context` | The C function needs to know the SystemVerilog scope it was called from, because it calls exported functions or tasks, or uses VPI/PLI | Slightly slower to call |

Functions versus tasks follow the SystemVerilog rule from M3: an imported **function** returns immediately and consumes no simulation time. An imported **task** may consume time, which it can only do by calling an exported SystemVerilog task that contains timing controls; such an import must be `context`.

### Data type mapping

| SystemVerilog type | C type | Notes |
|---|---|---|
| `byte` | `char` | |
| `shortint` | `short int` | |
| `int` | `int` | The most convenient type for DPI |
| `longint` | `long long` | |
| `real` | `double` | |
| `shortreal` | `float` | |
| `string` | `const char*` | A C string; do not keep the pointer after the call returns |
| `chandle` | `void*` | An opaque C pointer stored on the SystemVerilog side |
| `bit` | `svBit` (`unsigned char`) | Value 0 or 1 |
| `logic`, `reg` | `svLogic` (`unsigned char`) | Values 0, 1, Z, X encoded as 0, 1, 2, 3 |
| `bit [N:0]` (packed two-state) | `svBitVecVal*` | Array of 32-bit words |
| `logic [N:0]` (packed four-state) | `svLogicVecVal*` | Array of `{aval, bval}` word pairs (the encoding from M1, Section 2.1) |
| Open array `[]` argument | `svOpenArrayHandle` | Accessed through functions in `svdpi.h`; support varies between tools |

Argument directions:

| SystemVerilog direction | Passed to C as |
|---|---|
| `input` of a small scalar type (`int`, `real`, `byte`...) | By value |
| `input string` | `const char*` |
| `output`, `inout` | Pointer to the C type (`int*`, `double*`) |
| Packed vectors, any direction | Pointer to the canonical array |

The types `svBit`, `svLogic`, `svBitVecVal` and the helper functions are declared in the header file `svdpi.h`, which every simulator supplies.

> **Key point:** Use two-state C-compatible types (`int`, `longint`, `byte`, `real`, `string`) for DPI arguments whenever possible. They map one-to-one onto C types. Four-state and wide vectors require the `svLogicVecVal` structures and are much more error-prone.

### How it works internally

```text
   SystemVerilog side                                C side
   ------------------                                ------
   import "DPI-C" function int c_alu_model(...);     int c_alu_model(int op, int a, int b)
                                                     { ... return r; }
   exp = c_alu_model(op, a, b);   --- call --->      runs as normal compiled C code
                                  <-- return --      (simulation time does not advance)

   export "DPI-C" function sv_log;
   function void sv_log(string msg); ...             extern void sv_log(const char* msg);
                                  <--- call ---      sv_log("hello");

   Build: the C file is compiled into an object file or shared library and linked with the
          simulation. The simulator matches the import name with the C function name.
```

While the C function runs, the simulator is stopped inside that call. A C function that loops for ever hangs the simulation, and a C function that crashes brings the simulator down with it.

### Complete example

The SystemVerilog side:

```systemverilog file=tb_dpi.sv
module tb_dpi;

  // C functions callable from SystemVerilog
  import "DPI-C" pure    function int  c_alu_model(input int op, input int a, input int b);
  import "DPI-C"         function void c_minmax(input int a, input int b,
                                                output int lo, output int hi);
  import "DPI-C" context function void c_greet(input string name);

  // SystemVerilog function callable from C
  export "DPI-C" function sv_log;

  function void sv_log(input string msg);
    $display("[SV] %s", msg);
  endfunction

  int lo, hi;

  initial begin
    $display("1. c_alu_model(ADD, 200, 100) = %0d", c_alu_model(0, 200, 100));
    $display("2. c_alu_model(SUB, 5, 10)    = %0d", c_alu_model(1, 5, 10));

    c_minmax(42, 7, lo, hi);
    $display("3. lo = %0d, hi = %0d", lo, hi);

    c_greet("ALU testbench");
  end

endmodule
```

The C side:

```c file=dpi_model.c
#include <stdio.h>
#include "svdpi.h"

/* Exported from SystemVerilog: declared here so that C can call it. */
extern void sv_log(const char* msg);

/* A reference model of the ALU (opcode numbering as in alu_pkg). 9-bit result. */
int c_alu_model(int op, int a, int b)
{
    int r;
    a &= 0xFF;
    b &= 0xFF;
    switch (op) {
        case 0:  r = a + b;         break;   /* ALU_ADD */
        case 1:  r = a - b;         break;   /* ALU_SUB */
        case 2:  r = a & b;         break;   /* ALU_AND */
        case 3:  r = a | b;         break;   /* ALU_OR  */
        case 4:  r = a ^ b;         break;   /* ALU_XOR */
        case 5:  r = (~a) & 0xFF;   break;   /* ALU_NOT */
        case 6:  r = a << 1;        break;   /* ALU_SHL */
        default: r = a >> 1;        break;   /* ALU_SHR */
    }
    return r & 0x1FF;
}

/* Output arguments arrive as pointers. */
void c_minmax(int a, int b, int* lo, int* hi)
{
    *lo = (a < b) ? a : b;
    *hi = (a < b) ? b : a;
}

/* A context function: it calls back into SystemVerilog. */
void c_greet(const char* name)
{
    char buf[128];
    snprintf(buf, sizeof(buf), "hello from C, %s", name);
    sv_log(buf);
}
```

```output
1. c_alu_model(ADD, 200, 100) = 300
2. c_alu_model(SUB, 5, 10)    = 507
3. lo = 7, hi = 42
[SV] hello from C, ALU testbench
```

**How to run it.** Both files are given to the simulator, which compiles the C file with its built-in or the system C compiler. The exact command differs per tool; typically the C file is simply listed with the SystemVerilog files (for example `vcs -sverilog tb_dpi.sv dpi_model.c`, `xrun tb_dpi.sv dpi_model.c`, or `vlog tb_dpi.sv dpi_model.c` followed by `vsim`). On EDA Playground, add the C file as an extra file and enable the tool's DPI option.

**Line by line: SystemVerilog**

| Code | Explanation |
|---|---|
| `import "DPI-C" pure function int c_alu_model(...)` | Declares the C function. It is `pure`: the result depends only on its three inputs. |
| `import "DPI-C" function void c_minmax(..., output int lo, output int hi);` | A function with two `output` arguments. It cannot be `pure`. |
| `import "DPI-C" context function void c_greet(input string name);` | `context` because the C code calls the exported function `sv_log`. |
| `export "DPI-C" function sv_log;` | Makes the SystemVerilog function below callable from C. The export names the function only. |
| `c_alu_model(0, 200, 100)` | Called exactly like a SystemVerilog function. 200 + 100 = 300. |
| `c_alu_model(1, 5, 10)` | 5 - 10 = -5; masked to 9 bits this is `1FB` = 507, the same value the DUT produces (M1). |
| `c_minmax(42, 7, lo, hi);` | The C function writes through the pointers; `lo` and `hi` receive 7 and 42. |
| `c_greet("ALU testbench");` | C builds a message and passes it back to SystemVerilog, which prints it. |

**Line by line: C**

| Code | Explanation |
|---|---|
| `#include "svdpi.h"` | The standard DPI header. Not strictly needed for `int` and `const char*`, but always included. |
| `extern void sv_log(const char* msg);` | The C declaration of the exported SystemVerilog function. `string` maps to `const char*`. |
| `int c_alu_model(int op, int a, int b)` | `input int` arguments arrive by value as C `int`. |
| `return r & 0x1FF;` | Keeps 9 bits so that the model matches the width of the DUT's `result`. |
| `void c_minmax(int a, int b, int* lo, int* hi)` | `output int` arguments arrive as `int*`. |
| `sv_log(buf);` | A call from C into SystemVerilog. This is why `c_greet` had to be imported as `context`. |

Using the model in the scoreboard is then one line: `exp = c_alu_model(int'(txn.op), txn.a, txn.b);`.

### DPI compared with PLI/VPI

| Property | DPI | PLI / VPI |
|---|---|---|
| Call style | A normal function call with typed arguments | C routine registered with the simulator and invoked as a `$user_task` |
| Argument passing | Directly, by the type mapping | Through API calls that fetch each argument |
| Access to the design hierarchy from C | No (only what is passed in or exported) | Yes: can walk the hierarchy, read and force any signal |
| Speed | High | Lower |
| Effort | Small | Large |
| Typical use | Reference models, algorithms, firmware co-simulation | Tools: debuggers, waveform dumpers, coverage tools |

> **Interview trap:** "Can an imported C function consume simulation time?" An imported **function** cannot, like any function. An imported **task** can, but only indirectly, by calling an exported SystemVerilog task that contains delays or event controls; it must be declared `context`.

> **Common mistake:** A mismatch between the import declaration and the C definition, for example `input int` on one side and `long` or `char` on the other, or an `output` argument that is not a pointer in C. There is no checking across the language boundary; the result is wrong values or a crash.

> **Common mistake:** Declaring a function `pure` when it prints, reads a file, uses a static variable or has an `output` argument. A simulator is allowed to remove or merge calls to a pure function.

> **Common mistake:** Using `"DPI"` instead of `"DPI-C"`. `"DPI"` is the obsolete 2005 form with a different, simulator-dependent argument-passing convention for packed types.

### Interview questions

**Q1. What is DPI?**
The Direct Programming Interface: a standard mechanism for calling C functions from SystemVerilog (import) and SystemVerilog functions and tasks from C (export), with arguments passed directly through a defined type mapping.

**Q2. What is the difference between DPI import and export?**
An import declares a function implemented in C so that SystemVerilog code can call it. An export makes a function or task implemented in SystemVerilog callable from C.

**Q3. What do `pure` and `context` mean?**
A `pure` imported function has no side effects and its result depends only on its inputs; it must return a value and have only input arguments. A `context` imported function or task needs the calling SystemVerilog scope, typically because it calls exported SystemVerilog functions or tasks or uses VPI.

**Q4. How do SystemVerilog types map to C?**
`byte` to `char`, `shortint` to `short`, `int` to `int`, `longint` to `long long`, `real` to `double`, `shortreal` to `float`, `string` to `const char*`, `chandle` to `void*`. Single `bit` and `logic` map to `svBit` and `svLogic`; packed vectors map to arrays of `svBitVecVal` or `svLogicVecVal`. Output and inout arguments become pointers.

**Q5. Why use DPI instead of PLI or VPI?**
It is far simpler and faster for calling functions: no registration, no API calls to fetch arguments. VPI is still needed when C code must explore or modify the design hierarchy.

**Q6. Give a use of DPI in a verification environment.**
Calling a C reference model from the scoreboard to compute expected results; reusing a C CRC routine; letting C firmware perform register accesses through exported bus-functional tasks.

