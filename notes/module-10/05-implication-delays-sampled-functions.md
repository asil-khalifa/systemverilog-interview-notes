# Part 5: Assertion Operators and System Functions

## 5.1 Implication Operators: |-> and |=>

### In plain English

Most rules have the form **"if this happens, then that must happen"**. "If there is a request, there must be an acknowledge." The rule says nothing about cycles in which there is no request.

The implication operator expresses exactly this. Its left side is the trigger (the **antecedent**). Its right side is the obligation (the **consequent**). When the antecedent does not occur, there is nothing to check and the property is considered satisfied.

There are two implication operators. They differ only in **when** the consequent starts:

- `|->` **overlapped** implication: the consequent starts in the **same** clock tick in which the antecedent ends.
- `|=>` **non-overlapped** implication: the consequent starts in the **next** clock tick.

### Technical definition

```text
   antecedent_sequence  |->  consequent_property      overlapped
   antecedent_sequence  |=>  consequent_property      non-overlapped
```

For each evaluation attempt:

1. The antecedent sequence is evaluated starting at the tick of the attempt.
2. If the antecedent **does not match**, the property is true for this attempt. This is called **vacuous success**.
3. If the antecedent **matches**, the consequent is evaluated starting
   - at the tick where the antecedent match **ended**, for `|->`;
   - at the tick **after** the antecedent match ended, for `|=>`.
4. The property is true if the consequent holds, false if it does not.

The two operators are related by an exact identity:

```text
   a |=> b      is the same as      a |-> ##1 b
```

Implication can only be used in a **property**, never inside a sequence.

### Timing diagrams

```text
   Overlapped:       a |-> b              "when a is true, b must be true in the SAME tick"

      tick        T1     T2     T3
      a            1      0      0
      b            1      -      -           checked at T1
                   ^
                   antecedent and consequent in the same tick

   Non-overlapped:   a |=> b              "when a is true, b must be true in the NEXT tick"

      tick        T1     T2     T3
      a            1      0      0
      b            -      1      -           checked at T2
                   ^      ^
                   |      consequent
                   antecedent
```

When the antecedent is a multi-cycle sequence, the consequent is anchored to the **end** of the antecedent:

```text
   (a ##1 b) |-> c           a at T1, b at T2, c must be true at T2  (same tick as b)
   (a ##1 b) |=> c           a at T1, b at T2, c must be true at T3
```

### Complete example

```systemverilog file=tb_sva_implication.sv
module tb_sva_implication;

  logic clk = 0;
  logic req, ack;

  // stimulus for cycles 0..6 (cycle k is the posedge at time 10k+5)
  bit [0:6] req_v = 7'b0101010;
  bit [0:6] ack_v = 7'b0110001;

  always #5 clk = ~clk;

  // overlapped: ack in the SAME cycle as req
  a_overlap: assert property (@(posedge clk) req |-> ack)
    else $display("[%0t] a_overlap    FAILED: req without ack in the same cycle", $time);

  // non-overlapped: ack in the cycle AFTER req
  a_nonoverlap: assert property (@(posedge clk) req |=> ack)
    else $display("[%0t] a_nonoverlap FAILED: req not followed by ack", $time);

  initial begin
    for (int i = 0; i < 7; i++) begin
      req = req_v[i];
      ack = ack_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[35] a_overlap    FAILED: req without ack in the same cycle
[45] a_nonoverlap FAILED: req not followed by ack
[55] a_overlap    FAILED: req without ack in the same cycle
```

**Evaluation, cycle by cycle**

| Cycle | Time | `req` | `ack` | `a_overlap` (`req \|-> ack`) | `a_nonoverlap` (`req \|=> ack`) |
|---|---|---|---|---|---|
| 0 | 5 | 0 | 0 | Vacuous pass | Vacuous pass |
| 1 | 15 | 1 | 1 | **Pass**: `ack` is 1 now | Attempt starts; `ack` needed at cycle 2 |
| 2 | 25 | 0 | 1 | Vacuous pass | **Pass** (attempt of cycle 1); new attempt vacuous |
| 3 | 35 | 1 | 0 | **FAIL**: `ack` is 0 now | Attempt starts; `ack` needed at cycle 4 |
| 4 | 45 | 0 | 0 | Vacuous pass | **FAIL** (attempt of cycle 3) |
| 5 | 55 | 1 | 0 | **FAIL** | Attempt starts; `ack` needed at cycle 6 |
| 6 | 65 | 0 | 1 | Vacuous pass | **Pass** (attempt of cycle 5) |

