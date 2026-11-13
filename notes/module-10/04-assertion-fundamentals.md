# Part 4: Assertion Fundamentals

## 4.1 What Is an Assertion?

### In plain English

An assertion is a statement in the code that says **"this must always be true"**, and that complains immediately when it is not.

A specification is full of such rules: "a grant is never given without a request", "the FIFO is never full and empty at the same time", "`valid` stays high until `ready` is seen". A scoreboard does not check these directly; it looks at finished transactions. An assertion watches the signals themselves, at every clock, for the whole simulation, and reports the exact time and place where a rule was broken.

### Technical definition

An **assertion** is a check embedded in design or verification code that states an intended property of the design. The simulator (or a formal tool) evaluates it and reports a failure when the property does not hold. SystemVerilog Assertions (SVA) come in two kinds:

- **Immediate assertions**: procedural statements that check a condition at the moment they are executed, like an `if`.
- **Concurrent assertions**: statements that check behaviour **over time**, evaluated on a clock, using sequences and properties.

### Why assertions are needed

| Without assertions | With assertions |
|---|---|
| A protocol violation is noticed only if it corrupts data that the scoreboard later compares, possibly thousands of cycles after the cause | The violation is reported at the clock edge where it happens, with the name of the rule |
| Debug starts at the scoreboard mismatch and works backwards through waveforms | Debug starts at the failing assertion, next to the root cause |
| Internal design assumptions exist only in the designer's head | The assumptions are written in the code and checked in every simulation |
| Checks are hand-written `always` blocks with flags and counters | One line per rule, in a language made for the purpose |
| Checkers must be rewritten for formal verification | The same assertions are used by formal tools |

### Where assertions are in the verification environment

```text
   +---------------------------- tb_top ---------------------------------------+
   |                                                                           |
   |   class-based testbench                 interface alu_if                  |
   |   (generator, driver, monitor,   <--->  signals + clocking blocks         |
   |    scoreboard, coverage)                + PROTOCOL ASSERTIONS             |
   |        ^                                        |                         |
   |        | immediate assertions                   v                         |
   |        | in classes                     +------------------+              |
   |        | (assert(txn.randomize()))      |       DUT        |              |
   |                                         |  + DESIGN        |              |
   |                                         |    ASSERTIONS    |  <-- bind    |
   |                                         +------------------+      file    |
   +---------------------------------------------------------------------------+
```

| Written by | Typical content | Location |
|---|---|---|
| Designer | Internal assumptions: FSM state is one-hot, counter never overflows, FIFO never written when full | Inside the RTL, or in a separate module attached with `bind` |
| Verification engineer | Interface protocol rules: handshakes, signal stability, timing between request and response, no X on control signals | In the interface, or in a checker module attached with `bind` |
| Verification engineer | Testbench sanity checks: randomization succeeded, handle not null | Immediate assertions in classes |

### Benefits and limits

| Benefits | Limits |
|---|---|
| Errors are caught at the source and at the exact time | Poorly suited to checking data transformations (a scoreboard is better) |
| Compact, readable description of temporal behaviour | Complex properties are hard to write correctly and can pass for the wrong reason (vacuity) |
| Active in every test, without effort from the test writer | Many assertions slow the simulation down |
| Reusable from block level to system level and in formal verification | Concurrent assertions cannot be placed inside classes |
| `cover property` gives temporal functional coverage | |

> **Key point:** Assertions, the scoreboard and functional coverage are complementary. Assertions check **rules on signals over time**. The scoreboard checks **the data result of each transaction**. Coverage records **what was exercised**. A serious testbench has all three.

### Interview questions

**Q1. What is an assertion?**
A statement that specifies a property the design must satisfy. The tool checks it during simulation (or proves it formally) and reports a failure when the property is violated.

**Q2. What are the types of assertions in SystemVerilog?**
Immediate assertions and concurrent assertions. Immediate assertions are further divided into simple and deferred; concurrent assertions use the directives `assert property`, `assume property`, `cover property` and `restrict property`.

**Q3. What are the advantages of assertions?**
Failures are detected close to the cause, in time and in location; temporal protocol rules are expressed concisely; they document design intent; they work in every test and can be reused in formal verification; `cover property` provides temporal coverage.

**Q4. Who writes assertions, the designer or the verification engineer?**
Both. Designers write assertions about internal assumptions of the RTL. Verification engineers write assertions about interface protocols and end-to-end rules.

## 4.2 Immediate Assertions

### In plain English

An immediate assertion is an `if` statement with a built-in complaint. When the simulator reaches it, the condition is evaluated on the spot, using the current values of the variables. If the condition is true, the assertion passes. If it is false (or X), it fails.

