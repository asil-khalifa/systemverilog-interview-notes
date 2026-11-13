# OOP, IPC and Testbench Architecture Questions

These three groups go deeper into the areas where DV interviews spend most of their time. The questions are the "why" and "what if" follow-ups that come after the definitions in the basic and intermediate parts.

## OOP-Based Questions

**Q244. Explain the four pillars of OOP using a SystemVerilog testbench.**
*Encapsulation*: data and the methods that work on it are kept together in a class, and access is controlled with `local` and `protected`; the transaction's fields and its `print`, `copy` and `compare` methods are one unit. *Inheritance*: `class err_txn extends alu_txn` reuses everything in the base transaction and adds error-injection fields or constraints. *Polymorphism*: the generator holds an `alu_txn` handle; if the test puts an `err_txn` object there, calls to virtual methods such as `randomize()` and `print()` act on the extended class without any change to the generator. *Abstraction*: a `virtual class` with pure virtual methods defines what every driver must provide (`run`, `drive`) without saying how.

**Q245. A test extends the transaction and overrides `print()`, but the log still shows the base-class format. Why?**
The component calls `txn.print()` through a base-class handle and `print` was not declared `virtual` in the base class, so the handle type selects the base method. Declaring `virtual function void print();` in the base class fixes it; no change is needed in the extended class or in the caller.

**Q246. A derived class adds a method that the base class does not have. Can it be called through a base-class handle?**
No. The compiler only knows the members of the handle's type, so `b.new_method()` is a compile error even if the object is of the derived class. Downcast first: `if ($cast(d, b)) d.new_method();`. If every derived class needs the method, declare it (possibly as pure virtual) in the base class instead.

**Q247. Why is a transaction a class and not a struct?**
A class can be randomized with constraints, can carry methods (`copy`, `compare`, `print`), can be extended to create variants without editing the original, and is passed between components by handle without copying the data. A struct has none of these: no methods, no constraint blocks, no inheritance, and every assignment copies the whole value. Structs are for static bundles of signals in RTL.

**Q248. Apart from resolving name clashes, what is `this` used for?**
To pass the current object to another object, for example `scb.register(this);` or `child = new(this);` so that a child component knows its parent; to return the object from a method so calls can be chained; and to make it explicit in long methods that a name is a property and not a local variable.

**Q249. Can a class have no constructor? Can a constructor have arguments, a return type, or be virtual?**
If no `new` is written, the compiler provides an empty one that still initialises the properties and calls the base constructor. A constructor may have arguments, including default values. It has no return type (not even `void`); it implicitly returns the handle. It cannot be `virtual` or `static`, because it is called on the class, before any object exists.

**Q250. Give a practical example of encapsulation with `local` and `protected`.**

```systemverilog
class alu_scoreboard;
  local     int unsigned fail_cnt;        // only this class can change the count
  protected alu_txn      exp_q [$];       // derived scoreboards may use the queue

  function int unsigned get_fail_cnt();   // read-only access for everyone else
    return fail_cnt;
  endfunction
endclass
```

No other component can reset the error count by accident, and the internal queue can be changed to an associative array later without affecting users of the class.

**Q251. Give a practical example of abstraction.**

```systemverilog
virtual class base_driver;
  pure virtual task drive(alu_txn txn);   // every driver must implement this
  task run(mailbox #(alu_txn) mbx);       // common code written once
    alu_txn txn;
    forever begin
      mbx.get(txn);
      drive(txn);
    end
  endtask
endclass
```

The base class fixes the structure (get a transaction, drive it) and leaves the protocol-specific part to derived classes. `base_driver` cannot be constructed; a class that extends it and omits `drive` does not compile.

**Q252. What is the difference between inheritance and composition, and how do you choose?**
Inheritance is an "is-a" relationship: `err_txn` is an `alu_txn`. Composition is a "has-a" relationship: `alu_env` has a driver and a monitor as member handles. Use inheritance when the new class can be used wherever the base class is expected; use composition to build larger things out of parts. An environment that extended the driver class would be a misuse of inheritance.

**Q253. `randomize()` is called through a base-class handle that refers to a derived object. Which constraints apply?**
The constraints of the object's actual class: the base-class constraints plus those added or overridden in the derived class. `randomize()` is a built-in virtual method, so it acts on the real object. This is what makes the next question's pattern work.

