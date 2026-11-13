# Part 3: The Stimulus Side: Generator and Driver

## 3.1 The Generator

### In plain English

The generator is the component that decides **what** to send to the DUT. It produces a stream of transaction objects, usually randomized, and hands them one at a time to the driver. It knows nothing about clocks, pins or timing. If you deleted the DUT and the interface, the generator would still compile.

### Technical definition

A generator is a class that creates transaction objects, randomizes them (subject to the constraints in the transaction class and any the test adds), and passes them to the driver through a mailbox. It belongs to the scenario layer. In UVM the same role is played by a *sequence*.

### Why it is a separate component

| If stimulus generation were inside the driver... | With a separate generator |
|---|---|
| A new kind of stimulus would mean editing the driver | A test changes or replaces the generator; the driver is untouched |
| The driver could not be reused with a different stimulus source | The driver drives whatever arrives in its mailbox |
| Random and directed stimulus would need two drivers | Two generators (or two tests), one driver |

### Why a mailbox between generator and driver

The generator works in zero simulation time: it can create a thousand transactions without a single clock edge passing. The driver needs two clock cycles per transaction. Two processes running at different speeds need a channel that

1. carries an object from one to the other,
2. makes the receiver wait when nothing is available, and
3. keeps the two sides from knowing about each other.

A mailbox does all three (Module 7). `put()` places a handle in the mailbox. `get()` removes one, and blocks the caller while the mailbox is empty. The generator never calls a driver method and the driver never calls a generator method; each only knows the mailbox.

### Keeping the generator in step with the driver

With an unbounded mailbox, `put()` never blocks, so a generator that just loops would create all its transactions at time 0. That works, but it has two drawbacks: all objects exist in memory at once, and the generator cannot react to anything that happens during the test. Three common ways to pace the generator:

| Method | How | Used here? |
|---|---|---|
| Handshake event | Generator waits for an event (`drv_done`) that the driver triggers after each transaction | Yes |
| Bounded mailbox | `new(1)`: `put()` blocks while the mailbox is full, so the generator is at most one transaction ahead | Alternative |
| No pacing | Generate everything at time 0 into an unbounded mailbox | Simplest, common in small examples |

### The blueprint pattern

The obvious generator loop constructs a new transaction each time:

```systemverilog
repeat (num_txns) begin
  txn = new();                    // the class of the object is fixed here: alu_txn
  if (!txn.randomize()) ...
  gen2drv_mbx.put(txn);
end
```

The weakness is the line `txn = new();`. It hard-codes the class `alu_txn` inside the generator. A test that wants a transaction with extra constraints would have to edit the generator.

The **blueprint pattern** removes that. The generator owns one object, the blueprint. It randomizes the *blueprint* each time and sends a *copy*. A test can replace the blueprint with an object of a derived class before the run starts, and from then on every randomization obeys the derived class's constraints, with no change to the generator.

```text
   test (optional):  gen.blueprint = <object of a class derived from alu_txn>

   generator loop:   blueprint.randomize()    <- constraints of the object's ACTUAL class
                     txn = blueprint.copy()   <- a fresh object for this transaction
                     put(txn)
```

Section 6.6 uses this to build `alu_arith_test`.

### The file