### Technical definition

An **immediate assertion** is a procedural statement that tests an expression when the statement is executed. It is not temporal: there is no clock and no notion of "next cycle". It can be used wherever a procedural statement is allowed: in `initial` and `always` blocks, tasks, functions, and **inside class methods**.

### Syntax

```systemverilog
[ label : ] assert ( expression )
              [ pass_statement ]
            [ else fail_statement ]
```

| Part | Meaning |
|---|---|
| `label :` | Optional name, shown in the failure message and in assertion reports. Always give one |
| `expression` | Evaluated like the condition of an `if`. True (non-zero and known) passes; 0, X or Z fails |
| Pass statement | Optional. Executed when the assertion passes |
| `else` fail statement | Optional. Executed when the assertion fails. If it is omitted, the tool calls `$error` with a default message |

### Severity system tasks

The fail (or pass) statement normally calls one of four system tasks:

| Task | Severity | Effect |
|---|---|---|
| `$fatal(...)` | Fatal | Reports the message and **terminates** the simulation |
| `$error(...)` | Error | Reports a run-time error; the simulation continues. This is the default when there is no `else` |
| `$warning(...)` | Warning | Reports a warning; the simulation continues |
| `$info(...)` | Information | Reports a message with no severity |

Each of them prints the message together with the file name, line number, scope and simulation time. The exact layout is tool-specific. `$fatal` takes an optional first argument (0, 1 or 2) that controls how much diagnostic information is printed: `$fatal(1, "message")`.

### Complete example

To keep the output identical on every simulator, the example uses `$display` in the action blocks.

```systemverilog file=tb_immediate.sv
module tb_immediate;

  int         a, b;
  logic [3:0] grant;
  logic       unknown;

  initial begin
    a = 5;
    b = 5;
    a_equal: assert (a == b)
      $display("[%0t] a_equal passed: a=%0d b=%0d", $time, a, b);
    else
      $display("[%0t] a_equal FAILED: a=%0d b=%0d", $time, a, b);

    #10 b = 6;
    a_equal_again: assert (a == b)
      $display("[%0t] a_equal_again passed", $time);
    else
      $display("[%0t] a_equal_again FAILED: a=%0d b=%0d", $time, a, b);

    #10 grant = 4'b0110;
    a_onehot: assert ($onehot(grant))
      else $display("[%0t] a_onehot FAILED: grant=%b", $time, grant);

    grant = 4'b0100;
    a_onehot_again: assert ($onehot(grant))
      $display("[%0t] a_onehot_again passed: grant=%b", $time, grant);

    a_known: assert (unknown)
      else $display("[%0t] a_known FAILED: an X condition counts as false", $time);
  end

endmodule
```

```output
[0] a_equal passed: a=5 b=5
[10] a_equal_again FAILED: a=5 b=6
[20] a_onehot FAILED: grant=0110
[20] a_onehot_again passed: grant=0100
[20] a_known FAILED: an X condition counts as false
```

**Line by line**

| Code | Explanation |
|---|---|
| `a_equal: assert (a == b)` | Evaluated when execution reaches it, at time 0. 5 equals 5: pass. |
| The statement after the condition | The pass statement. Note there is **no semicolon** between it and `else` other than the one ending the pass statement itself. |
| `else $display(...)` | The fail statement. It replaces the default `$error`. |
| `a_equal_again` at time 10 | `b` is now 6: the fail statement runs. |
| `a_onehot` | `$onehot` is true when exactly one bit is 1. `0110` has two: fail. Only an `else` branch is given, so nothing is printed on a pass. |
| `a_onehot_again` | `0100` has one bit set: pass. Only a pass statement is given; had it failed, the default `$error` would have been issued. |
| `a_known` | `unknown` was never assigned and is X. An X condition is treated as false, so the assertion fails. |

### Immediate assertion versus if statement

| Property | `if (!cond) $error(...)` | `assert (cond) else $error(...)` |
|---|---|---|
| Checks the condition | Yes | Yes |
| States intent | No: it is ordinary code | Yes: it is recognisably a check |
| Appears in assertion reports and assertion coverage | No | Yes |
| Can be switched off globally (`$assertoff`, tool options) | No | Yes |
| Usable by formal tools | No | Yes (with restrictions) |
| Default action on failure | None | `$error` |

### Deferred immediate assertions

A simple immediate assertion in combinational code can fail on a **glitch**: when two inputs of the checked expression change in the same time step, the checking code may run once after the first change and again after the second, and the intermediate, never-really-existing combination can violate the condition.

