# Part 6: Module 11 Revision and Practice

## 6.1 Revision Summary

### Packages and scope

- A package is a named scope for shared declarations: types, parameters, functions, tasks, classes, variables. It is compiled once, exists once and is never instantiated.
- Not allowed in a package: module or interface definitions and instances, procedural blocks, continuous assignments, hierarchical references to the outside.
- Three ways to use an item: `pkg::name`, `import pkg::name;` (explicit), `import pkg::*;` (wildcard).
- An explicit import is a local declaration: it collides with a local name. A wildcard import only offers candidates: a local name wins, and two packages offering the same name are a problem only if the name is used.
- An explicit import of an enum type does not import its labels.
- Imports are not transitive; `export` passes names on.
- Put the import in the module header when ports need the types.
- `` `include `` pastes text; `import` gives visibility. A class file is included in exactly one package.
- `$unit` is the anonymous compilation-unit scope. Avoid declaring or importing there.
- `::` selects a name from a scope (package, class, `$unit`, `std`, `local`); `.` selects a member of an instance.

### Parameterized classes

- `class C #(type T = int, int N = 8);` Value parameters are constants; type parameters are types.
- Each distinct set of parameter values is a separate, unrelated class (a specialisation). No assignment or `$cast` between specialisations.
- Static members exist once per specialisation.
- `C` alone is the default specialisation in a declaration; with `::` write `C #()::member`.
- A common non-parameterized base class lets different specialisations share a handle type.
- A generic class may only use operations its type parameter supports. `==` on class handles compares handles; use `compare()` for objects.
- `mailbox #(T)` is the built-in parameterized class.
- A virtual interface to a parameterized interface carries the parameters: `virtual bus_if #(W) vif;`.

### Process control

| Tool | Stops or waits for |
|---|---|
| `wait fork` | All children of the calling process |
| `disable fork` | All children of the calling process, with descendants |
| `disable <name>` | Every activation of a named block or task |
| `p.kill()` | One process (with descendants) |
| `p.await()` | One process |
| `p.status()` | `FINISHED`, `RUNNING`, `WAITING`, `SUSPENDED`, `KILLED` |

- A task call does not create a process; `process::self()` in a task returns the caller's handle.
- After `join_none` the child has not started: `wait (p != null)` before using its handle.
- Isolating fork: `fork begin fork ... join_any disable fork; end join` limits `disable fork` to the threads inside.
- A `process` cannot be created with `new`.

### randcase, randsequence, DPI

- `randcase`: one branch chosen with probability weight / sum of weights. Weight 0 never; all zero takes no branch.
- `randsequence`: productions; `|` separates alternatives, `:=` gives a weight, `repeat (n)` repeats, `{ }` is a code block.
- DPI: `import "DPI-C" function ...` (SystemVerilog calls C), `export "DPI-C" function name;` (C calls SystemVerilog). `pure`: no side effects, no outputs, returns a value. `context`: calls back into SystemVerilog.
- Type mapping: `int`↔`int`, `byte`↔`char`, `shortint`↔`short`, `longint`↔`long long`, `real`↔`double`, `string`↔`const char*`, `chandle`↔`void*`; outputs are pointers.

### System tasks

| Remember | Detail |
|---|---|
| `$display` / `$strobe` / `$monitor` | Now / end of time step / on every change |
| `$error` / `$fatal(1, ...)` | Continue / terminate |
| `$finish` / `$stop` | End / pause |
| `$random` / `$urandom` / `$urandom_range(max, min)` | Signed legacy / unsigned stable / inclusive range |
| `$test$plusargs` / `$value$plusargs` | Prefix presence test / value extraction, returns found flag |
| `$fopen` returns 0 on failure | Always check, always `$fclose` |
| `$sformatf` | Returns a formatted string |
| `$clog2(n)` | Bits needed to address `n` items; `$clog2(1)` = 0 |
| `$onehot` / `$onehot0` | Exactly one / at most one bit set |
| `$dumpfile`, `$dumpvars(0, top)` | VCD waveforms of the whole hierarchy |

### UVM in ten lines

1. UVM is a SystemVerilog class library (`uvm_pkg`) plus macros; a methodology, not a language.
2. `uvm_component`: permanent structure with a parent and phases. `uvm_object`: transient data.
3. Phases: build (top-down), connect, end of elaboration, start of simulation, **run (task)**, extract, check, report, final.
4. Factory: create with `type_id::create()` so that a test can override the class.
5. `uvm_config_db #(T)::set/get`: central store, mostly for the virtual interface.
6. Sequence item = transaction; sequence = stimulus scenario; sequencer = router to the driver.
7. Driver: `get_next_item(req)`, drive, `item_done()`.
8. Monitor: sample, `ap.write(item)` to an analysis port (broadcast).
9. Agent = sequencer + driver + monitor; active or passive. Environment contains agents and scoreboard. Test selects sequences and configuration.
10. End of test by objections: `raise_objection` / `drop_objection`.