**Points to notice**

| Observation | Explanation |
|---|---|
| The same stimulus gives different results | At cycle 5, `req` is high with no `ack`: the overlapped assertion fails immediately. The acknowledge arrives one cycle later, which satisfies the non-overlapped assertion. Choosing the wrong operator makes a correct design fail or a wrong design pass. |
| Failure time of `a_nonoverlap` | The request was at time 35; the failure is reported at time 45, when the consequent was evaluated. |
| Four of the seven attempts of each assertion were vacuous | Cycles 0, 2, 4 and 6 have `req` = 0. Nothing was checked in them. |

### Vacuous success

An implication whose antecedent never matches passes at every tick without ever checking anything. This is the main weakness of assertions: **an assertion that never triggers looks exactly like an assertion that always holds**.

```text
   a_req_ack: assert property (@(posedge clk) req |=> ack);

   If the test never drives req = 1:
        every attempt is a vacuous pass   ->   zero failures   ->   "assertion passed"
        but the rule was never tested
```

How vacuity is detected and handled:

| Technique | How |
|---|---|
| Cover the antecedent | `c_req: cover property (@(posedge clk) req);` If this cover is never hit, the assertion was never exercised |
| Assertion coverage reports | Simulators report, per assertion, the number of attempts, real (non-vacuous) passes, vacuous passes and failures |
| Do not count vacuous passes as passes | `$assertvacuousoff;` stops pass action blocks from executing on vacuous success |
| Review | An assertion with zero real passes in the whole regression is a hole, the same as an uncovered bin |

### Which operator to choose

| Situation | Operator | Example |
|---|---|---|
| The response is combinational, or must be true in the same cycle as the condition | `\|->` | `wr_en \|-> !full` |
| The response comes from a flip-flop clocked by the same edge, so it is visible one cycle later | `\|=>` | `valid_in \|=> valid_out` |
| The response comes after an explicit number of cycles | `\|->` with a delay | `req \|-> ##[1:3] ack` |
| Checking the state **after** a clocked update, in terms of the state before | `\|=>` with `$past` | `en \|=> count == $past(count) + 4'd1` |

### Overlapped versus non-overlapped

| Property | `\|->` overlapped | `\|=>` non-overlapped |
|---|---|---|
| Consequent starts | In the tick where the antecedent ends | In the tick after the antecedent ends |
| Equivalent form | `a \|-> b` | `a \|-> ##1 b` |
| Read as | "if a, then b at the same time" | "if a, then b on the next clock" |
| Typical use | Combinational relationships, conditions that must hold simultaneously, consequents that begin with an explicit `##` delay | Registered outputs, next-state checks |
| Vacuous when | The antecedent does not match | The antecedent does not match |

> **Interview trap:** "What is the difference between `a |=> b` and `a |-> ##1 b`?" None. They are equivalent. And "between `a |-> b` and `a |=> b`?": one clock tick.

> **Interview trap:** "The assertion `req |=> ack` passed in every test. Is the handshake verified?" Not necessarily. If `req` was never asserted, all passes were vacuous. Check the assertion coverage or add a `cover property` on the antecedent.

> **Common mistake:** Writing `|=> ##1 b` when one cycle of delay was intended. `a |=> ##1 b` means `b` **two** ticks after `a`.

> **Common mistake:** Using a level instead of an edge in the antecedent. `req |-> ##[1:3] ack` starts a new attempt at every tick while `req` is high. If `req` stays high for five cycles, five overlapping attempts are created and one `ack` may satisfy several of them, or late attempts may fail unexpectedly. `$rose(req) |-> ##[1:3] ack` starts one attempt per request.

> **Common mistake:** Trying to use implication inside a sequence, for example `sequence s; a |-> b; endsequence`. Implication is a property operator; the code does not compile.

### Interview questions

**Q1. What is the implication operator?**
A property operator of the form antecedent implies consequent. If the antecedent sequence matches, the consequent must hold; if the antecedent does not match, the property succeeds vacuously.

**Q2. What is the difference between `|->` and `|=>`?**
With `|->` (overlapped) the consequent is evaluated starting in the same clock tick in which the antecedent matched. With `|=>` (non-overlapped) it is evaluated starting one clock tick later. `a |=> b` is equivalent to `a |-> ##1 b`.

**Q3. What is vacuous success?**
The success of an implication because its antecedent did not match, so that the consequent was never checked.