```systemverilog
always_comb begin
  a_simple  : assert (!(grant_a && grant_b));          // may report a zero-time glitch
  a_deferred: assert #0 (!(grant_a && grant_b));       // reports only the settled value
  a_final   : assert final (!(grant_a && grant_b));    // reported at the end of the time step
end
```

| Form | Syntax | When the failure is reported |
|---|---|---|
| Simple immediate | `assert (expr)` | Immediately, each time the statement executes |
| Observed deferred | `assert #0 (expr)` | The result is held and reported in the Observed region of the time step; if the block re-executes in the same time step, earlier pending reports are discarded |
| Final deferred (IEEE 1800-2012) | `assert final (expr)` | Reported in the Postponed region, when nothing can change any more |

Deferred assertions may only have a subroutine call (such as `$error`) as their action. They are the right choice for combinational checks in `always_comb` blocks and in continuous code. Deferred assertions can also be written outside procedural blocks, directly in a module.

### Real-world uses of immediate assertions

```systemverilog
// 1. Check that randomization succeeded (see the trap below)
if (!txn.randomize()) $fatal(1, "alu_txn randomization failed");

// 2. Check a handle before using it
a_vif_set: assert (vif != null) else $fatal(1, "virtual interface not set");

// 3. Check an argument at the start of a task
a_len_ok: assert (len inside {[1:16]}) else $error("illegal length %0d", len);

// 4. Combinational check in RTL
always_comb a_onehot_state: assert #0 ($onehot(state));
```

> **Interview trap:** `assert (txn.randomize());` is widely written and has a hidden danger. If assertions are disabled (with `$assertoff` or a tool option, often done to speed up a regression), the simulator may not evaluate the expression at all, so **`randomize()` is never called** and the transaction keeps its old values. Call the function unconditionally and check the result: `if (!txn.randomize()) $fatal(...)`, or `ok = txn.randomize(); assert (ok);`.

> **Common mistake:** Putting a semicolon after the condition when an `else` follows: `assert (a == b); else $error(...)`. The semicolon ends the assertion as a null pass statement, and the `else` becomes a syntax error.

> **Common mistake:** Using an immediate assertion in a clocked block to check something "one cycle later". An immediate assertion sees only the present values. Anything involving time needs a concurrent assertion.

### Interview questions

**Q1. What is an immediate assertion?**
A procedural statement that evaluates an expression when it is executed and passes if the expression is true. It is not clocked and checks only the current values.

**Q2. Where can immediate assertions be used?**
Anywhere a procedural statement is allowed: `initial` and `always` blocks, tasks, functions and class methods.

**Q3. What happens when an immediate assertion fails and there is no `else` clause?**
The tool issues an error by calling `$error` with a default message; the simulation continues.

**Q4. What are the severity levels?**
`$fatal`, `$error`, `$warning` and `$info`. `$fatal` ends the simulation.

**Q5. What is a deferred immediate assertion?**
`assert #0 (expr)` or `assert final (expr)`. The reporting of the result is postponed to a later region of the same time step, so that transient glitches in combinational logic do not produce false failures.

**Q6. Can assertions be used inside a class?**
Immediate assertions can. Concurrent assertions cannot: they are only allowed in modules, interfaces, programs and checkers.

**Q7. What does an immediate assertion do if the expression evaluates to X?**
It fails. X and Z are treated as false, as in an `if` statement.

## 4.3 Concurrent Assertions

### In plain English

A concurrent assertion describes behaviour that spreads over several clock cycles: "if a request is seen, a grant must follow within three cycles". It is not executed once like a statement. It is switched on for the whole simulation, and at **every clock edge** it starts a new check. Many checks can therefore be in progress at the same time, which is where the name "concurrent" comes from.

### Technical definition

A **concurrent assertion** is a statement that specifies a **property** to be evaluated at each occurrence of a **clocking event**. Its expressions use the **sampled values** of the signals: the values the signals had just before the clock edge. A new evaluation **attempt** (also called a thread) starts at every clock tick. Each attempt ends in success, failure, or (if a `disable iff` condition occurs) is discarded.

### Syntax

```systemverilog
[ label : ] assert property ( [ @(clock_event) ] [ disable iff (rst_expr) ] property_expr )
              [ pass_statement ]
            [ else fail_statement ] ;
```

The simplest example:

```systemverilog
a_no_overlap: assert property (@(posedge clk) !(grant_a && grant_b))
  else $error("both grants active");
```

### Where a concurrent assertion can be written