```systemverilog file=alu_generator.sv
class alu_generator;

  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  event              gen_done;
  alu_txn            blueprint;
  int unsigned       num_txns = 10;
  int unsigned       num_sent;

  function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done, event gen_done);
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
    this.gen_done    = gen_done;
    blueprint        = new();
  endfunction

  // Send one transaction to the driver and wait until the driver has applied it
  task send(alu_txn txn);
    num_sent++;
    txn.id = num_sent;
    gen2drv_mbx.put(txn);
    txn.print("GEN");
    @(drv_done);
  endtask

  virtual task run();
    repeat (num_txns) begin
      if (!blueprint.randomize()) $fatal(1, "GEN: randomization failed");
      send(blueprint.copy());
    end
    -> gen_done;
  endtask

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `mailbox #(alu_txn) gen2drv_mbx;` | A handle to a parameterized mailbox that can only carry `alu_txn` objects (or objects of classes derived from it). The compiler rejects an attempt to put anything else in. The generator does **not** create the mailbox; it receives the handle. |
| `event drv_done;` | Handle to the event the driver triggers when it has finished applying a transaction. |
| `event gen_done;` | Handle to an event the generator triggers once, after the last transaction. |
| `alu_txn blueprint;` | The object that is randomized. Public, so that a test can replace it. |
| `int unsigned num_txns = 10;` | How many transactions to generate. A default is given; the test overrides it. |
| `int unsigned num_sent;` | How many have actually been sent. The environment uses it at the end of the test. |
| `function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done, event gen_done);` | The constructor receives the shared handles. This is the "connect" step. |
| `this.gen2drv_mbx = gen2drv_mbx;` | The argument has the same name as the class property; `this.` selects the property (Module 4). After this line the generator and whoever else holds this handle share one mailbox. |
| `this.drv_done = drv_done;` | Assigning an event to an event makes both names refer to the same event. |
| `blueprint = new();` | A default blueprint of the base class, so the generator works even if the test supplies nothing. |
| `task send(alu_txn txn);` | A task, because it waits. Both `run()` here and the directed generator in Section 6.4 call it. |
| `num_sent++; txn.id = num_sent;` | Numbers the transactions 1, 2, 3... |
| `gen2drv_mbx.put(txn);` | Places the handle in the mailbox. The mailbox is unbounded, so this never blocks. |
| `txn.print("GEN");` | Log line. |
| `@(drv_done);` | Blocks until the driver triggers the event. The generator is now idle until the transaction has been applied to the DUT. |
| `virtual task run();` | `virtual`, so that a derived generator can replace the stimulus loop (Section 6.4). |
| `if (!blueprint.randomize()) $fatal(...)` | `randomize()` returns 0 if the constraints cannot be satisfied. The return value must always be checked; an unchecked failure leaves the old values in the object and the test carries on with stale data. `$fatal` ends the simulation because nothing useful can follow. |
| `send(blueprint.copy());` | A copy is sent, never the blueprint itself. |
| `-> gen_done;` | Announces that all stimulus has been generated. Then `run()` returns, which is what ends the `fork`...`join_any` in the environment (Section 5.1). |

### Why a copy is sent and not the blueprint

A mailbox stores **handles**, not objects. If the generator put the blueprint itself into the mailbox, every entry would be a handle to the same single object, and the next `randomize()` would overwrite the values of the transaction the driver is still using.

```text
   WRONG: put(blueprint) three times, generator not paced

      mailbox:  [ handle ] [ handle ] [ handle ]
                     \         |         /
                      \        |        /
                       v       v       v
                     +-------------------+
                     |  ONE object       |     the driver gets three handles
                     |  a, b, op = values|     to the same object and drives
                     |  of the LAST      |     the last values three times
                     |  randomize()      |
                     +-------------------+

   RIGHT: put(blueprint.copy()) three times

      mailbox:  [ handle ] [ handle ] [ handle ]
                    |          |          |
                    v          v          v
                +-------+  +-------+  +-------+
                | txn 1 |  | txn 2 |  | txn 3 |      three independent objects
                +-------+  +-------+  +-------+
```

With the `drv_done` handshake in this generator the overwrite would not actually happen (the generator waits before randomizing again), but the driver, the log and any later consumer would still all be holding the one blueprint object. Sending a copy is the habit that is always safe.

### Is there a race on drv_done?

An event trigger `->` is only seen by processes that are already waiting. If the driver triggered `drv_done` before the generator reached `@(drv_done)`, the generator would wait forever. Here that cannot happen: after `put()` the generator reaches `@(drv_done)` without any time passing, and the driver needs two clock edges after its `get()` before it triggers the event. The trigger always comes at least one clock edge after the generator has started to wait.

> **Common mistake:** Forgetting to check the return value of `randomize()`. With conflicting constraints the call fails, returns 0, and leaves the variables unchanged. The test then appears to run normally, sending the same transaction over and over.

> **Common mistake:** Calling `new()` on the mailbox inside the generator. The generator would then own a private mailbox that nobody reads, and the driver would wait forever on a different one. Shared objects are created once, in the environment.

> **Verification application:** In a real environment the generator is the most frequently varied component. There is typically a library of generators (in UVM, sequences): one random, one for error injection, one that replays a recorded trace, one per directed scenario. All of them feed the same driver.

### Interview questions

**Q1. What is a generator?**
The component that creates transaction objects, randomizes them, and sends them to the driver through a mailbox. It works at transaction level and has no access to the interface.

**Q2. Why does the generator not drive the DUT directly?**
Because deciding what to send and knowing how to put it on the pins are separate concerns. Keeping them apart lets the stimulus be changed without touching the driver, and lets the driver be reused with any stimulus source.

