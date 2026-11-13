# Advanced Questions

These questions are asked to candidates who answered the basics well. They probe the simulation scheduler, the constraint solver, the details of the object model, and the sampling rules of assertions and coverage.

## Scheduling and Timing

**Q111. What are the event regions of a SystemVerilog time step?**
Within one time step the simulator processes events in a fixed order of regions:

```text
   from previous time step
            |
        Preponed      sample values for concurrent assertions and #1step inputs
            |
   +--->  Active      blocking assignments, continuous assignments, RHS of
   |        |         nonblocking assignments, $display, module code
   |     Inactive     statements delayed with #0
   |        |
   |       NBA        nonblocking assignment updates
   |        |         (new events go back to Active)
   |    Observed      concurrent assertions are evaluated
   |        |
   |    Reactive      program block code, assertion action blocks
   |        |
   |   Re-Inactive    #0 in programs
   |        |
   +---  Re-NBA       nonblocking assignments from programs, clocking block drives
            |
        Postponed     $strobe, $monitor
            |
     to next time step
```

The loop Active → Inactive → NBA repeats until no events remain, then the Observed and Reactive regions run; if they create new design events the simulator goes back to Active. The purpose is to separate design activity (Active, NBA) from testbench and assertion activity (Observed, Reactive) so that the testbench sees settled values.

**Q112. Why do nonblocking assignments prevent races in sequential RTL?**
Two flip-flops clocked by the same edge are two `always_ff` blocks that the simulator may execute in either order. With blocking assignments, the second block would read the value already updated by the first. With nonblocking assignments, every right-hand side is evaluated in the Active region using the old values, and all left-hand sides are updated afterwards in the NBA region, so the order of execution of the blocks does not matter. This matches real hardware, where all flip-flops sample at the edge and change after it.

**Q113. Why is there a race between a testbench and the DUT, and how does a clocking block remove it?**
If the testbench does `@(posedge clk); a = value;` then, in the Active region of the clock edge, both the DUT's `always_ff` (which samples `a`) and the testbench assignment are scheduled, in an order the language does not define. The DUT may capture the old or the new value. Sampling a DUT output at the edge has the same problem. A clocking block fixes both directions: inputs are sampled with skew `#1step`, that is in the Preponed region, before anything changes at the edge; outputs are driven in the Re-NBA region, after the design has sampled. The testbench therefore behaves like a flip-flop connected to the DUT.

**Q114. What does `#0` do, and why is it discouraged?**
`#0` suspends the process and reschedules it in the Inactive region of the same time step, so it resumes after all currently active events. It is sometimes used to "let the other process go first". It is discouraged because it only moves the race: if two processes both use `#0`, the order is undefined again, and code that depends on it breaks when unrelated code changes. Use nonblocking assignments, clocking blocks, `wait (e.triggered)` or `->>` instead.

**Q115. What is `#1step`?**
A special delay meaning "one unit of the global time precision, just before the current time step". As an input skew it means the value is taken from the Preponed region of the time step containing the clock event, which is the value the signal had at the end of the previous time step. It is the default input skew of a clocking block and is also how concurrent assertions sample their signals.

**Q116. In which regions are concurrent assertions sampled, evaluated and reported?**
The signals are sampled in the Preponed region. The property is evaluated in the Observed region, after the design has settled. The pass and fail action blocks execute in the Reactive region. A consequence: an assertion clocked on `posedge clk` sees the values from just before the edge, not the values assigned by the flip-flops at that edge.

**Q117. What do these print, and why?**

```systemverilog
initial begin
  x = 1;
  x <= 2;
  $display("display: %0d", x);
  $strobe ("strobe : %0d", x);
end
```

`display: 1` then `strobe : 2`. `$display` runs in the Active region, before the nonblocking update has happened. `$strobe` prints in the Postponed region, after the NBA region has set `x` to 2. This is why `$strobe` or `$monitor` is used to print the final values of a time step.