| Location | Allowed |
|---|---|
| Module, interface, program, checker, generate block (outside any procedure) | Yes: the normal case |
| Inside an `always` or `initial` block | Yes: the clock can be inferred from the block |
| Inside a `class`, a task or a function | **No** |

### Sampled values: the most important rule

The simulator divides each time step into regions (Module 7 used the same idea for race avoidance):

```text
   one time step that contains a rising clock edge
   +-----------+---------+----------+-------+----------+----------+-----------+
   | Preponed  | Active  | Inactive |  NBA  | Observed | Reactive | Postponed |
   +-----------+---------+----------+-------+----------+----------+-----------+
        |           |                   |         |          |
        |           |                   |         |          +-- assertion action blocks run
        |           |                   |         |              (pass / fail statements);
        |           |                   |         |              program-block code runs
        |           |                   |         +-- concurrent assertions are EVALUATED,
        |           |                   |             using the sampled values
        |           |                   +-- nonblocking assignments update the flip-flops
        |           +-- the clock edge occurs; blocking assignments and always blocks run
        +-- signal values are SAMPLED here, before anything in this time step has changed
```

So a concurrent assertion uses the values of its signals as they were **immediately before** the clock edge. This is exactly what a flip-flop clocked by the same edge would capture. Two consequences:

- A signal that changes **at** the clock edge (driven by a flip-flop on that same edge) is seen by the assertion with its **old** value at this tick and its new value at the next tick.
- Assertions are free of races with the design and the testbench: the result does not depend on the order in which processes execute.

```text
   clk       ___/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
   time         5         15        25        35

   sig       _____/‾‾‾‾‾‾‾‾‾‾‾\_________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾     sig changes AT the clock edges
                  ^           ^         ^
   sampled      0 |         1 |       0 |         1          value just BEFORE each edge
   at tick      5           15        25        35
```

### Complete example: what value does the assertion see?

```systemverilog file=tb_sva_sampling.sv
module tb_sva_sampling;

  logic clk = 0;
  logic sig = 0;

  always #5 clk = ~clk;

  // "sig must be 1 at every rising clock edge"
  a_sig: assert property (@(posedge clk) sig)
    else $display("[%0t] a_sig FAILED: sampled sig=%b, current sig=%b",
                  $time, $sampled(sig), sig);

  initial begin
    @(posedge clk);  sig = 1;      // time 5 : changes at the clock edge
    @(posedge clk);  sig = 0;      // time 15
    @(posedge clk);  sig = 1;      // time 25
    @(posedge clk);                // time 35
    @(negedge clk);  $finish;      // time 40
  end

endmodule
```

```output
[5] a_sig FAILED: sampled sig=0, current sig=1
[25] a_sig FAILED: sampled sig=0, current sig=1
```

**Execution flow**

| Time | Sampled value of `sig` (Preponed) | What the `initial` block does at this edge | Result of the assertion |
|---|---|---|---|
| 5 | 0 | Sets `sig = 1` | **Fails**: the value before the edge was 0 |
| 15 | 1 | Sets `sig = 0` | Passes: the value before the edge was 1, although `sig` is 0 by the time the result is reported |
| 25 | 0 | Sets `sig = 1` | **Fails** |
| 35 | 1 | Nothing | Passes |

**Line by line**

| Code | Explanation |
|---|---|
| `assert property (@(posedge clk) sig)` | A concurrent assertion with the clock given inside the property. The property is the simplest possible: a Boolean that must be true at every tick. |
| `$sampled(sig)` | Returns the sampled value, the one the assertion used. |
| `sig` in the fail statement | The action block runs in the Reactive region, after the `initial` block has already changed `sig`, so it prints the **new** value. This is why failure messages sometimes seem to contradict the waveform; use `$sampled` in action blocks. |
| Failure at time 5 | In the waveform, `sig` rises exactly at time 5 and looks high "at" the edge. The assertion correctly treats it as low, because a flip-flop clocked at time 5 would have captured 0. |

### Evaluation attempts

```text
   property: @(posedge clk) req |-> ##2 ack        (if req, then ack two ticks later)

   tick        1      2      3      4      5      6
   req         1      1      0      0      1      0
   ack         0      0      1      1      0      0

   attempt 1   start ............. end (ack=1 at tick 3)   -> pass
   attempt 2          start ............. end (ack=1 at 4) -> pass
   attempt 3                 start/end (req=0)             -> vacuous pass
   attempt 4                        start/end (req=0)      -> vacuous pass
   attempt 5                               start ......... -> needs tick 7

   A new attempt starts at every tick. Attempts 1 and 2 overlap in time: they are concurrent.
```