**Q3. Why do you create a new object (or a copy) for every transaction?**
A mailbox holds handles. If the same object were put repeatedly, all the handles would point to one object whose contents keep changing with every `randomize()`, so earlier transactions would be overwritten before the driver used them.

**Q4. What is the blueprint pattern and what problem does it solve?**
The generator randomizes one template object and sends copies of it. Because the template is a handle that a test may replace with an object of a derived class, a test can change the constraints (or add fields) without modifying the generator code. It removes the hard-coded `new()` of a specific class from the generator.

**Q5. How does the generator know when to produce the next transaction?**
In this testbench it waits on the event `drv_done`, which the driver triggers after each transaction. Alternatives are a bounded mailbox of size 1, whose `put()` blocks until the driver has taken the previous item, or no pacing at all.

**Q6. What happens if `randomize()` fails?**
It returns 0 and the random variables keep their previous values. The generator must check the return value and stop the test with a clear message.

**Q7. Does the generator consume simulation time?**
Not by itself. Creating and randomizing objects takes zero simulation time. It only waits because of the handshake with the driver.

**Q8. How does the generator signal that it has finished?**
Its `run()` task returns, which ends the `fork`...`join_any` in the environment, and it triggers the event `gen_done` for any component that wants to wait for that explicitly.

## 3.2 The Driver

### In plain English

The driver is the component that knows **how** to talk to the DUT. It takes one transaction at a time from the mailbox and turns it into the right signal values at the right clock edges. It is the only component that writes to the DUT's input pins.

### Technical definition

A driver is a class that receives transactions from the generator through a mailbox and converts each one into pin-level activity on the DUT inputs, following the DUT's protocol and synchronised to the clock, through a virtual interface. It belongs to the command layer. In UVM it is a `uvm_driver`; a driver with this role is also called a bus functional model (BFM).

### What the driver does and does not do

| The driver does | The driver does not |
|---|---|
| Get the next transaction from the mailbox | Create or randomize transactions |
| Wait for the correct clock edge | Decide what data to send |
| Drive `valid_in`, `a`, `b`, `op` for the right number of cycles | Check DUT outputs |
| Return the bus to idle afterwards | Predict results |
| Drive idle values during and after reset | Generate the clock or the reset |
| Tell the generator when it is done (`drv_done`) | Send anything to the scoreboard |

> **Interview trap:** "The driver already knows what it drove. Why not have the driver send the transaction to the scoreboard, and save writing a monitor?" Because then the testbench checks what it *intended* to drive, not what actually reached the DUT. A bug in the driver, in the interface connections or in the protocol timing would be invisible. Section 4.1 returns to this.

### The protocol the driver implements

For one transaction the ALU needs `valid_in` high, with stable operands, across exactly one rising clock edge:

```text
                 edge E1          edge E2          edge E3
   clk        ______|‾‾‾‾‾‾|______|‾‾‾‾‾‾|______|‾‾‾‾‾‾|______

   driver:    drive txn at E1     drive idle at E2
              (appears E1 + 1)    (appears E2 + 1)

   valid_in   ________|‾‾‾‾‾‾‾‾‾‾‾‾‾|__________________________
   a, b, op   --------<   txn values  ...  held  ...  ----------
                                    ^
                                    DUT samples the transaction at E2
```

The driver therefore needs two clocking events per transaction: one to start driving, and one at which the DUT samples and the driver removes `valid_in`.

### How the driver reaches the pins

Recall from Section 2.4:

- `@(vif.drv_cb);` waits for the next rising edge of the clock.
- `vif.drv_cb.valid_in <= 1'b1;` is a synchronous drive. Executed at an edge, it changes the signal one time unit after that edge.

All driving goes through the clocking block. The driver never assigns to `vif.valid_in` directly.

### The file