**Q118. What is the difference between `@(vif.drv_cb)` and `@(posedge vif.clk)` in a driver?**
`@(posedge vif.clk)` resumes the driver in the Active region of the clock edge, where it can race with the DUT. `@(vif.drv_cb)` waits for the clocking event of the clocking block; the process resumes in the Observed region, after the clocking block has sampled its inputs and after the design has run, so values read through `vif.drv_cb.signal` are the newly sampled ones and there is no race. When a clocking block is used, all waiting should be on the clocking block event, not on the raw clock; mixing the two brings the race back.

## The Constraint Solver

**Q119. How does the solver choose values when several variables are constrained together?**
All active constraints and all active random variables are solved together as one problem. The solver finds the set of all legal combinations (the solution space) and picks one combination with uniform probability, unless `dist` or `solve`...`before` changes the distribution. Example: `rand bit [1:0] a, b; constraint c { a < b; }` has six solutions, (0,1) (0,2) (0,3) (1,2) (1,3) (2,3), each with probability 1/6. So `a == 0` has probability 1/2 and `a == 2` has probability 1/6: the variables are not individually uniform.

**Q120. Can `solve`...`before` make `randomize()` fail or succeed?**
No. It only changes the order of selection and therefore the probabilities. The set of legal solutions is exactly the same with or without it. If the constraints are contradictory, no ordering helps. It also cannot be used with `randc` variables, which are always solved first.

**Q121. What happens when a function is called inside a constraint?**
The function's arguments are solved first, without regard to the constraints that use the function's result; the function is then evaluated and its return value is treated as a constant in the remaining constraints. Two consequences: the relation is no longer bidirectional (the result cannot influence the arguments), and randomization can fail even though a solution exists. Such functions must be automatic, must not have side effects and must not have `output` or `ref` arguments.

**Q122. How does `randc` work internally and what are its limits?**
The solver computes a random permutation of the legal values of the variable and returns the next entry on each call; when the permutation is exhausted a new one is made. `randc` variables are solved before `rand` variables. Limits: the type may be at most a tool-defined size (at least 16 bits is guaranteed), `dist` cannot be applied to it, and if the constraints change between calls so that the set of legal values changes, the cycle restarts. Constraints that tie a `randc` variable to other random variables can make the cyclic behaviour impossible to keep.

**Q123. Several soft constraints conflict. Which one wins?**
The one with the highest priority. Priority increases in this order: constraints in a base class, constraints in a derived class, constraints declared later in the same class, and finally inline constraints in `randomize() with {}` (highest). The solver adds soft constraints from highest to lowest priority and discards any that would make the problem unsolvable. A hard constraint always beats any soft constraint.

**Q124. What do `randomize(null)` and `randomize(a, b)` do?**
`obj.randomize(null)` assigns nothing: every variable is treated as a state variable and the call only checks whether the current values satisfy the constraints, returning 1 or 0. It is used as a checker. `obj.randomize(a, b)` randomizes only the listed properties for this call (even properties not declared `rand`), treating all others as state variables.

**Q125. In what order are the size and the elements of a random dynamic array solved?**
The size is solved first, the array is resized, and then the `foreach` constraints are applied to the elements. A constraint that tries to make the size depend on the element values, such as "the size equals the number of non-zero elements", cannot work as written.

**Q126. What exactly happens when `randomize()` fails?**
It returns 0, the random variables keep the values they had before the call, `post_randomize()` is not called (`pre_randomize()` has already run), and most simulators print a warning naming the conflicting constraints. Simulation continues. If the return value is not checked, the test carries on with stale stimulus, which is why every call should be wrapped in a check.

**Q127. What is random stability, and how do you reproduce a failing random test?**
Each thread and each object has its own random number generator, seeded from its parent when it is created. Random stability means that the values drawn by one thread or object do not depend on what other threads do. A failing test is reproduced by rerunning with the same simulator seed (for example `+ntb_random_seed=` or `-sv_seed`, depending on the tool) and the same code. Adding or reordering object creations or forks before the point of interest changes the seeds handed out afterwards, so a "small" testbench edit can change the stimulus. An object can be reseeded explicitly with `obj.srandom(seed)`.

