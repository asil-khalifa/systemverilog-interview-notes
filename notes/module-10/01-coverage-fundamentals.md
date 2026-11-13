# Module 10 Overview

Modules 1 to 9 built a complete class-based testbench: random transactions, a driver, a monitor and a scoreboard. Two questions are still open.

1. **"Have we tested enough?"** The scoreboard says that everything that was tried gave the right answer. It says nothing about what was never tried. **Functional coverage** answers this question.
2. **"Did the DUT obey the protocol rules at every clock cycle?"** The scoreboard compares complete transactions. It does not notice that `valid` dropped one cycle too early, or that a FIFO accepted a write while full. **Assertions** answer this question.

Coverage and assertions are the two measuring instruments of a verification environment. Almost every Design Verification interview contains questions on both, and "write an assertion for this waveform" and "write a covergroup for this field" are standard whiteboard exercises.

**What this module covers**

| Part | Content |
|---|---|
| 1 | Coverage fundamentals: code coverage versus functional coverage, covergroup, coverpoint, sampling |
| 2 | Bins: automatic, explicit, wildcard, ignore, illegal and transition bins |
| 3 | Cross coverage, coverage options, how the percentage is computed, coverage-driven verification, the complete `alu_coverage` class |
| 4 | Assertion fundamentals: immediate and concurrent assertions, sequences, properties, clocking, sampling |
| 5 | Assertion operators and functions: implication, delays, repetition, `$rose`, `$fell`, `$stable`, `$changed`, `$past`, `$onehot`, `$isunknown`, `disable iff`, action blocks, sequence operators, `bind` |
| 6 | Practical assertion sets for a FIFO, a valid/ready handshake, a counter and the ALU |
| 7 | Revision summary, interview questions, output-prediction and debugging questions, coding exercises |

**What you should already know**

| From | Needed here |
|---|---|
| Module 1 | Four-state values, `$isunknown`, enums, expression width rules |
| Module 4 | Classes, constructors, handles (a covergroup inside a class is created with `new`) |
| Module 5 | Constraints (coverage tells you which constraints to change) |
| Module 6 | The `alu_txn` transaction class and the idea of a verification plan |
| Module 8 | Interfaces and clocking blocks (assertions are usually placed in the interface) |
| Module 9 | Monitor and scoreboard (the coverage collector receives transactions from the monitor) |

**Simulation-only or synthesizable?** Covergroups are simulation-only. Assertions are ignored by synthesis; they are used in simulation and are also the input language of formal verification tools.

> **Note:** As in the earlier modules, the "Expected output" blocks were worked out by hand from the IEEE 1800 rules and were not captured from a simulator run. The stimulus in every example is fixed (not random), so the coverage percentages and the assertion failure times are deterministic. In assertion examples the only text shown as exact output is text printed by the example's own `$display` calls. Messages that a simulator generates by itself (for a failing assertion with no `else` clause, or for an illegal bin) have a different layout in every tool.

**How the timing in the examples is arranged**

All clocked examples use the same scheme, so that you can check every result by hand:

```text
   clk starts at 0 and toggles every 5 time units

   time     0    5    10   15   20   25   30   35   40   45
   clk      ___/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\__
   posedge       ^         ^         ^         ^         ^
   cycle         0         1         2         3         4      cycle k = posedge at 10k+5

   stimulus changes at time 0 and at every negedge (10, 20, 30 ...),
   so every signal is stable around each posedge and the sampled value is never in doubt
```

# Part 1: Coverage Fundamentals

## 1.1 What Is Coverage?

### In plain English

Imagine testing a lift (elevator) in a ten-storey building. You ride it a thousand times and it never fails. Is the lift fully tested? You cannot say until you know **which** rides you took. If all thousand rides were between the ground floor and floor 1, the answer is no.

Coverage is the record of which rides were taken. It is a measurement of how much of the design, or how much of the design's intended behaviour, the tests have actually exercised.

### Technical definition

**Coverage** is a metric, expressed as a percentage, of the completeness of verification. There are two families:

- **Code coverage** measures how much of the **RTL source code** was exercised. The simulator collects it automatically.
- **Functional coverage** measures how many of the **features and scenarios listed in the verification plan** were exercised. The verification engineer writes it, using `covergroup` constructs (data-oriented coverage) and `cover property` statements (temporal, protocol-oriented coverage).

### Why it is needed

A constrained-random testbench generates stimulus that nobody wrote by hand, so nobody knows in advance what a given test did. Without coverage:

- you cannot tell whether a corner case (FIFO full and a simultaneous read and write, an addition that produces a carry) ever happened;
- you cannot tell when to stop running tests;
- you cannot tell whether a new test added anything;
- "1000 tests passed" has no meaning.

Coverage turns "we ran a lot of tests" into "we exercised 97 percent of the planned scenarios, and here is the list of the remaining 3 percent".

### Where coverage fits in the testbench

```text
                 +-----------+     gen2drv_mbx     +----------+       +---------+
                 | generator | ------------------> |  driver  | ----> |         |
                 +-----------+                     +----------+       |   DUT   |
                                                                      |         |
   +----------+      +------------+   mon2scb_mbx   +---------+       |         |
   | coverage | <--- | scoreboard | <-------------- | monitor | <---- |         |
   | collector|      +------------+                 +---------+       +---------+
   +----------+
     sample(txn)      Coverage is sampled from OBSERVED transactions (what reached the DUT),
                      not from generated ones (what the generator intended to send).
```

> **Key point:** Coverage records that something **happened**. It does not record that the DUT **behaved correctly** when it happened. Correctness is the job of the scoreboard and the assertions. Coverage is only meaningful together with checking: 100 percent coverage in a testbench with no checker proves nothing.

### Interview questions

**Q1. What is coverage?**
A measurement of how much of the design (code coverage) or of the planned functionality (functional coverage) has been exercised by the tests. It is used to judge verification progress and completeness.

**Q2. Why is coverage needed in constrained-random verification?**
Because random stimulus is not written by hand, the engineer does not know which scenarios occurred. Coverage is the feedback that shows which planned scenarios were hit, which were missed, and when verification can stop.

**Q3. Does 100 percent coverage mean the design has no bugs?**
No. Coverage shows only that scenarios were exercised. Bugs remain if the checkers are weak, if the coverage model itself is missing scenarios, or if a feature was never implemented (code coverage cannot see missing code).

## 1.2 Code Coverage vs Functional Coverage

### Code coverage

Code coverage answers: **"Which parts of the RTL did the simulation execute?"** The simulator instruments the RTL when a compile or run option is given; no extra code is written.

| Type | What it measures | Example of a hole |
|---|---|---|
| Statement (line) coverage | Each executable statement was executed at least once | An assignment inside an error-handling branch never ran |
| Block coverage | Each `begin`...`end` block was entered | Similar to statement coverage, counted per block |
| Branch coverage | Each branch of every `if`/`else` and `case` was taken, both the true and the false direction | An `if` without `else` was always true; the false path was never taken |
| Condition coverage | Each sub-condition of a Boolean condition was seen as both true and false | In `if (a \|\| b)`, `b` was never the reason the condition was true |
| Expression coverage | The same analysis for expressions on the right of assignments | In `y = a & b`, the case `a=1, b=0` never occurred |
| Toggle coverage | Each bit of each signal changed 0→1 and 1→0 | The top address bit never became 1 |
| FSM coverage | Each state was visited and each state transition was taken | The `ERROR` state was never entered |

**Why branch coverage is not enough: an example**

```systemverilog
always_comb begin
  if (a || b) y = 1;      // statement 1
  else        y = 0;      // statement 2
end
```

| Tests applied (`a`,`b`) | Statement | Branch | Condition |
|---|---|---|---|
| (1,0) only | 50% (statement 2 never ran) | 50% | Incomplete |
| (1,0) and (0,0) | 100% | 100% (true and false both taken) | Incomplete: `b` was never 1 |
| (1,0), (0,0) and (0,1) | 100% | 100% | Complete: each of `a` and `b` independently made the condition true |

### Functional coverage

Functional coverage answers: **"Which features of the specification did the simulation exercise?"** It is derived from the verification plan and written by the engineer.

Examples for the ALU:

- Was every opcode executed?
- Was every opcode executed with `a` = 0, with `a` = 255, and with a value in between?
- Did an addition produce a carry? Did a subtraction produce a borrow?
- Did two additions occur back to back?

None of these can be read from code coverage. The line `ALU_ADD: result_nxt = a + b;` is 100 percent covered by statement coverage after a single addition of 1 + 1.

### Comparison table