**Q4. Why is vacuous success a problem and how do you detect it?**
An assertion whose antecedent never occurs reports no failures although it never checked anything. It is detected with assertion coverage (real passes versus vacuous passes) or with a `cover property` on the antecedent.

**Q5. In `(a ##2 b) |=> c`, at which tick is `c` checked if the attempt starts at tick 1?**
`a` at tick 1, `b` at tick 3 (the antecedent ends there), `c` at tick 4.

**Q6. Can the antecedent be a property?**
No. The antecedent must be a sequence (a Boolean is the simplest sequence). The consequent may be a property.

**Q7. Write an assertion: whenever `start` is high, `busy` must be high in the same cycle.**
`assert property (@(posedge clk) start |-> busy);`

## 5.2 Cycle Delays and Repetition

### In plain English

Protocol rules talk about time: "two cycles later", "within one to four cycles", "for three cycles in a row", "after the third occurrence". The `##` operator counts clock ticks between events. The repetition operators say how many times something must happen.

### Cycle delay: ##

| Syntax | Meaning |
|---|---|
| `a ##1 b` | `b` is true exactly one tick after `a` |
| `a ##N b` | `b` is true exactly N ticks after `a` (N is a constant ≥ 0) |
| `a ##0 b` | `a` and `b` are true in the same tick (used to join two sequences at a common tick) |
| `a ##[m:n] b` | `b` is true at some tick between m and n ticks after `a` |
| `a ##[1:$] b` | `b` is true at some later tick; `$` means "no upper limit" |
| `##2 b` | A sequence beginning with a delay: `b` is true two ticks after the starting point |
| `a ##[*] b`, `a ##[+] b` | Short forms of `##[0:$]` and `##[1:$]` (IEEE 1800-2009) |

```text
   a ##2 b                     tick:   T    T+1   T+2
                               a       1
                               b                   1

   a ##[1:3] b                 tick:   T    T+1   T+2   T+3
                               a       1
                               b            ?     ?     ?       b must be 1 at one of these

   As a consequent, ##[1:3] b succeeds at the FIRST tick where b is 1,
   and fails at T+3 if b was 0 at T+1, T+2 and T+3.
```

### Repetition operators

| Operator | Name | Meaning |
|---|---|---|
| `a [*n]` | Consecutive repetition | `a` is true on n consecutive ticks |
| `a [*m:n]` | Consecutive repetition range | `a` is true on m to n consecutive ticks |
| `a [*0:$]`, `a [*]` | Zero or more | `a` true for any number of consecutive ticks, including none |
| `a [*1:$]`, `a [+]` | One or more | `a` true for at least one tick |
| `a [->n]` | Goto repetition | `a` is true on n ticks, **not necessarily consecutive**; the match **ends at the tick of the n-th occurrence** |
| `a [=n]` | Non-consecutive repetition | `a` is true on n ticks, not necessarily consecutive; the match may **extend beyond** the n-th occurrence for as long as `a` stays false |

Exact definitions in terms of simpler operators:

```text
   a [*3]     =   a ##1 a ##1 a
   a [->1]    =   (!a) [*0:$] ##1 a                  "wait for a"
   a [->2]    =   (!a)[*0:$] ##1 a ##1 (!a)[*0:$] ##1 a
   a [=2]     =   a [->2] ##1 (!a) [*0:$]
```

A repetition can also be applied to a parenthesised sequence: `(a ##1 b) [*2]` means `a ##1 b ##1 a ##1 b`.

### The three repetitions on one timeline

```text
   tick     1    2    3    4    5    6    7    8
   a        0    1    0    1    1    0    0    0
   b        0    0    0    0    0    1    0    1

   Sequence started at tick 1:

   a [*2]                 needs a at ticks 1 and 2        -> no match (a = 0 at tick 1)
   started at tick 4:     a at 4 and 5                    -> match, ends at tick 5

   a [->2]                the 2nd occurrence of a is at tick 4
                                                          -> match, ends at tick 4

   a [->3] ##1 b          the 3rd a is at tick 5, b must be 1 at tick 6
                                                          -> match, ends at tick 6

   a [=3]  ##1 b          the 3rd a is at tick 5; then a may stay 0 for a while;
                          b may be at tick 6, 7, 8 ... as long as a has not been 1 again
                                                          -> matches at tick 6 and at tick 8

   a [->3] ##1 b  if b were 0 at tick 6                   -> no match (b must come at once)
   a [=3]  ##1 b  if b were 0 at tick 6                   -> still matches at tick 8
```

