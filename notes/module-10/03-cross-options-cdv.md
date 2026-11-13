# Part 3: Cross Coverage, Options and Coverage-Driven Verification

## 3.1 Cross Coverage

### In plain English

Suppose a coverpoint shows that every ALU opcode was used, and another shows that operand `a` was zero, small, large and maximum. Both are at 100 percent. Was a **subtraction** ever done with `a` at its **maximum**? You cannot tell. Each coverpoint is a separate tally sheet.

**Cross coverage** is a two-dimensional tally sheet: one row per bin of the first coverpoint, one column per bin of the second, and a box for each combination. It records which **combinations** occurred at the same sample.

### Technical definition

A `cross` specifies cross coverage between two or more coverpoints (or variables) of the same covergroup. The set of **cross bins** is the Cartesian product of the bins of the crossed coverpoints. A cross bin is hit when, at one sample, each of the crossed coverpoints hits the corresponding bin. The user may regroup, ignore or declare illegal particular cross products with `bins`, `ignore_bins` and `illegal_bins` selected by `binsof` expressions.

### Syntax

```systemverilog
covergroup cg;
  cp_a: coverpoint a;
  cp_b: coverpoint b;

  x_ab : cross cp_a, cp_b;                // automatic cross bins

  x_ab2: cross cp_a, cp_b {               // user-controlled cross bins
    bins         name = binsof(cp_a.low) && binsof(cp_b) intersect {[0:3]};
    ignore_bins  name = binsof(cp_a) intersect {7};
    illegal_bins name = binsof(cp_a.max) && binsof(cp_b.max);
  }
endgroup
```

### How it works internally

```text
   cp_kind : 4 bins (k0 k1 k2 k3)          cp_dir : 2 bins (rd wr)

   x_kind_dir : cross cp_kind, cp_dir   ->   4 x 2 = 8 cross bins

                  rd        wr
            +---------+---------+
        k0  | <k0,rd> | <k0,wr> |
            +---------+---------+
        k1  | <k1,rd> | <k1,wr> |
            +---------+---------+
        k2  | <k2,rd> | <k2,wr> |
            +---------+---------+
        k3  | <k3,rd> | <k3,wr> |
            +---------+---------+

   at each sample: kind hits one row, dir hits one column -> one cross bin is incremented
   cross coverage = (cross bins hit) / (total cross bins)
```

Important rules:

| Rule | Detail |
|---|---|
| The cross works on **bins**, not on raw values | Crossing a coverpoint with 4 bins and one with 2 bins gives 8 cross bins, whatever the widths of the variables |
| Number of automatic cross bins | The product of the numbers of bins of the crossed coverpoints |
| Bins not included | `default`, `ignore_bins` and `illegal_bins` of the coverpoints do not take part in the cross |
| Same covergroup | Only coverpoints of the same covergroup can be crossed |
| Crossing a variable directly | `cross a, b;` is allowed: an implicit coverpoint with automatic bins is created for each variable |
| More than two | `cross cp_a, cp_b, cp_c;` is allowed; the number of bins is the product of all three |
| Coverage contribution | The cross is one more item in the covergroup, with its own weight, alongside the coverpoints |

### Complete example 1: automatic cross bins

```systemverilog file=tb_cross_basic.sv
module tb_cross_basic;

  bit [1:0] kind;
  bit       dir;       // 0 = read, 1 = write

  covergroup cg_xfer;
    cp_kind   : coverpoint kind;              // 4 bins
    cp_dir    : coverpoint dir;               // 2 bins
    x_kind_dir: cross cp_kind, cp_dir;        // 8 cross bins
  endgroup

  cg_xfer cg = new();

  initial begin
    kind = 0;  dir = 0;  cg.sample();
    kind = 0;  dir = 1;  cg.sample();
    kind = 1;  dir = 0;  cg.sample();
    kind = 3;  dir = 1;  cg.sample();
    kind = 0;  dir = 0;  cg.sample();

    $display("cp_kind    = %0.2f%%", cg.cp_kind.get_coverage());
    $display("cp_dir     = %0.2f%%", cg.cp_dir.get_coverage());
    $display("x_kind_dir = %0.2f%%", cg.x_kind_dir.get_coverage());
    $display("cg_xfer    = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_kind    = 75.00%
cp_dir     = 100.00%
x_kind_dir = 50.00%
cg_xfer    = 75.00%
```

**Explanation**

| Item | Calculation |
|---|---|
| `cp_kind` | Values 0, 1 and 3 were sampled: 3 of 4 bins. |
| `cp_dir` | Both values were sampled: 2 of 2. |
| `x_kind_dir` | Combinations sampled: (0,rd), (0,wr), (1,rd), (3,wr), and (0,rd) again. Four different cross bins of eight: 50 percent. |
| `cg_xfer` | (75 + 100 + 50) / 3 = 75 percent. |
| The lesson | `cp_dir` is at 100 percent and `kind` 1 was sampled, yet a write of kind 1 never happened. Only the cross shows that hole. |

### Selecting cross bins with binsof and intersect

| Expression | Selects |
|---|---|
| `binsof(cp_a)` | All bins of `cp_a` |
| `binsof(cp_a.low)` | The bin `low` of `cp_a` |
| `binsof(cp_a) intersect {[0:3]}` | The bins of `cp_a` that contain at least one of the values 0 to 3 |
| `!binsof(cp_a.low)` | All bins of `cp_a` except `low` |
| `expr1 && expr2` | Cross products that satisfy both selections |
| `expr1 \|\| expr2` | Cross products that satisfy either selection |