**Q254. How can a test change the kind of transaction the generator produces without editing the generator?**
The generator keeps a "blueprint" handle of the base type, randomizes it and sends a copy:

```systemverilog
class alu_generator;
  alu_txn blueprint = new();
  task run();
    repeat (n) begin
      if (!blueprint.randomize()) $fatal(1, "randomize failed");
      gen2drv_mbx.put(blueprint.copy());
    end
  endtask
endclass

// in the test
class add_only_txn extends alu_txn;
  constraint add_c { op == ALU_ADD; }
endclass
...
add_only_txn t = new();
env.gen.blueprint = t;                    // base handle now refers to a derived object
```

Because `randomize()` and `copy()` are virtual, the generator now produces `add_only_txn` objects. The UVM factory automates exactly this substitution.

**Q255. What are `const` properties in a class?**
A *global constant* is initialised in its declaration, `const int MAX = 16;`, and can never be changed; it is usually also `static`. An *instance constant* is declared without a value, `const int id;`, and must be assigned exactly once, in the constructor; after that it is read-only. An instance constant is useful for an ID that must not change during the life of the object.

**Q256. Two classes each contain a handle of the other. How do you make this compile?**
With a forward type declaration before the first class: `typedef class alu_env;`. The compiler then accepts `alu_env` as a class name inside `alu_driver` before the full definition of `alu_env` appears later in the same scope.

**Q257. What is the class scope resolution operator used for?**
`class_name::member` accesses things that belong to the class and not to an object: static properties and methods (`alu_txn::count`), and types, enums and parameters declared inside the class (`packet::kind_e`). It is also used to define an `extern` method outside the class (`function void alu_txn::print();`) and, with a package name, to pick a class out of a package (`alu_tb_pkg::alu_txn`).

**Q258. What can a class not contain that a module can?**
A class cannot contain `initial` or `always` blocks, continuous assignments, module or interface instances, nets, or concurrent assertions. It can contain properties, tasks (which may consume time), functions, constraints, covergroups, immediate assertions and `fork`...`join`. Activity in a class starts only when some `initial` block in a module calls one of its tasks.

**Q259. How are two objects compared? What does `h1 == h2` test, and can a method be called on a null handle?**
`h1 == h2` is true only if both handles refer to the same object (or both are `null`); it does not look at the contents. To compare contents, write a `compare()` method that compares each field (with `===` for four-state fields). A non-static method cannot be called on a null handle. A static method can, because it does not use the object: `alu_txn t; t.get_count();` works when `get_count` is static, though `alu_txn::get_count()` is the clearer form.

## IPC-Based Questions

**Q260. Why is inter-process communication needed in a class-based testbench?**
The generator, driver, monitor and scoreboard run as separate threads at the same time, each at its own pace: the generator works in zero time, the driver follows the clock, the monitor waits for DUT outputs. They must exchange data without losing or duplicating it and must not run ahead of each other. Mailboxes move the data and block when there is nothing to do, events signal milestones, and semaphores protect shared resources.

**Q261. Why use a mailbox between the generator and the driver instead of a shared queue?**
A queue has no blocking: the driver would have to poll it (`wait (q.size() > 0)`), and two threads modifying a queue in the same time step can interfere. A mailbox's `get()` suspends the driver until an item is available and its `put()` can suspend the generator when a bounded mailbox is full, and the operations are atomic. A queue is the right choice inside one component (for example the scoreboard's list of expected results); a mailbox is the right choice between threads.

**Q262. When would you use `peek()` instead of `get()`?**
When the item must stay in the mailbox until it has been fully processed. With a mailbox of size 1, the driver can `peek()` the transaction, drive it for several clocks, and only then `get()` it to remove it. During that time the generator's next `put()` stays blocked, so the generator is throttled to the driver's speed without any extra event.

**Q263. What do `try_get()` and `try_put()` return?**
`try_put()` returns a positive value if the item was stored and 0 if the mailbox is full. `try_get()` and `try_peek()` return a positive value on success, 0 if the mailbox is empty, and a negative value if an item is present but its type does not match the argument (possible only with a non-parameterised mailbox). They never block, so they can be used inside functions.