### Consecutive versus goto versus non-consecutive

| Property | `[*n]` | `[->n]` | `[=n]` |
|---|---|---|---|
| Occurrences must be consecutive | Yes | No | No |
| Where the match ends | At the n-th consecutive tick | Exactly at the n-th occurrence | At the n-th occurrence or any later tick before the next occurrence |
| What may follow | The next element comes right after the last repetition | The next element comes right after the n-th occurrence | The next element may come after a gap |
| Typical use | "held for n cycles" | "after the n-th event, immediately ..." | "n events happened before ..." |
| Example | `busy [*3]` | `beat [->4] ##1 last` | `beat [=4] ##1 done` |

### Complete example

```systemverilog file=tb_sva_delay_rep.sv
module tb_sva_delay_rep;

  logic clk = 0;
  logic start, busy, done;

  // stimulus for cycles 0..11 (cycle k is the posedge at time 10k+5)
  bit [0:11] start_v = 12'b0100_0010_0000;
  bit [0:11] busy_v  = 12'b0011_0001_0000;
  bit [0:11] done_v  = 12'b0001_0000_0000;

  always #5 clk = ~clk;

  // done must arrive 1 to 3 cycles after start rises
  a_range: assert property (@(posedge clk) $rose(start) |-> ##[1:3] done)
    else $display("[%0t] a_range FAILED: no done within 3 cycles of start", $time);

  // after start rises, busy must be high for exactly 2 cycles and then low
  a_busy: assert property (@(posedge clk) $rose(start) |=> busy [*2] ##1 !busy)
    else $display("[%0t] a_busy  FAILED: busy was not high for 2 cycles", $time);

  initial begin
    for (int i = 0; i < 12; i++) begin
      start = start_v[i];
      busy  = busy_v[i];
      done  = done_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[85] a_busy  FAILED: busy was not high for 2 cycles
[95] a_range FAILED: no done within 3 cycles of start
```

**Stimulus**

```text
   cycle   0    1    2    3    4    5    6    7    8    9   10   11
   time    5   15   25   35   45   55   65   75   85   95  105  115
   start   0    1    0    0    0    0    1    0    0    0    0    0
   busy    0    0    1    1    0    0    0    1    0    0    0    0
   done    0    0    0    1    0    0    0    0    0    0    0    0
```

**Evaluation**

| Attempt | `a_range`: `$rose(start) \|-> ##[1:3] done` | `a_busy`: `$rose(start) \|=> busy [*2] ##1 !busy` |
|---|---|---|
| Starts at cycle 1 (`start` rises) | `done` allowed at cycles 2, 3, 4. It is 0 at cycle 2 and 1 at cycle 3: **passes at cycle 3** | Cycle 2: `busy`=1. Cycle 3: `busy`=1. Cycle 4: `busy`=0. **Passes at cycle 4** |
| Starts at cycle 6 (`start` rises again) | `done` allowed at cycles 7, 8, 9. It is 0 at all three: **fails at cycle 9 (time 95)** | Cycle 7: `busy`=1. Cycle 8: `busy`=0, but a second high cycle was required: **fails at cycle 8 (time 85)** |
| All other cycles | `$rose(start)` is false: vacuous | Vacuous |

**Line by line**

| Code | Explanation |
|---|---|
| `$rose(start)` | True in the tick where the sampled `start` is 1 and was 0 in the previous tick. It gives one attempt per start pulse. Section 5.3 covers it. |
| `\|-> ##[1:3] done` | The overlapped implication followed by a delay range. The consequent begins at the antecedent's tick and looks 1 to 3 ticks ahead. |
| `\|=> busy [*2] ##1 !busy` | Starting one tick after `start` rose: two consecutive ticks of `busy`, then one tick of `!busy`. |
| Failure times | `a_busy` fails as soon as the pattern is broken (cycle 8). `a_range` can only fail when the whole window has passed (cycle 9). |

### Unbounded delays and "eventually"

```systemverilog
a_eventually: assert property (@(posedge clk) req |-> ##[1:$] ack);
```

This says that `ack` must follow `req` at some point, with no deadline. In simulation such an assertion **can never fail**: if `ack` never comes, the attempt is simply still waiting when the simulation ends. Some tools report unfinished attempts at the end of the run; many do not by default.

For simulation, always give a bound (`##[1:16] ack`). To make an open-ended requirement fail at the end of simulation, IEEE 1800-2009 provides strong operators: `req |-> strong(##[1:$] ack)` or `req |-> s_eventually ack`. These are mainly used in formal verification.