Used inside the braces of a cross:

- `bins name = <selection>;` groups all the selected cross products into **one** user-defined cross bin.
- `ignore_bins name = <selection>;` removes the selected cross products from coverage.
- `illegal_bins name = <selection>;` makes the selected cross products errors.

Cross products that are not selected by any user-defined `bins`, `ignore_bins` or `illegal_bins` remain as automatic cross bins.

### Complete example 2: user-defined and ignored cross bins

```systemverilog file=tb_cross_bins.sv
module tb_cross_bins;

  bit [1:0] kind;
  bit       dir;

  covergroup cg_xfer;
    cp_kind: coverpoint kind;
    cp_dir : coverpoint dir;

    x_kind_dir: cross cp_kind, cp_dir {
      // kind 0 with any direction counts as one scenario
      bins        kind0_any = binsof(cp_kind) intersect {0};
      // kind 3 is read-only: a write of kind 3 cannot happen
      ignore_bins kind3_wr  = binsof(cp_kind) intersect {3} && binsof(cp_dir) intersect {1};
    }
  endgroup

  cg_xfer cg = new();

  initial begin
    kind = 0;  dir = 0;  cg.sample();
    kind = 0;  dir = 1;  cg.sample();
    kind = 1;  dir = 0;  cg.sample();
    kind = 3;  dir = 1;  cg.sample();     // ignored cross product
    kind = 0;  dir = 0;  cg.sample();

    $display("x_kind_dir = %0.2f%%", cg.x_kind_dir.get_coverage());
  end

endmodule
```

```output
x_kind_dir = 33.33%
```

**How the cross bins are formed**

| Cross product (`kind`, `dir`) | Becomes | Hit? |
|---|---|---|
| (0, rd), (0, wr) | One user bin `kind0_any` | Yes |
| (1, rd) | Automatic cross bin | Yes |
| (1, wr) | Automatic cross bin | No |
| (2, rd) | Automatic cross bin | No |
| (2, wr) | Automatic cross bin | No |
| (3, rd) | Automatic cross bin | No |
| (3, wr) | Removed by `ignore_bins kind3_wr` | Not counted |

Six cross bins remain (one user bin and five automatic bins); two were hit: 2 / 6 = 33.33 percent.

**Line by line**

| Code | Explanation |
|---|---|
| `bins kind0_any = binsof(cp_kind) intersect {0};` | Selects every cross product whose `cp_kind` bin contains the value 0: (0,rd) and (0,wr). They are merged into one bin, so either one covers it. |
| `ignore_bins kind3_wr = ... && ...;` | Selects the single cross product (3,wr) and removes it. The sample `kind=3, dir=1` therefore changes nothing in the cross (it still counts in `cp_kind` and `cp_dir`). |
| Remaining products | Not mentioned in the braces, so they stay as automatic cross bins. |

### Controlling the size of a cross

The number of cross bins grows as a product. Crossing three coverpoints with automatic bins on 8-bit variables gives 64 × 64 × 64 = 262,144 bins, which can never be filled and makes the report useless.

| Technique | Effect |
|---|---|
| Define meaningful explicit bins on each coverpoint first | An 8 × 4 cross (32 bins) instead of 8 × 64 (512 bins) |
| `ignore_bins` in the cross | Removes combinations that are impossible or irrelevant |
| Group with `bins x = binsof(...)` | Many products become one scenario |
| Cross only what the plan asks for | Not every pair of coverpoints needs a cross |
| Coverpoints used only as cross inputs: `option.weight = 0` | The coverpoint does not count on its own; only the cross counts |

### Coverpoint versus cross

| Property | Coverpoint | Cross |
|---|---|---|
| What it covers | Values of one expression | Simultaneous combinations of bins of two or more coverpoints |
| Number of bins | Defined by its bins | Product of the bin counts of the crossed coverpoints |
| Bin selection syntax | `bins b = {values};` | `bins b = binsof(...) [intersect {...}];` |
| Can find | "This value never occurred" | "These two things never occurred together" |
| Cost | Small | Can explode; must be designed |

> **Interview trap:** "Both coverpoints are 100 percent, so the cross must be 100 percent." No. Each coverpoint can be completely covered by different samples. The cross requires the combinations to occur in the same sample. The reverse is true: if a cross of automatic bins is 100 percent, both coverpoints are 100 percent.

> **Interview trap:** "How many bins in `cross a, b` if `a` is `bit [3:0]` and `b` is `bit [7:0]`?" 16 × 64 = 1024, because `b` gets only 64 automatic bins.

> **Common mistake:** Trying to cross coverpoints from two different covergroups, or crossing a coverpoint with a `default` bin and expecting the default bin to appear in the cross. Neither is possible.

> **Verification application:** The ALU verification plan says "every operation must be tested with each operand at its boundary values". That sentence is a cross: `cross cp_op, cp_a` and `cross cp_op, cp_b`, with the single-operand operations (`ALU_NOT`, `ALU_SHL`, `ALU_SHR`) ignored in the cross with `b`.

### Interview questions

**Q1. What is cross coverage?**
Coverage of combinations: it records which combinations of bins of two or more coverpoints occurred at the same sampling point.

**Q2. How many cross bins does a cross create by default?**
The product of the number of bins of each crossed coverpoint.