### Immediate versus concurrent assertions

| Property | Immediate assertion | Concurrent assertion |
|---|---|---|
| Keyword | `assert (expr)` | `assert property (prop)` |
| Nature | Procedural statement | Declarative statement, always active |
| Clock | None | Required (explicit, inferred or default) |
| When evaluated | When execution reaches the statement | At every clock tick |
| Values used | Current values | Sampled values (from the Preponed region) |
| Evaluation region | Where the procedure is executing (Active or Reactive) | Observed |
| Can describe behaviour over several cycles | No | Yes: sequences, delays, repetition, implication |
| Allowed in classes, tasks, functions | Yes | No |
| Allowed directly in a module or interface | Deferred forms only | Yes |
| Sensitive to glitches | Simple form yes; deferred forms no | No |
| Formal verification | Limited | Yes: the main input of formal tools |
| Typical use | Testbench sanity checks, combinational checks | Protocol and timing rules |

> **Interview trap:** "A signal goes high exactly at the rising edge of the clock. Does a concurrent assertion at that edge see it as high or low?" Low. The assertion uses the value sampled in the Preponed region, before the edge. It sees the high value at the next tick.

> **Common mistake:** Printing signals in an assertion's action block without `$sampled`. The action block runs after the design has updated, so the printed values are those **after** the edge and may not match what the assertion evaluated.

> **Common mistake:** Trying to write `assert property` inside a class (for example in a driver or monitor). It does not compile. Put the assertion in the interface and, if the class needs to control it, expose a signal or use `$assertoff`/`$asserton`.

### Interview questions

**Q1. What is a concurrent assertion?**
An assertion that checks a property over time. It is evaluated at every tick of its clocking event using sampled values, and each tick starts a new evaluation attempt.

**Q2. What is the difference between immediate and concurrent assertions?**
An immediate assertion is a procedural statement checked once when executed, with current values and no clock. A concurrent assertion is clock-based, uses sampled values, is evaluated at every clock tick, can span many cycles, and cannot be placed in a class.

**Q3. In which regions are concurrent assertions sampled and evaluated?**
The signal values are sampled in the Preponed region, the property is evaluated in the Observed region, and the pass/fail action blocks execute in the Reactive region.

**Q4. Why are sampled values used?**
To model what clocked hardware sees (the value before the edge) and to make the assertion independent of the execution order of processes in the time step, which removes races.

**Q5. Why can a concurrent assertion not be written inside a class?**
Concurrent assertions are static, declarative constructs tied to the design hierarchy and a clock; they exist for the whole simulation. Class objects are dynamic and are created and destroyed at run time, so the language does not allow concurrent assertions in them.

**Q6. What is an assertion attempt or thread?**
One evaluation of the property that begins at a particular clock tick. Since a new attempt begins at every tick and a property may take several cycles, several attempts can be active at once.

## 4.4 Sequences and Properties

### In plain English

Concurrent assertions are built in layers, like sentences from words:

- A **Boolean expression** is a word: "`req` is high".
- A **sequence** is a phrase describing an order of events over clock ticks: "`req` is high, and one tick later `gnt` is high".
- A **property** is a complete rule, usually of the form "if this, then that": "whenever `req` is high, `gnt` is high within two ticks".
- A **directive** says what to do with the rule: check it (`assert`), assume it (`assume`), or record that it happened (`cover`).

### The four layers

```text
   Layer 4   DIRECTIVE     assert property / assume property / cover property / restrict
                 ^            "what to do with the property"
   Layer 3   PROPERTY      implication |->  |=>,  not,  disable iff,  clock
                 ^            "a rule that is true or false"
   Layer 2   SEQUENCE      ##delay, [*n] repetition, and, or, intersect, throughout, within
                 ^            "a pattern of Boolean values over consecutive clock ticks"
   Layer 1   BOOLEAN       req && !gnt,   count == 0,   $rose(valid),   $onehot(state)
                              "an expression evaluated at one clock tick with sampled values"
```

### Sequences

**Definition.** A sequence is a list of Boolean expressions in a linear order of increasing time, separated by cycle delays. A sequence **matches** if each expression is true at its tick.

```systemverilog
sequence s_req_gnt;
  req ##1 gnt;                 // req true at this tick, gnt true at the next tick
endsequence

sequence s_handshake (logic r, logic g, int max_wait);   // a sequence with arguments
  r ##[1:max_wait] g;
endsequence
```

