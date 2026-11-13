# Part 7: Module 10 Revision and Practice

## 7.1 Revision Summary

### Coverage on one page

| Term | One-line meaning |
|---|---|
| Code coverage | Tool-generated measure of which RTL statements, branches, conditions, toggles and FSM states/transitions were exercised |
| Functional coverage | User-written measure of which planned features and scenarios were exercised |
| `covergroup` | Container of a coverage model; a type that must be instantiated with `new` |
| `coverpoint` | One integral expression to observe, with its bins; optional `iff` guard |
| Bin | A named counter for a value, set of values, or sequence of values |
| Automatic bins | Created when no bins are given: one per enum member, or min(2^M, `auto_bin_max` = 64) |
| `bins b = {..}` / `b[] = {..}` / `b[N] = {..}` | One bin / one bin per value / N bins with values spread evenly |
| `wildcard bins` | X, Z, `?` in the value are don't-care positions |
| `ignore_bins` | Values excluded from coverage, silently |
| `illegal_bins` | Values excluded from coverage; sampling one is a run-time error |
| `bins b = default` | Catches everything else; not counted |
| Transition bins | `(a => b)`, `(a => b => c)`, `(a [*3])`, `(a, b => c, d)`; hit by consecutive samples |
| `cross` | Combinations of bins of two or more coverpoints; size is the product |
| `binsof` / `intersect` | Select cross products for `bins`, `ignore_bins`, `illegal_bins` |
| `option` / `type_option` | Per-instance settings / per-type settings |
| `sample()` | Built-in method that samples the covergroup; can be given arguments with `with function sample` |
| `get_coverage()` / `get_inst_coverage()` / `$get_coverage()` | Type coverage / instance coverage / overall coverage, as a real from 0 to 100 |

**Coverage rules to remember**

- A covergroup collects nothing until it is constructed. In a class, `cg = new();` goes in the class constructor.
- With explicit bins there are no automatic bins; values outside the bins are not tracked.
- Coverage of a coverpoint or cross = covered bins / total bins. Default, ignore and illegal bins are not in the total.
- Coverage of a covergroup = weighted average of its coverpoints and crosses (each is one item).
- A bin is covered when its hit count reaches `option.at_least` (default 1).
- Sample from the monitor side, only when the data is valid.
- Coverage shows what was exercised, never that it was correct.
- Both coverpoints at 100 percent does not imply the cross is at 100 percent.

### Assertions on one page

| Term | One-line meaning |
|---|---|
| Immediate assertion | `assert (expr)`: procedural, evaluated when executed, current values, no clock; allowed in classes |
| Deferred assertion | `assert #0 (expr)`, `assert final (expr)`: immediate assertion whose report waits for the values to settle; avoids glitches |
| Concurrent assertion | `assert property (...)`: clocked, sampled values, a new attempt every tick; not allowed in classes |
| Sampled value | The value in the Preponed region: just before the clock edge |
| Sequence | A pattern of Booleans over clock ticks (`##`, repetition) |
| Property | A rule built from sequences (implication, `disable iff`) |
| `assert` / `assume` / `cover` / `restrict` | Check / constrain inputs (formal) / record occurrence / formal-only constraint |
| `a \|-> b` | Overlapped implication: `b` in the tick where `a` ends |
| `a \|=> b` | Non-overlapped: `b` one tick later; same as `a \|-> ##1 b` |
| Vacuous success | The antecedent did not match, so nothing was checked |
| `##n`, `##[m:n]` | Delay of n ticks; delay window |
| `[*n]`, `[->n]`, `[=n]` | Consecutive, goto and non-consecutive repetition |
| `$rose`, `$fell` | LSB changed to 1 / to 0 since the previous tick |
| `$stable`, `$changed` | Value same as / different from the previous tick |
| `$past(e, n)` | Value of `e` n ticks ago |
| `$onehot`, `$onehot0` | Exactly one / at most one bit is 1 |
| `$isunknown`, `$countones` | Any bit X or Z / number of 1 bits |
| `disable iff (c)` | Do not check, and cancel running attempts, while `c` is true; asynchronous |
| Action blocks | Pass statement and `else` fail statement; run in the Reactive region; default failure action is `$error` |
| `bind` | Instantiate a checker module inside a design module without editing the design |

**Assertion rules to remember**

