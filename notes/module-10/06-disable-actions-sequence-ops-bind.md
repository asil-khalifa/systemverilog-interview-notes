## 5.5 disable iff

### In plain English

During reset the design is deliberately not following its normal rules: outputs are forced to their reset values, handshakes are cut off in the middle. An assertion that keeps checking during reset reports failures that are not bugs. `disable iff` tells an assertion: **"while this condition is true, do not check, and throw away any check that is in progress"**.

### Technical definition

`disable iff (expression)` specifies a **disable condition** (normally the reset) for a property.

- If the disable condition is true when an evaluation attempt would start, the attempt is disabled.
- If the disable condition becomes true **at any time while an attempt is in progress**, even between two clock ticks, that attempt is discarded.
- A disabled attempt is neither a pass nor a fail. Its action blocks do not execute.
- The disable expression is **not sampled**: its current value is used. This makes `disable iff` behave like an asynchronous reset.

### Syntax

```systemverilog
property p_req_ack;
  @(posedge clk) disable iff (!rst_n)       // after the clock, before the property body
    req |=> ack;
endproperty

a1: assert property (@(posedge clk) disable iff (!rst_n) req |=> ack);

default disable iff (!rst_n);               // for every assertion in this scope
```

Rules:

| Rule | Detail |
|---|---|
| Position | At the top level of the property, after the clocking event. It cannot be nested inside a sub-property or a sequence |
| Number | At most one `disable iff` per assertion |
| Polarity | The expression is the condition that **disables**. For an active-low reset `rst_n` it is `!rst_n`; for an active-high `rst` it is `rst` |
| Default | `default disable iff (expr);` applies to all assertions in the scope that have no `disable iff` of their own |
| Override | An assertion with its own `disable iff` ignores the default. `disable iff (1'b0)` switches the default off for one assertion |

### How it works

```text
   property: @(posedge clk) disable iff (!rst_n)  req |=> ack

   clk     ___/‾‾\___/‾‾\___/‾‾\___/‾‾\___/‾‾\___
   tick       1      2      3      4      5
   rst_n   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\______/‾‾‾‾‾‾‾     reset pulse between tick 3 and tick 4
   req        0      0      1      0      0
   ack        0      0      0      0      0

   attempt at tick 3: req = 1, so ack is required at tick 4
                      reset becomes active before tick 4  ->  attempt DISCARDED, no failure

   without disable iff: the same attempt FAILS at tick 4 (ack = 0)
```

### Complete example

```systemverilog file=tb_sva_disable_iff.sv
module tb_sva_disable_iff;

  logic clk = 0;
  logic rst_n, req, ack;

  // stimulus for cycles 0..5 (cycle k is the posedge at time 10k+5)
  bit [0:5] rst_v = 6'b011101;      // reset active in cycle 0 and again in cycle 4
  bit [0:5] req_v = 6'b101100;
  bit [0:5] ack_v = 6'b000100;

  always #5 clk = ~clk;

  a_with_disable: assert property (@(posedge clk) disable iff (!rst_n) req |=> ack)
    else $display("[%0t] a_with_disable FAILED", $time);

  a_no_disable: assert property (@(posedge clk) req |=> ack)
    else $display("[%0t] a_no_disable   FAILED", $time);

  initial begin
    for (int i = 0; i < 6; i++) begin
      rst_n = rst_v[i];
      req   = req_v[i];
      ack   = ack_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[15] a_no_disable   FAILED
[45] a_no_disable   FAILED
```

**Evaluation**

| Cycle | Time | `rst_n` | `req` | `ack` | `a_with_disable` | `a_no_disable` |
|---|---|---|---|---|---|---|
| 0 | 5 | 0 | 1 | 0 | Disabled: reset is active | Attempt starts |
| 1 | 15 | 1 | 0 | 0 | Vacuous | **FAIL**: `ack` is 0 (attempt of cycle 0) |
| 2 | 25 | 1 | 1 | 0 | Attempt starts | Attempt starts |
| 3 | 35 | 1 | 1 | 1 | Pass (attempt of cycle 2); new attempt starts | Pass; new attempt starts |
| 4 | 45 | 0 | 0 | 0 | Attempt of cycle 3 **discarded**: reset went low at time 40 | **FAIL**: `ack` is 0 (attempt of cycle 3) |
| 5 | 55 | 1 | 0 | 0 | Vacuous | Vacuous |

**Explanation**