| Aspect | Code coverage | Functional coverage |
|---|---|---|
| Question answered | Was this code executed? | Was this feature or scenario exercised? |
| Based on | The RTL implementation | The specification and verification plan |
| Who creates it | The tool, automatically | The verification engineer, manually |
| Effort | A compile/run option | Design and coding of a coverage model |
| SystemVerilog constructs | None | `covergroup`, `coverpoint`, `bins`, `cross`, `cover property` |
| Can detect a missing feature | No. Code that was never written cannot be uncovered | Yes, if the feature is in the plan |
| Can detect unreachable or dead code | Yes | No |
| Risk | Gives false confidence: every line executed does not mean every scenario | Only as good as the plan: a scenario nobody thought of is not measured |
| Types | Statement, branch, condition, expression, toggle, FSM | Data coverage (covergroups), temporal coverage (cover properties) |

### Reading the two numbers together

| Code coverage | Functional coverage | What it means | Action |
|---|---|---|---|
| High | High | Good position | Review the remaining holes; sign off |
| High | Low | The code runs, but the planned scenarios are not being produced | Improve stimulus: add constraints, tests, sequences |
| Low | High | The coverage model is too weak, or the RTL contains code for features not in the plan, or dead code | Review the plan and the coverage model; ask the designer about the uncovered code |
| Low | Low | Verification is at an early stage | Keep going |

> **Interview trap:** "If I have 100 percent code coverage, why do I need functional coverage?" Because code coverage cannot see (1) features that were specified but never implemented, (2) combinations of values and sequences of events: each line can be executed without the important combinations ever occurring. And the reverse: "If I have 100 percent functional coverage, why do I need code coverage?" Because the functional model may be incomplete, and code coverage reveals RTL that no planned scenario reaches.

> **How to say it in an interview:** "Code coverage is implementation-based and automatic: it tells me which lines, branches, conditions, toggles and FSM states of the RTL were exercised. Functional coverage is specification-based and user-written: it tells me which features and corner cases from the verification plan were exercised. Sign-off needs both, plus all tests passing and all assertions passing."

### Interview questions

**Q1. What are the types of code coverage?**
Statement (line), block, branch, condition, expression, toggle and FSM (state and transition) coverage.

**Q2. What is the difference between branch and condition coverage?**
Branch coverage checks that each `if`/`case` decision went both ways as a whole. Condition coverage checks each Boolean sub-expression of the decision individually. `if (a || b)` has 100 percent branch coverage with the inputs (1,0) and (0,0), but condition coverage is incomplete because `b` was never 1.

**Q3. What is toggle coverage used for?**
It shows whether every bit of every signal went both 0→1 and 1→0. It is useful for finding stuck or unconnected bits, especially at block boundaries and in gate-level or connectivity checks.

**Q4. Functional coverage is 100 percent but code coverage is 80 percent. What do you conclude?**
The functional coverage model is incomplete, or the RTL contains unreachable/dead code or features that are not in the verification plan. The uncovered code must be analysed: either new coverage items and tests are added, or the code is justified and excluded with the designer's agreement.

**Q5. Code coverage is 100 percent but functional coverage is 70 percent. What do you conclude?**
The tests execute all the code but do not produce all the planned scenarios (value combinations, sequences, corner cases). The stimulus must be improved with new constraints, seeds or directed tests.

**Q6. Can functional coverage be collected without writing code?**
No. It must be modelled by the engineer with covergroups and cover properties. That is its main cost and also its value: it encodes the verification plan in executable form.

## 1.3 Covergroup

### In plain English

A covergroup is a **tally sheet**. You decide which variables you want to watch and which values or value ranges count as separate "boxes". Each time you say "sample now", the covergroup looks at the current values of those variables and puts a tick in the matching boxes. At the end of the test, the fraction of boxes that have at least one tick is the coverage.

### Technical definition

A `covergroup` is a user-defined type that encapsulates the specification of a coverage model. It can contain:

- an optional **sampling event** (for example `@(posedge clk)`),
- one or more **coverpoints** (a variable or expression to observe),
- **bins** for each coverpoint (the boxes),
- **cross coverage** between coverpoints,
- **options** that control how coverage is collected and computed,
- optional formal arguments.

Like a class, a covergroup is only a definition. Nothing is collected until an **instance** is created with `new`.

### Syntax

```systemverilog
covergroup <name> [ ( <arguments> ) ] [ <sampling event> ];
  [ option.<name> = <value>; ]
  <label> : coverpoint <expression> [ iff ( <condition> ) ] [ { <bins> } ];
  <label> : cross <coverpoint>, <coverpoint> [ { <cross bins> } ];
endgroup

<name> <instance> = new( <arguments> );       // an instance must be constructed
```

### Where a covergroup can be declared