- Regions: sample in Preponed, evaluate in Observed, action blocks in Reactive.
- A signal changing at the clock edge is seen with its old value at that tick.
- Every concurrent assertion needs a clock: explicit, inferred from `always`, or `default clocking`.
- Use `|->` for same-cycle relationships and for consequents that start with `##`; use `|=>` for registered behaviour.
- Use `$rose(x)` instead of `x` in an antecedent to get one attempt per event.
- `##[1:$]` never fails in simulation. Use a bound.
- `$rose` and `$fell` look at bit 0 only.
- Watch the width in `$past(x) + 1`.
- The reset polarity in `disable iff` must be the condition that disables.
- Reset-value assertions must not be disabled by reset.
- Print `$sampled(sig)` in action blocks.
- Prove non-vacuity with `cover property` or assertion coverage.

### The comparison tables of this module

| Comparison | Section |
|---|---|
| Code coverage vs functional coverage | 1.2 |
| Covergroup vs coverpoint | 1.4 |
| Sampling event vs `sample()` | 1.5 |
| `bins b` vs `b[]` vs `b[N]` | 2.2 |
| `ignore_bins` vs `illegal_bins` | 2.5 |
| Value bins vs transition bins | 2.6 |
| Coverpoint vs cross | 3.1 |
| `option` vs `type_option`; `get_coverage` vs `get_inst_coverage` | 3.2, 3.3 |
| Directed vs coverage-driven verification | 3.4 |
| Immediate assertion vs `if`; immediate vs concurrent | 4.2, 4.3 |
| Sequence vs property | 4.4 |
| `\|->` vs `\|=>` | 5.1 |
| `[*n]` vs `[->n]` vs `[=n]` | 5.2 |
| `$rose` vs level vs `posedge` | 5.3 |
| `$onehot` vs `$onehot0` | 5.4 |
| `disable iff` vs reset in the antecedent | 5.5 |
| `and` vs `intersect` | 5.7 |
| Assertions vs scoreboard; covergroup vs `cover property` | 5.8 |

### Simulation-only or synthesizable

| Construct | Status |
|---|---|
| `covergroup`, `coverpoint`, `cross`, bins | Simulation-only |
| Immediate and concurrent assertions | Ignored by synthesis; used in simulation and formal verification |
| `cover property`, `assume property`, `restrict property` | Simulation and/or formal only |
| `$rose`, `$past`, `$onehot` and the other functions | Not synthesizable in general (`$onehot`, `$countones` and `$clog2` are accepted by many synthesis tools in ordinary RTL expressions) |
| `bind` | A verification construct; not part of the synthesised design |

## 7.2 Interview Questions and Answers

The sections of Parts 1 to 6 contain the direct questions on each topic. The questions below are additional.

### Basic level

**Q1. What are the two main types of coverage?**
Code coverage and functional coverage.

**Q2. Which constructs are used for functional coverage?**
`covergroup` with `coverpoint`, `bins` and `cross` for data-oriented coverage; `cover property` for temporal coverage.

**Q3. How do you instantiate a covergroup?**
With `new`: `cg_type cg = new();`, or `cg_name = new();` in the constructor of a class that embeds it.

**Q4. How do you trigger sampling manually?**
By calling the covergroup's `sample()` method.

**Q5. How many automatic bins does a coverpoint on `bit [2:0]` get? On `bit [9:0]`?**
8 and 64.

**Q6. What are the two kinds of assertions?**
Immediate and concurrent.

**Q7. Which keyword turns a property into a check?**
`assert property`.

**Q8. What does `a |-> b` mean?**
If `a` is true at a clock tick, `b` must be true at the same tick.

**Q9. What does `a |=> b` mean?**
If `a` is true at a clock tick, `b` must be true at the next tick.

**Q10. What does `##2` mean?**
Two clock ticks later.

**Q11. What does `$rose(sig)` return?**
True if the LSB of `sig` is 1 at this tick and was not 1 at the previous tick.

**Q12. What is `disable iff` used for?**
To switch a property off under a condition, normally during reset.

**Q13. What are the severity system tasks?**
`$fatal`, `$error`, `$warning`, `$info`.

**Q14. Can a covergroup be declared inside a class? Can a concurrent assertion?**
A covergroup can. A concurrent assertion cannot.

**Q15. What is the default action when an assertion fails?**
An error is reported (`$error`); the simulation continues.

### Intermediate level

**Q16. A coverpoint has `bins a = {[0:3]}; bins b[] = {[4:7]}; bins c[2] = {[8:15]};`. How many bins?**
1 + 4 + 2 = 7.

**Q17. How do you cover only the legal values of an enum that has two reserved members?**
Let the tool create automatic bins and exclude the reserved members: `coverpoint op { ignore_bins rsvd = {RSVD1, RSVD2}; }`, or list the legal members in explicit bins.

**Q18. What is the difference between `iff` in a coverpoint and `ignore_bins`?**
`iff` is a run-time condition on other signals: when it is false the coverpoint is not sampled at all for that event. `ignore_bins` permanently removes particular values of the coverpoint itself from the model.

