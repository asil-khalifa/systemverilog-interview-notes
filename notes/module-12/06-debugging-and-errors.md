# Code-Debugging Questions

Every fragment in this part compiles. It misbehaves at run time: a crash, a hang, wrong data, or a test that passes when it should not. For each one, find the bug, explain the mechanism, and give the fix. In an interview, say what symptom you would see first; that shows you have debugged real testbenches.

**Q171. The simulation stops with a "null object access" error in the driver.**

```systemverilog
class alu_driver;
  mailbox #(alu_txn) gen2drv_mbx;
  virtual alu_if     vif;

  task run();
    alu_txn txn;
    forever begin
      gen2drv_mbx.get(txn);
      @(vif.drv_cb);
      vif.drv_cb.a <= txn.a;
    end
  endtask
endclass
```

Answer: Nothing ever assigns `gen2drv_mbx` or `vif`. Both are handles whose default value is `null`, so the first `gen2drv_mbx.get()` dereferences a null handle. Declaring a mailbox variable does not create a mailbox. Fix: give the driver a constructor that receives both handles from the environment, `function new(mailbox #(alu_txn) mbx, virtual alu_if vif);`, and make the environment construct the mailbox with `new()` and pass the same handle to the generator and the driver. Note that `txn` being null before the `get` is fine: `get` assigns it.

**Q172. The generator sends ten transactions, but the driver drives the same values ten times.**

```systemverilog
task run();
  alu_txn txn = new();
  repeat (10) begin
    if (!txn.randomize()) $fatal(1, "randomize failed");
    gen2drv_mbx.put(txn);
  end
  -> gen_done;
endtask
```

Answer: Only one object is created. `put(txn)` stores the handle, not a copy, so the mailbox holds ten handles to the same object. The loop does not block (unbounded mailbox), so all ten randomizations happen before the driver runs, and the driver sees the last values ten times. Fix: construct a new object for every transaction, `txn = new();` inside the loop, or put a copy, `gen2drv_mbx.put(txn.copy());`. The second form is used when a "blueprint" object is kept so that a test can replace it with an extended class.

**Q173. The generator reports that it put transactions, but the driver waits forever.**

```systemverilog
class alu_generator;
  mailbox #(alu_txn) gen2drv_mbx = new();
  // ...
endclass

class alu_driver;
  mailbox #(alu_txn) gen2drv_mbx = new();
  // ...
endclass
```

Answer: Each class constructs its own mailbox. The two variables have the same name but refer to two different mailbox objects, so the items the generator puts never reach the driver, which blocks on `get()` of an empty mailbox. Fix: construct one mailbox in the environment and pass that single handle to both components.

**Q174. The scoreboard sometimes never sees the end-of-test event.**

```systemverilog
// generator                      // test
task run();                       task run_test();
  // ... put all transactions       fork
  -> gen_done;                        gen.run();
endtask                             join_none
                                    @(gen.gen_done);
                                    $display("generator finished");
                                  endtask
```

Answer: If the generator needs no simulation time (it only fills an unbounded mailbox), it triggers `gen_done` in the same time step in which the test reaches `@(gen.gen_done)`. Which happens first depends on scheduling: with `join_none` the parent normally continues first and reaches the `@`, but any reordering (a `#0`, calling `gen.run()` from another thread) makes the trigger come first, and then `@` waits forever for a trigger that has already happened. Fix: `wait (gen.gen_done.triggered);`, which is true for the rest of the time step in which the event fired, or trigger with the nonblocking `->> gen_done;`.

**Q175. After the first timeout check, the monitor stops collecting transactions.**

```systemverilog
task run();
  fork
    mon.run();                    // runs forever
  join_none

  forever begin
    fork
      wait_for_valid_out();
      #1000 $error("timeout waiting for valid_out");
    join_any
    disable fork;
  end
endtask
```

Answer: `disable fork` kills all threads spawned by the calling process, and `mon.run()` was spawned by this same process, so it is killed together with the losing branch of the timeout. Fix: isolate the timeout in its own process so that it has no other children:

```systemverilog
forever begin
  fork
    begin
      fork
        wait_for_valid_out();
        #1000 $error("timeout waiting for valid_out");
      join_any
      disable fork;
    end
  join
end
```