> **Interview trap:** "What is the difference between `a ##1 b [*3]` and `(a ##1 b) [*3]`?" Repetition binds more tightly than `##`. The first is `a ##1 b ##1 b ##1 b` (four ticks). The second is `a ##1 b ##1 a ##1 b ##1 a ##1 b` (six ticks).

> **Interview trap:** "What is the difference between `[->n]` and `[=n]`?" Both count n non-consecutive occurrences. With goto `[->n]` the sequence ends at the n-th occurrence, so whatever follows must come immediately after it. With `[=n]` the sequence may continue past the n-th occurrence while the expression is false, so whatever follows may come later.

> **Common mistake:** Reading `##[1:3]` as "for three cycles". It is a window in which the next expression must be true **once**. "True for three cycles" is `[*3]`.

> **Common mistake:** Using a variable as a delay or repetition count: `##n` where `n` is a signal. The values in `##` and `[*]` must be compile-time constants (parameters are fine). A variable number of cycles needs a counter with a local variable, or a different formulation.

> **Verification application:** Typical uses in a bus checker: `$rose(req) |-> ##[1:8] gnt` (response time limit), `$fell(cs_n) |-> !cs_n [*4]` (minimum chip-select length), `start |=> (data_valid [->8]) ##1 done` (exactly eight data beats, then done).

### Interview questions

**Q1. What does `##3` mean?**
A delay of three ticks of the assertion's clock.

**Q2. What does `a ##[2:4] b` mean?**
After `a` is true, `b` must be true 2, 3 or 4 ticks later.

**Q3. Explain `[*n]`, `[->n]` and `[=n]`.**
`[*n]`: the expression is true on n consecutive ticks. `[->n]`: goto repetition, true on n not necessarily consecutive ticks, ending exactly at the n-th. `[=n]`: non-consecutive repetition, true on n ticks, and the match may extend past the n-th occurrence while the expression remains false.

**Q4. Write a sequence for "`a` high for 3 cycles, then `b` high for 2 cycles".**
`a [*3] ##1 b [*2]`

**Q5. Write an assertion: after `req` rises, `gnt` must come within 1 to 5 cycles.**
`assert property (@(posedge clk) $rose(req) |-> ##[1:5] gnt);`

**Q6. Can `req |-> ##[1:$] ack` fail in simulation?**
No. With an unbounded upper limit the attempt just remains pending if `ack` never arrives. A finite bound, or a strong operator such as `s_eventually`, is needed for a failure to be reported.

**Q7. What does `a [*0]` mean?**
An empty match: `a` repeated zero times, taking no clock ticks. It appears inside ranges such as `a [*0:3]`, where the sequence may skip `a` entirely.

## 5.3 Sampled Value Functions: $rose, $fell, $stable, $changed, $past

### In plain English

A Boolean such as `valid` tells you the **level** of a signal at one tick. Many rules are about **changes**: "when `valid` goes high", "while `valid` is waiting, `data` must not change", "the counter is one more than it was". These five functions compare the value at the current tick with the value at earlier ticks.

### Technical definition

The sampled value functions use the **sampled value** of their argument at the current tick of the clocking event and at previous ticks.

| Function | Returns true (1) when | Applies to |
|---|---|---|
| `$rose(expr)` | The least significant bit of `expr` changed **to 1** since the previous tick (from 0, X or Z) | LSB only |
| `$fell(expr)` | The least significant bit of `expr` changed **to 0** since the previous tick (from 1, X or Z) | LSB only |
| `$stable(expr)` | The value of `expr` is the **same** as at the previous tick | Whole expression |
| `$changed(expr)` | The value of `expr` is **different** from the previous tick (IEEE 1800-2009) | Whole expression |
| `$past(expr)` | Not a Boolean: returns the **value** `expr` had at the previous tick | Whole expression |
| `$past(expr, n)` | The value `expr` had n ticks ago | Whole expression |
| `$past(expr, n, gate)` | The value `expr` had n ticks ago, counting only ticks at which `gate` was true | Whole expression |
| `$sampled(expr)` | The sampled value of `expr` at the current tick | Whole expression |

Each function takes an optional last argument giving the clocking event; inside a clocked assertion it is taken from the assertion.

### How it works internally