**Q19. How do you find out which bins are not covered?**
From the coverage report generated from the merged coverage database, which lists every bin with its hit count and marks the uncovered ones. `option.cross_num_print_missing` controls how many missing cross bins are listed.

**Q20. Why is functional coverage usually sampled in the monitor path and not in the driver?**
The monitor reports what really occurred at the DUT pins. The driver or generator only knows what was intended; a transaction dropped by the driver or ignored by the DUT would still be counted.

**Q21. What is the difference between a transition bin `(1 => 2)` and a cross?**
A transition bin covers values of **one** coverpoint on **consecutive samples** (a sequence in time). A cross covers values of **several** coverpoints at the **same sample** (a combination).

**Q22. How do you write coverage for "all 256 values of an 8-bit field"?**
`bins all[] = {[0:255]};` Automatic bins would only give 64 bins unless `option.auto_bin_max = 256` is set.

**Q23. What does it mean when an assertion "passes vacuously"?**
Its antecedent was false, so the consequent was not evaluated.

**Q24. Write an assertion: if `a` is high, then `b` must be high within the next 3 cycles (not in the same cycle).**
`assert property (@(posedge clk) a |-> ##[1:3] b);`

**Q25. Write an assertion: `req` and `gnt` are never high in the same cycle.**
`assert property (@(posedge clk) !(req && gnt));`

**Q26. Write an assertion: `sig` must be high for at least 2 consecutive cycles once it rises.**
`assert property (@(posedge clk) $rose(sig) |-> sig [*2]);`

**Q27. What is the difference between `$past(a)` and `##1`?**
`$past(a)` looks backwards: it returns the value of `a` at the previous tick, for use at the current tick. `##1` moves forwards: it advances the sequence by one tick. `a |=> b` and `b |-> $past(a)` relate the same two ticks but check different directions of implication.

**Q28. Where would you put the protocol assertions of a bus interface?**
In the SystemVerilog interface for that bus (or in a checker module bound to it), so that they are active wherever the interface is used.

**Q29. How do you turn assertions off for part of a test?**
`$assertoff` / `$asserton`, optionally with a hierarchy argument; or a control signal used in `disable iff`.

**Q30. What is the difference between `assert property` and `cover property`?**
`assert` reports a failure when the property is violated. `cover` never fails; it counts how often the property or sequence was observed.

### Advanced and scenario-based

**Q31. Functional coverage is 100 percent and all tests pass, but a bug escaped to silicon. How is that possible?**
(1) The coverage model did not include the scenario (the plan was incomplete). (2) The scenario was covered but the checker did not check the affected behaviour. (3) Bins were too coarse: the buggy value shared a bin with values that were hit. (4) Coverage was sampled at the wrong time or on the generator side. (5) Exclusions hid a real scenario. Coverage measures the tests against the plan; it cannot find what the plan omits.

**Q32. Your regression is stuck at 92 percent functional coverage. Describe your approach.**
List the uncovered bins and group them by cause. Run more seeds if hits are simply rare. Check constraints for accidental exclusion. Write targeted constraint-based tests or use `dist` for improbable combinations. Write directed tests for specific sequences. Confirm unreachable items with the designer and exclude them with justification. Fix errors in the coverage model itself. Re-run and re-merge.

**Q33. An assertion never fails and never passes non-vacuously. What are the possible reasons?**
The antecedent never occurs because the stimulus does not produce it; the `disable iff` polarity is wrong so the assertion is always disabled; the assertion's clock never ticks or is the wrong clock; the antecedent is written so that it can never be true (for example using a sampled value function on the clock itself); or assertions are globally switched off.

**Q34. An assertion fails at time 0 or at the first clock, before reset. Why, and what do you do?**
Signals are X before reset, or `$fell`/`$stable`/`$past` compare against an X history at the first tick. Add `disable iff (!rst_n)` (or `default disable iff`), make sure reset is asserted before the first active clock edge, and keep only dedicated reset assertions active during reset.

**Q35. Why might the same assertion pass in RTL simulation and fail in gate-level simulation?**
In gate-level simulation signals change after real delays instead of at the clock edge, there are glitches and X-pessimism, and reset or initialisation X propagates more. Assertions that sample internal signals, or that rely on zero-delay behaviour, see different values. Port-level, clock-synchronous assertions are the ones expected to hold in both.

**Q36. How do you decide between a scoreboard check and an assertion for a requirement?**
If the requirement is about signal behaviour over a few cycles (ordering, timing, stability, mutual exclusion, X), use an assertion. If it is about the correctness of transformed data, especially with queues, reordering or long latency, use the scoreboard. Simple data relationships with fixed latency can be done either way.