**Q176. The checksum computed by the testbench differs from the DUT's whenever a payload byte is 0x80 or more.**

```systemverilog
byte payload [];
int  checksum;

function void calc();
  checksum = 0;
  foreach (payload[i]) checksum += payload[i];
endfunction
```

Answer: `byte` is signed. A value such as `8'h90` is -112, and it is sign-extended when added to the 32-bit `checksum`, so the sum decreases instead of increasing by 144. Fix: declare the payload as `bit [7:0] payload [];` (or `byte unsigned`). A mismatch that appears only when the top bit of a value is set almost always points to signedness.

**Q177. The DUT output is X for the whole test, yet the test reports zero errors.**

```systemverilog
function bit compare(alu_txn exp);
  if (this.result != exp.result) begin
    $error("result mismatch: got %0h, expected %0h", result, exp.result);
    return 0;
  end
  return 1;
endfunction
```

Answer: With `result` equal to X, `!=` evaluates to X, the `if` treats X as false, and the function returns 1 ("match"). Fix: use the case inequality operator, `if (this.result !== exp.result)`, which treats X as a value that differs from every known value. Also make sure `result` is declared `logic [8:0]` in the transaction; if it were `bit`, the X would already have become 0 in the monitor.

**Q178. The simulation hangs at time 0. Nothing is driven.**

```systemverilog
// environment:  gen2drv_mbx = new(1);

// generator                           // driver
task run();                            task run();
  repeat (10) begin                      alu_txn txn;
    txn = new();                         @(start_drv);
    void'(txn.randomize());              forever begin
    gen2drv_mbx.put(txn);                  gen2drv_mbx.get(txn);
  end                                      drive(txn);
  -> start_drv;                          end
endtask                                endtask
```

Answer: A deadlock. The mailbox is bounded to one item. The generator's second `put()` blocks until the driver takes the first item. The driver is waiting for `start_drv`, which the generator triggers only after all ten puts. Each is waiting for the other. Fix: remove the start event (the mailbox already synchronises them), or make the mailbox unbounded. In general, draw the "who waits for whom" graph; a cycle is a deadlock.

**Q179. Two threads call the same task with different IDs; both messages show the same ID.**

```systemverilog
module tb;
  task send(input int id, input int dly);
    #dly;
    $display("[%0t] sent id %0d", $time, id);
  endtask

  initial fork
    send(1, 10);
    send(2, 20);
  join
endmodule
```

Answer: A task in a module is static by default: there is one copy of `id` and `dly`. Whichever call starts second overwrites `id` while the first is suspended at its delay. Each call has already evaluated its own delay, so the messages still appear at times 10 and 20, but both show the same `id` (2 if the first branch of the fork starts first, which is the usual case). Fix: `task automatic send(...)`.

**Q180. The DUT sometimes captures stimulus one cycle early, depending on the simulator.**

```systemverilog
task drive(alu_txn txn);
  @(posedge vif.clk);
  vif.a        = txn.a;
  vif.b        = txn.b;
  vif.op       = txn.op;
  vif.valid_in = 1'b1;
endtask
```

Answer: A race. The driver assigns the DUT inputs with blocking assignments in the Active region of the same clock edge at which the DUT's `always_ff` samples them. The order of the two is undefined, so one simulator captures the new values at this edge and another at the next edge. Fix: drive through the clocking block, `@(vif.drv_cb); vif.drv_cb.a <= txn.a;`, which drives after the design has sampled. Without a clocking block, use nonblocking assignments or drive on the opposite clock edge.

**Q181. One test drives the same stimulus as the previous transaction now and then, and coverage is lower than expected.**

```systemverilog
class alu_txn;
  rand bit [7:0] a, b;
  constraint small_c { a < 16; }
endclass

// in the test
txn.randomize() with { a > 100; };
```

Answer: The inline constraint contradicts the class constraint, so `randomize()` fails, returns 0 and leaves `a` and `b` unchanged. The return value is thrown away, so the test carries on with the old values. Fix the contradiction (switch the class constraint off with `txn.small_c.constraint_mode(0);`, or make it `soft`) and always check the result: `if (!txn.randomize() with { a > 100; }) $fatal(1, "randomize failed");`.

