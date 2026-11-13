# Part 7: Module 9 Revision and Practice

## 7.1 Revision Summary

### The architecture on one page

```text
   Stimulus path :  Generator -> Mailbox -> Driver -> Interface -> DUT
   Checking path :  DUT -> Interface -> Monitor -> Mailbox -> Scoreboard

   tb_top (module):  clock, reset, alu_if aif, alu dut, test = new(aif), test.run(), $finish
      test  (class):  env = new(vif); configure(); env.run(); env.scb.report()
         env (class): mailboxes, events, gen, drv, mon, scb;
                      fork ... join_any; drain; disable fork
```

### Each component in one line

| Component | Level | Input | Output | Has `vif`? | Ends by itself? |
|---|---|---|---|---|---|
| Transaction | Data | | | No | n/a |
| Generator | Transaction | Constraints, blueprint | Transactions into `gen2drv_mbx` | No | Yes |
| Driver | Transaction → pins | Transactions from `gen2drv_mbx` | Pin activity through `drv_cb` | Yes | No |
| Monitor | Pins → transaction | Samples through `mon_cb` | Transactions into `mon2scb_mbx` | Yes | No |
| Scoreboard | Transaction | Transactions from `mon2scb_mbx` | PASS/FAIL, counters, report | No | No |
| Environment | Structure | `vif` | Running components | Passes it on | When drained |
| Test | Scenario | `vif`, plusargs | Configuration, verdict | Passes it on | After report |
| Top | Static | | Clock, reset, instances | Owns the instance | Calls `$finish` |

### Who knows what

| Knowledge | Generator | Driver | Monitor | Scoreboard | Test |
|---|---|---|---|---|---|
| What values are legal (constraints) | Via the transaction | | | | Yes |
| Pin names and clock edges | | Yes | Yes | | |
| DUT latency | | Partly | Yes | | |
| What the correct result is | | | | Yes | |
| How many transactions | Yes | | | Counts | Yes |

### Rules to remember

**Structure**

- Only the driver and the monitor touch signals, and only through a virtual interface and clocking blocks.
- Components never call each other's methods. They share mailboxes and events created once in the environment.
- Create shared objects before passing them on. A handle that was never assigned is `null`.
- Class files are included in one package; only the package is compiled.

**Objects and handles**

- A mailbox carries handles. Every transaction put into a mailbox must be its own object: `copy()` in the generator, `new()` inside the loop in the monitor.
- `expected = actual.copy()`, never `expected = actual`.
- Stimulus fields are `rand bit`; fields sampled from DUT outputs are `logic`.

**Timing**