- The request seen at cycle 0 is sampled while reset is active. A design in reset will not answer it. `a_no_disable` reports a failure that is not a design bug.
- The request at cycle 3 is cut off by a reset at time 40, in the middle of the attempt. `a_with_disable` discards the attempt at the moment reset is asserted; `a_no_disable` fails.
- `a_with_disable` produces no output: it never fails, and it has no pass statement.

### disable iff versus putting reset in the antecedent

| Form | Behaviour |
|---|---|
| `disable iff (!rst_n) req \|=> ack` | Reset prevents attempts from starting **and** cancels attempts already running. Reset is evaluated asynchronously |
| `(rst_n && req) \|=> ack` | Reset only prevents attempts from **starting** (sampled at the clock). An attempt that started before reset continues and may fail during reset |
| `req \|=> (ack \|\| !rst_n)` | Each term must be handled by hand; unreadable for multi-cycle properties |

> **Interview trap:** "`disable iff (rst_n)` with an active-low reset: what happens?" The assertion is disabled whenever the design is **out of** reset, which is the whole useful part of the simulation. It never fails and never checks anything. Wrong reset polarity in `disable iff` is one of the most common silent assertion bugs; assertion coverage (zero non-vacuous passes) reveals it.

> **Interview trap:** "Is the `disable iff` condition sampled like the rest of the property?" No. It is evaluated with current values, continuously. A reset pulse shorter than a clock period still disables the attempts that are active at that time.

> **Common mistake:** Disabling the assertions that check the reset behaviour itself. `!rst_n |-> count == 0` under `default disable iff (!rst_n)` is always disabled. Give such an assertion `disable iff (1'b0)`, or place it in a scope without the default.

### Interview questions

**Q1. What is `disable iff`?**
A clause of a property that specifies a condition, usually reset, under which the property is not checked. Attempts that would start, and attempts already in progress, are disabled while the condition is true.

**Q2. What is the result of an attempt that is disabled?**
Neither pass nor fail. It is discarded and no action block runs.

**Q3. Is `disable iff` synchronous or asynchronous?**
Asynchronous. The expression is not sampled at the clock; if it becomes true at any time during an attempt, the attempt is disabled.

**Q4. What is the difference between `disable iff (!rst_n) a |=> b` and `(rst_n && a) |=> b`?**
The first also cancels an attempt that is already running when reset is asserted. The second only stops new attempts from starting; a running attempt continues and can fail during reset.

**Q5. How do you apply the same disable condition to all assertions in an interface?**
With `default disable iff (!rst_n);`.

## 5.6 Assertion Pass and Failure Behaviour

### The possible outcomes of an attempt

| Outcome | When | Action block executed |
|---|---|---|
| Success (non-vacuous pass) | The antecedent matched and the consequent held | Pass statement |
| Vacuous success | The antecedent did not match | Pass statement, unless vacuous passes are switched off (see below) |
| Failure | The antecedent matched and the consequent did not hold; or a property without implication was false | Fail statement; if there is none, the default `$error` |
| Disabled | The `disable iff` condition was true | None |
| Incomplete (pending) | The simulation ended while the attempt was still waiting | None; some tools list unfinished attempts in the report |

### Action blocks

```systemverilog
a_req_ack: assert property (@(posedge clk) disable iff (!rst_n) req |=> ack)
  pass_count++;                                               // pass statement (optional)
else begin                                                    // fail statement (optional)
  fail_count++;
  $error("[%0t] ack missing after req (req=%b ack=%b)",
         $time, $sampled(req), $sampled(ack));
end
```

| Fact | Detail |
|---|---|
| When action blocks run | In the **Reactive** region of the time step in which the attempt finished |
| Values seen in action blocks | Current values, after the design has updated. Use `$sampled(sig)` for the values the assertion used |
| No fail statement | The simulator reports an error (`$error`) with a tool-specific message naming the assertion, the file and line, and the time |
| `else $fatal(...)` | The simulation stops at the first failure |
| After a failure | The assertion remains active: new attempts continue at every tick, so one design bug can produce many failure messages |
| Pass statement | Rarely used. Printing in it floods the log, because most attempts are (vacuous) passes |
| `cover property` | Has one optional statement, executed when the property is covered. It has no `else` |

### What a simulator reports for a failure

With no `else` clause, a failure produces a message of this general form (the wording differs between tools):

```text
   Error: "<file>", line <n>: <hierarchical assertion name>: started at <t1> failed at <t2>
          Offending '<expression>'
```