```systemverilog file=alu_driver.sv
class alu_driver;

  virtual alu_if     vif;
  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  int unsigned       num_driven;

  function new(virtual alu_if vif, mailbox #(alu_txn) gen2drv_mbx, event drv_done);
    this.vif         = vif;
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
  endfunction

  // Put the bus into its idle state, then wait until reset has been released
  task reset();
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b0;
    vif.drv_cb.a        <= '0;
    vif.drv_cb.b        <= '0;
    vif.drv_cb.op       <= ALU_ADD;
    wait (vif.rst_n === 1'b1);
  endtask

  // Apply one transaction: valid_in is high across exactly one rising edge
  task drive(alu_txn txn);
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b1;
    vif.drv_cb.a        <= txn.a;
    vif.drv_cb.b        <= txn.b;
    vif.drv_cb.op       <= txn.op;
    @(vif.drv_cb);                      // the DUT samples the transaction at this edge
    vif.drv_cb.valid_in <= 1'b0;
  endtask

  task run();
    alu_txn txn;
    reset();
    forever begin
      gen2drv_mbx.get(txn);
      drive(txn);
      num_driven++;
      txn.print("DRV");
      -> drv_done;
    end
  endtask

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `virtual alu_if vif;` | Handle to the interface instance. Null until the constructor assigns it. |
| `mailbox #(alu_txn) gen2drv_mbx;` | The same mailbox the generator writes to; the handle arrives through the constructor. |
| `event drv_done;` | The same event the generator waits on. |
| `int unsigned num_driven;` | A counter, useful when debugging a hung test ("how far did the driver get?"). |
| `function new(virtual alu_if vif, ...)` | The constructor stores the three shared handles. Nothing else: no driving, no waiting. A constructor is a function and cannot consume time. |
| `task reset();` | Called once at the start of `run()`. |
| `@(vif.drv_cb);` (in `reset`) | Waits for the first rising clock edge. Clocking block drives are tied to clocking events, so the driver aligns itself to an edge before its first drive. |
| `vif.drv_cb.valid_in <= 1'b0;` and the next three lines | Idle values: nothing valid, operands zero, a legal opcode. They appear on the signals one time unit after the edge. From then on the DUT inputs are never X. |
| `wait (vif.rst_n === 1'b1);` | Level-sensitive wait until reset is released. If reset is already released, it does not block. `===` is used so that an X on `rst_n` does not count as released. |
| `task drive(alu_txn txn);` | Converts one transaction into pin activity. This task **is** the protocol. If the protocol changes, this is the code that changes. |
| `@(vif.drv_cb);` (first in `drive`) | Aligns to a clock edge. `get()` in `run()` may have returned at any time, so the driver must synchronise before driving. |
| `vif.drv_cb.valid_in <= 1'b1;` and three more | The transaction's fields are driven onto the pins. They change one time unit after this edge. |
| `@(vif.drv_cb);` (second) | One clock later. At this edge the DUT's flip-flops sample `valid_in` = 1 and the operands. |
| `vif.drv_cb.valid_in <= 1'b0;` | Removes `valid_in` one time unit after the sampling edge. The operands are left as they are; the DUT ignores them when `valid_in` is 0. |
| `alu_txn txn;` (in `run`) | A local handle. No `new()`: the driver does not create transactions, it receives them. |
| `reset();` | Idle the bus and wait for reset before taking any transaction. |
| `forever begin` | The driver never finishes by itself. The environment ends it (Section 5.1). |
| `gen2drv_mbx.get(txn);` | Blocks until a transaction is available, then removes it from the mailbox and stores its handle in `txn`. |
| `drive(txn);` | Takes two clock edges. |
| `txn.print("DRV");` | Printed at the edge where the DUT sampled the transaction. |
| `-> drv_done;` | Wakes the generator, which then produces the next transaction. |

### Step-by-step execution for the first transaction

With rising clock edges at 5, 15, 25... and reset released at time 20 (Section 5.4):

| Time | Driver | Signals |
|---|---|---|
| 0 | `run()` starts, enters `reset()`, waits for a clock edge | `valid_in`, `a`, `b`, `op` are X (never driven yet); DUT is held in reset |
| 5 | Edge. Schedules the idle values | |
| 6 | | `valid_in` = 0, `a` = 0, `b` = 0, `op` = `ALU_ADD` |
| 6 to 20 | Blocked in `wait (vif.rst_n === 1'b1)` | |
| 20 | Reset released; `reset()` returns. `get()` returns at once: the generator put transaction 1 in the mailbox at time 0. `drive()` starts and waits for an edge | |
| 25 | Edge. Schedules `valid_in` = 1 and the operands | |
| 26 | | `valid_in` = 1, operands of transaction 1 |
| 35 | Edge: the DUT samples the transaction. Driver schedules `valid_in` = 0, prints, triggers `drv_done`, loops to `get()` | |
| 35 | (same time step) Generator wakes, sends transaction 2. Driver's `get()` returns; `drive()` waits for an edge | |
| 36 | | `valid_in` = 0 |
| 45 | Edge. Schedules transaction 2 | |
| 46 | | `valid_in` = 1, operands of transaction 2 |
| 55 | Edge: the DUT samples transaction 2 | |

So one transaction is applied every two clock cycles: one cycle with `valid_in` high, one idle cycle.