| Location | Typical use |
|---|---|
| Inside a `class` (an "embedded" covergroup) | The normal case in a class-based testbench: coverage of transaction fields |
| Inside a `module` or `interface` | Coverage of signals, sampled on a clock |
| Inside a `package` | A reusable covergroup type, usually with arguments |
| Inside a `program` or `checker` | Less common |

### How it works internally

```text
   covergroup definition (compile time)          instance (run time, after new)
   ------------------------------------          --------------------------------------
   cp_mode : coverpoint mode                  cp_mode bins   auto[0] auto[1] auto[2] auto[3]
             (2-bit variable)                 hit counters      0       0       0       0

   each sample():
      1. evaluate the coverpoint expression            mode = 1
      2. find the bin(s) that contain the value        auto[1]
      3. increment the hit counter of those bins       0 1 0 0

   at any time:
      coverage of cp_mode = (bins whose counter >= at_least) / (number of bins) x 100
```

The simulator stores one hit counter per bin. At the end of simulation the counters are written to a coverage database, and the databases from all the tests of a regression are merged.

### Complete example 1: a covergroup in a module

```systemverilog file=tb_cg_basic.sv
module tb_cg_basic;

  bit [1:0] mode;        // 4 possible values
  bit [7:0] data;        // 256 possible values

  covergroup cg_basic;
    cp_mode: coverpoint mode;
    cp_data: coverpoint data;
  endgroup

  cg_basic cg = new();

  initial begin
    mode = 0;  data = 0;    cg.sample();
    mode = 1;  data = 3;    cg.sample();
    mode = 1;  data = 4;    cg.sample();
    mode = 3;  data = 255;  cg.sample();

    $display("cp_mode coverage    = %0.2f%%", cg.cp_mode.get_coverage());
    $display("cp_data coverage    = %0.2f%%", cg.cp_data.get_coverage());
    $display("covergroup coverage = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_mode coverage    = 75.00%
cp_data coverage    = 4.69%
covergroup coverage = 39.84%
```

**Line by line**

| Code | Explanation |
|---|---|
| `covergroup cg_basic;` | Declares a covergroup type with no sampling event. It will be sampled by calling `sample()`. |
| `cp_mode: coverpoint mode;` | A coverpoint on `mode`, labelled `cp_mode`. No bins are written, so the tool creates **automatic bins**: one per value, four bins. |
| `cp_data: coverpoint data;` | `data` has 256 values, more than the default limit of 64 automatic bins. The tool creates 64 bins of four consecutive values each: `[0:3]`, `[4:7]` ... `[252:255]`. Section 2.1 gives the rule. |
| `cg_basic cg = new();` | Creates the instance. Without this line no coverage is collected, and calling `cg.sample()` is a null-handle error. |
| `cg.sample();` | Built-in method: sample every coverpoint now. |
| Samples of `mode` | 0, 1, 1, 3. Bins hit: 0, 1 and 3. Three of four bins: 75 percent. |
| Samples of `data` | 0 and 3 fall in the same bin `[0:3]`; 4 falls in `[4:7]`; 255 falls in `[252:255]`. Three of 64 bins: 4.6875 percent, printed as 4.69. |
| `cg.cp_mode.get_coverage()` | Coverage of one coverpoint, returned as a `real` between 0 and 100. |
| `cg.get_coverage()` | Coverage of the whole covergroup: the average of its coverpoints (each has weight 1): (75 + 4.6875) / 2 = 39.84. |

### Complete example 2: a covergroup in a class

```systemverilog file=tb_cg_class.sv
module tb_cg_class;

  class packet_cov;
    bit [1:0] kind;
    bit [3:0] len;

    covergroup pkt_cg;
      cp_kind: coverpoint kind;
      cp_len : coverpoint len {
        bins small = {[0:3]};
        bins large = {[4:15]};
      }
    endgroup

    function new();
      pkt_cg = new();            // an embedded covergroup must be constructed here
    endfunction

    function void sample(bit [1:0] k, bit [3:0] l);
      kind = k;
      len  = l;
      pkt_cg.sample();
    endfunction
  endclass

  packet_cov cov;

  initial begin
    cov = new();
    cov.sample(2'd0, 4'd2);
    cov.sample(2'd1, 4'd9);
    cov.sample(2'd1, 4'd3);
    $display("pkt_cg coverage = %0.2f%%", cov.pkt_cg.get_coverage());
  end

endmodule
```

```output
pkt_cg coverage = 75.00%
```

**Line by line**