**Q3. What are `binsof` and `intersect`?**
`binsof(cp)` or `binsof(cp.bin)` selects bins of a coverpoint inside a cross. `intersect {values}` restricts the selection to bins that contain at least one of the given values. They are combined with `&&`, `||` and `!` to define, ignore or make illegal particular cross products.

**Q4. How do you exclude a combination from a cross?**
With `ignore_bins` in the cross body, for example `ignore_bins x = binsof(cp_op) intersect {ALU_NOT} && binsof(cp_b);`.

**Q5. Can you cross variables directly without declaring coverpoints?**
Yes. `cross a, b;` creates implicit coverpoints with automatic bins for `a` and `b`. Declaring labelled coverpoints with meaningful bins is preferred.

**Q6. Can coverpoints of different covergroups be crossed?**
No. A cross can only reference coverpoints (or variables) within its own covergroup.

**Q7. A cross has 10,000 bins and coverage is stuck at 3 percent. What do you do?**
The cross is badly designed. Reduce the bins of the crossed coverpoints to the ranges that matter, ignore impossible combinations, and group equivalent ones. A cross should have a number of bins that the regression can realistically fill.

## 3.2 Coverage Options

### In plain English

Options are the settings of a covergroup: how many hits a bin needs before it counts, how important one coverpoint is compared with another, whether each instance is reported separately, how many automatic bins to create.

### Technical definition

There are two sets of options.

- **`option`**: instance-specific options. They apply to a particular covergroup instance (or to a coverpoint or cross of it).
- **`type_option`**: type-specific options. They apply to the covergroup type as a whole, across all its instances.

### Syntax

```systemverilog
covergroup cg;
  option.per_instance = 1;                 // covergroup level
  option.at_least     = 2;                 // default for all coverpoints and crosses
  type_option.comment = "bus coverage";

  cp_a: coverpoint a {
    option.auto_bin_max = 8;               // coverpoint level
    option.weight       = 2;
  }
  x: cross cp_a, cp_b {
    option.weight = 0;                     // cross level
  }
endgroup

cg c = new();
c.option.comment     = "instance for port 0";     // may also be set after construction
c.cp_a.option.weight = 3;
cg::type_option.goal = 95;                         // type options: through the type name
```

### Instance options (`option.`)

| Option | Default | Level | Meaning |
|---|---|---|---|
| `name` | Tool-generated | Covergroup | Name of the instance in the report |
| `comment` | `""` | Covergroup, coverpoint, cross | Free text stored in the coverage database |
| `per_instance` | 0 | Covergroup | If 1, coverage of each instance is also stored and reported separately, not only the type coverage |
| `at_least` | 1 | Covergroup, coverpoint, cross | Minimum number of hits for a bin to count as covered |
| `weight` | 1 | Covergroup, coverpoint, cross | Weight of the item when computing the coverage of the enclosing level. Must be ≥ 0; a weight of 0 removes the item from the calculation |
| `goal` | 100 | Covergroup, coverpoint, cross | Target percentage. Used by reports to mark the item as "goal met"; it does not change the computed value |
| `auto_bin_max` | 64 | Covergroup, coverpoint | Maximum number of automatic bins of a coverpoint |
| `cross_num_print_missing` | 0 | Covergroup, cross | Number of uncovered cross bins to list in the report |
| `detect_overlap` | 0 | Covergroup, coverpoint | If 1, a warning is given when two bins of a coverpoint overlap |
| `get_inst_coverage` | 0 | Covergroup | Relevant only with `type_option.merge_instances`: enables per-instance queries when instances are merged |
| `cross_auto_bin_max` | unlimited | Covergroup, cross | Maximum number of automatic cross bins. Defined in IEEE 1800-2005 and 1800-2009, **removed in 1800-2012**. Some tools still accept it; do not rely on it |

### Type options (`type_option.`)

| Option | Default | Level | Meaning |
|---|---|---|---|
| `weight` | 1 | Covergroup, coverpoint, cross | Weight used in **type** coverage and in the overall `$get_coverage()` |
| `goal` | 100 | Covergroup, coverpoint, cross | Target for the type |
| `comment` | `""` | Covergroup, coverpoint, cross | Comment for the type |
| `strobe` | 0 | Covergroup | If 1, sampling takes place at the end of the time step (Postponed region), after all values have settled |
| `merge_instances` | 0 | Covergroup | If 1, type coverage is computed from the **union** of the bins hit by all instances. If 0, it is the weighted average of the instance coverages. Tools differ in their default behaviour here |

### option versus type_option

| Property | `option` | `type_option` |
|---|---|---|
| Applies to | One instance | The covergroup type (all instances together) |
| Set where | Inside the covergroup, or through an instance handle: `c.option.x` | Inside the covergroup, or through the type name: `cg::type_option.x` |
| Can differ between instances | Yes | No |
| Options available | `name`, `comment`, `per_instance`, `at_least`, `weight`, `goal`, `auto_bin_max`, `cross_num_print_missing`, `detect_overlap` | `weight`, `goal`, `comment`, `strobe`, `merge_instances` |
| `weight` affects | Instance coverage (`get_inst_coverage()`) | Type coverage (`get_coverage()`) and `$get_coverage()` |

### Complete example 1: at_least and weight