```text
   clk        ___/‾‾\___/‾‾\___/‾‾\___/‾‾\___/‾‾\___/‾‾\__
   tick          0      1      2      3      4      5

   sig        _________/‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________/‾‾‾‾‾‾
   sampled       0      1      1      0      0      1

   $rose         0      1      0      0      0      1       0 -> 1
   $fell         0      0      0      1      0      0       1 -> 0
   $stable       1      0      1      0      1      0       same as previous tick
   $changed      0      1      0      1      0      1       different from previous tick
   $past(sig)    0      0      1      1      0      0       value one tick earlier
   $past(sig,2)  0      0      0      1      1      0       value two ticks earlier
```

The simulator keeps a small history of the sampled values of each expression used in such a function, like a shift register clocked by the assertion clock.

**The first tick.** At the first tick there is no earlier sample. The "previous" value is then the initial value of the variable: its declaration initialiser if it has one, otherwise the default of its type (0 for `bit`, **X for `logic`**). The diagram above assumes a two-state signal. For a `logic` signal that is 0 at the first tick without having been initialised in its declaration, the previous value is X, so `$fell` is **true** and `$stable` is false at that first tick. This is one reason almost every assertion has a `disable iff` for reset.

### Complete example

Sampled value functions can also be called in procedural code inside a clocked `always` block, where they use the clock of the block. This lets us print them tick by tick.

```systemverilog file=tb_sva_sampled_funcs.sv
module tb_sva_sampled_funcs;

  logic clk = 0;
  bit   sig;

  // stimulus for cycles 0..5 (cycle k is the posedge at time 10k+5)
  bit [0:5] sig_v = 6'b011001;

  always #5 clk = ~clk;

  always @(posedge clk)
    $display("[%0t] sig=%b  rose=%b fell=%b stable=%b changed=%b  past=%b past2=%b",
             $time, sig, $rose(sig), $fell(sig), $stable(sig), $changed(sig),
             $past(sig), $past(sig, 2));

  initial begin
    for (int i = 0; i < 6; i++) begin
      sig = sig_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
```

```output
[5] sig=0  rose=0 fell=0 stable=1 changed=0  past=0 past2=0
[15] sig=1  rose=1 fell=0 stable=0 changed=1  past=0 past2=0
[25] sig=1  rose=0 fell=0 stable=1 changed=0  past=1 past2=0
[35] sig=0  rose=0 fell=1 stable=0 changed=1  past=1 past2=1
[45] sig=0  rose=0 fell=0 stable=1 changed=0  past=0 past2=1
[55] sig=1  rose=1 fell=0 stable=0 changed=1  past=0 past2=0
```

**Line by line**

| Time | Explanation |
|---|---|
| 5 | First tick. `sig` is a `bit`, so the "previous" value is the default 0: nothing rose or fell, the value is stable, `$past` returns 0. |
| 15 | `sig` went 0 → 1: `$rose` and `$changed` are true. `$past(sig)` is the value at time 5. |
| 25 | `sig` stayed 1: `$stable` is true. `$past(sig, 2)` is still the value from time 5. |
| 35 | `sig` went 1 → 0: `$fell` and `$changed` are true. `$past(sig, 2)` is the value from time 15. |
| 45 | Stable at 0. |
| 55 | Rose again. |

### Using the functions in assertions

```systemverilog
// A request pulse starts exactly one transaction
a_gnt: assert property (@(posedge clk) $rose(req) |-> ##[1:4] gnt);

// When chip select is released, the bus must be released in the same cycle
a_release: assert property (@(posedge clk) $fell(cs) |-> !oe);

// While valid waits for ready, data must not change
a_stable: assert property (@(posedge clk) valid && !ready |=> $stable(data));

// The address may only change when the bus is idle
a_addr: assert property (@(posedge clk) $changed(addr) |-> !busy);

// A register captures its input: q is the previous value of d
a_reg: assert property (@(posedge clk) en |=> q == $past(d));

// A counter increments by one when enabled
a_cnt: assert property (@(posedge clk) en |=> count == $past(count) + 4'd1);
```

### $past in detail

| Call | Meaning |
|---|---|
| `$past(d)` | Value of `d` one tick ago |
| `$past(d, 3)` | Value of `d` three ticks ago |
| `$past(d, 1, en)` | Value of `d` at the most recent earlier tick at which `en` was true |
| `$past(d, 2, en)` | Value of `d` at the second most recent earlier tick at which `en` was true |

The gating form is used with clock enables: if a register only loads when `en` is 1, then "the previous value" in the sense of the design is the value at the last enabled tick, not at the last clock.