**Q37. What is the cost of too many covergroups or too large crosses?**
Slower simulation and larger databases, reports that nobody can read, and coverage that cannot be closed. A coverage item that does not correspond to a plan item should not exist.

**Q38. In formal verification, what is the role of `assume`?**
Assumptions describe the legal behaviour of the inputs. The formal tool explores only input sequences that satisfy them. Too few assumptions give false failures (illegal stimulus); too many, or contradictory ones, hide bugs (over-constraint), which is checked with covers.

**Q39. Why should a failing assertion not be "fixed" by adding `disable iff` conditions until it passes?**
Each added condition removes checking. The failure must first be understood: design bug, illegal stimulus, or wrong assertion. Weakening the assertion without that analysis hides the bug it found.

**Q40. How would you verify that a `valid_out` pulse is exactly one cycle wide?**
`assert property (@(posedge clk) disable iff (!rst_n) $rose(valid_out) |=> !valid_out);` (For the ALU with back-to-back operations this rule does not apply, because consecutive results keep `valid_out` high; the specification decides.)

## 7.3 Output-Prediction Questions

Work out each answer on paper before reading it.

**P1. How many bins, and what is the coverage?**

```systemverilog
bit [2:0] x;
covergroup cg;  cp: coverpoint x;  endgroup
// samples of x: 1, 1, 2, 7
```

Answer: 8 automatic bins. Values 1, 2 and 7 were hit: 3 / 8 = **37.50 percent**.

**P2. How many bins, and what is the coverage?**

```systemverilog
bit [3:0] v;
covergroup cg;
  cp: coverpoint v {
    bins a    = {[0:7]};
    bins b[]  = {[8:11]};
    bins c[2] = {[12:15]};
  }
endgroup
// samples of v: 3, 9, 9, 13
```

Answer: 1 + 4 + 2 = 7 bins. Hit: `a` (3), `b[9]` (9, twice), `c[0]` (12 to 13). 3 / 7 = **42.86 percent**.

**P3. What is the coverage?**

```systemverilog
bit x;
covergroup cg;
  option.at_least = 3;
  cp: coverpoint x;
endgroup
// samples of x: 0, 0, 0, 1, 1
```

Answer: Two bins. Value 0 has three hits (covered); value 1 has two (not covered). **50 percent**.

**P4. What is the coverage? Is there an error?**

```systemverilog
bit [2:0] x;
covergroup cg;
  cp: coverpoint x {
    bins        v[] = {[0:7]};
    ignore_bins ig  = {6, 7};
  }
endgroup
// samples of x: 0, 1, 6, 6
```

Answer: 8 - 2 = 6 counted bins. Hit: 0 and 1. 2 / 6 = **33.33 percent**. No error: ignored values are skipped silently. With `illegal_bins` the two samples of 6 would each produce a run-time error.

**P5. What are the coverpoint, cross and covergroup coverages?**

```systemverilog
bit       a;
bit [1:0] b;
covergroup cg;
  cp_a: coverpoint a;
  cp_b: coverpoint b;
  x_ab: cross cp_a, cp_b;
endgroup
// samples (a, b): (0,0), (1,3), (0,0), (1,0)
```

Answer: `cp_a`: both values, 100 percent. `cp_b`: values 0 and 3, 2 / 4 = 50 percent. `x_ab`: 2 × 4 = 8 bins; hit (0,0), (1,3), (1,0): 3 / 8 = 37.5 percent. Covergroup: (100 + 50 + 37.5) / 3 = **62.50 percent**.

**P6. Which transition bins are hit, and what is the coverage?**

```systemverilog
bit [1:0] s;
covergroup cg;
  cp: coverpoint s {
    bins t1 = (0 => 1 => 2);
    bins t2 = (1 => 2);
    bins t3 = (2 [*2]);
  }
endgroup
// samples of s: 0, 1, 1, 2, 2
```

Answer: `t1` is not hit: after 0, 1 comes another 1, not 2. `t2` is hit (third and fourth samples). `t3` is hit (fourth and fifth samples). 2 / 3 = **66.67 percent**.

**P7. At which tick does the assertion fail?**

```text
   a_t: assert property (@(posedge clk) a |=> b);

   tick   1   2   3   4
   a      1   1   0   0
   b      0   1   0   0
```

Answer: The attempt of tick 1 needs `b` at tick 2: `b` = 1, pass. The attempt of tick 2 needs `b` at tick 3: `b` = 0, **fails at tick 3**. Ticks 3 and 4 are vacuous.

**P8. Compare the two assertions on the same stimulus.**