## 6.2 Interview Questions and Answers

The questions inside each section cover the direct definitions. These are additional.

### Basic level

**Q1. What is the purpose of a package?**
To hold declarations that several design or testbench units share, in one named scope, so that they are written once and name clashes are avoided.

**Q2. Write the three ways to use the type `alu_op_e` from `alu_pkg` in a module.**
`alu_pkg::alu_op_e op;` or `import alu_pkg::alu_op_e;` then `alu_op_e op;` or `import alu_pkg::*;` then `alu_op_e op;`.

**Q3. Can a package contain a class? A module? An `always` block?**
A class yes. A module no. An `always` block no.

**Q4. What does `#(type T = int)` mean in a class declaration?**
The class has a type parameter named `T`, with `int` as the default. Inside the class `T` is used as a data type, and each use of the class can supply a different type.

**Q5. What is `mailbox #(alu_txn)`?**
The built-in mailbox class specialised so that it carries only `alu_txn` handles, with compile-time type checking.

**Q6. What does `process::self()` return?**
A handle to the process that is currently executing the call.

**Q7. What does `disable fork` do?**
Kills all child processes of the calling process, and their descendants.

**Q8. What is the difference between `$display` and `$strobe`?**
`$display` prints immediately with the values at that instant. `$strobe` prints at the end of the current time step, after all assignments (including nonblocking ones) of that time step have taken effect.

**Q9. What is `$urandom_range(15, 4)`?**
A random unsigned integer between 4 and 15 inclusive.

**Q10. What is DPI used for?**
Calling C code from SystemVerilog and SystemVerilog from C, typically to reuse C reference models and algorithms.

**Q11. What does UVM stand for and what is it?**
Universal Verification Methodology: a standard SystemVerilog class library and methodology for building reusable testbenches.