| Code | Explanation |
|---|---|
| `covergroup pkt_cg; ... endgroup` inside the class | An embedded covergroup. It can read the class properties `kind` and `len` directly. The declaration also creates a class member named `pkt_cg`, which is the instance handle. |
| `bins small = {[0:3]};` | An explicit bin that covers the values 0 to 3. `cp_len` has exactly two bins. Section 2.2 covers explicit bins. |
| `pkt_cg = new();` in the constructor | An embedded covergroup must be constructed **in the class constructor** `new`. If the line is forgotten, the covergroup handle is `null`. |
| `function void sample(...)` | A wrapper method: copy the values into the class properties, then call the covergroup's built-in `sample()`. |
| Result | `kind` saw 0 and 1: two of four bins, 50 percent. `len` saw 2 (small), 9 (large) and 3 (small): two of two bins, 100 percent. Average: 75 percent. |

### Rules for covergroups in classes

| Rule | Detail |
|---|---|
| Construction | `cg_name = new();` must be executed in the constructor of the enclosing class |
| One instance per object | The embedded covergroup name is both the type and the variable. You cannot declare a second variable of that type in the class |
| Several covergroups | A class may contain several embedded covergroups; construct each of them in `new` |
| Access to members | Coverpoints may use any property of the class, including properties reached through a handle (`txn.a`) |
| Null handles | If a coverpoint expression is `txn.a`, the handle `txn` must not be `null` when `sample()` is called |

### Covergroup with arguments

A covergroup can take arguments, which makes one definition reusable:

```systemverilog
covergroup cg_range (int lo, int hi) with function sample(int v);
  cp_v: coverpoint v {
    bins below    = {[$:lo-1]};
    bins in_range = {[lo:hi]};
    bins above    = {[hi+1:$]};
  }
endgroup

cg_range cg_len  = new(4, 64);       // two instances with different limits
cg_range cg_gap  = new(1, 10);
```

Arguments are passed once, at construction. A `ref` argument (`covergroup cg (ref bit [7:0] sig) @(posedge clk);`) lets each instance watch a different variable.

### Built-in methods of a covergroup

| Method | Purpose |
|---|---|
| `sample()` | Trigger sampling of the covergroup |
| `get_coverage()` | Coverage of the covergroup **type**, over all instances (0 to 100, `real`) |
| `get_inst_coverage()` | Coverage of this **instance** only |
| `start()` / `stop()` | Resume / suspend collection for this instance |
| `set_inst_name(string)` | Give the instance a name for the report |

Section 3.3 explains the coverage query methods in detail.

> **Common mistake:** Declaring a covergroup and forgetting to construct it. The definition alone collects nothing. In a module: `cg_basic cg = new();`. In a class: `cg_name = new();` inside the constructor.

> **Common mistake:** Constructing an embedded covergroup outside the class constructor, for example in a `build()` method. The standard requires construction in `new`; tools report an error.

> **Verification application:** In the layered testbench of Module 9, the coverage collector is a small class, `alu_coverage`, that owns the covergroup `alu_cg`. The scoreboard (or a separate subscriber connected to the monitor) calls `cov.sample(txn)` for every observed transaction. Section 3.5 gives the complete class.

### Interview questions

**Q1. What is a covergroup?**
A user-defined construct that encapsulates a functional coverage model: coverpoints, bins, crosses, options and an optional sampling event. It must be instantiated with `new` before it collects anything.

**Q2. Where can a covergroup be defined?**
In a class, module, interface, package, program or checker.

**Q3. How do you instantiate a covergroup that is declared inside a class?**
By assigning `covergroup_name = new();` inside the class constructor. The embedded covergroup's name serves as the handle.

**Q4. Can a class have more than one covergroup?**
Yes. Each one is constructed in the class constructor.

**Q5. What happens if a covergroup is never constructed?**
No coverage is collected for it. If its `sample()` method is called, a null-handle error occurs.

**Q6. Can a covergroup have arguments?**
Yes. Arguments are supplied to `new` and can be used in bin definitions, or passed by `ref` so that different instances observe different variables.

## 1.4 Coverpoint

### In plain English

A coverpoint is **one thing you want to watch**: a variable, or an expression built from variables. For that one thing, the coverpoint holds the list of boxes (bins) into which its values are sorted.

### Technical definition

A `coverpoint` specifies an integral expression to be covered. Each coverpoint has a set of **bins** associated with the sampled values or value transitions of the expression. The bins are either defined explicitly by the user or created automatically by the tool. A coverpoint may have an `iff` guard: when the guard expression is false at the moment of sampling, the coverpoint is not sampled.

### Syntax