```text
   a_edge : assert property (@(posedge clk) $rose(a) |-> ##[1:2] b);
   a_level: assert property (@(posedge clk)       a  |-> ##[1:2] b);

   tick   1   2   3   4   5   6
   a      0   1   1   1   0   0
   b      0   0   0   0   1   0
```

Answer: `a_edge` has one real attempt, at tick 2: `b` is needed at tick 3 or 4, both 0: **fails at tick 4**. `a_level` has three attempts. Tick 2: fails at tick 4. Tick 3: `b` at tick 4 is 0, at tick 5 is 1: passes at tick 5. Tick 4: `b` at tick 5 is 1: passes at tick 5. So `a_level` also reports one failure at tick 4, plus two passes; the level form creates overlapping attempts.

**P9. Does the assertion pass or fail at time 15?**

```systemverilog
// clk rises at 5, 15, 25 ...
always @(posedge clk) q <= d;                    // q updated by the same edge
a_q: assert property (@(posedge clk) d |-> q);
// d = 1 from time 10 onwards; q was 0 before time 15
```

Answer: It **fails at time 15**. At the tick at time 15 the sampled values are `d` = 1 and `q` = 0, because `q` is updated by that same edge and the assertion sees the value before the edge. The correct property for a flip-flop is `d |=> q`, which checks at time 25 and passes.

**P10. Where does the sequence match?**

```text
   sequence s;  a ##1 b [*2] ##1 c;  endsequence

   tick   1   2   3   4   5
   a      1   0   0   0   0
   b      0   1   1   0   0
   c      0   0   0   1   0
```

Answer: `a` at tick 1, `b` at ticks 2 and 3, `c` at tick 4. The sequence **matches, ending at tick 4**. (`b [*2]` binds only to `b`.)

**P11. Evaluate the functions.**

| Expression | Value |
|---|---|
| `$onehot(4'b1000)` | 1 |
| `$onehot(4'b0000)` | 0 |
| `$onehot0(4'b0000)` | 1 |
| `$onehot0(4'b1010)` | 0 |
| `$countones(8'b1011_0010)` | 4 |
| `$isunknown(4'b10z1)` | 1 |
| `$onehot(4'b1x00)` | 1 (X bits are not counted as ones) |

**P12. A 3-bit counter increments every cycle. Does this assertion ever fail?**

```systemverilog
logic [2:0] cnt;
a_c: assert property (@(posedge clk) disable iff (!rst_n) cnt == $past(cnt) + 1);
```

Answer: Yes, at the wrap-around. When the previous value is 7, the right side is 7 + 1 = 8 in 32 bits, while `cnt` is 0. It also needs care at the first tick after reset, where `$past(cnt)` refers to a tick during reset. The fix for the wrap is `$past(cnt) + 3'd1`.

## 7.4 Find-the-Error and Debugging Questions

### Compile-time errors

**E1.**

```systemverilog
class my_cov;
  bit [3:0] v;
  covergroup cg;
    coverpoint v;
  endgroup
  function void build();
    cg = new();
  endfunction
endclass
```

An embedded covergroup must be constructed in the class constructor. Move `cg = new();` into `function new();`.

**E2.**

```systemverilog
covergroup cg_a;  cp_a: coverpoint a;  endgroup
covergroup cg_b;
  cp_b: coverpoint b;
  x: cross cp_a, cp_b;
endgroup
```

A cross can only use coverpoints (or variables) of its own covergroup. Put `cp_a` and `cp_b` in the same covergroup.

**E3.**

```systemverilog
a_eq: assert (a == b); else $error("mismatch");
```

The semicolon after the condition ends the assertion; the `else` has nothing to attach to. Remove the semicolon: `assert (a == b) else $error("mismatch");`.

**E4.**

```systemverilog
class alu_driver;
  virtual alu_if vif;
  a_v: assert property (@(posedge vif.clk) vif.valid_in |=> vif.valid_out);
endclass
```

Concurrent assertions are not allowed in classes. Move the assertion into `alu_if` or into a bound checker module.

**E5.**

```systemverilog
module m (input logic clk, req, gnt);
  a1: assert property (req |=> gnt);
endmodule
```

The assertion has no clock. Add `@(posedge clk)` or a `default clocking` declaration.

**E6.**

```systemverilog
sequence s_req_gnt;
  req |-> ##1 gnt;
endsequence
```

Implication is a property operator and cannot be used in a sequence. Declare it as a `property`.

**E7.**

```systemverilog
logic [3:0] n;
a2: assert property (@(posedge clk) start |-> ##n done);
```

The delay must be a constant. Use a parameter, or a range with constant bounds, or a counter in a local variable.

**E8.**

```systemverilog
cp_st: coverpoint state {
  bins t = {IDLE => RUN};
}
```

A transition bin is written with parentheses: `bins t = (IDLE => RUN);`. Braces are for value sets.