`$past(d, n)` and the delay `##n` are two ways of spanning time. The following two assertions state the same rule:

```systemverilog
// looking forward from the cause
a_fwd : assert property (@(posedge clk) valid_in |=> valid_out);

// looking backward from the effect (also catches valid_out without valid_in)
a_back: assert property (@(posedge clk) valid_out |-> $past(valid_in));
```

In practice both directions are asserted: the first says "every input produces an output", the second says "there is no output without an input".

### $rose versus a level, and $rose versus posedge

| Expression | Meaning |
|---|---|
| `sig` | The sampled value is 1 at this tick (level) |
| `$rose(sig)` | The sampled value is 1 at this tick and was not 1 at the previous tick (a synchronous edge, seen through the clock) |
| `@(posedge sig)` | An event: the signal itself rises, at any time. This is an event control, not an expression, and cannot be used as a term inside a sequence |

```text
   clk    ___/‾‾\___/‾‾\___/‾‾\___/‾‾\___/‾‾\___
   tick      1      2      3      4      5
   req    _____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_________
   sampled   0      1      1      1      0

   req              -> true at ticks 2, 3, 4      (three attempts are started)
   $rose(req)       -> true at tick 2 only        (one attempt is started)
```

> **Interview trap:** "`logic [3:0] vec` changes from `4'b0010` to `4'b0100`. Is `$rose(vec)` true?" No. `$rose` and `$fell` look at the **least significant bit only**, and bit 0 stayed 0. To detect "the vector became non-zero" use `$rose(|vec)`; to detect any change use `$changed(vec)`.

> **Interview trap:** "What does `$past(sig)` return at the first clock tick?" The initial value of `sig`: its declaration initialiser, or the default of its type, which is X for four-state types.

> **Common mistake:** `count == $past(count) + 1` for a counter that wraps. The literal `1` is 32 bits wide, so the right side is evaluated in 32 bits: when `$past(count)` is 15, the sum is 16, which never equals the 4-bit `count` value 0. Write `$past(count) + 4'd1`, so that the addition wraps like the hardware. Section 6.3 demonstrates this bug.

> **Common mistake:** Using `$stable(sig)` in the same tick as the condition when the stability is required from the next tick on: `valid && !ready |-> $stable(data)` compares the data with the tick **before** `valid` rose. The correct form is `valid && !ready |=> $stable(data)`.

> **Common mistake:** `@(posedge clk) $rose(clk)`. The clock sampled at its own rising edge is always the pre-edge value 0, so `$rose(clk)` is never true. Do not apply sampled value functions to the assertion's own clock.

### Interview questions

**Q1. What do `$rose`, `$fell` and `$stable` do?**
They compare the sampled value at the current clock tick with that at the previous tick. `$rose` is true if the LSB changed to 1, `$fell` if the LSB changed to 0, and `$stable` if the whole value is unchanged.

**Q2. What is `$past`?**
A function that returns the sampled value an expression had a given number of clock ticks earlier (one by default), optionally counting only ticks at which a gating expression was true.

**Q3. What is the difference between `$rose(a)` and `@(posedge a)`?**
`$rose(a)` is a Boolean evaluated at ticks of the assertion clock; it is true if the sampled `a` is 1 now and was not 1 at the previous tick. `@(posedge a)` is an event control that triggers at the actual instant `a` rises, independent of any clock.

**Q4. What is `$changed`?**
The complement of `$stable`: true if the value differs from the previous tick.

**Q5. `$rose` is applied to a multi-bit signal. What is checked?**
Only bit 0.

**Q6. Write an assertion: `data` must not change while `valid` is high and `ready` is low.**
`assert property (@(posedge clk) valid && !ready |=> $stable(data));`

**Q7. Write an assertion that `q` is `d` delayed by two clocks.**
`assert property (@(posedge clk) q == $past(d, 2));` (with a suitable `disable iff` so that the first two ticks after reset are not checked).

**Q8. Why would you use `$rose(req)` instead of `req` as an antecedent?**
To start exactly one evaluation attempt per request. With a level, a new attempt starts at every tick while the signal is high.

## 5.4 Vector Functions: $onehot, $onehot0, $isunknown, $countones

### In plain English

These four functions look at the bits of **one** vector at one moment and answer a question about them: is exactly one bit set, is at most one bit set, is any bit unknown, how many bits are set. They are ordinary system functions: they work in assertions, in procedural code and in coverage.

### Technical definition