**Q182. The constraint is meant to produce `lo < mid < hi`, but values such as lo=200, mid=5, hi=9 appear.**

```systemverilog
rand bit [7:0] lo, mid, hi;
constraint order_c { lo < mid < hi; }
```

Answer: Relational operators cannot be chained. The expression is parsed as `(lo < mid) < hi`: the 1-bit result of `lo < mid` (0 or 1) is compared with `hi`. Any `hi` of 2 or more satisfies it regardless of `lo` and `mid`. Fix: `constraint order_c { lo < mid; mid < hi; }`.

**Q183. The scoreboard's queue of observed transactions contains N copies of the last transaction.**

```systemverilog
class alu_monitor;
  mailbox #(alu_txn) mon2scb_mbx;
  virtual alu_if     vif;
  alu_txn            txn = new();

  task run();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid_out) begin
        txn.result = vif.mon_cb.result;
        mon2scb_mbx.put(txn);
      end
    end
  endtask
endclass
```

Answer: The same mistake as Q172, on the monitor side. One object is reused, the mailbox and the scoreboard's queue hold handles to it, and every new sample overwrites the fields that all those handles see. It may appear to work if the scoreboard consumes each item before the next sample, and fail as soon as it stores them. Fix: `txn = new();` for each observed transaction.

**Q184. Every comparison fails: the observed result always belongs to the previous operation.**

```systemverilog
// monitor
forever begin
  @(vif.mon_cb);
  if (vif.mon_cb.valid_in) begin
    txn = new();
    txn.a      = vif.mon_cb.a;
    txn.b      = vif.mon_cb.b;
    txn.op     = vif.mon_cb.op;
    txn.result = vif.mon_cb.result;
    mon2scb_mbx.put(txn);
  end
end
```

Answer: The ALU registers its result: `result` and `valid_out` appear one clock after `valid_in`. The monitor samples `result` in the same cycle as the inputs, so it pairs each set of inputs with the result of the operation before it. Fix: capture the inputs when `valid_in` is 1, and capture `result` when `valid_out` is 1 on a later cycle, then send the transaction. A constant one-cycle offset between expected and actual is the signature of sampling at the wrong pipeline stage.

**Q185. The simulation stops advancing: the time stays at 0 and the simulator uses 100% CPU.**

```systemverilog
task run();
  alu_txn txn;
  forever begin
    if (mon2scb_mbx.num() > 0) begin
      mon2scb_mbx.get(txn);
      check(txn);
    end
  end
endtask
```

Answer: When the mailbox is empty the loop body contains no blocking statement, so the `forever` loop spins without ever letting simulation time advance. No other process can run, so the mailbox never fills. Fix: remove the polling and let `get()` block: `forever begin mon2scb_mbx.get(txn); check(txn); end`. Every `forever` loop must contain a statement that is guaranteed to block on each iteration.

**Q186. A `randc` field repeats values long before all values have been used.**

```systemverilog
class id_txn;
  randc bit [3:0] id;
endclass

repeat (16) begin
  id_txn t = new();
  void'(t.randomize());
  $display("%0d", t.id);
end
```

Answer: The cyclic history of a `randc` variable is stored in the object. A new object is constructed in every iteration, so every call is the first call of a new cycle and the values are effectively plain random. Fix: construct the object once and call `randomize()` on it sixteen times; if separate objects are needed downstream, send copies.

# Find-the-Error Questions

Each fragment is rejected by the compiler or the elaborator. Name the rule that is broken and correct the code.

**Q187.**

```systemverilog
function int wait_and_add(int a, int b);
  #10;
  return a + b;
endfunction
```

Answer: A function cannot contain a delay or any other time-consuming statement. Make it a task with an `output` argument, or remove the delay.

**Q188.**

```systemverilog
class alu_txn;
  int        id;
  static int count;
  static function int next_id();
    id = count++;
    return id;
  endfunction
endclass
```

Answer: A static method has no object (`this`), so it cannot access the non-static property `id`. Either make the method non-static or have it use only `count`: `return count++;`.

**Q189.**

```systemverilog
class cfg;
  local int secret = 42;
endclass

module tb;
  cfg c = new();
  initial $display("%0d", c.secret);
endmodule
```