### Run-time and logic bugs (the code compiles)

**D1.**

```systemverilog
cp_cmd: coverpoint cmd {
  bins odd = {4'b???1};
}
```

The `wildcard` keyword is missing, so `?` is a literal Z and the bin can never be hit. Write `wildcard bins odd = {4'b???1};`.

**D2.**

```systemverilog
covergroup cg @(posedge clk);
  cp_data: coverpoint data;
endgroup
```

`data` is sampled at every clock, including idle cycles and reset. The coverage fills with meaningless values. Add `iff (valid && rst_n)`, or remove the event and call `sample()` from the monitor.

**D3.**

```systemverilog
cp_addr: coverpoint addr {      // addr is 32 bits
  bins all = {[0:$]};
}
```

One bin over the whole range is covered by the first sample. The coverpoint always reports 100 percent and measures nothing. Define bins for the regions and boundaries that matter.

**D4.**

```systemverilog
a_rst: assert property (@(posedge clk) disable iff (rst_n) req |=> ack);
```

`rst_n` is active low, so the assertion is disabled whenever the design is running. It should be `disable iff (!rst_n)`.

**D5.**

```systemverilog
a_d: assert property (@(posedge clk) en |=> ##1 q == $past(d));
```

`|=>` already moves one tick; `##1` moves another. `q` is checked two ticks after `en` against `d` from one tick earlier, which is probably not the intent. For a simple register: `en |=> q == $past(d)`.

**D6.**

```systemverilog
logic [3:0] grant;
a_g: assert property (@(posedge clk) $rose(grant) |-> busy);
```

`$rose` on a vector checks only bit 0, so grants on bits 1 to 3 never trigger the assertion. Use `$rose(|grant)` or `$changed(grant) && grant != 0`.

**D7.**

```systemverilog
a_ack: assert property (@(posedge clk) req |-> ##[1:$] ack);
```

With an unbounded window the assertion cannot fail in simulation; a missing `ack` only leaves the attempt pending. Use a finite bound such as `##[1:16]`.

**D8.**

```systemverilog
a_rand: assert (txn.randomize()) else $fatal(1, "randomize failed");
```

It works until assertions are disabled; then `randomize()` may not be executed at all. Call it outside the assertion: `if (!txn.randomize()) $fatal(1, "randomize failed");`.

**D9.**

```systemverilog
a_fail: assert property (@(posedge clk) valid |-> ready)
  else $error("valid=%b ready=%b", valid, ready);
```

The message prints current values, which may already have changed after the clock edge. Print `$sampled(valid)` and `$sampled(ready)`.

**D10.**

```systemverilog
cp_op: coverpoint txn.op { option.weight = 0; }
cp_a : coverpoint txn.a  { option.weight = 0; }
// no cross declared
```

Both coverpoints have weight 0 and there is no cross that uses them, so the covergroup has nothing that counts. Either a cross was forgotten or the weights are wrong.

## 7.5 Coding Exercises with Solutions

### Exercise 1: FIFO fill-level coverage

A testbench tracks the number of entries in a 16-entry FIFO. Write a covergroup that covers the three fill classes (empty, partial, full) and the transitions empty→partial, partial→full, full→partial, partial→empty, and "full for three samples in a row". Sample the levels 0, 5, 16, 16, 3, 0 and compute the coverage.

```systemverilog file=ex01_fifo_level_cov.sv
module ex01_fifo_level_cov;

  covergroup cg_level with function sample(int unsigned level);
    cp_class: coverpoint level {
      bins empty   = {0};
      bins partial = {[1:15]};
      bins full    = {16};
    }
    cp_trans: coverpoint level {
      bins start_fill = (0 => [1:15]);
      bins reach_full = ([1:15] => 16);
      bins leave_full = (16 => [1:15]);
      bins drain      = ([1:15] => 0);
      bins stay_full  = (16 [*3]);
    }
  endgroup

  cg_level cg = new();

  initial begin
    cg.sample(0);
    cg.sample(5);
    cg.sample(16);
    cg.sample(16);
    cg.sample(3);
    cg.sample(0);
    $display("cp_class = %0.2f%%", cg.cp_class.get_coverage());
    $display("cp_trans = %0.2f%%", cg.cp_trans.get_coverage());
    $display("cg_level = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_class = 100.00%
cp_trans = 80.00%
cg_level = 90.00%
```

All three classes were sampled. The transitions 0→5, 5→16, 16→3 and 3→0 hit four bins. The FIFO was full for only two consecutive samples, so `stay_full` is the hole: 4 / 5 = 80 percent. The covergroup is the average of the two coverpoints.

### Exercise 2: check the width of a pulse