```systemverilog file=tb_cg_options.sv
module tb_cg_options;

  bit [1:0] sel;
  bit       flag;

  covergroup cg_opt;
    option.per_instance = 1;
    option.comment      = "demonstrates at_least and weight";

    cp_sel: coverpoint sel {
      option.at_least = 2;        // a bin needs two hits
      option.weight   = 3;        // three times as important as cp_flag
    }
    cp_flag: coverpoint flag;     // at_least = 1, weight = 1
  endgroup

  cg_opt cg = new();

  initial begin
    sel = 0;  flag = 0;  cg.sample();
    sel = 0;  flag = 0;  cg.sample();
    sel = 1;  flag = 0;  cg.sample();
    sel = 2;  flag = 1;  cg.sample();
    sel = 2;  flag = 0;  cg.sample();

    $display("cp_sel   = %0.2f%%", cg.cp_sel.get_inst_coverage());
    $display("cp_flag  = %0.2f%%", cg.cp_flag.get_inst_coverage());
    $display("instance = %0.2f%%", cg.get_inst_coverage());
  end

endmodule
```

```output
cp_sel   = 50.00%
cp_flag  = 100.00%
instance = 62.50%
```

**Explanation**

| Item | Calculation |
|---|---|
| Hits of `cp_sel` | Value 0: two hits. Value 1: one hit. Value 2: two hits. Value 3: none. |
| `option.at_least = 2` | Only bins with two or more hits count. Bins 0 and 2 are covered; bin 1, with a single hit, is **not**. 2 of 4: 50 percent. With the default `at_least = 1` it would be 75 percent. |
| `cp_flag` | Both values seen: 100 percent. |
| Instance coverage | Weighted average: (3 × 50 + 1 × 100) / (3 + 1) = 62.5 percent. Without the weights it would be 75 percent. |
| `get_inst_coverage()` | The example queries **instance** coverage, because `option.weight` is an instance option. The **type** coverage returned by `get_coverage()` uses `type_option.weight`, which is still 1 here. |

### Complete example 2: per_instance

```systemverilog file=tb_cg_per_instance.sv
module tb_cg_per_instance;

  covergroup cg_port with function sample(bit [1:0] v);
    option.per_instance = 1;
    cp_v: coverpoint v;
  endgroup

  cg_port cg_port_a = new();
  cg_port cg_port_b = new();

  initial begin
    cg_port_a.set_inst_name("port_a");
    cg_port_b.set_inst_name("port_b");

    cg_port_a.sample(2'd0);
    cg_port_a.sample(2'd1);
    cg_port_b.sample(2'd1);
    cg_port_b.sample(2'd2);

    $display("port_a instance coverage = %0.2f%%", cg_port_a.get_inst_coverage());
    $display("port_b instance coverage = %0.2f%%", cg_port_b.get_inst_coverage());
  end

endmodule
```

```output
port_a instance coverage = 50.00%
port_b instance coverage = 50.00%
```

**Explanation**

Two instances of one covergroup type observe two ports. Each instance saw two of the four values, so each has 50 percent instance coverage. With `per_instance = 1` the report lists both instances, and you can see that `port_a` never carried the values 2 and 3 and `port_b` never carried 0 and 3.

The **type** coverage (`cg_port::get_coverage()`) combines the instances. Depending on `type_option.merge_instances` and on the tool's default, it is either the union of the hits (values 0, 1 and 2: 75 percent) or the average of the instance coverages (50 percent). Check your simulator's documentation before quoting a type-coverage number for a multi-instance covergroup.

> **Interview trap:** "A covergroup is instantiated in four agents. The report shows 100 percent. Was every agent fully covered?" Not necessarily. Without `option.per_instance = 1` only the combined type coverage may be reported, and one busy agent can hide three idle ones. Set `per_instance` when each instance must be covered on its own.

> **Common mistake:** Setting `option.weight = 0` on a coverpoint to "disable" it and then being surprised that its cross still counts. Weight 0 removes that item from the average; the coverpoint is still sampled and its bins still feed the cross. This is in fact the standard trick for coverpoints that exist only to build a cross.

> **Common mistake:** Raising `auto_bin_max` to a large value to get "one bin per value" on a wide variable. Write `bins b[] = {[lo:hi]};` for the values that matter instead.

### Interview questions

**Q1. What is the difference between `option` and `type_option`?**
`option` holds instance-specific settings that can differ for each covergroup instance. `type_option` holds settings for the covergroup type as a whole, shared by all instances.

**Q2. What does `option.at_least` do?**
It sets the minimum number of hits a bin needs before it is counted as covered. The default is 1.

**Q3. What does `option.per_instance` do?**
When set to 1, coverage is tracked and reported for each instance of the covergroup separately, in addition to the type coverage. It is needed when the same covergroup is instantiated for several ports, agents or configurations.

**Q4. What is `option.weight` used for?**
It sets the relative importance of a coverpoint or cross in the covergroup's coverage, or of a covergroup in the overall coverage. A weight of 0 excludes the item from the calculation.

**Q5. What does `option.goal` do?**
It sets the target coverage percentage for the item (default 100). It is used for reporting; it does not alter the calculated coverage.

**Q6. What does `option.auto_bin_max` control?**
The maximum number of automatically created bins for a coverpoint (default 64).

**Q7. How do you avoid a race when a covergroup samples on a clock event?**
Set `type_option.strobe = 1` so that sampling happens at the end of the time step, or sample through a clocking block, or call `sample()` procedurally at a safe point.

## 3.3 How the Coverage Percentage Is Computed

### The three levels

```text
   Level 1: one coverpoint or one cross

                         number of bins with hits >= at_least
        C_item  =  -------------------------------------------------  x 100
                    number of bins (ignore, illegal, default excluded)

   Level 2: one covergroup = weighted average of its coverpoints and crosses

                    sum of ( weight_i  x  C_item_i )
        C_group =  ----------------------------------
                           sum of weight_i

   Level 3: the whole testbench = weighted average of all covergroup types
        $get_coverage()
```