The two times are important: the **start** time is the tick at which the antecedent began to match, and the **failure** time is the tick at which the consequent was found false. Debugging begins at the start time.

At the end of simulation the tools also provide an assertion summary and assertion coverage: for each assertion, the number of attempts, real passes, vacuous passes, failures and incomplete attempts.

### Controlling assertions

| System task | Effect |
|---|---|
| `$assertoff;` | Stops new attempts of all assertions; attempts already running continue |
| `$asserton;` | Re-enables assertions |
| `$assertkill;` | Stops new attempts and also kills attempts in progress |
| `$assertoff(0, tb_top.dut);` | The same, limited to a hierarchy (first argument: number of levels, 0 = all levels below) |
| `$assertpassoff;` / `$assertpasson;` | Disable / enable execution of pass action blocks |
| `$assertfailoff;` / `$assertfailon;` | Disable / enable execution of fail action blocks |
| `$assertvacuousoff;` | Do not execute pass action blocks for vacuous successes |
| `$assertcontrol(...)` | General form that covers all of the above (IEEE 1800-2012) |

A typical use is to switch assertions off while the DUT is deliberately driven with illegal stimulus (error-injection tests), or during the reset phase of a test: `$assertoff; apply_reset(); $asserton;`.

### Counting failures for the test verdict

```systemverilog
// in the interface
int unsigned sva_errors;

a_valid_out: assert property (valid_in |=> valid_out)
  else begin
    sva_errors++;
    $error("valid_out did not follow valid_in");
  end
```

At the end of the test, the test class reads `vif.sva_errors` together with the scoreboard's error count and prints the final PASS or FAIL. In practice `$error` is enough: every simulator counts error-severity messages, and the regression script fails the test if the count is not zero.

> **Interview trap:** "Does the simulation stop when an assertion fails?" No. By default a failing assertion issues an error and the simulation continues. It stops only if the fail statement calls `$fatal` or `$finish`, or if the simulator is configured to stop on errors.

> **Interview trap:** "Is the pass statement executed on a vacuous success?" By the standard, yes: a vacuous success is a success, unless `$assertvacuousoff` has been called. Tools differ in their default settings, so do not rely on a counter incremented in a pass statement to prove that an assertion was really exercised. Use `cover property` on the antecedent, or the tool's assertion coverage.

> **Common mistake:** Writing an action block that prints signal values without `$sampled`, then spending an hour on a message that "contradicts the waveform".

### Interview questions

**Q1. What happens by default when a concurrent assertion fails?**
The simulator issues a run-time error (as if `else $error(...)` had been written), reporting the assertion name, location and time. The simulation continues.

**Q2. What are action blocks?**
The optional statements executed when an assertion passes (pass statement) or fails (the statement after `else`).

**Q3. In which region do action blocks execute?**
The Reactive region.

**Q4. How do you make the simulation stop at the first assertion failure?**
Call `$fatal` in the fail statement, or use a simulator option that stops on assertion failure.

**Q5. How do you disable assertions during reset or error injection?**
With `disable iff` in the property, or procedurally with `$assertoff` and `$asserton` (optionally for a specific hierarchy).

**Q6. What is the difference between `$assertoff` and `$assertkill`?**
`$assertoff` prevents new attempts but lets attempts in progress finish. `$assertkill` also terminates attempts in progress.

**Q7. What information does assertion coverage give?**
For each assertion: how many attempts were made, how many passed non-vacuously, how many passed vacuously, how many failed, and how many were incomplete. An assertion with no non-vacuous pass was never really tested.

## 5.7 Sequence Operators

The implication, delay and repetition operators cover most assertions. The operators in this section combine whole sequences. For a fresher interview you should know what each one means and recognise it in code.

### Overview

| Operator | Form | Meaning |
|---|---|---|
| `and` | `s1 and s2` | Both sequences match, starting at the same tick. They may end at different ticks; the result ends when the **later** one ends |
| `intersect` | `s1 intersect s2` | Both sequences match, starting at the same tick **and ending at the same tick** (same length) |
| `or` | `s1 or s2` | At least one of the sequences matches |
| `throughout` | `expr throughout s` | The Boolean `expr` is true at **every** tick from the start to the end of `s` |
| `within` | `s1 within s2` | `s1` matches somewhere inside the span of a match of `s2` (starts no earlier, ends no later) |
| `first_match` | `first_match(s)` | Of all the possible matches of `s`, only the earliest-ending one is used |
| `.triggered` | `s.triggered` | A Boolean that is true in the time step in which sequence `s` reached its end point. Used to test, in another sequence or in procedural code, that a sequence has just completed |
| `.matched` | `s.matched` | Like `.triggered`, for a sequence on a **different clock**: true at the first tick of the destination clock after `s` ended |