## Classes and Memory

**Q128. How is object memory managed? Can there be a memory leak?**
Objects are allocated by `new` and reclaimed automatically when no handle refers to them. There is no explicit free. Leaks in the usual sense happen when handles are kept unintentionally: a scoreboard queue or associative array that is never emptied keeps every transaction of the test alive, and memory grows with simulation length.

**Q129. Are class properties polymorphic like virtual methods?**
No. Property access is resolved from the type of the handle at compile time. If a base class and a derived class both declare `int x`, then through a base handle `b.x` is the base property even when the object is of the derived class. Only virtual methods are resolved from the object. Redeclaring a base property in a derived class (hiding) is legal but almost always a mistake.

**Q130. Why is `copy()` normally a virtual method that returns the base type?**
So that a component holding a base-class handle can copy an object without knowing its real type. Each derived class overrides `copy()` to create an object of its own type and copy its extra fields; a call through the base handle then produces a complete copy of the derived object. If `copy()` were not virtual, copying through a base handle would create a base object and lose the derived fields. Because the signature of an override must match, the return type stays the base type and the caller uses `$cast` if it needs the derived handle.

**Q131. Does SystemVerilog support multiple inheritance? What about `super.super`?**
A class can extend only one class, and `super.super.method()` is not allowed; a class can reach only its direct base. IEEE 1800-2012 added `interface class`: a class containing only pure virtual method prototypes (and types and parameters). A class can `implements` several interface classes, which gives multiple inheritance of the method contract but not of code or data.

**Q132. How do static members behave in a parameterised class?**
Each specialisation is a separate class with its own static members. In `class counter #(type T = int); static int n; endclass`, `counter#(int)::n` and `counter#(bit)::n` are different variables. To share one variable among all specialisations, put it in a non-parameterised base class.

**Q133. Does a shallow copy (`b = new a;`) call the constructor?**
No. Memory is allocated and the property values are copied from `a`, but the `new()` function of the class is not executed. Anything the constructor does, such as incrementing a static object counter or creating nested objects, does not happen for the copy.

## Process Control

**Q134. What is the `process` class?**
A built-in class that gives a handle to a thread. `process::self()` returns the handle of the calling thread. Methods: `status()` returns `FINISHED`, `RUNNING`, `WAITING`, `SUSPENDED` or `KILLED`; `kill()` terminates the thread and its children; `await()` blocks until the thread finishes; `suspend()` and `resume()` pause and continue it. It gives finer control than `disable fork`, which cannot select a single thread.

```systemverilog
process p;
fork
  begin p = process::self(); do_work(); end
join_none
wait (p != null);
#100 if (p.status() != process::FINISHED) p.kill();
```

**Q135. `disable fork` killed a thread it was not supposed to. Why, and how is that prevented?**
`disable fork` kills every thread spawned by the calling process, including threads started much earlier with `join_none` (for example a background monitor), not only those of the nearest `fork`. Wrap the timeout logic in its own `fork`...`join` so that it runs in a new process whose only children are the ones to be killed:

```systemverilog
fork
  begin                       // isolating process
    fork
      wait_for_response();
      #1000;
    join_any
    disable fork;             // kills only the two threads above
  end
join
```

**Q136. A thread started with `join_none` uses a local variable of the task that started it, and the task returns. Is that safe?**
Yes, for automatic variables. An automatic variable lives as long as any thread that can reference it, so the storage of the enclosing scope is kept until the spawned threads finish. The risk is different: all threads see the same variable, and its value when they run may not be the value it had when they were created (the loop-variable trap of Q92). A `ref` argument, however, may not be used inside `fork`...`join_none` or `join_any`, because the referenced variable could cease to exist.

**Q137. What happens when one event variable is assigned to another?**
Event variables are handles to synchronisation objects. After `e2 = e1;` both names refer to the same event: triggering either wakes processes waiting on either. Processes that were already blocked on the old `e2` object are not woken by later triggers, because nothing refers to that object any more. Assigning `null` to an event variable disconnects it. This handle behaviour is what allows an event to be shared between classes by passing it to a constructor.