Each coverpoint counts as **one item** and each cross counts as **one item**, whatever its number of bins. A coverpoint with 2 bins and a cross with 64 bins have the same influence on the covergroup's number unless the weights are changed.

### Worked example

A covergroup has three items after a test:

| Item | Bins | Bins hit | Item coverage | Weight |
|---|---|---|---|---|
| `cp_op` | 8 | 6 | 75.0% | 1 |
| `cp_a` | 4 | 3 | 75.0% | 1 |
| `x_op_a` | 32 | 12 | 37.5% | 1 |

Covergroup coverage = (75.0 + 75.0 + 37.5) / 3 = **62.5 percent**.

Notice that it is **not** (6 + 3 + 12) / (8 + 4 + 32) = 47.7 percent. Bins are not pooled across items.

If `cp_op` and `cp_a` exist only to feed the cross and are given `option.weight = 0`, the covergroup coverage is that of the cross alone: 37.5 percent.

### What is in the denominator

| Bin kind | Counted in the total |
|---|---|
| Automatic bins | Yes |
| Explicit `bins`, each element of `bins b[]` or `bins b[N]` | Yes |
| Wildcard bins, transition bins | Yes |
| `bins x = default;` and `default sequence` | No |
| `ignore_bins` and values removed by them | No |
| `illegal_bins` and values removed by them | No |
| A coverpoint whose `iff` guard was never true | Yes: its bins exist and are simply not hit |

### Query methods

| Call | Returns |
|---|---|
| `cg_inst.get_inst_coverage()` | Coverage of this covergroup **instance** |
| `cg_inst.get_coverage()` or `cg_type::get_coverage()` | Coverage of the covergroup **type**, all instances combined |
| `cg_inst.cp_label.get_inst_coverage()` | Coverage of one coverpoint or cross of this instance |
| `cg_inst.cp_label.get_coverage()` | Coverage of one coverpoint or cross for the type |
| `$get_coverage()` | Overall coverage of **all** covergroup types in the simulation |

All return a `real` from 0 to 100. `get_coverage()` and `get_inst_coverage()` optionally take two `ref int` arguments that receive the number of covered bins and the total number of bins:

```systemverilog
int covered, total;
real pct;
pct = cg.cp_op.get_inst_coverage(covered, total);
$display("cp_op: %0d of %0d bins, %0.1f%%", covered, total, pct);
```

### get_coverage versus get_inst_coverage

| Property | `get_coverage()` | `get_inst_coverage()` |
|---|---|---|
| Scope | The covergroup type, over all instances | The one instance it is called on |
| Can be called without an instance | Yes: `cg_type::get_coverage()` | No |
| Weights used | `type_option.weight` | `option.weight` |
| With a single instance and default options | Same value as `get_inst_coverage()` | Same value as `get_coverage()` |
| With several instances | Combined according to `type_option.merge_instances` | Needs `option.per_instance = 1` to be meaningful |

### Using the number inside a test

```systemverilog
// stop when the coverage goal is reached, or after a maximum number of transactions
while (cov.alu_cg.get_inst_coverage() < 100.0 && count < max_txns) begin
  generate_and_send_one_txn();
  count++;
end
```

This is a simple form of coverage-driven test termination. In practice the coverage of a single simulation is rarely the decision criterion; the merged coverage of the whole regression is.

### Interview questions

**Q1. How is the coverage of a coverpoint calculated?**
The number of its bins that have reached `at_least` hits, divided by the total number of its bins (excluding default, ignore and illegal bins), times 100.

**Q2. How is the coverage of a covergroup calculated?**
As the weighted average of the coverage of its coverpoints and crosses. Each coverpoint and each cross is one item, with weight 1 by default.

**Q3. A covergroup has a coverpoint with 2 bins (both hit) and a coverpoint with 100 bins (10 hit). What is the covergroup coverage?**
(100 + 10) / 2 = 55 percent. It is not 12 / 102, because items are averaged, not bins.

**Q4. What is the difference between `get_coverage()` and `get_inst_coverage()`?**
`get_coverage()` returns the coverage of the covergroup type across all instances and can be called on the type. `get_inst_coverage()` returns the coverage of the particular instance.

**Q5. What does `$get_coverage()` return?**
The overall functional coverage of all covergroup types in the simulation, as a real number between 0 and 100.

**Q6. Do ignore bins increase or decrease the coverage percentage?**
For the same set of hits they increase it (or leave it unchanged), because the ignored values are removed from the total number of bins.

## 3.4 Coverage-Driven Verification

### In plain English

In directed testing the plan is a list of tests: "write test 1, test 2, ... test 200; when all pass, we are done". In **coverage-driven verification (CDV)** the plan is a list of **things that must be observed**, written as coverage. Tests are generated randomly, and the coverage report, not the test list, says how far along you are and what to do next.

### Technical definition

**Coverage-driven verification** is a methodology in which

1. the features and scenarios of the verification plan are encoded as a functional coverage model,
2. stimulus is generated by constrained randomization,
3. checking is automatic (scoreboard and assertions),
4. coverage results are analysed to find **holes**, and
5. the stimulus (constraints, seeds, tests) is adjusted to fill the holes,

repeated until the coverage goals are met. The process of getting from the first results to the goals is called **coverage closure**.