- A clocking block input is the value just before the edge; a clocking block output appears a skew after the edge.
- The driver aligns to a clocking event before every drive.
- The monitor pairs the inputs of edge N with the outputs of edge N+1 (the DUT's latency).
- Reset is driven by the top module, away from the active clock edge. The driver idles the bus and waits; the monitor skips.

**Checking**

- The reference model is written from the specification, has no timing, and uses exact widths.
- The scoreboard predicts from what the monitor observed.
- Compare with `===`. Print time, id, stimulus, actual and expected on a mismatch.
- Fail the test if nothing was checked or if not everything sent was checked.

**Control**

- `fork`...`join_any` starts the components; the generator is the thread that finishes.
- End of test = generator done **and** scoreboard caught up, with a timeout; then `disable fork`.
- Only the top module calls `$finish`.
- New tests extend the base test and change knobs, the blueprint or the generator. Components are not edited.

### Direct versus layered, in four lines

| | Direct | Layered |
|---|---|---|
| Stimulus and expected values | Hand-written | Constrained-random; expected from a reference model |
| Structure | One module | Reusable class components plus one top module |
| Cost | Low at first, grows with every test | High at first, low per additional test |
| Use | Small blocks, bring-up | Industry standard; basis of UVM |

## 7.2 Interview Questions and Answers

### Basic level

**Q1. Draw and explain a layered testbench.**
Draw the diagram of Section 1.3: test containing environment; environment containing generator, driver, monitor and scoreboard; generator to driver through a mailbox; monitor to scoreboard through a mailbox; driver and monitor connected to the interface through a virtual interface; interface connected to the DUT inside the top module. Then give each component's one-line job.

**Q2. List the components of a layered testbench.**
Transaction, generator, driver, monitor, scoreboard, environment, test, interface, and the testbench top module. A coverage collector is usually added.

**Q3. What is the role of the generator?**
To create and randomize transactions and send them to the driver.

**Q4. What is the role of the driver?**
To convert transactions into pin-level activity on the DUT inputs according to the protocol.

**Q5. What is the role of the monitor?**
To sample the DUT pins passively and convert the activity back into transactions for the scoreboard and coverage.

**Q6. What is the role of the scoreboard?**
To compare the DUT's actual outputs with the expected outputs from a reference model and report pass or fail.

**Q7. What connects the generator to the driver?**
A mailbox of transaction handles, created in the environment and shared by both.

**Q8. What connects the driver to the DUT?**
A virtual interface: a handle in the driver that points to the interface instance in the top module, whose signals are wired to the DUT ports.

**Q9. Which components have a virtual interface handle?**
The driver and the monitor. The environment and test hold one only to pass it down.

**Q10. What is a self-checking testbench?**
A testbench that determines pass or fail by itself, by comparing DUT outputs with expected values computed automatically, with no manual inspection of waveforms.

**Q11. Why is a mailbox used instead of a queue between generator and driver?**
A mailbox is built for communication between threads: `get()` blocks while it is empty and `put()` blocks while a bounded mailbox is full, and its operations are atomic. A queue has no blocking; the driver would have to poll it, and concurrent access would need extra protection.

**Q12. What is the top module responsible for?**
Clock and reset generation, instantiating the interface and the DUT and connecting them, creating the test with the interface handle, running it, and ending the simulation.

**Q13. In which order are the testbench objects created?**
The top module creates the test; the test's constructor creates the environment; the environment's constructor creates the mailboxes and then the generator, driver, monitor and scoreboard.

**Q14. What is the difference between `fork`...`join`, `join_any` and `join_none`?**
`join` waits for all forked threads, `join_any` for the first one to finish, `join_none` for none. The environment uses `join_any` because only the generator finishes.

**Q15. Which signals does the driver drive, and which does the monitor sample?**
The driver drives the DUT inputs (`valid_in`, `a`, `b`, `op`). The monitor samples inputs and outputs (`valid_in`, `a`, `b`, `op`, `valid_out`, `result`).

### Intermediate level

**Q16. Why are the generator and driver separate components?**
What to send and how to send it change for different reasons. Separating them lets many generators (scenarios) share one driver, and lets the driver change with the protocol without affecting the scenarios.

**Q17. Why are the driver and monitor separate, when the driver could also sample the outputs?**
The monitor must work without the driver: when the block is integrated into a larger design the driver disappears, but the monitor and scoreboard are still needed. Separation also keeps the checking path independent of the stimulus path.

**Q18. Why are the monitor and scoreboard separate?**
The monitor depends on the protocol; the scoreboard depends on the function. Either can change without the other. The monitor's transactions also feed coverage and other subscribers.

**Q19. How does your testbench avoid race conditions with the DUT?**
The driver and monitor use clocking blocks. Inputs are sampled with `#1step` skew (the value before the clock edge) and outputs are driven a skew after the edge, so the testbench never reads or writes a signal at the same moment as the DUT's clocked logic. Reset is changed on the opposite clock edge.

**Q20. What is the blueprint pattern?**
The generator randomizes a template object that a test can replace with a derived-class object, and sends copies of it. It lets tests change constraints without modifying the generator.

**Q21. How do the generator and driver stay synchronised?**
The generator waits for the event `drv_done` after each `put()`, and the driver triggers the event when the transaction has been applied. Alternatively a mailbox of size 1 provides back-pressure.

**Q22. What would happen if the environment used `fork`...`join`?**
It would never return, because driver, monitor and scoreboard run `forever`. The simulation would hang until a timeout.

**Q23. What would happen if the test called `$finish` as soon as the generator finished?**
The transactions still in the driver, the DUT and the monitor would never be checked. The test would report a pass on fewer transactions than it sent.

**Q24. How do you make sure every generated transaction was checked?**
Compare counters at the end: the number the scoreboard checked must equal the number the generator sent. The environment waits for that equality with a timeout, and the report fails if nothing was checked.

**Q25. Where are the classes declared, and how does the top module see them?**
In a package that includes the class files. The top module imports the package.

**Q26. Why can a class not instantiate the interface itself?**
An interface is a static design element that must exist in the elaborated hierarchy and be wired to the DUT. Classes are created at run time. A class can only hold a virtual interface handle that refers to an existing instance.

**Q27. How is the DUT reset in this testbench, and how do the components react?**
The top module drives `rst_n` low from time 0 and releases it after two falling clock edges. The driver first drives idle values and waits for `rst_n` to be 1. The monitor discards anything it sees while `rst_n` is not 1.

**Q28. What does the scoreboard do if the DUT output is X?**
The comparison uses `===`, so X does not match the expected value and a failure is reported.

**Q29. How do you run a different test without recompiling?**
The top module reads a plusarg (`+TEST=name`), constructs the corresponding test class and runs it through a base-class handle.

**Q30. What is the UVM equivalent of each component?**
Transaction: `uvm_sequence_item`. Generator: `uvm_sequence` running on a `uvm_sequencer`. Driver: `uvm_driver`. Monitor: `uvm_monitor`. Driver, sequencer and monitor together: `uvm_agent`. Scoreboard: `uvm_scoreboard`. Environment: `uvm_env`. Test: `uvm_test`. Mailboxes: TLM ports and FIFOs. Passing the virtual interface: `uvm_config_db`.

### Advanced and scenario-based

**Q31. The simulation hangs at time 0 after printing one `GEN` line. What do you check?**
The generator is waiting for `drv_done`, so the driver never completed a transaction. Check, in order: is the driver's mailbox the same object as the generator's; is `vif` assigned; is the clock running; was reset released (the driver waits for it); does the driver trigger the same event object the generator waits on.

**Q32. Every transaction fails, and in each failure the actual result equals the expected result of the previous transaction. What is wrong?**
The monitor is pairing inputs and outputs from the same clock edge. The output at an edge belongs to the inputs sampled one edge earlier. Fix the monitor's latency alignment.

**Q33. The test passes, but you later find that the DUT's `result` was X throughout. Name three testbench faults that could cause this.**
The scoreboard compares with `!=`/`==`; the transaction's `result` field is two-state, so X became 0 and happened to match; the scoreboard checked zero transactions and the report did not treat that as a failure; or `expected` and `actual` were the same object.

**Q34. The scoreboard sees duplicate transactions: the same values several times, and some values never. Why?**
The monitor (or generator) is putting the same object into the mailbox repeatedly instead of creating a new one each time, so all handles refer to one object holding the latest values.

**Q35. A test passes with one seed and fails with another. Is that a testbench problem?**
Not necessarily; that is what random testing is for. The failing seed reached a scenario the passing one did not. Rerun with the failing seed to reproduce it, and debug as usual. It is a testbench problem only if the *same* seed gives different results between runs, which indicates a race.

**Q36. The same test and seed pass on one simulator and fail on another. What do you suspect?**
A race condition: behaviour that depends on the order in which the simulator executes processes in the same time step. Typical causes are driving or sampling at the clock edge without a clocking block, an event triggered before its waiter is waiting, or two threads writing a shared variable. Different random number generators between simulators also change the stimulus, so first confirm that the failing scenario is the same.

**Q37. How would you verify a DUT with two input interfaces and one output interface?**
One agent-like group (generator, driver, monitor) per input interface and a monitor on the output interface, all inside one environment. The scoreboard receives expected data from the input monitors through one mailbox each and actual data from the output monitor, with a reference model that combines the inputs.

**Q38. Your block-level environment must be reused at subsystem level, where real logic drives the ALU. What changes?**
The generator and driver are not created (the environment gets a configuration flag for "passive" mode). The monitor and scoreboard are created and connected exactly as before, with the virtual interface bound to the ALU's signals inside the subsystem. This is why checking must not depend on the stimulus components.

**Q39. Why should the reference model not use the DUT's own package functions or internal signals?**
Any logic shared between DUT and model is not being verified, because both sides produce the same answer whether it is right or wrong. Sharing type definitions (the opcode enum) is fine; sharing behaviour is not.

**Q40. How would you add functional coverage to this testbench?**
Add a coverage component with a covergroup sampled on each observed transaction. The monitor sends each transaction to a second mailbox for the coverage component (or the scoreboard samples it). Coverage is taken from monitored transactions, not generated ones, so that it reflects what actually reached the DUT.

**Q41. What is the weakness of ending the test on a transaction count, and how do you guard against it?**
If a transaction is dropped anywhere, the count is never reached and the simulation hangs. A watchdog timeout running in parallel converts the hang into an error.

**Q42. The driver is killed by `disable fork` in the middle of driving. Is that a problem?**
Not in this testbench: `disable fork` is executed only after every transaction has been checked, so the driver is idle, blocked on the mailbox. In general, killing a driver mid-transaction leaves the bus in an undefined protocol state, which matters if the simulation continues afterwards (for example a reset test). Then the driver should be stopped cleanly and the bus returned to idle.

**Q43. Why is `configure()` called from `run()` and not from the constructor?**
A constructor of a base class runs before the derived class's part of the object is initialised, and calling a virtual method from a constructor is a well-known source of surprises. Calling it at the start of `run()`, when the whole object tree exists, is safe and also guarantees that every component is already built when the settings are applied.

**Q44. How would you test reset in the middle of operation with this architecture?**
A reset generator thread (driven by the test) asserts `rst_n` at a random time. The driver must abandon the current transaction and return to idle; the monitor already discards its pending transaction during reset; the scoreboard must be told to discard expected items for transactions that were in flight, and the end-of-test count must account for them.

**Q45. What makes a testbench reusable?**
Components with a single responsibility; no test-specific code inside components; communication only through transactions and well-defined channels; all pin access behind a virtual interface; configuration through knobs and replaceable objects; and a checking path that works without the stimulus path.

## 7.3 Output-Prediction Questions

Each of these is a small, self-contained module about a mechanism the layered testbench depends on. Work out the output first.

**P1.**

```systemverilog
module p1;
  class item;
    int v;
  endclass

  mailbox #(item) mbx = new();
  item it, got;

  initial begin
    it = new();
    for (int i = 1; i <= 3; i++) begin
      it.v = i;
      mbx.put(it);
    end
    repeat (3) begin
      mbx.get(got);
      $display("%0d", got.v);
    end
  end
endmodule
```

Answer: `3`, `3`, `3`. One object was created and its handle was put into the mailbox three times. All three handles refer to that object, whose `v` was last set to 3. Moving `it = new();` inside the loop gives 1, 2, 3. This is the "new object per transaction" rule.

**P2.**

```systemverilog
module p2;
  initial begin
    fork
      begin #10 $display("A"); end
      begin #20 $display("B"); end
      begin #30 $display("C"); end
    join_any
    $display("after join_any at %0t", $time);
    #15;
    disable fork;
    $display("end at %0t", $time);
  end
endmodule
```

Answer:

```output
A
after join_any at 10
B
end at 25
```

`join_any` returns when the first thread finishes (time 10). The other two keep running: B prints at 20. At 25 `disable fork` kills the remaining thread, so C never prints. This is the environment's start-up and shutdown in miniature.

**P3.**

```systemverilog
module p3;
  class txn;
    int result;
  endclass

  txn actual, expected;

  initial begin
    actual          = new();
    actual.result   = 44;
    expected        = actual;
    expected.result = 300;
    $display("%0d %0d %s", actual.result, expected.result,
             (actual.result == expected.result) ? "PASS" : "FAIL");
  end
endmodule
```

Answer: `300 300 PASS`. `expected = actual;` copies the handle, not the object. Writing the prediction through `expected` overwrote the DUT's value, and the object was then compared with itself. A scoreboard written this way can never fail.

**P4.**

```systemverilog
module p4;
  event e;

  initial begin
    -> e;
    $display("triggered at %0t", $time);
  end

  initial begin
    #1;
    @(e);
    $display("received at %0t", $time);
  end

  initial #10 $display("end at %0t", $time);
endmodule
```

Answer:

```output
triggered at 0
end at 10
```

The event is triggered at time 0, but the waiting process only reaches `@(e)` at time 1. A trigger is not remembered, so the second block waits forever and "received" is never printed. In a testbench this is a hung generator or a test that only ends by timeout.

**P5.**

```systemverilog
module p5;
  initial begin
    for (int i = 0; i < 3; i++)
      fork
        $display("i=%0d", i);
      join_none
    #1 $display("done");
  end
endmodule
```

Answer:

```output
i=3
i=3
i=3
done
```

Threads created with `join_none` do not start until the parent blocks, which here is at `#1`, after the loop has finished and `i` is 3. All three threads share the one variable `i`. This is the bug that appears when a loop starts one driver per interface. The fix is a per-iteration copy: `automatic int k = i;` declared inside the `fork` before the statement, and `k` used in the thread.

**P6.**

```systemverilog
module p6;
  mailbox #(int) m = new(2);

  initial begin
    fork
      for (int i = 1; i <= 4; i++) begin
        m.put(i);
        $display("[%0t] put %0d", $time, i);
      end
      begin
        int v;
        #10;
        repeat (4) begin
          m.get(v);
          $display("[%0t] got %0d", $time, v);
          #10;
        end
      end
    join
  end
endmodule
```

Answer:

```output
[0] put 1
[0] put 2
[10] got 1
[10] put 3
[20] got 2
[20] put 4
[30] got 3
[40] got 4
```

The mailbox is bounded to two entries. The producer puts 1 and 2 and then blocks in `put(3)`. Each `get()` frees one place, which lets exactly one more `put()` complete. A bounded mailbox paces the producer to the consumer's speed without any event. (The consumer continues to its `$display` before the unblocked producer runs, so "got" is printed before "put" at each time.)

**P7.**

```systemverilog
module p7;
  class base_test;
    function void configure();
      $display("base configure");
    endfunction
    function void run();
      configure();
    endfunction
  endclass

  class my_test extends base_test;
    function void configure();
      $display("my configure");
    endfunction
  endclass

  base_test t;
  my_test   m;

  initial begin
    m = new();
    t = m;
    t.run();
    m.configure();
  end
endmodule
```

Answer:

```output
base configure
my configure
```

`configure()` is not virtual. Inside `base_test::run` the call is bound to `base_test::configure` at compile time, even though the object is a `my_test`. Called directly through the `my_test` handle, the derived version runs. With `virtual function void configure();` in the base class both lines would be `my configure`. A test whose settings are mysteriously ignored usually has this cause.

## 7.4 Find-the-Error and Debugging Questions

For each fragment, say what goes wrong and how to fix it.

**D1.**

```systemverilog
class my_env;
  mailbox #(alu_txn) gen2drv_mbx;
  alu_generator      gen;
  alu_driver         drv;
  event              drv_done, gen_done;
  function new(virtual alu_if vif);
    gen = new(gen2drv_mbx, drv_done, gen_done);
    drv = new(vif, gen2drv_mbx, drv_done);
    gen2drv_mbx = new();
  endfunction
endclass
```

The mailbox is created after its (still null) handle has been passed to both components. Generator and driver hold `null`; the first `put()` is a null object access at time 0. Create the mailbox first.

**D2.**

```systemverilog
function new(virtual alu_if vif);
  gen = new(new(), drv_done, gen_done);       // intention: "give it a mailbox"
  drv = new(vif, new(), drv_done);
endfunction
```

Even where a tool accepts this, each component receives its own, different mailbox. The generator fills one, the driver waits on the other, and the test hangs. One mailbox must be created, stored in a variable, and that same handle passed to both.

**D3.**

```systemverilog
task run();
  alu_txn t;
  t = new();
  forever begin
    @(vif.mon_cb);
    if (vif.mon_cb.valid_out === 1'b1) begin
      t.result = vif.mon_cb.result;
      mon2scb_mbx.put(t);
    end
  end
endtask
```

Two faults. One object is reused for every transaction (move `t = new();` inside the `if`). And the monitor never samples the inputs, so the scoreboard has nothing to predict from.

**D4.**

```systemverilog
task drive(alu_txn txn);
  @(posedge vif.clk);
  vif.valid_in = 1'b1;
  vif.a        = txn.a;
  vif.b        = txn.b;
  vif.op       = txn.op;
  @(posedge vif.clk);
  vif.valid_in = 1'b0;
endtask
```

Blocking assignments to DUT inputs at the active clock edge race with the DUT's `always_ff`. The DUT may see the new values at the same edge or one edge later, depending on the simulator. Drive through the clocking block (`vif.drv_cb.valid_in <= 1'b1;` after `@(vif.drv_cb)`). In this project there is a second fault: these signals are clocking block outputs, and mixing direct assignments with clocking drives on the same variable is asking for trouble.

**D5.**

```systemverilog
task run();
  fork
    gen.run();
    drv.run();
    mon.run();
    scb.run();
  join
  scb.report();
endtask
```

`join` waits for all four threads; three are endless. `report()` is never reached. Use `join_any`, then drain, then `disable fork`.

**D6.**

```systemverilog
task run();
  fork
    gen.run();
    drv.run();
    mon.run();
    scb.run();
  join_any
  scb.report();
  $finish;
endtask
```

The report and `$finish` happen at the instant the generator finishes. The last transaction has not reached the scoreboard yet. Wait for `scb.num_checked == gen.num_sent` (with a timeout) first.

**D7.**

```systemverilog
function void check_txn(alu_txn actual);
  logic [8:0] exp_result;
  exp_result = alu_predict(actual);
  if (actual.result != exp_result) begin
    num_fail++;
    $error("mismatch");
  end
endfunction
```

Three faults. `!=` yields X when `result` contains X, so an X output is not reported: use `!==`. The message contains none of the information needed to debug. And nothing counts checked transactions, so a run in which nothing arrived looks the same as a clean run.

**D8.**

```systemverilog
virtual task run();
  repeat (num_txns) begin
    blueprint.randomize();
    gen2drv_mbx.put(blueprint);
  end
endtask
```

The return value of `randomize()` is ignored, so a constraint failure goes unnoticed. The blueprint itself is put into the mailbox each time, so all entries are the same object and (with no pacing here) the driver sees only the last values. Check the return value and send `blueprint.copy()`.

**D9.**

```systemverilog
class alu_monitor;
  virtual alu_if     vif;
  mailbox #(alu_txn) mon2scb_mbx;
  function new(mailbox #(alu_txn) mon2scb_mbx);
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction
  ...
endclass
```

`vif` is never assigned. The first `@(vif.mon_cb)` dereferences a null virtual interface: a fatal run-time error at time 0. Pass the interface through the constructor.

**D10.**

```systemverilog
function logic [8:0] alu_predict(alu_txn t);
  logic [7:0] r;
  case (t.op)
    ALU_ADD: r = t.a + t.b;
    ...
  endcase
  return r;
endfunction
```

`r` is 8 bits wide, so the addition is done in 8 bits and the carry is lost; the returned value has bit 8 always 0. Every addition that overflows is reported as a DUT failure although the DUT is right. Declare `r` as `logic [8:0]`.

**D11.**

```systemverilog
// tb_top
initial begin
  alu_test test;
  test.run();
  $finish;
end
```

The test object is never constructed. `test` is `null` and `test.run()` is a null object access. Add `test = new(aif);`.

**D12.**

```systemverilog
// In the generator
task send(alu_txn txn);
  gen2drv_mbx.put(txn);
  #1;
  @(drv_done);
endtask
```

Not a compile error, and it works with this driver, but it is fragile: adding a delay between `put()` and the wait opens a window in which a faster driver could trigger `drv_done` before the generator is waiting, and the generator would hang. Wait immediately after the `put()`, or use a mechanism that remembers (`wait (drv_done.triggered)` in the same time step, a bounded mailbox, or a semaphore).

**D13.** A colleague's test log ends with:

```text
SCOREBOARD SUMMARY: checked=0 pass=0 fail=0
TEST PASSED
```

The report treats "no failures" as a pass even though nothing was checked. The stimulus never reached the scoreboard (reset never released, monitor not sampling, wrong mailbox). The report must fail when `num_checked` is 0, and the cause must be found.

**D14.** The compile fails with "class `alu_txn` is declared more than once" or, in another tool, with type-mismatch errors between `alu_txn` and `alu_tb_pkg::alu_txn`.

The class files were compiled both directly (listed on the command line) and through the package's `` `include ``. Compile only the package.

## 7.5 Coding Exercises with Solutions

### Exercise 1: a miniature layered flow with no DUT

Build the smallest structure that has the shape of the real one: a producer that sends three items through a mailbox, a middle stage that stands in for "driver + DUT + monitor" (it takes 3 time units and doubles the value), and a checker that verifies the doubling. Start the three with `fork`...`join_any` and end cleanly.

```systemverilog file=ex01_mini_layered.sv
module ex01_mini_layered;

  class item;
    int unsigned id;
    bit [7:0]    din;
    bit [8:0]    dout;
  endclass

  class producer;
    mailbox #(item) out_mbx;
    int unsigned    count = 3;

    function new(mailbox #(item) out_mbx);
      this.out_mbx = out_mbx;
    endfunction

    task run();
      item it;
      for (int unsigned i = 1; i <= count; i++) begin
        it     = new();                  // a new object for every item
        it.id  = i;
        it.din = 50 * i;
        out_mbx.put(it);
        $display("[%0t] PRODUCER sent id=%0d din=%0d", $time, it.id, it.din);
        #10;
      end
    endtask
  endclass

  class doubler;                         // stands in for driver + DUT + monitor
    mailbox #(item) in_mbx;
    mailbox #(item) out_mbx;

    function new(mailbox #(item) in_mbx, mailbox #(item) out_mbx);
      this.in_mbx  = in_mbx;
      this.out_mbx = out_mbx;
    endfunction

    task run();
      item it;
      forever begin
        in_mbx.get(it);
        #3;
        it.dout = it.din * 2;
        out_mbx.put(it);
      end
    endtask
  endclass

  class result_checker;
    mailbox #(item) in_mbx;
    int unsigned    num_checked;
    int unsigned    num_fail;

    function new(mailbox #(item) in_mbx);
      this.in_mbx = in_mbx;
    endfunction

    task run();
      item      it;
      bit [8:0] expected;
      forever begin
        in_mbx.get(it);
        expected = it.din * 2;
        if (it.dout !== expected) begin
          num_fail++;
          $display("[%0t] CHECKER id=%0d din=%0d dout=%0d FAIL, expected %0d",
                   $time, it.id, it.din, it.dout, expected);
        end
        else
          $display("[%0t] CHECKER id=%0d din=%0d dout=%0d PASS",
                   $time, it.id, it.din, it.dout);
        num_checked++;
      end
    endtask
  endclass

  mailbox #(item) p2d_mbx = new();
  mailbox #(item) d2c_mbx = new();
  producer        prod;
  doubler         dbl;
  result_checker  chk;

  initial begin
    prod = new(p2d_mbx);
    dbl  = new(p2d_mbx, d2c_mbx);
    chk  = new(d2c_mbx);

    fork
      prod.run();
      dbl.run();
      chk.run();
    join_any
    wait (chk.num_checked == prod.count);
    disable fork;
    $display("[%0t] checked=%0d fail=%0d", $time, chk.num_checked, chk.num_fail);
  end

endmodule
```

```output
[0] PRODUCER sent id=1 din=50
[3] CHECKER id=1 din=50 dout=100 PASS
[10] PRODUCER sent id=2 din=100
[13] CHECKER id=2 din=100 dout=200 PASS
[20] PRODUCER sent id=3 din=150
[23] CHECKER id=3 din=150 dout=300 PASS
[30] checked=3 fail=0
```

The producer finishes at time 30 (its last `#10`), which releases `join_any`. All three items have already been checked, so the `wait` passes immediately and `disable fork` stops the two endless threads. The class is named `result_checker` because `checker` is a reserved word in SystemVerilog.

### Exercise 2: a queue-based reference model for a FIFO

Write the checking core of a FIFO scoreboard as a function that is called once per observed operation, and exercise it with a hand-written sequence that includes one wrong read value and one read from an empty FIFO.

```systemverilog file=ex02_fifo_model.sv
module ex02_fifo_model;

  typedef enum bit {FIFO_WRITE, FIFO_READ} fifo_kind_e;

  bit [7:0]    model_q [$];
  int unsigned num_checked;
  int unsigned num_fail;

  function automatic void observe(fifo_kind_e kind, logic [7:0] value);
    bit [7:0] expected_data;
    if (kind == FIFO_WRITE) begin
      model_q.push_back(value);
      $display("WRITE %h  model holds %0d", value, model_q.size());
    end
    else begin
      num_checked++;
      if (model_q.size() == 0) begin
        num_fail++;
        $display("READ  %h  FAIL: model is empty", value);
      end
      else begin
        expected_data = model_q.pop_front();
        if (value !== expected_data) begin
          num_fail++;
          $display("READ  %h  FAIL: expected %h", value, expected_data);
        end
        else
          $display("READ  %h  PASS", value);
      end
    end
  endfunction

  initial begin
    observe(FIFO_WRITE, 8'hA1);
    observe(FIFO_WRITE, 8'hB2);
    observe(FIFO_READ,  8'hA1);
    observe(FIFO_WRITE, 8'hC3);
    observe(FIFO_READ,  8'hB2);
    observe(FIFO_READ,  8'hFF);     // the "DUT" returned FF instead of C3
    observe(FIFO_READ,  8'h00);     // the "DUT" produced data from an empty FIFO
    $display("checked=%0d fail=%0d left in model=%0d",
             num_checked, num_fail, model_q.size());
  end

endmodule
```

```output
WRITE a1  model holds 1
WRITE b2  model holds 2
READ  a1  PASS
WRITE c3  model holds 2
READ  b2  PASS
READ  ff  FAIL: expected c3
READ  00  FAIL: model is empty
checked=4 fail=2 left in model=0
```

The queue is the reference model. Order is preserved by `push_back` and `pop_front`. Note that after the wrong read the model and the DUT are back in step, because the model popped the entry it expected.

### Exercise 3: add functional coverage

Add a coverage component to the ALU testbench that records which operations and which operand corner values were observed. (Covergroups are the subject of Module 10; this exercise shows where coverage plugs into the architecture.)

```systemverilog
// alu_coverage.sv  (include it in alu_tb_pkg after alu_txn.sv)
class alu_coverage;

  mailbox #(alu_txn) mon2cov_mbx;
  alu_txn            txn;

  covergroup alu_cg;
    cp_op : coverpoint txn.op;
    cp_a  : coverpoint txn.a {
      bins zero   = {8'h00};
      bins max    = {8'hFF};
      bins others = {[8'h01:8'hFE]};
    }
    cp_b  : coverpoint txn.b {
      bins zero   = {8'h00};
      bins max    = {8'hFF};
      bins others = {[8'h01:8'hFE]};
    }
    op_x_a : cross cp_op, cp_a;
  endgroup

  function new(mailbox #(alu_txn) mon2cov_mbx);
    this.mon2cov_mbx = mon2cov_mbx;
    alu_cg           = new();
  endfunction

  task run();
    forever begin
      mon2cov_mbx.get(txn);
      alu_cg.sample();
    end
  endtask

  function void report();
    $display("Functional coverage = %0.1f%%", alu_cg.get_coverage());
  endfunction

endclass
```

Changes elsewhere:

| File | Change |
|---|---|
| `alu_monitor.sv` | A second mailbox handle `mon2cov_mbx` (constructor argument); after `mon2scb_mbx.put(pending);` add `mon2cov_mbx.put(pending);` |
| `alu_env.sv` | Declare and create `mon2cov_mbx` and `alu_coverage cov;`; pass the mailbox to the monitor and to `cov`; add `cov.run();` to the first `fork` |
| `alu_test.sv` | After `env.scb.report();` add `env.cov.report();` |

The same handle is put into both mailboxes. That is safe because neither the scoreboard nor the coverage component modifies the monitor's object. Coverage is sampled from **observed** transactions, so it measures what the DUT actually received. Generator, driver, scoreboard and all tests are untouched.

### Exercise 4: a knob for idle cycles between transactions

Give the driver a setting `idle_cycles` (default 0) that inserts that many extra idle clock cycles after each transaction, and write a test that uses it.

```systemverilog
// In alu_driver: one new property and two new lines in run()
int unsigned idle_cycles = 0;

task run();
  alu_txn txn;
  reset();
  forever begin
    gen2drv_mbx.get(txn);
    drive(txn);
    num_driven++;
    txn.print("DRV");
    repeat (idle_cycles) @(vif.drv_cb);       // extra idle cycles, bus already idle
    -> drv_done;
  end
endtask
```

```systemverilog
// alu_slow_test.sv
class alu_slow_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_slow_test";
  endfunction

  virtual function void configure();
    env.gen.num_txns    = 5;
    env.drv.idle_cycles = 2;
  endfunction

endclass
```

With `idle_cycles` = 2 each transaction takes four clock cycles instead of two: the `DRV` lines appear at 35, 75, 115 and so on (40 time units apart instead of 20), and each `MON`/`SCB` pair still follows its `DRV` line by one clock. The monitor and scoreboard need no change: the monitor reacts to `valid_in` and `valid_out`, however far apart the transactions are. The default of 0 keeps every existing test's behaviour.

### Exercise 5: a corner-case test

Write a test that sends 30 transactions in which both operands are always one of `00`, `01`, `7F`, `80`, `FE`, `FF`.

```systemverilog
// alu_corner_test.sv
class alu_corner_txn extends alu_txn;

  constraint corner_c {
    a inside {8'h00, 8'h01, 8'h7F, 8'h80, 8'hFE, 8'hFF};
    b inside {8'h00, 8'h01, 8'h7F, 8'h80, 8'hFE, 8'hFF};
  }

endclass

class alu_corner_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_corner_test";
  endfunction

  virtual function void configure();
    alu_corner_txn corner_txn;
    corner_txn        = new();
    env.gen.blueprint = corner_txn;
    env.gen.num_txns  = 30;
  endfunction

endclass
```

Then add `` `include "alu_corner_test.sv" `` to the package and a branch to the `case` in `tb_top`. The new constraint is combined with the inherited `operand_c`. The two do not conflict: `operand_c` is a distribution over all values from `00` to `FF`, and `corner_c` restricts the choice to six of them, each of which the distribution allows.

### Exercise 6: read the number of transactions from the command line

Make the base test accept `+NUM=<n>`.

```systemverilog
// Replacement for alu_test::configure
virtual function void configure();
  int unsigned n;
  if ($value$plusargs("NUM=%d", n)) env.gen.num_txns = n;
  else                              env.gen.num_txns = 10;
endfunction
```

`./simv +TEST=alu_test +NUM=1000` now runs a thousand random transactions with no recompilation. The environment's drain logic needs no change, because it compares against `gen.num_sent`, the number actually sent.

### Further practice (no solutions given)

1. Change the environment to use a bounded mailbox of size 1 between generator and driver, and remove the `drv_done` handshake. Which component's code changes, and what must the driver do so that the generator is held back until the transaction has really been applied?
2. Rewrite the monitor to send two kinds of transaction (inputs observed, outputs observed) through two mailboxes, and move the pairing into the scoreboard using a queue of expected results. When is this structure better than the one used in this module?
3. Extend the driver so that it can send transactions on consecutive clock cycles with no idle cycle between them. Check, by reasoning through the timeline, that the monitor of Section 4.1 already handles this.
4. Add a mid-test reset: a thread in the test asserts `rst_n` for two cycles at a random time. List every component that must react and what it must do.
5. Introduce each of these bugs into the DUT, one at a time, and write down what the directed test's log shows: `ALU_SUB` computes `b - a`; `ALU_SHR` shifts by two; `valid_out` is delayed by two cycles instead of one; `result` is not cleared by reset.
6. Introduce each of these bugs into the testbench and observe the symptom: the monitor reuses one object; the scoreboard uses `expected = actual`; the environment creates two mailboxes for generator and driver; `configure()` is not virtual.
7. Write the complete layered testbench for a 4-bit up-counter with `enable` and synchronous `load`. Decide first what a transaction is, and where the reference model's state lives.
8. Sketch (boxes and arrows) the testbench for a DUT with two ALUs sharing one output bus. How many drivers, monitors and scoreboards are there?

## 7.6 Concepts You Must Understand Before Moving Forward

Do not start Module 10 until you can answer each of these without looking at the notes.

**Architecture**

- [ ] I can draw the layered testbench from memory and state the stimulus path and the checking path.
- [ ] I can give the one-sentence job of the generator, driver, monitor, scoreboard, environment, test and top module.
- [ ] I can list three advantages and two disadvantages of each of the direct and the layered testbench.
- [ ] I can say which components know the pin-level protocol and which never see a signal.

**Connections**

- [ ] I can explain how one mailbox handle ends up in two components, and what goes wrong if two mailboxes are created.
- [ ] I can trace the virtual interface from `tb_top` to the driver.
- [ ] I can explain why class files are included in a package and not compiled directly.
- [ ] I can explain build, connect and run, and where each happens.

**Components**

- [ ] I can explain why the generator sends a copy of the blueprint, and how the blueprint lets a test change constraints.
- [ ] I can explain why the driver waits for a clocking event before each drive and uses `<=` through the clocking block.
- [ ] I can explain why the monitor creates a new object per transaction.
- [ ] I can explain how the monitor aligns inputs and outputs across the one-cycle latency.
- [ ] I can explain why the scoreboard predicts from monitored inputs, why the model must be independent of the RTL, and why it compares with `===`.
- [ ] I can write a reference model that keeps the carry bit, and explain the `~` width trap.

**Control**

- [ ] I can explain why the environment uses `fork`...`join_any`, what happens after it returns, and what `disable fork` kills.
- [ ] I can describe a robust end-of-test condition and why it needs a timeout.
- [ ] I can add a test by extending the base test, in three different ways (knob, blueprint, generator).
- [ ] Given a scoreboard failure message, I can decide whether to suspect the DUT, the reference model or the stimulus path.
- [ ] I can describe how the scoreboard changes for a FIFO.

## 7.7 What Comes Next

Module 10 adds the two things this testbench is still missing. **Functional coverage** answers "which operations and operand corners did the random tests actually hit?" using covergroups sampled on the monitor's transactions (Exercise 3 showed the plug-in point). **Assertions** check the protocol continuously at signal level, for example that `valid_out` follows `valid_in` by exactly one cycle and that outputs are never X when valid; they live in the interface, next to the signals they watch. Module 11 then shows how UVM packages this whole architecture into a standard library.