**Q138. Several processes are blocked on `get()` of the same mailbox or semaphore. Who is served first?**
A mailbox serves waiting processes in the order in which they started waiting (FIFO). For a semaphore the standard also specifies a FIFO waiting queue, but a request for few keys may be satisfied before an earlier request for more keys that cannot yet be met, and simulators differ in the detail. Do not write testbenches that depend on fairness between waiters; if order matters, enforce it explicitly.

## Coverage Semantics

**Q139. What are the rules for a covergroup declared inside a class?**
An embedded covergroup is declared in the class and must be constructed in the class constructor: `cg = new();` (only one instance per object, and the name of the covergroup is used as the variable). It can refer to the class properties directly. It is sampled either by its own event, `covergroup cg @(posedge clk);`, or, more commonly in a class, by calling `cg.sample()` when a transaction is complete. If the constructor does not `new` it, `sample()` is a null-handle error.

**Q140. What is the difference between `option` and `type_option`, and between `get_coverage()` and `get_inst_coverage()`?**
`option` settings apply to one instance of a covergroup (or one coverpoint); `type_option` settings apply to the covergroup type across all instances. `cg.get_inst_coverage()` returns the coverage percentage of that instance alone (meaningful when `option.per_instance = 1`); `cg.get_coverage()` returns the coverage of the type, combined over all instances. `$get_coverage()` returns the overall figure for all covergroups in the simulation.

**Q141. How are X and Z handled in coverage, and what are wildcard bins?**
Automatically created bins cover only two-state values; a sampled value containing X or Z does not fall into any automatic bin. In an explicit bin, a value is counted only on an exact match, unless the bin is declared `wildcard`, in which case X, Z and `?` in the bin definition are don't-care positions: `wildcard bins odd = {4'b???1};` counts every odd value.

## Assertion Semantics

**Q142. What is a vacuous success?**
When the antecedent of an implication does not match, the property is true by definition, although nothing was actually checked. `req |-> ack` passes vacuously on every clock where `req` is 0. Tools do not count vacuous successes in assertion coverage. The danger is an assertion whose antecedent can never be true: it never fails and gives false confidence, which is why each assertion should have a matching `cover property` for its antecedent.

**Q143. How many evaluation attempts of a concurrent assertion can be active at once?**
A new attempt starts at every clock tick, independently of earlier attempts that are still in progress. For `req |-> ##[1:5] ack`, if `req` is high on three consecutive clocks there are three overlapping attempts, and a single `ack` may complete all of them. This matters when the intent is "one `ack` per `req`": the simple property does not check that, and a counter or a local variable is needed.

**Q144. What does `$past(x)` return on the first clock tick, and what is its gating argument?**
On ticks before enough history exists, `$past` returns the default initial value of the expression's type (X for four-state types, 0 for two-state). Properties using `$past` therefore usually need `disable iff` during reset, or an explicit guard. The full form is `$past(expr, n, gate, clock)`: with a gating expression, only clock ticks on which `gate` was true are counted as "past" ticks.

**Q145. What are `throughout`, `within`, `intersect`, `first_match` and sequence local variables?**
`cond throughout seq`: `cond` must hold on every tick of `seq`. `s1 within s2`: `s1` must occur entirely inside the span of `s2`. `s1 intersect s2`: both match, starting and ending at the same ticks. `first_match(seq)`: of all possible matches of a sequence with ranges, only the earliest is used. A local variable is declared inside a sequence or property and captures a value at one point for comparison later:

```systemverilog
property data_through_p;
  logic [7:0] d;
  @(posedge clk) (wr_en, d = din) |-> ##[1:$] (rd_en && dout == d);
endproperty
```

**Q146. What is `bind`?**
A statement that instantiates a module or interface (typically one containing assertions or coverage) inside another module without editing that module's source: `bind sync_fifo fifo_sva u_sva (.*);`. The bound instance behaves as if it had been written inside the target, with access to its signals. Verification engineers use it to attach assertions to RTL they do not own, including VHDL blocks.