### The CDV loop

```text
        +----------------------+
        |   Specification      |
        +----------+-----------+
                   v
        +----------------------+        +-----------------------------+
        |  Verification plan   | -----> |  Functional coverage model  |
        |  (features, corners) |        |  covergroups, cover props   |
        +----------+-----------+        +--------------+--------------+
                   v                                   |
        +----------------------+                       |
   +--> |  Constrained-random  |                       |
   |    |  tests, many seeds   |                       |
   |    +----------+-----------+                       |
   |               v                                   |
   |    +----------------------+   fail   +---------------------+
   |    |  Simulate + check    | -------> |  Debug: fix RTL or  | --+
   |    |  (scoreboard, SVA)   |          |  fix testbench      |   |
   |    +----------+-----------+          +---------------------+   |
   |               | pass                                           |
   |               v                                                |
   |    +----------------------+ <----------------------------------+
   |    |  Merge coverage of   |
   |    |  all tests and seeds |
   |    +----------+-----------+
   |               v
   |    +----------------------+   yes    +---------------------+
   |    |  Goals met?          | -------> |  Sign-off review    |
   |    +----------+-----------+          +---------------------+
   |               | no
   |               v
   |    +----------------------------------------------+
   +--- |  Analyse holes: new seeds? new constraints?  |
        |  new directed test? unreachable -> exclude?  |
        +----------------------------------------------+
```

### What to do with a coverage hole

| Cause of the hole | Action |
|---|---|
| Not enough random runs | Run more seeds |
| The scenario is legal but improbable (for example FIFO full with simultaneous read and write) | Add a test with tighter constraints or weighted distributions (`dist`) that steer the stimulus towards it |
| A constraint accidentally forbids it | Fix or relax the constraint |
| Needs a precise sequence that random stimulus will not produce | Write a directed test or a directed sequence |
| The DUT cannot reach it (unreachable by design) | Confirm with the designer, then exclude it with `ignore_bins` or a documented waiver |
| The coverage model is wrong (wrong bin range, wrong sampling point) | Fix the coverage model |
| The feature is not implemented | It is a design bug or a specification question: report it |

### The typical closure curve

```text
   coverage
   100% |                                   ..........o   <- directed tests, exclusions,
        |                         ......''''              review of the last few percent
    90% |                 ....''''
        |           ...'''                               the last 10% of coverage usually costs
        |       ..''                                     more effort than the first 90%
    50% |    .''
        |  .'      <- random tests fill most bins quickly
        | .
     0% +--------------------------------------------------->  time / number of tests
```

### Sign-off criteria in practice

| Criterion | Typical target |
|---|---|
| All tests in the regression pass | 100% |
| Functional coverage | 100% of the plan, with every exclusion reviewed |
| Code coverage (statement, branch, condition, toggle, FSM) | Close to 100%, with waivers for unreachable code |
| Assertions | None failing; every assertion has been triggered non-vacuously (assertion coverage) |
| Bug rate | New bugs per week has fallen to near zero |

### Directed versus coverage-driven verification

| Aspect | Directed testing | Coverage-driven verification |
|---|---|---|
| Stimulus | Written by hand for each scenario | Constrained-random |
| Progress metric | Number of tests written and passing | Coverage percentage |
| Finds unexpected bugs | Rarely: only what the engineer thought of | Often: random combinations nobody listed |
| Effort over time | Grows linearly with the number of scenarios | High at the start (environment), low per additional scenario |
| Proof that a scenario occurred | By construction of the test | By the coverage report |
| Used for | Bring-up, specific corner cases, last holes | The bulk of verification |

> **Key point:** Random stimulus without functional coverage is blind: you do not know what the random tests did. Functional coverage without random stimulus is slow: you are back to writing one test per bin. CDV is the combination.

> **Interview trap:** "Coverage is 100 percent. Are we done?" Only if (1) all tests pass with strong checkers, (2) the coverage model has been reviewed against the plan, (3) the exclusions are justified, (4) code coverage has been analysed, and (5) the assertions were actually exercised. 100 percent of a weak model means little.

> **Common mistake:** Writing the coverage model from the RTL instead of from the specification. Coverage copied from the implementation repeats the designer's assumptions and cannot reveal a missing feature.

### Interview questions

**Q1. What is coverage-driven verification?**
A methodology in which the verification plan is implemented as functional coverage, stimulus is constrained-random, checking is automatic, and coverage results are used to measure progress and to direct further stimulus until the coverage goals are met.

**Q2. What is coverage closure?**
The process of analysing uncovered items (holes) and eliminating them, by running more seeds, adjusting constraints, adding directed tests, fixing the coverage model, or excluding unreachable items with justification, until the coverage goals are reached.

**Q3. What is a coverage hole and how do you handle it?**
A bin, cross or code item that has not been hit. First determine why: insufficient seeds, over-constrained stimulus, improbable scenario, unreachable code, or an error in the coverage model. Then apply the matching action from the table above.

**Q4. How is coverage from many tests combined?**
Each simulation writes a coverage database. The databases of all tests and seeds in the regression are merged by the tool, and the merged result is analysed.

**Q5. When do you exclude a coverage item?**
Only when it is genuinely unreachable or not applicable (reserved values, configurations not supported), after confirmation with the designer or architect, and with the reason recorded for the sign-off review.

**Q6. When is verification complete?**
When the regression passes, functional and code coverage goals are met with reviewed exclusions, no assertion fails and all assertions have been exercised, and the rate of new bugs has dropped to an agreed level.