### Timelines

```text
   tick              1    2    3    4    5
   a                 1    0    0    0    0
   b                 0    0    1    0    0
   c                 0    0    0    0    1
   en                1    1    1    1    0

   s1 = a ##2 b              matches ticks 1..3
   s2 = a ##4 c              matches ticks 1..5

   s1 and s2                 both match from tick 1            -> match, ends at tick 5
   s1 intersect s2           lengths differ (3 and 5 ticks)    -> NO match
   s1 or s2                  at least one matches              -> match (ends at 3, and at 5)
   en throughout s1          en = 1 at ticks 1, 2, 3           -> match
   en throughout s2          en = 0 at tick 5                  -> NO match
   (b) within s2             b occurs at tick 3, inside 1..5   -> match
```

### Typical uses

```systemverilog
// chip select must stay low for the whole transfer
a_cs_low: assert property (@(posedge clk)
  $fell(cs_n) |-> (!cs_n throughout (##[1:8] done)));

// a burst of exactly 4 beats: 'last' on the 4th valid beat, whole burst within 10 cycles
sequence s_four_beats;  valid [->4] ##0 last;  endsequence
a_burst: assert property (@(posedge clk)
  $rose(start) |=> (s_four_beats intersect (1'b1 [*1:10])));

// the response is either an acknowledge or an error
a_resp: assert property (@(posedge clk)
  req |=> (ack ##1 !ack) or (err ##1 !err));

// an interrupt pulse occurs somewhere inside the busy window
c_irq_in_busy: cover property (@(posedge clk)
  ($rose(irq) ##1 $fell(irq)) within ($rose(busy) ##[1:$] $fell(busy)));

// only the first grant after a request matters
a_first: assert property (@(posedge clk)
  first_match(req ##[1:5] gnt) |-> ##1 !gnt);
```

`intersect` with `1'b1 [*m:n]` is the standard idiom for "this sequence must take between m and n ticks": the constant-true sequence matches any m to n ticks, and `intersect` forces the two to have the same length.

### and versus intersect

| Property | `and` | `intersect` |
|---|---|---|
| Both sequences must match | Yes | Yes |
| Same start tick | Yes | Yes |
| Same end tick | Not required | **Required** |
| End of the combined match | The later of the two ends | The common end |
| Typical use | Two independent requirements after a trigger | Limiting the length of a sequence; two views of the same window |

### Why first_match matters

A sequence with a range has several possible matches. When such a sequence is the **antecedent** of an implication, the consequent must hold for **every** match:

```text
   (req ##[1:3] gnt) |-> ##1 done

   If gnt is high at 1, 2 and 3 ticks after req, the antecedent matches three times,
   and done is required after each of them.

   first_match(req ##[1:3] gnt) |-> ##1 done        only the first gnt counts
```

### Local variables (awareness level)

A sequence or property can declare a variable, capture a value at one tick and compare it at a later tick. This is how assertions check **data** across cycles.

```systemverilog
// The ALU registers its result: the sum computed from the inputs at the tick of valid_in
// must appear on result at the next tick.
property p_add_result;
  logic [8:0] exp;
  @(posedge clk) disable iff (!rst_n)
    (valid_in && op == ALU_ADD, exp = a + b) |=> (result == exp);
endproperty
a_add_result: assert property (p_add_result);
```

`(expression, variable = value)` means: when the expression is true, also perform the assignment. Each evaluation attempt has its **own copy** of the local variable, so overlapping attempts do not disturb each other. That is something a module-level variable cannot provide.

### Other property operators (awareness level)

| Operator | Meaning |
|---|---|
| `not p` | The property `p` must **not** hold. `not (a ##1 b)` means "`a` followed by `b` never happens" |
| `p1 and p2`, `p1 or p2` | Both / at least one property hold |
| `if (c) p1 else p2` | Select the property to check by a condition |
| `p1 until p2`, `s_until`, `until_with` | `p1` holds at every tick until `p2` holds (IEEE 1800-2009) |
| `nexttime p`, `always p`, `s_eventually p` | Temporal-logic operators (IEEE 1800-2009), mainly used in formal verification |
| `strong(s)`, `weak(s)` | Whether an unfinished sequence at the end of simulation counts as a failure (strong) or not (weak) |