Write an assertion that a pulse on `p` is exactly two clock cycles wide, and test it with one good and one bad pulse.

```systemverilog file=ex02_pulse_width.sv
module ex02_pulse_width;

  logic clk = 0;
  logic p;

  // cycles 0..9 : a 2-cycle pulse at cycles 1-2, a 3-cycle pulse at cycles 5-7
  bit [0:9] p_v = 10'b0110011100;

  always #5 clk = ~clk;

  a_width: assert property (@(posedge clk) $rose(p) |-> p [*2] ##1 !p)
    else $display("[%0t] a_width FAILED: pulse is not exactly 2 cycles wide", $time);

  initial begin
    for (int i = 0; i < 10; i++) begin
      p = p_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[75] a_width FAILED: pulse is not exactly 2 cycles wide
```

`$rose(p)` is true at cycles 1 and 5. From cycle 1: `p` is 1 at cycles 1 and 2 and 0 at cycle 3, a pass. From cycle 5: `p` is 1 at cycles 5 and 6 but still 1 at cycle 7 (time 75), where `!p` was required. A pulse of only one cycle would fail at its second cycle, because `p [*2]` would not match.

### Exercise 3: covergroup for a packet length field

A packet has a 6-bit `len` field. Legal lengths are 1 to 60. Lengths 0 and 61 to 63 are illegal. The plan asks for: minimum, maximum, the values next to each boundary, and three ranges in between.

```systemverilog
covergroup cg_len with function sample(bit [5:0] len);
  cp_len: coverpoint len {
    bins         min       = {1};
    bins         near_min  = {2};
    bins         short_len = {[3:20]};
    bins         mid_len   = {[21:40]};
    bins         long_len  = {[41:58]};
    bins         near_max  = {59};
    bins         max       = {60};
    illegal_bins bad       = {0, [61:63]};
  }
endgroup
```

Seven counted bins. The boundary values get their own bins because off-by-one errors are found there. The illegal values produce an error if the monitor ever observes them (and the same condition should also be checked by an assertion or the scoreboard).

### Exercise 4: request/grant rules

Write assertions for: (a) a grant is given within 1 to 4 cycles after a request rises; (b) there is never a grant without a request having been made in one of the previous four cycles or in the current one; (c) `gnt` is a single-cycle pulse.

```systemverilog
default clocking cb @(posedge clk); endclocking
default disable iff (!rst_n);

// (a) forward: every request is granted in time
a_gnt_in_time: assert property ($rose(req) |-> ##[1:4] gnt);

// (b) backward: every grant has a cause
a_gnt_has_req: assert property (
  gnt |-> (req || $past(req, 1) || $past(req, 2) || $past(req, 3) || $past(req, 4)));

// (c) pulse width of one cycle
a_gnt_pulse: assert property ($rose(gnt) |=> !gnt);

// non-vacuity
c_req: cover property ($rose(req));
c_gnt: cover property ($rose(gnt));
```

The forward assertion alone would be satisfied by a design that holds `gnt` permanently high. The backward assertion and the pulse-width assertion close that gap. Checking both directions is a habit worth mentioning in an interview.

### Exercise 5: one-hot state machine

Write assertions for an FSM whose state register `state[3:0]` is one-hot encoded with `state[0]` = IDLE: (a) the state is always one-hot and known; (b) after reset the state is IDLE; (c) from IDLE the FSM leaves only when `start` is high.

```systemverilog
// (a)
a_onehot: assert property (@(posedge clk) disable iff (!rst_n)
  $onehot(state) && !$isunknown(state));

// (b) not disabled by reset
a_reset_idle: assert property (@(posedge clk) !rst_n |-> state == 4'b0001);

// (c) if we were in IDLE and start was low, we are still in IDLE
a_stay_idle: assert property (@(posedge clk) disable iff (!rst_n)
  (state[0] && !start) |=> state[0]);
```

### Exercise 6: coverage for a valid/ready channel

Write coverage showing that the channel was exercised with: immediate acceptance, a stall of one cycle, a stall of two or more cycles, and back-to-back transfers.

```systemverilog
default clocking cb @(posedge clk); endclocking

c_immediate   : cover property ($rose(valid) ##0 ready);
c_stall_1     : cover property ($rose(valid) ##0 !ready ##1 (valid && ready));
c_stall_2plus : cover property ($rose(valid) ##0 !ready [*2:$] ##1 (valid && ready));
c_back_to_back: cover property ((valid && ready) [*2]);
```

Temporal scenarios on signals are expressed most directly with `cover property`. The same information could be collected by a monitor that measures the wait time of each transfer and samples a covergroup with bins `{0}`, `{1}`, `{[2:$]}`.