### Why the first statement of drive() is a clock wait

Suppose `drive()` drove immediately and only then waited for an edge:

```systemverilog
// Fragile version
vif.drv_cb.valid_in <= 1'b1;      // (1) executed whenever get() happened to return
...
@(vif.drv_cb);
vif.drv_cb.valid_in <= 1'b0;      // (2)
```

If `get()` returns between two clock edges, drive (1) is not at a clocking event. The standard says such a drive is processed as if it had been executed at the next clocking event. Drive (2) is executed exactly at that next event. Both drives then apply to `valid_in` at the same time, the later one wins, and `valid_in` never goes high: the transaction is silently lost. Waiting for the clocking event first guarantees that every drive is executed at an edge, and that two drives to the same signal are always at different edges.

### Differences between generator and driver

| Aspect | Generator | Driver |
|---|---|---|
| Layer | Scenario | Command |
| Works with | Transaction objects only | Transactions in, signals out |
| Knows the pin protocol | No | Yes; it implements it |
| Has a virtual interface | No | Yes |
| Uses the clock | No | Yes, through the clocking block |
| Creates transactions | Yes | No |
| Mailbox operation | `put()` | `get()` |
| Finishes by itself | Yes, after `num_txns` | No, `forever` loop |
| Changed when | A new scenario is needed | The protocol changes |
| UVM equivalent | Sequence | Driver |

> **Common mistake:** Driving DUT inputs with plain blocking assignments at the active clock edge, for example `@(posedge vif.clk); vif.valid_in = 1;`. The DUT's `always_ff` is triggered by the same edge. Whether the DUT sees the old or the new value depends on which process the simulator runs first: a race. The result can differ between simulators, or change when an unrelated line is added. Driving through a clocking block (or, in simple benches, with a nonblocking assignment or on the opposite edge) removes the race.

> **Common mistake:** Using `peek()` instead of `get()`. `peek()` copies the handle but leaves the transaction in the mailbox, so the driver would drive the first transaction forever.

> **Common mistake:** Leaving the DUT inputs undriven (X) after reset because the driver only starts driving when the first transaction arrives. The DUT may then sample X on `valid_in`. A driver should drive idle values first.

> **Verification application:** A driver for a protocol with back-pressure adds one more step: after asserting `valid`, it keeps the signals stable until it samples `ready` high through the clocking block (`while (!vif.drv_cb.ready) @(vif.drv_cb);`). That is the reason `drv_cb` also contains inputs.

### Interview questions

**Q1. What is a driver?**
The component that takes transactions from the generator through a mailbox and drives the DUT's input pins according to the protocol, synchronised to the clock, through a virtual interface.

**Q2. How does the driver access the DUT signals?**
Through a virtual interface handle that is passed down from the top module at construction. It drives through the interface's clocking block with nonblocking (synchronous) drives.

**Q3. Why does the driver use a clocking block?**
To avoid races with the DUT. The clocking block drives outputs a fixed skew after the clock edge and samples inputs just before it, so the DUT never samples a signal at the same instant the driver changes it.

**Q4. What does the driver do when the mailbox is empty?**
`get()` blocks, so the driver simply waits. The bus stays in the idle state it was left in (`valid_in` = 0).

**Q5. What is the difference between `get()` and `peek()` in the driver?**
`get()` removes the transaction from the mailbox. `peek()` returns a handle to it but leaves it there. A driver uses `get()` so that each transaction is driven once. (Some drivers `peek()`, drive, then `get()`, so that the item stays in the mailbox while it is in progress; with a bounded mailbox of size 1, that holds back the generator without needing an event.)

**Q6. How does the driver tell the generator that a transaction is finished?**
It triggers the shared event `drv_done` after the DUT has sampled the transaction.

**Q7. Does the driver create transaction objects?**
No. It declares a handle and receives objects through the mailbox.

**Q8. What should the driver do during reset?**
Drive the inputs to their idle values and not start any transaction until reset is released.

**Q9. Why is the driver's `run()` a `forever` loop? How does it stop?**
The driver does not know how many transactions the test will send; that is the test's decision. It keeps serving the mailbox until the environment ends the simulation phase, here by `disable fork` after the scoreboard has checked everything.

**Q10. If the protocol changed so that `valid_in` had to be held for two cycles, which files would change?**
Only `alu_driver.sv` (the `drive()` task) and, because the pairing of inputs and outputs is protocol knowledge too, `alu_monitor.sv`. The generator, the scoreboard, the environment and every test stay as they are.