| Element | Meaning |
|---|---|
| `a ##1 b` | `a` at tick T, `b` at tick T+1 |
| `a ##0 b` | `a` and `b` at the same tick |
| `a ##3 b` | `b` three ticks after `a` |
| `a ##[1:3] b` | `b` one, two or three ticks after `a` |
| `a [*3]` | `a` true on three consecutive ticks |

Part 5 covers delays and repetition in full.

A sequence by itself is not a rule. It is a pattern that can be found (matched) starting at some tick, or not.

### Properties

**Definition.** A property specifies behaviour that must hold. It is built from sequences and Boolean expressions with property operators, most importantly **implication**, and it evaluates to true or false for each attempt.

```systemverilog
property p_req_gnt;
  @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:2] gnt;       // if req, then gnt within 1 to 2 ticks
endproperty
```

| Part | Meaning |
|---|---|
| `@(posedge clk)` | The clocking event |
| `disable iff (!rst_n)` | The check is abandoned while reset is active |
| `req` | The **antecedent**: the condition that triggers the check |
| `\|->` | Implication: "if the antecedent matches, the consequent must match" |
| `##[1:2] gnt` | The **consequent**: what must then happen |

Properties, like sequences, can take arguments, which makes them reusable:

```systemverilog
property p_stable_until_ack (logic vld, logic ack, logic [7:0] dat);
  @(posedge clk) disable iff (!rst_n)
    vld && !ack |=> $stable(dat);
endproperty

a_wdata_stable: assert property (p_stable_until_ack(wvalid, wready, wdata));
a_rdata_stable: assert property (p_stable_until_ack(rvalid, rready, rdata));
```

### Directives

| Directive | Meaning in simulation | Meaning in formal verification |
|---|---|---|
| `assert property (p)` | Check that `p` holds; report a failure if not | A proof obligation: prove that `p` always holds |
| `assume property (p)` | Checked exactly like `assert` | A constraint on the inputs: the tool only considers input behaviour satisfying `p` |
| `cover property (p)` | Record that `p` (or a sequence) was observed; counted in coverage | Find a trace that reaches it: proves the scenario is reachable |
| `restrict property (p)` | Ignored | A constraint, like `assume`, that is never checked |

`cover property` is the temporal form of functional coverage. It answers "did this sequence of events ever occur?".

### Sequence versus property

| Aspect | Sequence | Property |
|---|---|---|
| Describes | A pattern of events over ticks | A rule about behaviour |
| Result | Matches or does not match | Holds (true) or fails (false) |
| Keywords | `sequence` ... `endsequence` | `property` ... `endproperty` |
| Operators | `##`, `[*]`, `[->]`, `[=]`, `and`, `or`, `intersect`, `throughout`, `within`, `first_match` | `\|->`, `\|=>`, `not`, `and`, `or`, `if`...`else`, `disable iff` |
| Can contain implication | No | Yes |
| Can be asserted directly | Yes, but then it must match at **every** tick, which is rarely intended | Yes |
| Can be covered directly | Yes: `cover property (seq)` | Yes |
| Used inside | Other sequences and properties | Other properties and directives |

### Complete example

```systemverilog file=tb_sva_seq_prop.sv
module tb_sva_seq_prop;

  logic clk = 0;
  logic req, gnt;

  // stimulus for cycles 0..7 (cycle k is the posedge at time 10k+5)
  bit [0:7] req_v = 8'b0100_1000;
  bit [0:7] gnt_v = 8'b0010_0001;

  always #5 clk = ~clk;

  // Layer 2: sequences
  sequence s_gnt_within_2;
    ##[1:2] gnt;
  endsequence

  sequence s_req_then_gnt;
    req ##1 gnt;
  endsequence

  // Layer 3: property
  property p_req_gnt;
    @(posedge clk) req |-> s_gnt_within_2;
  endproperty

  // Layer 4: directives
  a_req_gnt: assert property (p_req_gnt)
    else $display("[%0t] a_req_gnt FAILED: no gnt within 2 cycles of req", $time);

  c_req_gnt: cover property (@(posedge clk) s_req_then_gnt)
    $display("[%0t] c_req_gnt covered: gnt came one cycle after req", $time);

  initial begin
    for (int i = 0; i < 8; i++) begin
      req = req_v[i];
      gnt = gnt_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[25] c_req_gnt covered: gnt came one cycle after req
[65] a_req_gnt FAILED: no gnt within 2 cycles of req
```

**Stimulus and evaluation**