## 3.5 The Complete alu_coverage Class

This section puts Parts 1 to 3 together in the coverage collector of the ALU testbench. The class follows the naming used in the whole course: it receives observed `alu_txn` objects, and its covergroup is `alu_cg`.

### From the verification plan to the coverage model

| Plan item | Coverage item |
|---|---|
| Every operation is executed | `cp_op`: automatic bins on the enum, 8 bins |
| Operand `a` takes its boundary values and both halves of its range | `cp_a`: `zero`, `low`, `high`, `max` |
| The same for operand `b` | `cp_b` |
| Carry / borrow / shifted-out bit is seen as 0 and as 1 | `cp_carry`, guarded by the operations that can produce it |
| A result of zero is seen | `cp_zero` |
| Back-to-back operations | `cp_op_seq`: transition bins |
| Every operation with every class of `a` | `x_op_a`: 8 × 4 = 32 cross bins |
| Every two-operand operation with every class of `b` | `x_op_b`: the three one-operand operations are ignored, 5 × 4 = 20 cross bins |
| Carry observed for each operation that can produce one | `x_op_carry`: 3 × 2 = 6 cross bins |

### The class

```systemverilog file=alu_coverage.sv
// Functional coverage collector for the ALU testbench.
// This file is included inside alu_tb_pkg (or, in the demo below, inside a module),
// after the declaration of alu_txn.
class alu_coverage;

  alu_txn txn;                       // the transaction currently being sampled

  covergroup alu_cg;
    option.per_instance = 1;
    option.comment      = "ALU functional coverage";

    // ---- every operation ----
    cp_op: coverpoint txn.op;

    // ---- operand classes ----
    cp_a: coverpoint txn.a {
      bins zero = {8'h00};
      bins low  = {[8'h01:8'h7F]};
      bins high = {[8'h80:8'hFE]};
      bins max  = {8'hFF};
    }
    cp_b: coverpoint txn.b {
      bins zero = {8'h00};
      bins low  = {[8'h01:8'h7F]};
      bins high = {[8'h80:8'hFE]};
      bins max  = {8'hFF};
    }

    // ---- result properties ----
    cp_carry: coverpoint txn.result[8]
              iff (txn.op inside {ALU_ADD, ALU_SUB, ALU_SHL}) {
      bins no_carry = {1'b0};
      bins carry    = {1'b1};
    }
    cp_zero: coverpoint (txn.result[7:0] == 8'h00) {
      bins non_zero = {1'b0};
      bins zero     = {1'b1};
    }

    // ---- sequences of operations ----
    cp_op_seq: coverpoint txn.op {
      bins same_op[] = (ALU_ADD => ALU_ADD), (ALU_SUB => ALU_SUB);
      bins add_sub   = (ALU_ADD => ALU_SUB);
      bins sub_add   = (ALU_SUB => ALU_ADD);
    }

    // ---- combinations ----
    x_op_a: cross cp_op, cp_a;

    x_op_b: cross cp_op, cp_b {
      ignore_bins one_operand = binsof(cp_op) intersect {ALU_NOT, ALU_SHL, ALU_SHR};
    }

    x_op_carry: cross cp_op, cp_carry {
      ignore_bins no_carry_ops =
        binsof(cp_op) intersect {ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHR};
    }
  endgroup

  function new();
    alu_cg = new();
  endfunction

  // called by the scoreboard (or a monitor subscriber) for every observed transaction
  function void sample(alu_txn t);
    txn = t;
    alu_cg.sample();
  endfunction

  function void report();
    $display("ALU functional coverage = %0.2f%%", alu_cg.get_inst_coverage());
  endfunction

endclass
```

**Line by line**

| Code | Explanation |
|---|---|
| `alu_txn txn;` | A handle that the covergroup reads. `sample()` sets it before triggering the covergroup. |
| `option.per_instance = 1;` | The environment might be instantiated more than once; each collector is reported separately. |
| `cp_op: coverpoint txn.op;` | Enum coverpoint: eight automatic bins named after the opcodes. |
| `cp_a`, `cp_b` | Four explicit bins each. The boundaries 0 and 255 have their own bins, and the two ranges split at the MSB, where signed-interpretation bugs appear. |
| `cp_carry ... iff (...)` | Bit 8 of the result is meaningful only for add, subtract and shift-left. The guard prevents the constant 0 of the logical operations from filling the `no_carry` bin. |
| `cp_zero: coverpoint (txn.result[7:0] == 8'h00)` | A coverpoint on an expression. Explicit bins give the two outcomes readable names. |
| `cp_op_seq` | A second coverpoint on `op` with transition bins. `same_op[]` creates two bins (ADD after ADD, SUB after SUB). Four transition bins in total. |
| `x_op_a` | Every operation with every class of `a`: 32 automatic cross bins. |
| `x_op_b` | `ALU_NOT`, `ALU_SHL` and `ALU_SHR` do not use `b`. Their 12 cross products are removed; 20 remain. |
| `x_op_carry` | Only the three operations that can set bit 8 are kept: 6 cross bins. |
| `alu_cg = new();` | Mandatory construction in the class constructor. |
| `function void sample(alu_txn t);` | Stores the handle and samples. The transaction must not be modified by another component between this call and the covergroup's evaluation; because `sample()` is a function and executes in zero time, that is guaranteed. |

### A small test of the collector