**Q12. Name the UVM components that correspond to a generator and a mailbox in a layered testbench.**
A sequence (the generator's role) and a sequencer with the driver's `seq_item_port` (the mailbox's role).

### Intermediate level

**Q13. A module imports two packages with `::*`, and both define `MAX`. When does the compiler complain?**
Only when `MAX` is referenced without a package prefix. The unused collision is legal. Use `pkg_a::MAX`.

**Q14. Why should classes be put in a package instead of being compiled as loose files?**
Loose class declarations go into the compilation-unit scope, whose extent depends on the tool's compile mode, so visibility is not portable. In a package the classes have a fixed scope, are compiled once, and are visible exactly where the package is imported.

**Q15. A function in a package is used from RTL. Why should it be `automatic`?**
A static function has one shared copy of its arguments and local variables. If it is called from several places concurrently they interfere, and synthesis tools require automatic functions so that each call is independent logic.

**Q16. What is the difference between a parameterized class and inheritance?**
A parameterized class generates several independent classes from one template, differing in types or constants fixed at compile time. Inheritance creates a related class that extends or overrides behaviour, and allows a base handle to refer to a derived object at run time.

**Q17. How do you declare a queue that can hold `typed_item #(int)` and `typed_item #(string)` objects together?**
Make `typed_item` extend a non-parameterized base class, and declare the queue with the base type: `item_base q [$];`.

**Q18. What is the difference between `fork`...`join_any` followed by `disable fork`, and using a `process` handle?**
`disable fork` kills every child of the current process, which is simple but coarse and needs an isolating fork to be safe. A process handle refers to one thread, so that thread alone can be killed or awaited, and its status can be queried.

**Q19. What states can `status()` return, and which will a parent usually see for a child that is waiting on a mailbox `get`?**
`FINISHED`, `RUNNING`, `WAITING`, `SUSPENDED`, `KILLED`. A child blocked on a mailbox is `WAITING`.

**Q20. What is the difference between `randcase` and `if (($urandom % 10) < 6) ... else ...`?**
They can produce the same distribution, but `randcase` states the weights directly, scales to many branches, and lets the weights be expressions. The hand-written form is error-prone as branches are added.

**Q21. In a DPI import, how does an `output int` argument appear in the C function?**
As a pointer, `int*`. The C function writes the result through it.

**Q22. What is the difference between `$value$plusargs("N=%d", n)` returning 0 and returning 1?**
0: no plusarg starting with `N=` was given, and `n` is unchanged. 1: it was found and `n` holds the converted value.

**Q23. Why is the virtual interface passed through `uvm_config_db` and not through a constructor in UVM?**
Components are created by the factory with a fixed constructor signature `(name, parent)`, so extra constructor arguments are not possible. The configuration database also removes the need for every hierarchical level to pass the handle on.

**Q24. What is the difference between `uvm_object_utils` and `uvm_component_utils`?**
Both register a class with the factory. `uvm_object_utils` is for classes derived from `uvm_object` (constructor with a name only); `uvm_component_utils` is for classes derived from `uvm_component` (constructor with name and parent).

### Advanced and scenario-based

**Q25. Two teams deliver packages that both `` `include "common_txn.sv" ``. Your environment imports both and gets "type mismatch" when connecting them. Explain and fix.**
The class was compiled into two packages, producing two unrelated classes with the same name. A handle of one cannot be passed where the other is expected. The class must be compiled in one package only (a shared package), which both teams import.

**Q26. A timeout task containing `fork ... join_any  disable fork;` works in a unit test, but in the full testbench the monitor stops working after the first timeout. Why?**
The task runs in the caller's process. That process had earlier started the monitor with `join_none`, so the monitor is also its child, and `disable fork` killed it. Wrap the race in an isolating `fork begin ... end join`.

**Q27. A test hangs. How would you find out which threads are still running?**
If the threads registered their `process` handles, print each handle's `status()` from a watchdog before calling `$fatal`: threads that are `WAITING` are the suspects. Otherwise use the simulator's thread view, or add a watchdog and progressively narrow down with messages. Typical causes are a `get` on a mailbox that nobody fills, an event triggered before the `@` started waiting, and `wait fork` with a never-ending child.

**Q28. Why does `uvm_driver` have a type parameter?**
So that the `req` handle and the `seq_item_port` are typed with the user's transaction class. The driver code then accesses `req.a` directly, and connecting it to a sequencer of a different item type is a compile error. It is the same reason `mailbox #(alu_txn)` is preferred over a typeless mailbox.

**Q29. The generic scoreboard works for `int` but reports every transaction object as a mismatch. Why?**
It compares with `==`. For class handles that compares identity, and the expected and actual transactions are different objects. Call the transaction's `compare()` method, or write the scoreboard against a base class that declares `compare` as a virtual method.

**Q30. You must check an ALU against an existing C model. Outline the solution.**
Import the C function with DPI: `import "DPI-C" pure function int c_alu_model(input int op, input int a, input int b);`. In the scoreboard, call it with the fields of each observed transaction, mask the result to 9 bits, and compare with `!==` against the DUT result. Compile the C file together with the testbench.

**Q31. A regression must run the same compiled testbench with different numbers of transactions and different tests. How?**
Use plusargs. Read `+NUM_TXN=` with `$value$plusargs` into a variable that has a default, and select the test by a `+TEST=` string (in UVM, `+UVM_TESTNAME=`). Set the random seed with the simulator's seed option.

**Q32. Why must the parent wait before using a process handle set inside `fork ... join_none`?**
A thread created by `join_none` is only scheduled; it starts executing when the parent blocks or finishes. Until then the assignment `p = process::self()` has not happened and `p` is `null`.

**Q33. What would break if `run_phase` were a function?**
A function cannot contain timing controls, so a driver could not wait for clock edges and a monitor could not sample over time. `run_phase` is the one phase that must consume simulation time, so it is a task; the library forks one process per component for it.

**Q34. Explain, in terms of language features only, what happens in `drv = alu_uvm_driver::type_id::create("drv", this);`.**
`alu_uvm_driver::type_id` is a type declared inside the class by the registration macro. `create` is its static method. It asks the factory singleton for an object of the registered type, or of an overriding derived type, constructs it with `new(name, parent)`, and returns a base-type handle that is cast with `$cast` to the requested type and assigned to `drv`.

## 6.3 Output-Prediction Questions

Work each one out on paper first.

**P1.**

```systemverilog
package cnt_pkg;
  int hits = 0;
  function automatic void hit();
    hits++;
  endfunction
endpackage

module m_a;
  initial begin
    #1 cnt_pkg::hit();
       cnt_pkg::hit();
  end
endmodule

module m_b;
  import cnt_pkg::*;
  initial begin
    #2 hit();
       $display("%0d", hits);
  end
endmodule

module p1;
  m_a u_a ();
  m_b u_b ();
endmodule
```

Answer: `3`. There is one `hits` in the simulation. Module `m_a` increments it twice at time 1 and `m_b` once at time 2.

**P2.**

```systemverilog
package p_pkg;
  int v = 5;
  int w = 6;
endpackage

module p2;
  import p_pkg::*;
  int v = 50;
  initial $display("%0d %0d %0d", v, w, p_pkg::v);
endmodule
```

Answer: `50 6 5`. The local `v` takes precedence over the wildcard candidate. `w` comes from the package. The prefix still reaches the package's `v`.

**P3.**

```systemverilog
class cnt #(type T = int);
  static int n;
  function new();
    n++;
  endfunction
endclass

module p3;
  cnt #(int) a, b;
  cnt #(bit) c;
  cnt        d;
  initial begin
    a = new();  b = new();  c = new();  d = new();
    $display("%0d %0d", cnt #(int)::n, cnt #(bit)::n);
  end
endmodule
```

Answer: `3 1`. `cnt` without parameters is the default specialisation `cnt #(int)`, so `a`, `b` and `d` share one counter. `cnt #(bit)` has its own.

**P4.**

```systemverilog
module p4;
  process p_init, p_task, p_fork;

  task automatic grab();
    p_task = process::self();
  endtask

  initial begin
    p_init = process::self();
    grab();
    fork
      p_fork = process::self();
    join
    $display("%b %b", p_task == p_init, p_fork == p_init);
  end
endmodule
```

Answer: `1 0`. A task runs in its caller's process, so `p_task` is the `initial` process. A `fork` branch is a new process.

**P5.**

```systemverilog
module p5;
  initial begin
    fork
      #50 $display("A");
    join_none

    fork
      #10 $display("B");
      #20 $display("C");
    join_any
    disable fork;

    #100 $display("D");
  end
endmodule
```

Answer: `B` then `D`. `join_any` returns at time 10. `disable fork` kills **all** children of the `initial` process: the `C` thread and also the `A` thread from the earlier fork.

**P6.**

```systemverilog
module p6;
  int x;
  initial begin
    x = 1;
    x <= 5;
    $strobe ("S %0d", x);
    $display("D %0d", x);
    x = 2;
    #1 $display("E %0d", x);
  end
endmodule
```

Answer:

```output
D 1
S 5
E 5
```

`$display` prints at once: 1. The blocking `x = 2` then executes, and at the end of the time step the nonblocking assignment sets `x` to 5 (its right-hand side was evaluated when the statement executed). `$strobe` prints after that: 5.

**P7.**

```systemverilog
module p7;
  initial $display("%0d %0d %0d %b %b",
                   $clog2(5), $clog2(16), $clog2(17), $onehot(4'b0000), $onehot0(4'b0000));
endmodule
```

Answer: `3 4 5 0 1`. Five items need 3 address bits, 16 need 4, 17 need 5. All zeros is not one-hot, but it satisfies "at most one bit set".

**P8.**

```systemverilog
module p8;
  initial begin
    for (int i = 0; i < 3; i++) begin : outer
      for (int j = 0; j < 3; j++) begin
        if (j == 1) disable outer;
        $display("%0d%0d", i, j);
      end
    end
    $display("end");
  end
endmodule
```

Answer: `00`, `10`, `20`, `end`. `outer` names the **body** of the outer loop. Disabling it abandons the rest of that iteration (including the inner loop) and the outer `for` continues with the next `i`.

**P9.**

```systemverilog
module p9;
  int n = 7;
  initial begin
    if ($value$plusargs("N=%d", n)) $display("given %0d", n);
    else                            $display("default %0d", n);
  end
endmodule
```

Answer: with no plusarg, `default 7`. With `+N=12` on the command line, `given 12`. When the plusarg is absent the function returns 0 and does not modify the variable.

**P10.**

```systemverilog
module p10;
  process        p;
  process::state s;
  initial begin
    fork
      begin
        p = process::self();
        #10;
      end
    join_none
    #1  s = p.status();  $display("%s", s.name());
    #20 s = p.status();  $display("%s", s.name());
  end
endmodule
```

Answer: `WAITING` then `FINISHED`. At time 1 the child is blocked in its delay. At time 21 it has run to completion. (The handle is valid at time 1 because the child started when the parent blocked on `#1`.)

## 6.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
package bad_pkg;
  logic clk;
  initial clk = 0;
  always #5 clk = ~clk;
endpackage
```

Procedural blocks are not allowed in a package. Generate the clock in a module or interface.

**E2.**

```systemverilog
module m;
  import alu_pkg::alu_op_e;
  alu_op_e op;
  initial op = ALU_SUB;
endmodule
```

The explicit import brings in the type name only. `ALU_SUB` is not visible. Write `alu_pkg::ALU_SUB`, import the label too, or use `import alu_pkg::*;`.

**E3.**

```systemverilog
package a_pkg;  int size = 4;   endpackage
package b_pkg;  int size = 8;   endpackage

module m;
  import a_pkg::*;
  import b_pkg::*;
  initial $display("%0d", size);
endmodule
```

`size` is offered by two wildcard imports and is used without a prefix: ambiguous. Write `a_pkg::size` or `b_pkg::size`.

**E4.**

```systemverilog
module m;
  int count;
  import cfg_pkg::count;
endmodule
```

An explicit import declares `count` in the module scope, where `count` already exists. Either remove the local declaration, use a wildcard import (the local name then wins), or refer to `cfg_pkg::count`.

**E5.**

```systemverilog
module dut (input alu_op_e op);
  import alu_pkg::*;
endmodule
```

The import is in the body, after the port list has already used the type. Move it into the header: `module dut import alu_pkg::*; (input alu_op_e op);`.

**E6.**

```systemverilog
class stack #(type T = int);
  static int instances;
endclass

module m;
  initial $display("%0d", stack::instances);
endmodule
```

A parameterized class name cannot be used unadorned with `::` outside the class. Write `stack #()::instances` or `stack #(int)::instances`.

**E7.**

```systemverilog
stack #(int)    s_int = new();
stack #(string) s_str;
initial s_str = s_int;
```

Different specialisations are different, unrelated types. The assignment is illegal, and `$cast` would fail too.

**E8.**

```systemverilog
process p = new();
```

A process object cannot be constructed. Obtain a handle with `process::self()` from inside the process.

**E9.**

```systemverilog
import "DPI-C" pure function void c_fill(output int value);
```

A `pure` function must return a value and may not have `output` or `inout` arguments. Remove `pure`, or return the value as the function result.

**E10.**

```systemverilog
package tb_pkg;
  function automatic void wait_clk();
    @(posedge tb_top.clk);
  endfunction
endpackage
```

Two errors. A package may not contain a hierarchical reference to something outside it (`tb_top.clk`), and a function may not contain a timing control. Use a task that receives a virtual interface as an argument.

### Run-time bugs (the code compiles)

**D1.**

```systemverilog
process p;
initial begin
  fork
    begin  p = process::self();  forever #10;  end
  join_none
  p.kill();
end
```

Null handle error. The child has not started when `p.kill()` executes. Insert `wait (p != null);` before using the handle.

**D2.**

```systemverilog
task run();
  fork  mon.run();  join_none
  repeat (10) begin
    fork
      drv.send();
      #1000;
    join_any
    disable fork;
  end
endtask
```

The first `disable fork` also kills `mon.run()`, because it is a child of the same process. Wrap the race in `fork begin ... end join`.

**D3.**

```systemverilog
if ($test$plusargs("TEST")) run_special_test();
```

Run with `+TESTNAME=smoke`, the special test executes unexpectedly: `$test$plusargs` matches any plusarg that **starts with** the string. Use a more specific string or `$value$plusargs`.

**D4.**

```systemverilog
int idx;
initial idx = $random % 16;      // used as mem[idx]
```

`$random` is signed, so `idx` can be anywhere from -15 to 15. Use `$urandom_range(15)`.

**D5.**

```systemverilog
int fd;
initial begin
  fd = $fopen("/no/such/dir/log.txt", "w");
  $fdisplay(fd, "start of test");
end
```

The open fails and returns 0; the write is silently lost. Check `if (fd == 0) $fatal(1, ...)`, and close the file at the end.

**D6.**

```systemverilog
int w_rd = 0, w_wr = 0;
initial repeat (100)
  randcase
    w_rd : do_read();
    w_wr : do_write();
  endcase
```

Both weights are 0, so no branch is ever taken: the loop does nothing, possibly with a warning. Initialise the weights to non-zero values.

**D7.**

```systemverilog
int seed;
initial begin
  $value$plusargs("SEED=%d", seed);
  $display("using seed %0d", seed);
end
```

When `+SEED=` is not given, `seed` stays at its default 0 and the log misleadingly reports a seed. Check the return value and handle the missing case (and note that a return value ignored in this way also draws a compiler warning; use `void'(...)` if it is intended).

**D8.**

```systemverilog
class port_driver;
  task run();
    forever begin : drive_one
      get_item();
      if (abort) disable drive_one;
      drive_item();
    end
  endtask
endclass
```

Four `port_driver` objects run this method in parallel. `disable drive_one` in one object terminates the block in **all** of them, since `disable` works on the name. Use `continue` here: `if (abort) continue;`.

**D9.**

```systemverilog
// in tb_top
initial begin
  run_test("alu_base_test");
  uvm_config_db #(virtual alu_if)::set(null, "*", "vif", alu_vif);
end
```

`run_test()` starts the phases and does not return until the test is over, so the `set` happens too late (in practice never). The driver's `get` fails in `build_phase` and reports the missing interface. Call `set` before `run_test()`.

**D10.**

```systemverilog
task run_phase(uvm_phase phase);
  alu_sequence seq = alu_sequence::type_id::create("seq");
  seq.start(env.agent.sqr);
endtask
```

No objection is raised, so the run phase ends at time 0 and the sequence is killed before it sends anything. Add `phase.raise_objection(this);` before and `phase.drop_objection(this);` after.

## 6.5 Coding Exercises with Solutions

### Exercise 1: a design package

Write a package `bus_pkg` containing address and data width parameters, a direction enum, a packed struct for a bus request, a function that builds a request (data defaulting to zero) and a function that returns its parity. Use it from a module.

```systemverilog file=ex01_bus_pkg.sv
package bus_pkg;

  parameter int ADDR_W = 8;
  parameter int DATA_W = 16;

  typedef enum bit {BUS_READ, BUS_WRITE} bus_dir_e;

  typedef struct packed {
    bus_dir_e          dir;
    logic [ADDR_W-1:0] addr;
    logic [DATA_W-1:0] data;
  } bus_req_t;

  function automatic bus_req_t make_req(bus_dir_e          dir,
                                        logic [ADDR_W-1:0] addr,
                                        logic [DATA_W-1:0] data = '0);
    bus_req_t r;
    r.dir  = dir;
    r.addr = addr;
    r.data = data;
    return r;
  endfunction

  function automatic bit parity(bus_req_t r);
    return ^r;
  endfunction

endpackage : bus_pkg

module ex01_bus_pkg;
  import bus_pkg::*;

  bus_req_t req;

  initial begin
    req = make_req(BUS_WRITE, 8'h3C, 16'hBEEF);
    $display("dir=%s addr=%h data=%h bits=%0d",
             req.dir.name(), req.addr, req.data, $bits(req));
    $display("raw=%h parity=%b", req, parity(req));

    req = make_req(BUS_READ, 8'h10);
    $display("dir=%s addr=%h data=%h", req.dir.name(), req.addr, req.data);
  end
endmodule
```

```output
dir=BUS_WRITE addr=3c data=beef bits=25
raw=13cbeef parity=0
dir=BUS_READ addr=10 data=0000
```

The struct is 1 + 8 + 16 = 25 bits. As a vector it is `1_0011_1100_1011_1110_1110_1111`, printed in hexadecimal as `13cbeef`. It contains 18 ones (1 in `dir`, 4 in `3C`, 13 in `BEEF`), an even number, so the reduction XOR is 0. The second call omits `data`, which takes its default.

### Exercise 2: a generic statistics class

Write a parameterized class with static functions that return the maximum and the minimum of a queue of any numeric type. Use it with `int` and with `real`.

```systemverilog file=ex02_generic_stats.sv
class stats #(type T = int);

  static function T max_of(T q [$]);
    T m = q[0];
    foreach (q[i]) if (q[i] > m) m = q[i];
    return m;
  endfunction

  static function T min_of(T q [$]);
    T m = q[0];
    foreach (q[i]) if (q[i] < m) m = q[i];
    return m;
  endfunction

endclass

module ex02_generic_stats;

  int  iq [$] = '{3, 9, -2, 7};
  real rq [$] = '{1.5, 0.25, 7.75};

  initial begin
    $display("int : max=%0d min=%0d", stats #(int)::max_of(iq), stats #(int)::min_of(iq));
    $display("real: max=%0.2f min=%0.2f",
             stats #(real)::max_of(rq), stats #(real)::min_of(rq));
  end

endmodule
```

```output
int : max=9 min=-2
real: max=7.75 min=0.25
```

No object is created: the functions are static and are called through the specialisation name. The class would not compile for a type without `<` and `>`, such as a class handle.

### Exercise 3: a task with a timeout, using a process handle

Write `run_with_timeout(duration, limit, timed_out)`: start a piece of work that takes `duration` time units; if it has not finished after `limit` time units, kill it and report a timeout.

```systemverilog file=ex03_timeout.sv
module ex03_timeout;

  task automatic do_work(int duration);
    #duration;
  endtask

  task automatic run_with_timeout(int duration, int limit, output bit timed_out);
    process p_work;

    fork                                   // start the work as its own process
      begin
        p_work = process::self();
        do_work(duration);
      end
    join_none
    wait (p_work != null);

    fork                                   // isolating fork around the race
      begin
        fork
          p_work.await();
          #limit;
        join_any
        disable fork;
      end
    join

    timed_out = (p_work.status() != process::FINISHED);
    if (timed_out) p_work.kill();
  endtask

  bit expired;

  initial begin
    run_with_timeout(30, 50, expired);
    $display("[%0t] work=30 limit=50 : timed_out=%b", $time, expired);

    run_with_timeout(80, 50, expired);
    $display("[%0t] work=80 limit=50 : timed_out=%b", $time, expired);

    #100 $display("[%0t] end", $time);
  end

endmodule
```

```output
[30] work=30 limit=50 : timed_out=0
[80] work=80 limit=50 : timed_out=1
[180] end
```

First call: the work ends at time 30, `await()` returns, `join_any` completes, `disable fork` removes the timer, and the status is `FINISHED`. Second call (starting at 30): the timer expires at 80 while the work is still `WAITING`, so a timeout is reported and the work process is killed. The isolating fork guarantees that `disable fork` touches only the awaiting thread and the timer; the work itself is stopped explicitly through its handle.

### Exercise 4: a weighted stimulus mix with a self-check

Use `randcase` to choose among three kinds of operation with weights 8, 1 and 1 for 2000 iterations. Check that exactly one branch executed each time and that the heavily weighted branch dominates.

```systemverilog file=ex04_randcase_mix.sv
module ex04_randcase_mix;

  int n_add, n_sub, n_shift;

  initial begin
    repeat (2000) begin
      randcase
        8 : n_add++;
        1 : n_sub++;
        1 : n_shift++;
      endcase
    end

    $display("add=%0d sub=%0d shift=%0d", n_add, n_sub, n_shift);

    if (n_add + n_sub + n_shift != 2000)        $display("FAIL: total is wrong");
    else if (n_add < n_sub || n_add < n_shift)  $display("FAIL: weights not respected");
    else                                        $display("PASS");
  end

endmodule
```

```output
add=1611 sub=197 shift=192
PASS
```

**Sample output; the three counts differ per seed and simulator.** The total is always 2000, and with weights 8:1:1 the first count is about 1600, so the check prints `PASS`.

### Exercise 5: several specialisations in one queue

Store objects of `typed_item #(int)`, `typed_item #(byte)` and `typed_item #(bit [11:0])` in a single queue and print a description of each.

```systemverilog file=ex05_common_base.sv
virtual class item_base;
  pure virtual function string describe();
endclass

class typed_item #(type T = int) extends item_base;
  T value;

  function new(T value);
    this.value = value;
  endfunction

  virtual function string describe();
    return $sformatf("%0d-bit item with value %0d", $bits(value), value);
  endfunction
endclass

module ex05_common_base;

  item_base                q [$];
  typed_item #(int)        i_item;
  typed_item #(byte)       b_item;
  typed_item #(bit [11:0]) v_item;

  initial begin
    i_item = new(100);
    b_item = new(-5);
    v_item = new(12'hABC);

    q.push_back(i_item);        // derived handle stored in a base-class queue (upcast)
    q.push_back(b_item);
    q.push_back(v_item);

    foreach (q[k]) $display("%0d: %s", k, q[k].describe());
  end

endmodule
```

```output
0: 32-bit item with value 100
1: 8-bit item with value -5
2: 12-bit item with value 2748
```

The three specialisations are unrelated to each other, but each extends the non-parameterized `item_base`. The queue is declared with the base type, and the virtual method `describe` reaches the right specialisation at run time. `12'hABC` is 2748 in decimal and prints as a positive number because `bit [11:0]` is unsigned.

### Exercise 6: write and load a memory image

Create a hexadecimal memory file from the testbench, load it into an 8-entry memory with `$readmemh`, and print the memory.

```systemverilog file=ex06_readmem.sv
module ex06_readmem;

  logic [7:0] mem [0:7];
  int         fd;

  initial begin
    fd = $fopen("mem_init.hex", "w");
    if (fd == 0) $fatal(1, "cannot create mem_init.hex");
    $fdisplay(fd, "// test image");
    $fdisplay(fd, "@0");
    $fdisplay(fd, "de ad be ef");
    $fdisplay(fd, "@6");
    $fdisplay(fd, "55 aa");
    $fclose(fd);

    $readmemh("mem_init.hex", mem);
    foreach (mem[i]) $display("mem[%0d] = %h", i, mem[i]);
  end

endmodule
```

```output
mem[0] = de
mem[1] = ad
mem[2] = be
mem[3] = ef
mem[4] = xx
mem[5] = xx
mem[6] = 55
mem[7] = aa
```

`@0` and `@6` set the load address. Locations 4 and 5 are not mentioned in the file, so they keep the default value of `logic`, X. (Some simulators print a warning that not every location was initialised.)

### Further practice (no solutions given)

1. Split the M9 testbench into `alu_pkg`, `alu_tb_pkg` (with one `` `include `` per class file) and `tb_top`. Write the compile order.
2. Write a generic class `pair #(type A = int, type B = string)` with a constructor and a `swap_into(output pair #(B, A) p)` method. Why is the type of the result a different specialisation?
3. Rewrite `inorder_scoreboard` as an out-of-order scoreboard using an associative array keyed by `id`.
4. Start five threads in a loop, each with a random delay from `$urandom_range(10, 50)`. Using process handles, print which thread finished first and kill the others.
5. Write a `randsequence` that generates: one `CONFIG`, then between 2 and 5 transfers (each `WRITE` twice as likely as `READ`), then one `DISABLE`.
6. Write a C function `c_crc8(const char* s)` and call it through DPI for three strings. Declare it `pure`. Explain why that is legitimate.
7. Add `+TIMEOUT=<cycles>` to the M9 testbench: read it with `$value$plusargs`, default 10000, and end the test with `$fatal` when it expires.
8. For each class in the UVM skeleton of Section 5.8, write one sentence naming the M9 class it corresponds to and one difference.

## 6.6 Concepts You Must Understand Before Moving Forward

**Packages and scope**

- [ ] I can list what a package may and may not contain, and say why.
- [ ] I can explain explicit import, wildcard import and `pkg::name`, and the collision rules of each.
- [ ] I can explain why an explicit import of an enum type does not give me its labels.
- [ ] I can explain `` `include `` versus `import`, and why a class file belongs in exactly one package.
- [ ] I can list at least six uses of `::` and distinguish it from `.`.

**Generic code**

- [ ] I can write a parameterized class with a type parameter and a value parameter.
- [ ] I can explain why specialisations are unrelated types and how static members behave.
- [ ] I can explain when a generic class should use `==` and when `compare()`.
- [ ] I can declare a virtual interface to a parameterized interface.
- [ ] I can state the default clocking-block skews and what they prevent.

**Process control**

- [ ] I can say what creates a process and what does not.
- [ ] I can explain the `disable fork` trap and write the isolating fork from memory.
- [ ] I can obtain a process handle correctly and name the five states.
- [ ] I can choose between `disable fork`, `disable <label>` and `kill()`.
- [ ] I can write a timeout around a blocking operation.

**randcase, randsequence, DPI, system tasks**

- [ ] I can compute branch probabilities of a `randcase` and say what happens with zero weights.
- [ ] I can read a small `randsequence`.
- [ ] I can write a DPI import with input and output arguments and the matching C prototype, and explain `pure` and `context`.
- [ ] I can explain `$display`/`$strobe`/`$monitor`, `$error`/`$fatal`, `$random`/`$urandom`, the two plusargs functions, `$readmemh`, `$fopen`, `$sformatf`, `$clog2`, `$onehot`/`$onehot0`.

**UVM**

- [ ] I can say what UVM is in two sentences.
- [ ] I can map every M9 component to its UVM counterpart.
- [ ] I can explain `uvm_object` versus `uvm_component`, the phases, the factory, `uvm_config_db`, analysis ports and objections at the level of "what problem does it solve".
- [ ] For each of those, I can name the SystemVerilog feature it is built on.

## 6.7 What Comes Next

This was the last teaching module. The final part of the course is the **interview preparation section**: more than 150 questions with answers covering all eleven modules, grouped as basic, intermediate and advanced, and including output-prediction, code-debugging, find-the-error, write-the-code, constraint-writing, OOP, IPC, layered-testbench and scenario-based questions, with coding exercises and solutions. Use the checklists at the end of each module to decide which areas to revise before attempting it.