```systemverilog
[ <label> : ] coverpoint <expression> [ iff ( <guard> ) ]
{
  bins          <name> = { <values> };
  ignore_bins   <name> = { <values> };
  illegal_bins  <name> = { <values> };
  option.<name> = <value>;
}
```

or, with automatic bins, simply:

```systemverilog
<label> : coverpoint <expression>;
```

### What can be covered

| Coverpoint | Meaning |
|---|---|
| `coverpoint mode;` | A variable. With no label, the coverpoint takes the variable's name |
| `cp_op: coverpoint txn.op;` | A class property reached through a handle |
| `cp_carry: coverpoint txn.result[8];` | A bit-select or part-select |
| `cp_sum: coverpoint (a + b);` | An expression. Its width follows the normal expression rules of Module 1 |
| `cp_zero: coverpoint (result == 0);` | A 1-bit condition: two automatic bins, for 0 and 1 |
| `cp_len: coverpoint pkt.payload.size();` | A function call result |
| `cp_addr: coverpoint addr iff (valid);` | Sampled only when `valid` is true |

Only **integral** expressions can be covered: bits, vectors, integers, enums. A `real` or a `string` cannot be a coverpoint (IEEE 1800-2012 added limited support for `real` coverpoints with explicit bins, but tool support is uneven).

> **Key point:** Give every coverpoint a **label** (`cp_op:`). The label is the name in the coverage report, the name used in a `cross`, and the name used to call `get_coverage()` on the coverpoint. A coverpoint on an expression without a label gets a tool-generated name.

### The iff guard

```systemverilog
cp_addr: coverpoint addr iff (valid && !reset);
```

When `sample()` is called (or the sampling event fires), the guard is evaluated first. If it is false, this coverpoint is skipped for this sample: no bin counter changes. Other coverpoints in the same covergroup are not affected.

```text
   sample #   valid   addr     cp_addr sampled?
   --------   -----   ----     ----------------
      1         0     8'h10    no   (guard false: the value is on the bus by accident)
      2         1     8'h20    yes
      3         1     8'h20    yes
      4         0     8'hFF    no
```

A guard can also be attached to a single bin: `bins b = {[0:3]} iff (en);`.

### Four-state values

If the sampled value of a coverpoint contains X or Z, it does not fall into any automatic bin and does not match any ordinary explicit bin. It is simply not counted.

### Coverpoint versus covergroup

| Property | Covergroup | Coverpoint |
|---|---|---|
| What it is | A container: the whole coverage model for one sampling moment | One observed expression inside the container |
| Sampling event | Defined at covergroup level | Inherits it; can be restricted with `iff` |
| Contains | Coverpoints, crosses, options | Bins, options |
| Instantiated with `new` | Yes | No, it exists inside a covergroup instance |
| Coverage value | Weighted average of its coverpoints and crosses | Covered bins divided by total bins |

> **Common mistake:** Sampling when the data is not meaningful. If `addr` is covered on every clock, the values present on the bus during idle cycles fill the bins, and the coverage number is a lie. Either guard the coverpoint with `iff (valid)`, or (better) call `sample()` only when the monitor has assembled a complete, valid transaction.

> **Common mistake:** Covering a wide variable with automatic bins and believing the result. A coverpoint on a 32-bit address gets 64 bins of about 67 million values each. "100 percent" then means only that 64 values spread over the range were seen. Wide variables need explicit bins chosen from the specification (Part 2).

### Interview questions

**Q1. What is a coverpoint?**
A coverpoint specifies one integral variable or expression to be covered inside a covergroup, together with its bins.

**Q2. What does `iff` do in a coverpoint?**
It is a guard. The coverpoint is sampled only if the `iff` expression is true at the sampling moment. It is used to ignore values that are not valid, for example during reset or when `valid` is low.

**Q3. Can you cover an expression?**
Yes: `coverpoint (a + b)`, `coverpoint (x == y)`, a part-select, or a function return value. It should be given a label.

**Q4. Can a `real` variable be a coverpoint?**
Not in general. Coverpoints are for integral types. A real value is normally converted to an integer or classified into an enum first.

**Q5. Why should a coverpoint have a label?**
The label names the coverpoint in reports, lets a `cross` refer to it, and lets code query it (`cg.cp_op.get_coverage()`).

## 1.5 Sampling

### In plain English

A covergroup does not watch its variables continuously. It looks at them only at the instants you choose. Choosing those instants correctly is half of writing good coverage: sample too often and meaningless values are counted; sample at the wrong instant and you record a value the DUT never used.