Answer: A `local` member is accessible only inside the methods of its own class. Add a public accessor, `function int get_secret(); return secret; endfunction`, or remove `local`.

**Q190.**

```systemverilog
class base;                 endclass
class child extends base;   endclass

module tb;
  base  b = new();
  child c;
  initial c = b;
endmodule
```

Answer: A base-class handle cannot be assigned to a derived-class handle directly. Use `$cast(c, b)`, which compiles and checks at run time. (Here the cast would fail, because the object is a plain `base`.)

**Q191.**

```systemverilog
virtual class shape;
  pure virtual function real area();
endclass

module tb;
  shape s = new();
endmodule
```

Answer: An abstract (`virtual`) class cannot be constructed. Declare a derived class that implements `area()` and construct that; the handle may still be of type `shape`.

**Q192.**

```systemverilog
virtual class shape;
  pure virtual function real area();
endclass

class square extends shape;
  real side;
endclass
```

Answer: `square` is not abstract but does not implement the pure virtual method `area()`. Implement it, `virtual function real area(); return side * side; endfunction`, or declare `square` as `virtual class`.

**Q193.**

```systemverilog
class pkt;
  randc bit [2:0] kind;
  constraint kind_c { kind dist {0 := 50, [1:7] := 10}; }
endclass
```

Answer: `dist` cannot be applied to a `randc` variable; a weighted distribution contradicts cyclic behaviour. Declare `kind` as `rand`, or drop the `dist`.

**Q194.**

```systemverilog
class child extends base;
  int n;
  function new(int n);
    this.n = n;
    super.new();
  endfunction
endclass
```

Answer: A call to `super.new()` must be the first statement of the constructor. Move it above `this.n = n;`.

**Q195.**

```systemverilog
class alu_driver;
  alu_if vif;
endclass
```

Answer: A class cannot contain an interface instance. Declare a virtual interface, `virtual alu_if vif;`, and assign the real instance to it from the testbench top.

**Q196.**

```systemverilog
class pkt;
  rand bit       mode;
  rand bit [3:0] len;
  constraint len_c { if (mode) len = 4; }
endclass
```

Answer: A constraint is a set of Boolean expressions, not procedural code, so an assignment is not allowed. Use equality: `if (mode) len == 4;`.

**Q197.**

```systemverilog
int d [];
initial begin
  d.push_back(5);
end
```

Answer: `push_back` is a queue method; a dynamic array does not have it. Declare a queue, `int d [$];`, or resize the dynamic array with `d = new[d.size() + 1](d);` and assign the last element.

**Q198.**

```systemverilog
task automatic wait_clk();
  @(posedge clk);
endtask

function automatic void sample();
  wait_clk();
endfunction
```

Answer: A function cannot call a task, because a task may consume time. Make `sample` a task.

**Q199.**

```systemverilog
int m [2][3];
initial
  foreach (m[i][j]) m[i][j] = i + j;
```

Answer: The loop variables of a multidimensional `foreach` are written inside one pair of brackets, separated by commas: `foreach (m[i, j]) m[i][j] = i + j;`.

**Q200.**

```systemverilog
module tb;
  task incr(ref int x);
    x++;
  endtask
endmodule
```

Answer: A `ref` argument is allowed only in a task or function with automatic lifetime, and tasks in a module are static by default. Write `task automatic incr(ref int x);`.

**Q201.**

```systemverilog
class alu_monitor;
  virtual alu_if vif;
  a_valid: assert property (@(posedge vif.clk) vif.valid_in |=> vif.valid_out);
endclass
```

Answer: Concurrent assertions are not allowed inside a class; they must be in a module, interface, program or checker. Put the assertion in `alu_if` (or in a module attached with `bind`). Immediate assertions are allowed in class methods.

**Q202.**

```systemverilog
interface alu_if (input logic clk);
  logic [7:0] a;
  logic [8:0] result;
  modport MON (input a, result);
endinterface

module mon_block (alu_if.MON bus);
  assign bus.result = 9'd0;
endmodule
```

Answer: Through the `MON` modport, `result` is an input, so this module is not allowed to drive it. Either the module should not drive it (a monitor never drives), or it needs a modport in which `result` is an output.