| Function | Returns | Definition |
|---|---|---|
| `$onehot(expr)` | 1 if **exactly one** bit of `expr` is 1 | `$countones(expr) == 1` |
| `$onehot0(expr)` | 1 if **at most one** bit of `expr` is 1 (zero or one) | `$countones(expr) <= 1` |
| `$isunknown(expr)` | 1 if **any** bit of `expr` is X or Z | `^expr === 1'bx` |
| `$countones(expr)` | The number of bits of `expr` that are 1 (an integer) | X and Z bits are not counted |
| `$countbits(expr, v1, v2, ...)` | The number of bits having any of the listed values (IEEE 1800-2012) | `$countbits(e, '0)` counts zeros; `$countbits(e, 'x, 'z)` counts unknown bits |

### Values at a glance

| `expr` | `$onehot` | `$onehot0` | `$isunknown` | `$countones` |
|---|---|---|---|---|
| `4'b0000` | 0 | 1 | 0 | 0 |
| `4'b0100` | 1 | 1 | 0 | 1 |
| `4'b0110` | 0 | 0 | 0 | 2 |
| `4'b1111` | 0 | 0 | 0 | 4 |
| `4'b01x0` | 1 | 1 | 1 | 1 |
| `4'bzzzz` | 0 | 1 | 1 | 0 |

The last two rows show that `$onehot` and `$onehot0` count only the bits that are definitely 1. A vector with one 1 and one X passes `$onehot`. If X must be rejected as well, combine the checks: `$onehot(v) && !$isunknown(v)`.

### Typical assertions

```systemverilog
// A one-hot encoded state register always has exactly one bit set
a_state_onehot: assert property (@(posedge clk) disable iff (!rst_n) $onehot(state));

// An arbiter grants to at most one requester
a_one_grant: assert property (@(posedge clk) disable iff (!rst_n) $onehot0(grant));

// Chip selects: never two active at once (active low, so invert first)
a_cs: assert property (@(posedge clk) $onehot0(~cs_n));

// Control signals are never unknown after reset
a_ctrl_known: assert property (@(posedge clk) disable iff (!rst_n)
                               !$isunknown({valid_in, valid_out}));

// Data is known whenever it is qualified by valid
a_data_known: assert property (@(posedge clk) disable iff (!rst_n)
                               valid_out |-> !$isunknown(result));

// At most two of the eight interrupt lines may be active
a_irq: assert property (@(posedge clk) $countones(irq) <= 2);
```

### $onehot versus $onehot0

| Property | `$onehot` | `$onehot0` |
|---|---|---|
| All bits zero | Fails (returns 0) | Passes (returns 1) |
| Exactly one bit set | Passes | Passes |
| Two or more bits set | Fails | Fails |
| Use when | One must always be active: one-hot FSM state, one-hot select of a multiplexer | Idle is allowed: grants, chip selects, interrupt acknowledge |

> **Interview trap:** "What is the difference between `$onehot` and `$onehot0`?" `$onehot0` also accepts the all-zero value. An arbiter with no request has `grant` = 0; `$onehot(grant)` would fail in every idle cycle.

> **Interview trap:** "Why write `valid |-> !$isunknown(data)` instead of just `!$isunknown(data)`?" Data buses are legitimately X or Z when they carry nothing (an idle or tri-stated bus). The X check is meaningful only when the data is qualified by `valid`. Control signals such as `valid` itself must never be X, so they are checked unconditionally.

> **Verification application:** "No X on the interface after reset" is the first assertion written in almost every interface. X on a control signal usually means a missing reset or an unconnected port, and since `if` statements treat X as false (Module 1, Section 4.3), the testbench might otherwise never notice.

### Interview questions

**Q1. What does `$onehot` return?**
1 if exactly one bit of the expression is 1, otherwise 0.

**Q2. What is the difference between `$onehot` and `$onehot0`?**
`$onehot` requires exactly one bit set. `$onehot0` requires at most one bit set, so it also returns 1 when all bits are zero.

**Q3. What does `$isunknown` return?**
1 if any bit of the expression is X or Z.

**Q4. What does `$countones` do?**
It returns the number of bits in the expression that are 1.

**Q5. Write an assertion that a 4-bit `grant` is one-hot or zero and never unknown.**
`assert property (@(posedge clk) disable iff (!rst_n) $onehot0(grant) && !$isunknown(grant));`

**Q6. How would you check that a signal has even parity with these functions?**
`$countones(data) % 2 == 0`, or equivalently `^data == 1'b0`.