### Exercise 7: add operand-boundary coverage for the ALU

Extend `alu_coverage` so that it shows, for the addition only, that both operands were at their maximum together and that a carry resulted.

```systemverilog
// inside covergroup alu_cg of class alu_coverage
cp_add_max: coverpoint (txn.a == 8'hFF && txn.b == 8'hFF) iff (txn.op == ALU_ADD) {
  bins both_max = {1'b1};
}
cp_add_max_carry: coverpoint txn.result[8]
                  iff (txn.op == ALU_ADD && txn.a == 8'hFF && txn.b == 8'hFF) {
  bins carry = {1'b1};
}
```

Each coverpoint has a single bin for the one scenario of interest. This style, a Boolean expression with one bin, is useful for specific corner cases from the verification plan.

### Further practice (no solutions given)

1. Write a covergroup for an 8-bit `addr` and a 1-bit `wr` in which the address space has three regions, 0x00-0x3F (RAM), 0x40-0x7F (registers, read-only) and 0x80-0xFF (unused). Cross region with direction, ignore writes to the read-only region, and make any access to the unused region illegal.
2. For the transition example of Section 2.6, write the stimulus that brings `cp_state` to 100 percent with the fewest samples.
3. Write an assertion: once `error` is raised it stays high until `clear` is high.
4. Write an assertion: `busy` is high from the cycle after `start` until, and including, the cycle in which `done` is high.
5. Write an assertion with a local variable: the value on `din` when `push` is high appears on `dout` exactly three cycles later.
6. In `tb_fifo_sva`, change the DUT so that `full` is asserted when the count is 15. Predict which assertions fail and at what times, then run it.
7. Add a covergroup to `handshake_sva` that covers the wait time (in cycles) of each transfer, and compute its coverage for the stimulus of Section 6.2.
8. Bind `alu_sva` to the ALU in the layered testbench of Module 9 and add its cover properties to the end-of-test report.

## 7.6 Concepts You Must Understand Before Moving Forward

**Coverage**

- [ ] I can explain code coverage and functional coverage, name the code coverage types, and say what each combination of high/low means.
- [ ] I can write a covergroup in a module and in a class, and I know where it must be constructed.
- [ ] I can explain sampling by event, by `sample()` and by `sample()` with arguments, and why coverage is sampled on the monitor side.
- [ ] I can state how many automatic bins a coverpoint gets.
- [ ] I can explain `bins b`, `bins b[]` and `bins b[N]`.
- [ ] I can write wildcard, ignore, illegal and transition bins and say how each affects the percentage.
- [ ] I can write a cross, restrict it with `binsof` and `intersect`, and count its bins.
- [ ] I can compute the coverage of a coverpoint, a cross and a covergroup by hand, including `at_least` and `weight`.
- [ ] I can explain `option` versus `type_option` and `get_coverage()` versus `get_inst_coverage()`.
- [ ] I can describe the coverage-driven verification loop and what to do with a coverage hole.

**Assertions**

- [ ] I can explain the difference between immediate, deferred and concurrent assertions.
- [ ] I can explain sampled values and the Preponed, Observed and Reactive regions, and predict what an assertion sees for a signal that changes at the clock edge.
- [ ] I can explain the sequence, property and directive layers, and `assert`, `assume`, `cover`.
- [ ] I can give the four ways of specifying the clock.
- [ ] I can explain `|->` versus `|=>` with a timeline, and vacuous success.
- [ ] I can use `##n`, `##[m:n]`, `[*n]`, `[->n]` and `[=n]`.
- [ ] I can use `$rose`, `$fell`, `$stable`, `$changed` and `$past`, and I know their behaviour at the first tick and on vectors.
- [ ] I can use `$onehot`, `$onehot0`, `$isunknown` and `$countones`.
- [ ] I can explain `disable iff`, its asynchronous nature and the polarity trap.
- [ ] I can explain action blocks, default failure behaviour and the severity tasks.
- [ ] I can write a checker module and attach it with `bind`.
- [ ] I can write a reasonable set of assertions for a FIFO, a valid/ready handshake and a counter from a verbal description.
- [ ] I can explain what belongs in an assertion and what belongs in the scoreboard.

## 7.7 What Comes Next

Module 11 completes the language with packages and `import`, parameterized and generic classes, process control (`process` handles, named `fork` blocks), `randsequence` and `randcase`, an introduction to DPI, and the commonly used system tasks. It then introduces UVM: how the generator, driver, monitor, scoreboard, coverage collector and environment that you have built by hand in Modules 6 to 10 correspond to UVM sequences, sequencers, drivers, monitors, agents, scoreboards, subscribers and environments. After Module 11, the final section collects more than 150 interview questions across all modules.