Tool support for the 2009 operators in simulation is good in the major simulators but not universal; `##`, repetition and implication are supported everywhere.

> **Interview trap:** "What is the difference between `and` and `intersect`?" Both need both sequences to match from the same starting tick. `intersect` additionally requires them to end at the same tick.

> **Common mistake:** Using `throughout` with a sequence on the left. The left operand of `throughout` must be a Boolean expression; the right operand is the sequence.

> **Common mistake:** Checking data over several cycles with a module-level register written by the assertion's action block. Overlapping transactions overwrite it. Use a local variable in the property.

### Interview questions

**Q1. What does `throughout` do?**
`expr throughout seq` requires the Boolean expression to be true at every clock tick during the match of the sequence.

**Q2. What is the difference between `and` and `intersect` for sequences?**
`and` requires both sequences to match starting at the same tick, with any end ticks. `intersect` requires the same start tick and the same end tick.

**Q3. What does `within` do?**
`s1 within s2` matches when `s1` matches entirely inside the time span of a match of `s2`.

**Q4. What is `first_match` and when is it needed?**
It keeps only the first (earliest-ending) match of a sequence that could match several times, typically because of a delay range. It is needed when such a sequence is used as an antecedent and the consequent should be checked only once.

**Q5. What are local variables in assertions used for?**
To capture a data value at one point of a sequence and compare it at a later point, with a separate copy for each evaluation attempt. They make data-integrity checks across cycles possible, for example "the data written is the data read later".

**Q6. What is `.triggered`?**
A method of a named sequence that returns true in the time step at which the sequence reached its end. It lets another property, or procedural code such as `wait (s.triggered)`, react to the completion of a sequence.

**Q7. How do you write "sequence `s` must complete within 3 to 6 cycles"?**
`s intersect (1'b1 [*3:6])`.

## 5.8 Where Assertions Live, bind, and Assertions vs Scoreboard

### The possible locations