| Cycle | Time | `req` | `gnt` | `a_req_gnt` | `c_req_gnt` |
|---|---|---|---|---|---|
| 0 | 5 | 0 | 0 | No request: nothing to check | |
| 1 | 15 | 1 | 0 | Attempt A starts: `gnt` required at cycle 2 or 3 | Possible match starts |
| 2 | 25 | 0 | 1 | Attempt A **passes** | **Covered** (`req` at 1, `gnt` at 2) |
| 3 | 35 | 0 | 0 | | |
| 4 | 45 | 1 | 0 | Attempt B starts: `gnt` required at cycle 5 or 6 | Possible match starts |
| 5 | 55 | 0 | 0 | Still waiting | No `gnt`: no match |
| 6 | 65 | 0 | 0 | Attempt B **fails**: window exhausted | |
| 7 | 75 | 0 | 1 | Too late | |

**Line by line**

| Code | Explanation |
|---|---|
| `bit [0:7] req_v = 8'b0100_1000;` | The value of `req` for each cycle, written left to right: cycles 1 and 4 are 1. |
| `sequence s_gnt_within_2; ##[1:2] gnt; endsequence` | A sequence that starts with a delay: `gnt` true one or two ticks after the starting point. |
| `property p_req_gnt; @(posedge clk) req \|-> s_gnt_within_2; endproperty` | Uses the named sequence as the consequent. |
| `a_req_gnt: assert property (p_req_gnt) else ...` | The directive. Only a fail statement is given. |
| `c_req_gnt: cover property (...) $display(...)` | A cover directive may have one statement, executed each time the property is covered. |
| The `for` loop | Applies the stimulus for cycle `i`, then waits for the falling edge, so signals change at times 0, 10, 20 ... |

> **Key point:** The failure is reported at time 65, the last tick at which `gnt` could still have arrived, not at time 45 when the request was made. A failing attempt ends when it becomes certain that the property cannot hold. When debugging, look backwards from the failure time to find the start of the attempt (most simulators report the start time as well).

> **Common mistake:** Asserting a sequence that was meant as a scenario: `assert property (@(posedge clk) req ##1 gnt);`. This demands that `req` is true at **every** clock tick and `gnt` at every following one. It fails at the first tick where `req` is low. A rule needs an implication (`req |-> ##1 gnt`); a scenario you only want to observe needs `cover property`.

> **Verification application:** Verification IP for a bus protocol is largely a library of named properties, one per rule in the protocol specification, each asserted in the interface and each paired with `cover property` statements that prove the interesting scenarios occurred. In formal verification the same properties on DUT inputs are switched from `assert` to `assume`.

### Interview questions

**Q1. What is a sequence?**
A specification of Boolean expressions that must be true at successive clock ticks, in a given order, with given delays. A sequence matches or does not match.

**Q2. What is a property?**
A specification of design behaviour built from sequences and Boolean expressions with property operators such as implication. A property is true or false for each evaluation attempt and is what an assertion checks.

**Q3. What is the difference between a sequence and a property?**
A sequence is a temporal pattern; a property is a rule. Implication, `not` and `disable iff` belong to properties. Sequences are building blocks for properties.

**Q4. What are the layers of SVA?**
Boolean layer, sequence layer, property layer and directive (verification) layer.

**Q5. What is the difference between `assert`, `assume` and `cover`?**
`assert` checks that the property holds. `assume` is checked like `assert` in simulation but in formal verification constrains the environment. `cover` does not check anything; it records that the property or sequence was observed.

**Q6. What is `cover property` used for?**
Temporal functional coverage: confirming that a sequence of events (for example a back-to-back transfer, or a FIFO going from full to empty) actually occurred during simulation. It also shows that an assertion's triggering condition occurred, so the assertion did not pass only vacuously.

**Q7. Why is `assert property (@(posedge clk) a ##1 b);` usually wrong?**
Without an implication, the sequence must match starting at every clock tick, so `a` must be true on every tick. The intended rule is normally `a |-> ##1 b` (or `a |=> b`).

## 4.5 Clocking Events

### In plain English

A concurrent assertion needs to know **when to look**. The clocking event is that instant, typically the rising edge of a clock. All delays in the assertion (`##1`, `##[1:3]`) are counted in ticks of this event.

### Technical definition

Every concurrent assertion is associated with a **clocking event**. The sampled values of the assertion's expressions are taken at each occurrence of the event, and one tick of delay (`##1`) means one occurrence of the event. The clock can be specified in four ways.

### The four ways to specify the clock