### Technical definition

**Sampling** is the act of evaluating the coverpoint expressions of a covergroup instance and incrementing the hit counters of the matching bins. A covergroup is sampled in one of two ways:

1. **By a sampling event** written in the covergroup header: `covergroup cg @(posedge clk);`. The covergroup is sampled automatically each time the event occurs.
2. **By calling the built-in `sample()` method** from procedural code. This is used when the covergroup has no sampling event (and may also be used in addition to an event).

### The two methods compared

| Property | Sampling event `@(...)` | `sample()` method |
|---|---|---|
| Who triggers it | The simulator, on every occurrence of the event | Your code, exactly when you call it |
| Typical location | Covergroup in a module or interface, covering signals | Covergroup in a class, covering transaction fields |
| Control | Coarse; refine with `iff` guards | Precise: one sample per completed transaction |
| Cost | Samples on every clock, even when idle | Samples only when something happened |
| Risk | Counting idle or invalid values; races | Forgetting to call it |
| Passing values | Reads variables that are in scope | Reads variables in scope, or receives arguments (`with function sample`) |

### Complete example 1: sampling event with an iff guard

```systemverilog file=tb_cg_event.sv
module tb_cg_event;

  logic     clk = 0;
  bit       valid;
  bit [1:0] mode;

  // stimulus for cycles 0..4 (index 0 is the leftmost bit / first element)
  bit [0:4] valid_v     = 5'b01011;
  bit [1:0] mode_v [5]  = '{2'd0, 2'd1, 2'd2, 2'd3, 2'd1};

  covergroup cg_mode @(posedge clk);
    cp_mode: coverpoint mode iff (valid);
  endgroup

  cg_mode cg = new();

  always #5 clk = ~clk;

  initial begin
    for (int i = 0; i < 5; i++) begin
      valid = valid_v[i];
      mode  = mode_v[i];
      @(negedge clk);
    end
    $display("cp_mode coverage = %0.2f%%", cg.get_coverage());
    $finish;
  end

endmodule
```

```output
cp_mode coverage = 50.00%
```

**Execution flow**

| Cycle | Posedge at | `valid` | `mode` | Effect on `cp_mode` |
|---|---|---|---|---|
| 0 | 5 | 0 | 0 | Guard false: not sampled |
| 1 | 15 | 1 | 1 | Bin for value 1 hit |
| 2 | 25 | 0 | 2 | Guard false: not sampled |
| 3 | 35 | 1 | 3 | Bin for value 3 hit |
| 4 | 45 | 1 | 1 | Bin for value 1 hit again |

Two of the four bins (values 1 and 3) were hit: 50 percent. Without the guard, the values 0 and 2 would have been counted too and the coverage would be 100 percent, although the design never treated those values as valid.

**Line by line**

| Code | Explanation |
|---|---|
| `covergroup cg_mode @(posedge clk);` | The covergroup is sampled automatically at every rising clock edge. |
| `coverpoint mode iff (valid);` | The guard is evaluated at each sample. |
| `valid_v`, `mode_v` | The stimulus for each cycle, stored in vectors so that the example is deterministic. |
| The `for` loop | Applies the values for cycle `i`, then waits for the falling edge. Values therefore change at time 0, 10, 20... and are stable at every rising edge. |

### Complete example 2: sample() with arguments

A covergroup can declare its own `sample` method with arguments. The arguments are then the things being covered, and no intermediate variables are needed.

```systemverilog file=tb_cg_sample_args.sv
module tb_cg_sample_args;

  covergroup cg_xfer with function sample(bit [7:0] addr, bit wr);
    cp_addr: coverpoint addr {
      bins lo = {[0:127]};
      bins hi = {[128:255]};
    }
    cp_wr: coverpoint wr;
    x_addr_wr: cross cp_addr, cp_wr;
  endgroup

  cg_xfer cg = new();

  initial begin
    cg.sample(8'h10, 1'b1);      // low address, write
    cg.sample(8'hF0, 1'b0);      // high address, read
    $display("cp_addr   = %0.2f%%", cg.cp_addr.get_coverage());
    $display("cp_wr     = %0.2f%%", cg.cp_wr.get_coverage());
    $display("x_addr_wr = %0.2f%%", cg.x_addr_wr.get_coverage());
    $display("cg_xfer   = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_addr   = 100.00%
cp_wr     = 100.00%
x_addr_wr = 50.00%
cg_xfer   = 83.33%
```

**Line by line**