| Location | Who uses it | Advantages | Disadvantages |
|---|---|---|---|
| Inline in the RTL module | Designers | Next to the logic it checks; can see every internal signal | Mixes verification code with design code; must be excluded from synthesis (most tools ignore assertions, or the code is wrapped in `` `ifdef ``); RTL files change when assertions change |
| In the **interface** | Verification engineers | The natural home for protocol rules; reused wherever the interface is used; visible to the testbench through the virtual interface | Sees only the interface signals, not DUT internals |
| In a separate **checker module** connected with `bind` | Both | The RTL file is not touched; assertions are kept, reviewed and versioned separately; can still see internal signals | One more file and a port list to maintain |
| In a `checker` ... `endchecker` construct | Advanced users, formal | A construct designed for packaging assertions, with free variables for formal | Uneven simulator support |
| In a class | Not possible for concurrent assertions | | Immediate assertions only |

### bind

**In plain English.** `bind` attaches a module full of assertions to a design module **from the outside**. The simulator behaves as if the assertion module had been instantiated inside the design module, but the design source file is not edited.

**Technical definition.** The `bind` directive instantiates a module, interface, program or checker inside a target module (or inside specific instances of it) without modifying the target's source. The port connections of the bound instance are resolved **in the scope of the target**, so they can name the target's ports and its internal signals.

**Syntax**

```systemverilog
// bind to EVERY instance of a module
bind <target_module>  <checker_module>  <instance_name> ( <port connections> );

// bind to ONE specific instance
bind <hierarchical.path.to.instance>  <checker_module>  <instance_name> ( <connections> );
```

```text
   without bind                               with bind
   ------------                               ---------
   module alu (...);                          module alu (...);       <- unchanged RTL file
     ...                                        ...
     alu_sva u_sva (.*);  <- RTL edited       endmodule
   endmodule
                                              // in a separate file (or in tb_top):
                                              bind alu alu_sva u_alu_sva (.*);

   Resulting hierarchy in both cases:   tb_top.dut.u_alu_sva
```

**Example**

```systemverilog
// checker module: all ports are inputs
module alu_sva
  import alu_pkg::*;
(
  input logic       clk, rst_n, valid_in, valid_out,
  input logic [7:0] a, b,
  input alu_op_e    op,
  input logic [8:0] result
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_valid_follow: assert property (valid_in |=> valid_out);
endmodule

// bind statement: connect by name to the signals of module alu
bind alu alu_sva u_alu_sva (.*);
```

| Point | Explanation |
|---|---|
| All ports of the checker are inputs | A checker only observes |
| `bind alu ...` | Every instance of `alu` in the design receives its own copy of the checker |
| `(.*)` | Each checker port is connected to the signal of the same name inside `alu`. Named connections (`.count(count)`) can reach internal signals that are not ports |
| Where the `bind` statement goes | In a separate file compiled with the testbench, or inside `tb_top` |
| Parameters | `bind sync_fifo sync_fifo_sva #(.DEPTH(DEPTH)) u_sva (...);` passes the target's parameter to the checker |

Section 6 uses `bind` in all four practical examples.

### Assertions versus the scoreboard

| Aspect | Assertions (SVA) | Scoreboard |
|---|---|---|
| Looks at | Signals, cycle by cycle | Transactions, one per operation |
| Best at | Temporal and protocol rules: handshakes, stability, timing windows, illegal signal combinations, X checks | Data correctness: is the result what the reference model predicts? Ordering, loss or duplication of data |
| Reference | The rule written in the property | A reference model or expected-data queue |
| Time of detection | At the clock edge where the rule is broken | When the transaction completes, possibly much later |
| Where it lives | Interface, DUT (via `bind`), checker module | A class in the testbench environment |
| Language | Declarative: sequences and properties | Procedural, object-oriented |
| Reuse in formal verification | Yes | No |
| Weak at | Complex data transformations, long-lived state | Cycle-accurate protocol timing |
| Example for the ALU | "`valid_out` is high exactly one cycle after `valid_in`"; "`result` is never X when `valid_out` is high" | "For `a`=200, `b`=100, `op`=ADD the result must be 300" |

### Covergroup versus cover property

| Aspect | `covergroup` | `cover property` |
|---|---|---|
| Covers | Values, ranges, combinations (cross), value transitions of sampled data | Sequences of events on signals over clock cycles |
| Sampling | Event or `sample()` call | Every clock tick |
| Where | Classes, modules, interfaces | Modules, interfaces, checkers (not classes) |
| Granularity of result | Bins with hit counts, percentages | One hit count per cover statement |
| Typical use | Transaction-level coverage in the monitor path | Protocol scenarios: back-to-back transfers, stalls, full-to-empty |

> **Key point:** Use the scoreboard for **what** the DUT computed, assertions for **how and when** the signals behaved, covergroups for **which data** was exercised and cover properties for **which signal scenarios** occurred.

> **Interview trap:** "Can assertions replace the scoreboard?" No. Simple data checks can be written with `$past` or local variables, as in the ALU example, but a general check of data against a reference model, with queues, out-of-order responses or complex algorithms, is procedural work that belongs in a scoreboard. The opposite is also true: a scoreboard does not notice a protocol violation that happens not to corrupt the data.

> **Common mistake:** Putting the `bind` statement inside the target module's own file. The point of `bind` is that the design file stays untouched.

### Interview questions

**Q1. Where can concurrent assertions be placed?**
In modules, interfaces, programs and checkers: inline in the RTL, in the testbench interface, or in a separate checker module attached to the DUT with `bind`. They cannot be placed in classes.

**Q2. What is `bind`?**
A directive that instantiates a module (typically one containing assertions and coverage) inside a target module or instance without modifying the target's source code. The bound instance can connect to the target's ports and internal signals.

**Q3. Why use `bind` instead of writing assertions in the RTL?**
The design files stay unchanged and free of verification code; assertions can be developed, reviewed and switched on or off independently; the same checker can be bound to RTL from another team or to a gate-level netlist (for port-level checks).

**Q4. How do you bind to only one instance of a module?**
Use the hierarchical instance path as the target: `bind tb_top.dut.u_fifo0 sync_fifo_sva u_sva (...);`.

**Q5. What is the difference between an assertion and a scoreboard check?**
An assertion checks signal-level, cycle-accurate rules continuously and reports at the moment of violation. A scoreboard compares completed transactions against expected data from a reference model. They find different kinds of bugs.

**Q6. What is the difference between `cover property` and a covergroup?**
A covergroup records values, combinations and transitions of data at sampling points. `cover property` records that a temporal sequence of signal behaviour occurred. Covergroups can be used in classes; cover properties cannot.