The demonstration below uses a cut-down `alu_txn` (only the data fields; the full class with `print`, `copy` and `compare` is in Module 6) so that the file can be run on its own. `alu_pkg.sv` is the package from Module 1 and must be compiled first.

```systemverilog file=alu_pkg.sv
package alu_pkg;

  typedef enum logic [2:0] {
    ALU_ADD = 3'b000,
    ALU_SUB = 3'b001,
    ALU_AND = 3'b010,
    ALU_OR  = 3'b011,
    ALU_XOR = 3'b100,
    ALU_NOT = 3'b101,
    ALU_SHL = 3'b110,
    ALU_SHR = 3'b111
  } alu_op_e;

endpackage
```

```systemverilog file=tb_alu_coverage.sv
// compile order: alu_pkg.sv  tb_alu_coverage.sv   (alu_coverage.sv is included below)
module tb_alu_coverage;
  import alu_pkg::*;

  class alu_txn;                     // cut-down version of the Module 6 transaction
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;
  endclass

  `include "alu_coverage.sv"

  alu_coverage cov;
  alu_txn      t;
  alu_op_e     op;

  initial begin
    cov = new();

    // one transaction per opcode, always with a = 0 and b = 255
    op = op.first();
    for (int i = 0; i < op.num(); i++) begin
      t        = new();
      t.id     = i;
      t.op     = op;
      t.a      = 8'h00;
      t.b      = 8'hFF;
      t.result = 9'd0;               // not relevant for the items printed below
      cov.sample(t);
      op = op.next();
    end

    $display("cp_op     = %0.2f%%", cov.alu_cg.cp_op.get_inst_coverage());
    $display("cp_a      = %0.2f%%", cov.alu_cg.cp_a.get_inst_coverage());
    $display("x_op_a    = %0.2f%%", cov.alu_cg.x_op_a.get_inst_coverage());
    $display("x_op_b    = %0.2f%%", cov.alu_cg.x_op_b.get_inst_coverage());
    $display("cp_op_seq = %0.2f%%", cov.alu_cg.cp_op_seq.get_inst_coverage());
  end

endmodule
```

```output
cp_op     = 100.00%
cp_a      = 25.00%
x_op_a    = 25.00%
x_op_b    = 25.00%
cp_op_seq = 25.00%
```

**What the numbers say**

| Item | Calculation | What the hole means |
|---|---|---|
| `cp_op` | All 8 opcodes sampled: 8 / 8 | Nothing missing |
| `cp_a` | Only `zero` hit: 1 / 4 | `a` was never non-zero |
| `x_op_a` | 8 opcodes × only the `zero` class: 8 / 32 | Every operation was tried, but only with `a` = 0 |
| `x_op_b` | 5 two-operand opcodes × only the `max` class of `b`: 5 / 20 | The same for `b` |
| `cp_op_seq` | The order was ADD, SUB, AND, ...: only `add_sub` occurred: 1 / 4 | No operation was repeated back to back |

A test that executes every opcode gives 100 percent on `cp_op` and would also give 100 percent statement coverage on the `case` statement of the ALU. The functional coverage shows how little was really tested. This is the argument for functional coverage in one example.

### Connecting the collector in the layered testbench

```systemverilog
// inside alu_scoreboard (Module 9)
alu_coverage cov;

task run();
  alu_txn txn;
  forever begin
    mon2scb_mbx.get(txn);          // transaction observed by the monitor
    check(txn);                    // compare with the reference model
    cov.sample(txn);               // then record what was exercised
  end
endtask
```

At the end of the test, `alu_test` calls `env.scb.cov.report()`.

> **Verification application:** Coverage is sampled **after** checking and from the **monitor's** transaction. If the DUT produced a wrong result, the test fails anyway; if it produced the right one, the scenario has been both exercised and checked. That pairing is what makes the coverage number trustworthy.

> **Common mistake:** Sampling a transaction handle that the generator keeps re-randomizing. If the collector stores `txn = t` and samples later, the object may already contain the next values. Sample immediately (as above), or sample a copy.

### Interview questions

**Q1. Where is the coverage collector placed in a layered testbench?**
On the monitor side. The monitor (through the scoreboard or a dedicated subscriber) passes each observed transaction to a coverage class that owns the covergroup and calls `sample()`.

**Q2. Why did `cp_carry` need an `iff` guard?**
Bit 8 of the result is a carry only for add, subtract and shift-left. For the other operations it is always 0; without the guard, those operations would fill the `no_carry` bin and hide the fact that an addition without carry was never tested.

**Q3. Why does the cross of `op` and `b` ignore some operations?**
`ALU_NOT`, `ALU_SHL` and `ALU_SHR` do not use operand `b`, so combinations of those operations with classes of `b` say nothing about the design. Leaving them in would add twelve bins that are meaningless to fill.

**Q4. A test runs all 8 opcodes once. `cp_op` is 100 percent. Is the ALU verified?**
No. The crosses with the operand classes, the carry coverage and the sequence coverage are almost empty. One execution per opcode exercises a tiny part of the behaviour.

**Q5. How would you write coverage for "all operations with both operands at maximum"?**
The simplest form is a dedicated coverpoint on the opcode with a guard: `cp_op_max: coverpoint txn.op iff (txn.a == 8'hFF && txn.b == 8'hFF);`, which has one bin per operation. The alternative is a three-way cross `cross cp_op, cp_a, cp_b` in which every product that does not involve `cp_a.max` and `cp_b.max` is removed: `ignore_bins not_max = !binsof(cp_a.max) || !binsof(cp_b.max);`.