**Q264. Describe three ways to make the generator wait until the driver has finished a transaction.**
(1) An event: the driver triggers `drv_done` after driving and the generator waits for it after each `put()`. (2) A bounded mailbox of size 1 together with `peek()` in the driver, as in Q262. (3) A second mailbox in the opposite direction, through which the driver returns the transaction (or a response) and the generator does a blocking `get()` on it. UVM's `get_next_item()` and `item_done()` are a standardised form of this handshake.

**Q265. What is `wait_order`?**
A statement that waits for several events to be triggered in a given order: `wait_order (req, gnt, done) $display("ok"); else $error("wrong order");`. It passes when all the events have occurred in that sequence and fails if one of them is triggered out of order. It is a compact protocol-order check.

**Q266. How do you wait for any one of several events, and for all of them?**
Any one: `@(e1 or e2);` (also written `@(e1, e2)`), or a `fork` with one waiting branch per event followed by `join_any`. All of them, in any order and at different times: a `fork`...`join` with one branch per event, each doing `wait (e.triggered)` or `@e`. `wait (e1.triggered && e2.triggered)` works only if both are triggered in the same time step, because `triggered` is cleared when time advances.

**Q267. What is a race condition between testbench threads? Give an example and the fix.**
A race is when the result depends on the order in which the simulator runs threads that are ready at the same time. Example: one thread does `count = count + 1;` and another prints `count` in the same time step; the printed value depends on which runs first. Fixes: communicate through a mailbox instead of a shared variable, protect the shared variable with a semaphore, separate the threads in time with clocking blocks, or use `wait (e.triggered)` or `->>` for events.

**Q268. What is a deadlock? Give an example with semaphores.**
A deadlock is when two or more threads each wait for something that only another of them can provide, so none can continue. Example: thread A takes semaphore `s1` and then asks for `s2`; thread B takes `s2` and then asks for `s1`. Each holds what the other needs. Prevention: always acquire resources in the same order, take both keys in one call where possible, and add a timeout around blocking calls so that a deadlock is reported instead of hanging silently.

**Q269. A task starts a thread with `fork`...`join_none` and returns. What happens to the thread?**
It keeps running. A thread started with `join_none` or left behind by `join_any` is not tied to the lifetime of the task that started it; it ends when its own statements finish, when it is killed by `disable fork`, `disable` or `process.kill()`, or when the simulation ends.

**Q270. When does a simulation end if there are threads still waiting?**
Simulation ends when `$finish` is called or when no further events are scheduled. A thread blocked forever on a mailbox or an event does not keep the simulation alive by itself: if nothing else is scheduled (no clock, no pending delays), the simulation stops. With a free-running clock generator there is always a next event, so a testbench with a hung thread runs forever unless a watchdog calls `$finish`.

**Q271. What is the danger of `disable task_name` or `disable block_name`?**
It stops every active execution of that named task or block, not only the one started by the caller. If two threads are both inside the same task and one of them executes `disable` on the task name, both are terminated. For killing specific threads use `disable fork` inside an isolating `fork`...`join`, or a `process` handle and `kill()`.

**Q272. Give an example where a semaphore with more than one key is needed.**
A DUT that can service at most two requests at a time, driven by four requesting threads: `semaphore slots = new(2);` and each thread does `slots.get(1); ... slots.put(1);`, so at most two are active. A thread can also ask for several keys at once, `slots.get(2)`, to reserve the whole resource, and waits until both keys are free.

**Q273. How is one event shared between two class objects?**
An event variable is a handle. Declare the event in the environment and pass it to both constructors, `gen = new(mbx, done); drv = new(mbx, done);`, each class storing it in its own `event` member; both members then refer to the same event object. Alternatively one object can assign the other's event directly: `drv.drv_done = gen.drv_done;`. If each class merely declares its own event and nothing connects them, they are two unrelated events.

**Q274. At the end of a test the generator is finished. Why must the test not stop immediately, and how does it wait correctly?**
Transactions may still be waiting in `gen2drv_mbx`, in flight inside the DUT, or waiting in `mon2scb_mbx`. Stopping at once would skip their checks. The test should wait until the driver has driven everything (a count or `drv_done`), then until the scoreboard has compared the expected number of transactions (or its expected queue is empty), with a timeout in case the DUT never responds. A fixed "drain time" delay is a common but weaker substitute.