| Code | Explanation |
|---|---|
| `with function sample(bit [7:0] addr, bit wr);` | Overrides the built-in `sample()` with a version that takes arguments. Inside the covergroup, `addr` and `wr` are used like variables. |
| `cg.sample(8'h10, 1'b1);` | One call passes the values and samples. |
| `cp_addr`, `cp_wr` | Both address bins and both `wr` values were seen: 100 percent each. |
| `x_addr_wr` | The cross has 2 × 2 = 4 combinations. Only (lo, write) and (hi, read) occurred: 50 percent. Cross coverage is covered in Section 3.1. |
| `cg.get_coverage()` | Average of the three items: (100 + 100 + 50) / 3 = 83.33. |

### When exactly are the values read?

| Sampling method | Values used |
|---|---|
| `cg.sample()` | The values of the variables at the moment of the call |
| `@(posedge clk)` | The values at the moment the event is processed in that time step. This is **not** the "sampled value" used by assertions (Section 4.3). If a variable is changed by a blocking assignment at the same clock edge, the order is a race |
| Event sampling with `type_option.strobe = 1` | The values at the end of the time step (Postponed region), after all assignments of that time step have settled |

```text
   Race with a sampling event:

      always @(posedge clk) data = data + 1;      // blocking assignment at the clock edge
      covergroup cg @(posedge clk);  coverpoint data;  endgroup

      At each posedge, both the always block and the covergroup wake up.
      Which runs first is not defined, so the covergroup may see the old or the new value.

   Three safe alternatives:
      1. sample signals through a clocking block (Module 8): stable sampled values
      2. sample on the opposite clock edge, when nothing changes
      3. do not use a sampling event: call sample() from the monitor after it has captured
         a complete transaction   <-- the normal class-based solution
```

### Other controls

| Control | Effect |
|---|---|
| `cg.stop();` | Suspend collection for this instance (for example during reset) |
| `cg.start();` | Resume collection |
| `iff` on a coverpoint or bin | Skip the coverpoint or bin when the guard is false |
| `covergroup cg @(event_name);` | Sample when a named event is triggered: `-> event_name;` |

> **Interview trap:** "How many times is a covergroup sampled if it has `@(posedge clk)` and the simulation runs for 1000 clocks?" 1000 times, including every idle cycle, unless guards are used. Coverage quality depends on sampling only meaningful values, not on sampling often.

> **Common mistake:** Sampling the transaction in the **generator** or **driver**. That covers what the testbench intended to send, even if the driver dropped the item or the DUT ignored it during reset. Sample from the **monitor** side, which reports what was actually observed on the interface.

> **Common mistake:** Declaring a sampling event **and** calling `sample()` for the same instance without meaning to. Both take effect, so values are counted twice.

> **Verification application:** The monitor of Module 9 collects one `alu_txn` per `valid_in`/`valid_out` pair and sends it through `mon2scb_mbx`. The scoreboard checks the transaction and then calls `cov.sample(txn)`. Each real ALU operation is therefore sampled exactly once, after it has been observed at the DUT pins.

### Interview questions

**Q1. What are the ways to sample a covergroup?**
(1) A sampling event in the covergroup declaration, such as `@(posedge clk)` or a named event; (2) an explicit call to the built-in `sample()` method, optionally overridden with arguments using `with function sample(...)`.

**Q2. Which sampling method is preferred in a class-based testbench, and why?**
Calling `sample()` from the monitor or scoreboard when a complete, valid transaction has been observed. It gives precise control, avoids sampling idle or invalid data, avoids races with the clock, and is cheaper than sampling on every clock.

**Q3. What is `with function sample`?**
A way to give a covergroup its own `sample` method with arguments. The arguments can be used as coverpoint expressions, so the values to be covered are passed directly in the call.

**Q4. What is the difference between `iff` on a coverpoint and a sampling event?**
The sampling event decides when the whole covergroup is sampled. The `iff` guard is a per-coverpoint (or per-bin) condition evaluated at each sample; if it is false, that coverpoint is skipped for that sample.

**Q5. How do you stop coverage collection during reset?**
Use a guard such as `iff (rst_n)` on the coverpoints, call `cg.stop()` when reset is asserted and `cg.start()` when it is released, or simply do not call `sample()` during reset.

**Q6. Why can sampling with `@(posedge clk)` cause a race?**
The covergroup reads the current values when the event is processed. If the covered variable is updated by a blocking assignment in another process triggered by the same clock edge, the order of the two is not defined. Using a clocking block, the `strobe` option, the opposite edge, or procedural `sample()` calls avoids the race.