```systemverilog
// 1. Explicitly, in the assertion or in the property
a1: assert property (@(posedge clk) req |=> gnt);

property p_req_gnt;
  @(posedge clk) req |=> gnt;
endproperty
a2: assert property (p_req_gnt);

// 2. Explicitly, in a sequence
sequence s_req_gnt;
  @(posedge clk) req ##1 gnt;
endsequence

// 3. Inferred from an always block
always @(posedge clk) begin
  a3: assert property (req |=> gnt);      // clock inferred from the always block
end

// 4. Default clocking for the whole module or interface
default clocking cb_default @(posedge clk);
endclocking

a4: assert property (req |=> gnt);        // uses the default clocking
a5: assert property (valid |-> !$isunknown(data));
```

| Method | When to use |
|---|---|
| Explicit `@(posedge clk)` in each property | A few assertions, or assertions on different clocks |
| `default clocking` | Many assertions on the same clock: the normal style in an interface or checker module |
| Inferred from `always` | Assertions embedded in RTL next to the logic they check |
| A clocking block as the clock: `@(vif.mon_cb)` or `@(mon_cb)` | Inside an interface that already has clocking blocks (Module 8) |

If none of these applies, the assertion has no clock and the compiler reports an error.

### Variations

| Clocking event | Meaning |
|---|---|
| `@(posedge clk)` | Rising edges |
| `@(negedge clk)` | Falling edges |
| `@(edge clk)` | Both edges (IEEE 1800-2009 and later) |
| `@(posedge clk iff en)` | Only the rising edges at which `en` is true. Ticks where `en` is false do not exist for the assertion: they are neither sampled nor counted by `##` |

### default clocking and default disable iff

```systemverilog
interface alu_if (input logic clk);
  logic rst_n, valid_in, valid_out;
  // ...

  default clocking cb_sva @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_valid_out: assert property (valid_in |=> valid_out);      // short and readable
endinterface
```

`default disable iff` (IEEE 1800-2009) does for the reset condition what `default clocking` does for the clock. An assertion that states its own clock or its own `disable iff` overrides the default.

### Multi-clock properties (awareness level)

A property may refer to more than one clock:

```systemverilog
// a request in the clk_a domain must be followed by an acknowledge in the clk_b domain
a_cdc: assert property (@(posedge clk_a) req |=> @(posedge clk_b) ack);
```

After the antecedent matches on `clk_a`, the consequent is evaluated at the **next tick of `clk_b`** that is strictly later. Multi-clock assertions are used at clock-domain crossings; the details are beyond what a fresher interview normally expects, but you should know that they exist.

### Clock and sampling together: a timing diagram

```text
   property: @(posedge clk) a |=> b

   clk    ___/‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\___
   tick      T1      T2      T3      T4

   a      ‾‾‾‾‾‾‾‾‾\_________________________     a is 1 before T1, 0 before T2
   b      __________/‾‾‾‾‾‾‾‾‾‾‾‾\___________     b is 0 before T1, 1 before T2 and T3

   T1: sampled a = 1  -> antecedent true, b must be 1 at T2
   T2: sampled b = 1  -> attempt from T1 passes ; sampled a = 0 -> no new obligation
   T3, T4: a = 0      -> nothing to check
```

> **Interview trap:** "What is the clock of `assert property (req |=> gnt);` written directly in a module with no `default clocking`?" There is none, and it is a compile error. A concurrent assertion always needs a clocking event from one of the four sources.

> **Common mistake:** Using a signal that glitches, or a gated clock that the design does not actually use, as the assertion clock. The assertion then samples at instants when the design is not sampling. Use the same clock (and edge) as the logic being checked.

> **Common mistake:** Writing `@(posedge clk)` inside both the sequence and the property that uses it, on different clocks, by accident. This silently creates a multi-clock property with different semantics.

### Interview questions

**Q1. How is the clock of a concurrent assertion specified?**
Explicitly with `@(posedge clk)` in the assertion, property or sequence; by inference from an enclosing `always` block; through a `default clocking` declaration; or by naming a clocking block.

**Q2. What is `default clocking`?**
A declaration that makes one clocking block the default clock for all concurrent assertions (and cycle delays) in a module, interface or program that do not specify their own clock.

**Q3. What does `##1` mean?**
A delay of one tick of the assertion's clocking event, not one time unit.

**Q4. What does `@(posedge clk iff en)` do?**
It uses only the rising clock edges where `en` is true as ticks. Edges where `en` is false are skipped completely.

**Q5. Can a property use two different clocks?**
Yes. Multi-clock properties are allowed; the clock changes at an implication or at a `##1` between sub-sequences. They are used for clock-domain-crossing checks.

**Q6. What is `default disable iff`?**
A declaration that supplies a default `disable iff` condition, usually the reset, for all concurrent assertions in the scope that do not have their own.