**Q275. What is the difference between `#delay`, `@(event)` and `wait (condition)`?**
`#n` suspends the process for a fixed amount of simulation time. `@(x)` suspends until the next change (or the named edge) of `x`; it is edge-sensitive and always waits, even if `x` already has the desired value. `wait (cond)` is level-sensitive: it continues immediately if the condition is already true and otherwise suspends until it becomes true. `@(posedge ready)` misses the case where `ready` is already high; `wait (ready)` does not.

## Layered Testbench Architecture Questions

**Q276. Draw the layered testbench and describe the flow of one transaction.**

```text
   +-----------------------------  alu_test  --------------------------------+
   |  +---------------------------  alu_env  -----------------------------+  |
   |  |                                                                   |  |
   |  |  alu_generator --gen2drv_mbx--> alu_driver                        |  |
   |  |                                     |  vif.drv_cb                 |  |
   |  |                                     v                             |  |
   |  |                                 [ alu_if ] <----> DUT (alu)       |  |
   |  |                                     |  vif.mon_cb                 |  |
   |  |                                     v                             |  |
   |  |  alu_scoreboard <--mon2scb_mbx-- alu_monitor                      |  |
   |  |   (predict + compare)                                             |  |
   |  +-------------------------------------------------------------------+  |
   +-------------------------------------------------------------------------+
        tb_top: clock, reset, interface instance, DUT instance, test = new(vif)
```

The generator creates and randomizes an `alu_txn` and puts it in `gen2drv_mbx`. The driver gets it and, on the next clocking event, drives `a`, `b`, `op` and `valid_in` through the virtual interface. The DUT computes and one clock later presents `result` with `valid_out`. The monitor samples the inputs and the output from the interface, builds a new `alu_txn` and puts it in `mon2scb_mbx`. The scoreboard gets it, computes the expected result from the observed `a`, `b` and `op`, compares it with the observed `result` and records pass or fail.

**Q277. Why is a layered testbench preferred to one flat testbench module?**
Each layer has one job and a defined connection to its neighbours, so it can be written, debugged, replaced and reused independently. A new test changes only the test layer; a protocol change touches only the driver and monitor; the checking is independent of how stimulus was created. A flat testbench mixes stimulus, timing and checking, so every change risks breaking everything and nothing can be reused in another project or at chip level.

**Q278. Why do the components exchange transactions through mailboxes instead of calling each other's methods?**
Mailboxes decouple the components: the generator does not need a handle to the driver, does not depend on its method names, and the two can run at different speeds, the mailbox absorbing the difference. A component can be replaced, or a second consumer added, without touching the producer. UVM's TLM ports are a more formal version of the same decoupling.

**Q279. Why does the scoreboard take its data from the monitor and not directly from the generator or driver?**
The monitor reports what actually happened on the DUT pins. If the driver has a bug (wrong timing, wrong bit order), the generator's copy of the transaction would not match what the DUT received, and the scoreboard would either report false errors or, worse, hide real ones. Taking both stimulus and response from the monitor also lets the same scoreboard work when the block is driven by other RTL at chip level, where no generator exists.

**Q280. Where is the expected result computed?**
In a reference model (predictor), normally a function or class inside or next to the scoreboard. It takes the inputs observed by the monitor and computes what a correct DUT should output, written from the specification and independently of the RTL: for the ALU, a `case (op)` that computes a 9-bit result. Complex models are sometimes written in C and called through DPI. The model must not copy the RTL code, or it will contain the same bugs.

**Q281. In what order does the environment build, connect and start its components?**
Build: construct the mailboxes and events, then construct each component. Connect: give the generator and driver the same `gen2drv_mbx` handle, the monitor and scoreboard the same `mon2scb_mbx` handle, and the driver and monitor the virtual interface. Run: start every component's `run()` task in parallel with `fork`. The shared objects are created in the environment because it is the only place that knows both ends of each connection.

**Q282. How does the test know when to end?**
The generator triggers `gen_done` (or simply returns) after producing the required number of transactions. The environment then waits until the scoreboard has checked that number of transactions, protected by a timeout, and calls the scoreboard's report function and `$finish`. The forever-running driver, monitor and scoreboard threads are started with `join_none` or left behind by `join_any`, so they do not prevent the end. In UVM the same decision is made with objections.

```systemverilog
task run();
  fork
    gen.run();  drv.run();  mon.run();  scb.run();
  join_any                                  // gen.run() is the only one that returns
  fork
    wait (scb.checked_cnt == gen.num_txn);
    #100000 $error("timeout: checked %0d of %0d", scb.checked_cnt, gen.num_txn);
  join_any
  disable fork;                             // also stops drv, mon and scb: intended here
  scb.report();
  $finish;
endtask
```

**Q283. How do you add a new test without changing the environment?**
Write a new test class (or extend a base test) that changes only configuration: the number of transactions, constraint modes, an extended transaction placed in the generator's blueprint handle (Q254), or a different generator sequence. The environment, driver, monitor and scoreboard stay untouched. If a new test needs edits inside the driver, the testbench layering is wrong.

**Q284. How should the components behave when reset is applied in the middle of a test?**
The driver stops driving, sets the interface to its idle values and discards or restarts the current transaction. The monitor abandons any partly collected transaction. The scoreboard flushes its queue of expected results, because the DUT has lost its state and those outputs will never appear. Each component watches `rst_n`, typically with a `fork` of the normal activity and a reset-wait, followed by `disable fork` and a restart after reset is released.

**Q285. What is the difference between an active and a passive agent, and why does it matter for reuse?**
An agent groups the driver, monitor (and sequencer) for one interface. In active mode it drives and monitors; in passive mode it only monitors. At block level the agent on the DUT's inputs is active. At chip level those inputs are driven by another RTL block, so the same agent is switched to passive: the monitor, coverage and scoreboard are reused unchanged while the driver is disabled. This is the main reason the driver and monitor are kept strictly separate.

**Q286. The DUT may return responses in a different order from the requests. How does the scoreboard handle it?**
Each transaction carries an identifier (a tag, or the address). The scoreboard stores expected transactions in an associative array indexed by that ID instead of a queue: `alu_txn exp [int unsigned];`. When a response arrives, it looks up the entry with the response's ID, compares, and deletes the entry. A response whose ID is not in the array is an error, and entries left at the end of the test are missing responses.

**Q287. The DUT has a pipeline latency of several cycles and outputs stay in order. How does the scoreboard match inputs to outputs?**
With a queue used as a FIFO. When the monitor reports accepted inputs, the scoreboard computes the expected result and pushes it to the back of the queue. When the monitor reports an output, the scoreboard pops the front of the queue and compares. The latency does not need to be known; only the order matters. If the latency itself is a requirement, it is checked separately, by a timestamp in the transaction or by an assertion.

**Q288. Where is functional coverage sampled, and why not in the generator?**
In the monitor, or in a coverage component fed by the monitor, when a complete transaction has been observed on the interface. Coverage must record what the DUT actually experienced. Sampling in the generator would count transactions that were never driven (for example dropped because of reset or a driver bug) and could not include response information such as the carry bit of the result.

**Q289. What must a driver do besides copying transaction fields to signals?**
Follow the protocol timing: wait for reset to finish, drive only on the correct clock edge through the clocking block, assert `valid_in` for the right number of cycles, return the signals to idle values between transactions, wait for a ready or acknowledge signal if the protocol has back-pressure, and insert the delays requested by the transaction (idle cycles). It must also tell the generator when it is done if a handshake is used.

**Q290. What belongs in `tb_top` and what does not?**
`tb_top` is the static part: clock and reset generation, the interface instance, the DUT instance connected to the interface, the construction of the test with the virtual interface, the call to `test.run()`, and waveform dumping. It does not contain stimulus, checking or anything specific to one test. Everything dynamic is in classes inside the package `alu_tb_pkg`.

**Q291. A test fails in a layered testbench. How do you find which layer is at fault?**
Follow one transaction through the layers using its `id`. Print the transaction when the generator creates it, when the driver drives it, when the monitor observes it and when the scoreboard compares it. If generator and driver agree but the monitor shows different inputs, the fault is in the driver, the monitor or the interface connection; check the waveform at the interface. If the inputs agree everywhere and the result differs, compute the correct answer by hand: if the scoreboard's expectation is wrong the reference model is at fault, otherwise the DUT is.
