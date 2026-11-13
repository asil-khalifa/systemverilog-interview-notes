# Part 2: Bins

## 2.1 Bins and Automatic Bins

### In plain English

A coverpoint watches a variable. A **bin** is one box on the tally sheet for that variable: a named counter attached to a value, a range of values, or a sequence of values. Each time the coverpoint is sampled, the counter of every bin that contains the sampled value is increased by one. A bin is **covered** (hit) when its counter has reached the required number, which is 1 by default.

The coverage of a coverpoint is simply:

```text
                        number of bins that are covered
   coverage (%)  =  -----------------------------------------  x 100
                     total number of bins of the coverpoint
```

So the bins **are** the coverage model. Choosing them is the real design work in functional coverage: each bin should correspond to something the verification plan says must be tested.

### Kinds of bins

| Kind | Keyword | Created by | Counts towards coverage |
|---|---|---|---|
| Automatic (implicit) bins | none | The tool, when the coverpoint defines no bins | Yes |
| Explicit (user-defined) value bins | `bins` | The user | Yes |
| Wildcard bins | `wildcard bins` | The user | Yes |
| Transition bins | `bins x = (a => b)` | The user | Yes |
| Default bin | `bins x = default` | The user | **No** |
| Ignore bins | `ignore_bins` | The user | No: the values are removed from coverage |
| Illegal bins | `illegal_bins` | The user | No: a hit is a run-time error |

### Automatic bins: technical definition

If a coverpoint does not define any bins, the tool creates **automatic bins** (also called implicit bins) for it. The number of automatic bins is decided as follows.

| Coverpoint type | Number of automatic bins | Bin names in reports |
|---|---|---|
| Enum | One bin per named member of the enum | `auto[NAME]` |
| Integral, `M` bits wide, with 2^M ≤ `auto_bin_max` | 2^M bins, one per value | `auto[0]`, `auto[1]` ... |
| Integral, `M` bits wide, with 2^M > `auto_bin_max` | `auto_bin_max` bins; the 2^M values are divided evenly among them | `auto[low:high]` |

`auto_bin_max` is a coverage option whose default value is **64**.

When the values do not divide evenly, the **last bin** receives the remaining values. Example from the standard: a 3-bit variable with `auto_bin_max = 3` gets the bins `[0:1]`, `[2:3]` and `[4:7]`.

```text
   bit [1:0] mode;          4 values  <= 64   ->  4 bins : auto[0] auto[1] auto[2] auto[3]

   bit [7:0] data;        256 values  >  64   -> 64 bins of 4 values each :
                                                 auto[0:3] auto[4:7] ... auto[252:255]

   bit [9:0] len;        1024 values  >  64   -> 64 bins of 16 values each

   int       count;      2^32 values  >  64   -> 64 bins of 67,108,864 values each (useless)

   alu_op_e  op;         8 names              ->  8 bins : auto[ALU_ADD] ... auto[ALU_SHR]
```

Automatic bins never include values that contain X or Z.

### Complete example

```systemverilog file=tb_bins_auto.sv
module tb_bins_auto;

  typedef enum bit [1:0] {CMD_IDLE, CMD_RD, CMD_WR} cmd_e;

  bit [2:0] level;      //    8 values
  bit [9:0] len;        // 1024 values
  cmd_e     cmd;        //    3 named values

  covergroup cg_auto;
    cp_level: coverpoint level;
    cp_len  : coverpoint len { option.auto_bin_max = 4; }
    cp_cmd  : coverpoint cmd;
  endgroup

  cg_auto cg = new();

  initial begin
    level = 7;  len = 300;   cmd = CMD_RD;  cg.sample();
    level = 0;  len = 1000;  cmd = CMD_RD;  cg.sample();

    $display("cp_level = %0.2f%%", cg.cp_level.get_coverage());
    $display("cp_len   = %0.2f%%", cg.cp_len.get_coverage());
    $display("cp_cmd   = %0.2f%%", cg.cp_cmd.get_coverage());
  end

endmodule
```

```output
cp_level = 25.00%
cp_len   = 50.00%
cp_cmd   = 33.33%
```

**Line by line**

| Code | Explanation |
|---|---|
| `cp_level: coverpoint level;` | 3 bits, 8 values, fewer than 64: eight bins, one per value. The values 7 and 0 were sampled: 2 of 8. |
| `option.auto_bin_max = 4;` | Limits this coverpoint to four automatic bins. The 1024 values are split into `[0:255]`, `[256:511]`, `[512:767]`, `[768:1023]`. 300 is in the second and 1000 in the fourth: 2 of 4. |
| `cp_cmd: coverpoint cmd;` | An enum: one bin per name, three bins, even though the 2-bit base type has four possible values. The unused encoding 3 gets no bin. Only `CMD_RD` was sampled: 1 of 3. |

### When automatic bins are appropriate

| Coverpoint | Automatic bins? | Reason |
|---|---|---|
| Enum (opcode, state, command) | Yes | One bin per name is exactly what is wanted |
| Small control field (1 to about 6 bits) where every value matters | Yes | One bin per value |
| 1-bit flag or condition | Yes | Two bins |
| Data or address of 8 bits or more | No | Bins of arbitrary equal ranges do not correspond to anything in the specification; corner values such as 0 and the maximum are hidden inside large bins |

> **Interview trap:** "How many bins does `coverpoint a;` create for `bit [7:0] a`?" 64, not 256, because of the default `auto_bin_max` of 64. Each bin covers four values. For a `bit [3:0]` the answer is 16. For an enum with five members it is 5.

> **Common mistake:** Leaving a 32-bit address with automatic bins. The 64 bins are hit quickly by random values, the coverpoint shows 100 percent, and nothing has been learned. Define explicit bins for the boundaries and regions that matter.

### Interview questions

**Q1. What is a bin?**
A named counter associated with a value, a set or range of values, or a sequence of values of a coverpoint. The percentage of bins that have been hit is the coverage of the coverpoint.

**Q2. What are automatic bins?**
Bins created by the tool when the coverpoint defines none. An enum gets one bin per member; an integral coverpoint of M bits gets the smaller of 2^M and `auto_bin_max` bins.

**Q3. What is `auto_bin_max` and what is its default?**
The maximum number of automatic bins for a coverpoint. The default is 64.

**Q4. How are values distributed when there are more values than automatic bins?**
Evenly across the bins, in increasing order; if the division is not exact, the last bin receives the extra values.

**Q5. A coverpoint is on a 4-bit enum variable with 5 members. How many automatic bins?**
Five. The number is determined by the enum members, not by the width.

## 2.2 Explicit Bins

### In plain English

With explicit bins you decide what the boxes are. Instead of "64 equal slices of the address range", you write "the first address, the last address, the boundary of each memory region, and everything in between as one box". Each box carries a name that appears in the coverage report, so a hole reads as "bin `max` of `cp_a` was never hit" rather than "bin `auto[252:255]`".

### Technical definition

Explicit bins are declared with the `bins` keyword inside the braces of a coverpoint. Each declaration associates a bin name with a set of values of the coverpoint expression. When a coverpoint has at least one explicit bin, **no automatic bins are created**: values that fall in no bin are simply not counted.

### Syntax forms

| Declaration | Bins created | Meaning |
|---|---|---|
| `bins zero = {0};` | 1 | One bin for one value |
| `bins low = {[1:15]};` | 1 | One bin for a range: hit if any value from 1 to 15 is sampled |
| `bins some = {1, 5, [8:11]};` | 1 | One bin for a list of values and ranges |
| `bins val[] = {[0:3]};` | 4 | `[]` creates one bin **per value**: `val[0]`, `val[1]`, `val[2]`, `val[3]` |
| `bins pow[] = {1, 2, 4, 8};` | 4 | One bin per listed value |
| `bins grp[4] = {[0:15]};` | 4 | A fixed number of bins; the 16 values are distributed evenly: `[0:3]`, `[4:7]`, `[8:11]`, `[12:15]` |
| `bins grp[3] = {[0:9]};` | 3 | 10 values in 3 bins: `{0,1,2}`, `{3,4,5}`, `{6,7,8,9}`. The last bin takes the remainder |
| `bins top = {[200:$]};` | 1 | `$` means the largest value of the coverpoint type (as a lower bound it means the smallest) |
| `bins others = default;` | 1 | Catches every value not in another bin. **Not counted** in the coverage percentage |
| `bins b = {[0:3]} iff (en);` | 1 | The bin is incremented only if the guard is true at the sample |
| `bins mul4[] = {[0:255]} with (item % 4 == 0);` | 64 | IEEE 1800-2012 `with` filter: keep only values satisfying the expression. Tool support is uneven |

```text
   coverpoint a   (bit [7:0])

      bins zero   = {0};            one bin              |0|
      bins low    = {[1:15]};       one bin              |1 ............ 15|
      bins mid[4] = {[16:239]};     four bins            |16..71|72..127|128..183|184..239|
      bins high   = {[240:254]};    one bin              |240 ........ 254|
      bins max    = {255};          one bin              |255|
                                                         -------------------------------------
                                                         total: 8 bins
```

### The difference between `bins b`, `bins b[]` and `bins b[N]`

For the same value set `{[0:7]}`:

| Declaration | Number of bins | Fully covered when |
|---|---|---|
| `bins b = {[0:7]};` | 1 | **Any one** of the values 0 to 7 has been sampled |
| `bins b[] = {[0:7]};` | 8 | **Every** value 0 to 7 has been sampled |
| `bins b[2] = {[0:7]};` | 2 | At least one value from 0 to 3 **and** one from 4 to 7 have been sampled |

This is the most frequently asked bin question. A single bin over a range is a weak requirement; an array of bins is a strong one.

### Overlapping bins and values with no bin

- A value may belong to more than one bin. All matching bins are incremented.
- A value that belongs to no bin (and there is no `default` bin) is ignored: nothing is incremented and nothing is reported.

### Complete example

```systemverilog file=tb_bins_explicit.sv
module tb_bins_explicit;

  bit [7:0] a;

  covergroup cg_a;
    cp_a: coverpoint a {
      bins zero   = {0};
      bins low    = {[1:15]};
      bins mid[4] = {[16:239]};
      bins high   = {[240:254]};
      bins max    = {255};
    }
    cp_pow2: coverpoint a {
      bins pow2[] = {1, 2, 4, 8, 16, 32, 64, 128};
      bins others = default;
    }
  endgroup

  cg_a cg = new();

  initial begin
    a = 0;    cg.sample();
    a = 5;    cg.sample();
    a = 9;    cg.sample();
    a = 100;  cg.sample();
    a = 255;  cg.sample();
    a = 200;  cg.sample();
    a = 64;   cg.sample();

    $display("cp_a    = %0.2f%%", cg.cp_a.get_coverage());
    $display("cp_pow2 = %0.2f%%", cg.cp_pow2.get_coverage());
    $display("cg_a    = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_a    = 75.00%
cp_pow2 = 12.50%
cg_a    = 43.75%
```

**Which bin does each sample hit?**

| Sample | `cp_a` bin | `cp_pow2` bin |
|---|---|---|
| 0 | `zero` | `others` (default) |
| 5 | `low` | `others` |
| 9 | `low` (already hit) | `others` |
| 100 | `mid[1]` (72 to 127) | `others` |
| 255 | `max` | `others` |
| 200 | `mid[3]` (184 to 239) | `others` |
| 64 | `mid[0]` (16 to 71) | `pow2[64]` |

**Explanation**

| Item | Calculation |
|---|---|
| `cp_a` | Eight bins: `zero`, `low`, `mid[0]`..`mid[3]`, `high`, `max`. Hit: `zero`, `low`, `mid[0]`, `mid[1]`, `mid[3]`, `max`. 6 / 8 = 75 percent. The holes are `mid[2]` and `high`. |
| `mid[4]` | 16 to 239 is 224 values; divided among 4 bins that is 56 values each: 16-71, 72-127, 128-183, 184-239. |
| `cp_pow2` | Eight counted bins, one per power of two. Only `pow2[64]` was hit: 1 / 8 = 12.5 percent. The `default` bin collected six samples but does not count, in either the numerator or the denominator. |
| `cg_a` | (75 + 12.5) / 2 = 43.75 percent. |
| Two coverpoints on one variable | Legal and common: the same variable is classified in two different ways. |

### What is the default bin for?

`bins others = default;` shows, in the report, how many samples fell outside the bins you defined. It is a debugging aid: a large count in `others` may mean the bin definitions miss something. It never contributes to the percentage, and it cannot be used in a cross.

> **Interview trap:** `bins b = {[0:255]};` on an 8-bit variable is covered by the very first sample, whatever its value: one bin, any value hits it. The coverpoint shows 100 percent after one transaction. If the intention is "all 256 values", the declaration must be `bins b[] = {[0:255]};`.

> **Common mistake:** Assuming that values outside the explicit bins are still covered by automatic bins. Once a single explicit bin exists, automatic bins are not created. If `cp_a` above had only `bins zero = {0};`, the coverpoint would have exactly one bin and would reach 100 percent as soon as a zero was sampled.

> **Verification application:** Bins are derived from the specification by asking "which values would a designer treat differently?". Typical choices for a data operand: zero, one, all ones, the sign boundary (`7F`/`80`), and a few ranges. For a length field: minimum, maximum, the values just inside and just outside each legal limit. For an address: the first and last address of each region.

### Interview questions

**Q1. What is the difference between `bins b = {[0:3]};` and `bins b[] = {[0:3]};`?**
The first creates one bin that is hit by any of the four values. The second creates four bins, one per value, so all four values must occur for full coverage.

**Q2. What does `bins b[2] = {[0:9]};` create?**
Two bins with the ten values distributed evenly: 0 to 4 in `b[0]` and 5 to 9 in `b[1]`.

**Q3. What does `bins b[3] = {[0:9]};` create?**
Three bins. Ten values do not divide by three, so the first two bins get three values each and the last gets the remaining four: {0,1,2}, {3,4,5}, {6,7,8,9}.

**Q4. If a coverpoint has explicit bins, are automatic bins also created for the remaining values?**
No. Values not covered by any explicit bin are not tracked at all.

**Q5. What is a default bin? Does it count towards coverage?**
`bins name = default;` catches all values not included in any other bin. It is reported but does not count towards the coverage percentage.

**Q6. What does `$` mean in a bin range?**
The maximum value of the coverpoint type when used as the upper bound (`[200:$]`), and the minimum when used as the lower bound (`[$:10]`).

**Q7. Can one value belong to two bins?**
Yes. Overlapping bins are allowed and each matching bin is incremented.

## 2.3 Wildcard Bins

### In plain English

Sometimes only some bits of a value matter. "All opcodes whose top two bits are 01" or "any odd value" are patterns, not ranges. A wildcard bin lets you write a pattern in which certain bit positions mean "any value".

### Technical definition

A bin declared with the `wildcard` keyword treats every **X**, **Z** or **?** in its value specification as a don't-care bit position. A sampled value matches the bin if it equals the pattern in all the other bit positions. This is the same matching rule as the wildcard equality operator `==?` (Module 1, Section 4.6).

### Syntax

```systemverilog
wildcard bins odd      = {4'b???1};     // 1, 3, 5, 7, 9, 11, 13, 15       -> one bin
wildcard bins upper    = {4'b1???};     // 8 to 15                          -> one bin
wildcard bins rd       = {4'b00??};     // 0 to 3                           -> one bin
wildcard bins each[]   = {4'b11??};     // 12, 13, 14, 15                   -> four bins
wildcard bins t        = (2'b0? => 2'b1?);   // wildcard transition bin
```

Without the `wildcard` keyword, an X or Z in a bin value is taken literally: the bin would match only a sampled value that really has X or Z in that position.

### How it works

```text
   wildcard bins rd = {4'b00??};

   pattern      0  0  ?  ?
   sampled      0  0  1  0     -> bits 3 and 2 match, bits 1 and 0 are don't-care  -> HIT
   sampled      0  1  1  0     -> bit 2 differs                                    -> no hit
```

A complete example that uses wildcard bins together with ignore and illegal bins follows in Section 2.5.

> **Common mistake:** Forgetting the keyword: `bins odd = {4'b???1};`. The `?` characters are then literal Z values, no two-state sample can ever match, and the bin stays empty forever.

> **Interview trap:** "How many bins does `wildcard bins b[] = {3'b1??};` create?" Four: the pattern matches the values 4, 5, 6 and 7, and `[]` creates one bin for each.

### Interview questions

**Q1. What is a wildcard bin?**
A bin whose value contains X, Z or `?` characters that are treated as don't-care bits, so that the bin matches every value fitting the pattern.

**Q2. Write a bin that is hit by any even value of a 4-bit coverpoint.**
`wildcard bins even = {4'b???0};`

**Q3. What happens if `wildcard` is omitted but the value contains `?`?**
The `?` is interpreted as a literal Z bit. The bin only matches a sampled value that has Z in those positions, which normally never happens.

## 2.4 Ignore Bins

### In plain English

Some values of a variable are not interesting, or cannot occur at all. A reserved opcode, an address in an unmapped region, a length that the protocol forbids and the generator never produces. If such values stay in the coverage model, the coverage can never reach 100 percent. `ignore_bins` removes them from the model.

### Technical definition

`ignore_bins` specifies a set of values or transitions that are **excluded from coverage**. Ignored values:

- do not increment any counted bin, even if they are also included in another bin;
- are removed from the bins of the coverpoint, so they do not appear in the **denominator** of the coverage calculation;
- produce no error when sampled.

### Syntax

```systemverilog
cp_cmd: coverpoint cmd {
  bins         val[]    = {[0:15]};
  ignore_bins  reserved = {[12:13]};       // val[12] and val[13] are removed
}

cp_op: coverpoint op {
  ignore_bins not_used = {ALU_NOT};        // automatic bins for the other members
}

ignore_bins no_trans = (CMD_WR => CMD_WR); // an ignored transition
wildcard ignore_bins hi = {4'b11??};       // ignore by pattern
```

### Effect on the calculation

```text
   coverpoint cmd (bit [3:0])  { bins val[] = {[0:15]}; }                    16 bins
   sampled values: 0 to 11                                                   12 / 16 = 75 %

   coverpoint cmd (bit [3:0])  { bins val[] = {[0:15]};
                                 ignore_bins reserved = {[12:15]}; }         12 bins
   sampled values: 0 to 11                                                   12 / 12 = 100 %
```

The second form is how a coverage model is made to describe exactly the reachable, legal space.

> **Common mistake:** Using `ignore_bins` to hide a hole that you could not hit. Every ignored value must be justified by the specification ("reserved", "not supported in this configuration") and reviewed. Ignoring a legal scenario because it is hard to generate removes it from verification without anyone noticing.

### Interview questions

**Q1. What are ignore bins?**
Bins that list values or transitions to be excluded from coverage. They are not counted and they reduce the total number of bins used for the percentage.

**Q2. If a value is in both a normal bin and an ignore bin, what happens?**
The ignore bin wins. The value is excluded from the normal bin.

**Q3. Does sampling an ignored value cause an error?**
No. It is silently ignored. That is the difference from an illegal bin.

## 2.5 Illegal Bins

### In plain English

Some values must **never** be seen. If they are seen, something is wrong with the DUT or the testbench. `illegal_bins` marks such values: sampling one produces a run-time error.

### Technical definition

`illegal_bins` specifies a set of values or transitions that are illegal. If an illegal value or transition is sampled, the simulator issues a **run-time error**. Illegal bins are excluded from coverage in the same way as ignore bins, and they take precedence over every other bin, including ignore bins.

### Syntax

```systemverilog
cp_cmd: coverpoint cmd {
  bins         val[] = {[0:11]};
  illegal_bins bad   = {[14:15]};
}

illegal_bins bad_trans = (CMD_IDLE => CMD_IDLE [*10]);   // an illegal transition
```

### Ignore bins versus illegal bins

| Property | `ignore_bins` | `illegal_bins` |
|---|---|---|
| Meaning | "Not interesting; do not count it" | "Must never happen" |
| When the value is sampled | Nothing happens | Run-time error |
| Counted in the coverage percentage | No | No |
| Removes the value from other bins | Yes | Yes |
| Precedence | Lower | Higher: if a value is in both, it is illegal |
| Typical use | Reserved or unreachable values, combinations not applicable | Encodings that indicate a bug if observed |

### Complete example: wildcard, ignore and illegal bins together

```systemverilog file=tb_bins_special.sv
module tb_bins_special;

  bit [3:0] cmd;

  covergroup cg_cmd;
    // classification by pattern
    cp_kind: coverpoint cmd {
      wildcard bins read   = {4'b00??};     // 0..3   one bin
      wildcard bins write  = {4'b01??};     // 4..7   one bin
      wildcard bins ctrl[] = {4'b10??};     // 8..11  four bins
    }
    // every legal value separately
    cp_val: coverpoint cmd {
      bins         val[]    = {[0:15]};
      ignore_bins  reserved = {[12:13]};
      illegal_bins bad      = {[14:15]};
    }
  endgroup

  cg_cmd cg = new();

  initial begin
    cmd = 1;   cg.sample();
    cmd = 5;   cg.sample();
    cmd = 9;   cg.sample();
    cmd = 12;  cg.sample();     // reserved: ignored, no error
    cmd = 12;  cg.sample();
    // cmd = 14; cg.sample();   // illegal: this line would cause a run-time error

    $display("cp_kind = %0.2f%%", cg.cp_kind.get_coverage());
    $display("cp_val  = %0.2f%%", cg.cp_val.get_coverage());
    $display("cg_cmd  = %0.2f%%", cg.get_coverage());
  end

endmodule
```

```output
cp_kind = 50.00%
cp_val  = 25.00%
cg_cmd  = 37.50%
```

**Line by line**

| Code | Explanation |
|---|---|
| `wildcard bins read = {4'b00??};` | One bin for the values 0 to 3. Sample 1 hits it. |
| `wildcard bins write = {4'b01??};` | One bin for 4 to 7. Sample 5 hits it. |
| `wildcard bins ctrl[] = {4'b10??};` | Four bins, for 8, 9, 10 and 11. Sample 9 hits one of them. |
| `cp_kind` | Six bins in total (1 + 1 + 4); three were hit: 50 percent. The value 12 matches no pattern, so it is not counted. |
| `bins val[] = {[0:15]};` | Sixteen bins, one per value, before exclusions. |
| `ignore_bins reserved = {[12:13]};` | Removes `val[12]` and `val[13]`. The two samples of 12 increment nothing. |
| `illegal_bins bad = {[14:15]};` | Removes `val[14]` and `val[15]` and makes them errors. |
| `cp_val` | 16 - 2 - 2 = 12 counted bins. Hit: the bins for 1, 5 and 9. 3 / 12 = 25 percent. |
| Commented line | If `cmd = 14` were sampled, the simulator would report an illegal-bin error. The wording and the severity are tool-specific. |

A common shorter idiom is to write only the exclusions and let the tool create automatic bins for the remaining values:

```systemverilog
cp_op: coverpoint txn.op {
  ignore_bins not_in_this_config = {ALU_SHL, ALU_SHR};   // 6 automatic bins remain
}
```

> **Interview trap:** "Should illegal bins be used to check the DUT?" Not as the only check. Coverage can be switched off for speed, or excluded in some regressions, and then the check silently disappears. A condition that must never occur should be checked by an assertion or by the scoreboard; an illegal bin is at most a second line of defence.

> **Common mistake:** Expecting the simulation to stop at an illegal bin. The standard only requires a run-time error message; whether the simulation stops depends on the tool and its settings.

### Interview questions

**Q1. What are illegal bins?**
Bins that declare values or transitions that must never occur. Sampling one produces a run-time error, and the values are excluded from coverage.

**Q2. What is the difference between ignore bins and illegal bins?**
Both exclude values from coverage. An ignored value is skipped silently. An illegal value causes a run-time error. If a value is in both, the illegal bin takes precedence.

**Q3. Do ignore and illegal bins change the coverage percentage?**
Yes. The excluded values are removed from the counted bins, which reduces the denominator, so the same set of hits gives a higher percentage.

**Q4. Would you use an illegal bin or an assertion to catch an illegal opcode?**
An assertion (or a scoreboard check). Checking should not depend on coverage being enabled. An illegal bin can be added as well, to document the coverage model.

## 2.6 Transition Bins

### In plain English

Value bins record **which values** occurred. They cannot tell you in **which order**. For a state machine, the order is the whole point: was the transition from `EXEC` to `DONE` taken? Did the state stay in `EXEC` for three cycles? Did a write follow a write? A transition bin is hit by a **sequence of values** seen on consecutive samples of the coverpoint.

### Technical definition

A transition bin specifies one or more ordered sequences of coverpoint values, written with the `=>` operator inside parentheses. The bin is incremented when the values of the coverpoint at **successive sampling points** match the complete sequence. "Successive" refers to samples of the covergroup, not to clock cycles (they are the same only if the covergroup is sampled on every clock).

### Syntax forms

| Declaration | Sequence(s) that hit the bin |
|---|---|
| `bins t = (1 => 2);` | 1 followed by 2 on the next sample |
| `bins t = (1 => 2 => 3);` | 1, then 2, then 3 on three consecutive samples |
| `bins t = (1, 2 => 3, 4);` | A set of transitions: 1=>3, 1=>4, 2=>3, 2=>4. **One** bin, hit by any of them |
| `bins t[] = (1, 2 => 3, 4);` | The same four transitions as **four separate bins** |
| `bins t = (1 => 2), (3 => 4);` | Two sequences in one bin; either hits it |
| `bins t = (5 [*3]);` | Consecutive repetition: 5 => 5 => 5 |
| `bins t = (5 [*2:4]);` | 5 repeated 2, 3 or 4 times. With `t[]`: three separate bins |
| `bins t = (1 => 5 [->2] => 7);` | "Goto" repetition: 1, then any values until 5 has occurred twice (not necessarily adjacent), then 7 **immediately** after the second 5 |
| `bins t = (1 => 5 [=2] => 7);` | Non-consecutive repetition: as above, but other values may also occur between the second 5 and the 7 |
| `bins t = default sequence;` | All transitions not covered by other transition bins. Not counted |
| `ignore_bins t = (2 => 1);` / `illegal_bins t = (2 => 1);` | Exclude a transition / make it an error |

```text
   samples of the coverpoint over time:       1   5   3   5   7

   (1 => 5)                 hit at sample 2        ^
   (5 => 7)                 hit at sample 5                        ^
   (1 => 5 [->2] => 7)      hit at sample 5   1 ... 5 ..... 5  7   ^   (7 right after 2nd 5)
   (1 => 5 => 7)            NOT hit: after the first 5 comes 3, not 7
```

### How it works internally

For each transition bin the simulator keeps a small matcher that remembers how much of the sequence has been seen so far. At every sample it compares the new value with the next expected value. Because the matcher needs the **previous** samples, the first sample of a covergroup instance can only start a sequence, never complete a two-value transition.

There are **no automatic transition bins**. Transitions are covered only if you declare them.

### Complete example

```systemverilog file=tb_bins_transition.sv
module tb_bins_transition;

  typedef enum bit [1:0] {IDLE, FETCH, EXEC, DONE} state_e;

  state_e state;

  covergroup cg_state;
    cp_state: coverpoint state {
      bins idle_to_fetch = (IDLE => FETCH);
      bins full_cycle    = (IDLE => FETCH => EXEC => DONE);
      bins stay_exec     = (EXEC [*3]);
      bins fetch_to_done = (FETCH => DONE [->1]);
      bins to_idle[]     = (FETCH, EXEC, DONE => IDLE);
    }
  endgroup

  cg_state cg = new();

  initial begin
    state = IDLE;   cg.sample();    // sample 1
    state = FETCH;  cg.sample();    // sample 2
    state = EXEC;   cg.sample();    // sample 3
    state = EXEC;   cg.sample();    // sample 4
    state = EXEC;   cg.sample();    // sample 5
    state = DONE;   cg.sample();    // sample 6
    state = IDLE;   cg.sample();    // sample 7

    $display("cp_state = %0.2f%%", cg.cp_state.get_coverage());
  end

endmodule
```

```output
cp_state = 57.14%
```

**Which bins are hit?**

The sampled sequence is `IDLE, FETCH, EXEC, EXEC, EXEC, DONE, IDLE`.

| Bin | Sequence required | Hit? | Reason |
|---|---|---|---|
| `idle_to_fetch` | IDLE => FETCH | Yes | Samples 1 and 2 |
| `full_cycle` | IDLE => FETCH => EXEC => DONE | **No** | After IDLE, FETCH, EXEC the next sample is EXEC, not DONE. The sequence requires consecutive samples |
| `stay_exec` | EXEC => EXEC => EXEC | Yes | Samples 3, 4 and 5 |
| `fetch_to_done` | FETCH, then the first later DONE | Yes | FETCH at sample 2; the first DONE is at sample 6 |
| `to_idle[]` (FETCH => IDLE) | | No | |
| `to_idle[]` (EXEC => IDLE) | | No | |
| `to_idle[]` (DONE => IDLE) | | Yes | Samples 6 and 7 |

Seven bins in total (1 + 1 + 1 + 1 + 3), four hit: 4 / 7 = 57.14 percent.

**Line by line**

| Code | Explanation |
|---|---|
| `bins idle_to_fetch = (IDLE => FETCH);` | A single two-value transition. Enum names can be used directly. |
| `bins full_cycle = (IDLE => FETCH => EXEC => DONE);` | A four-value sequence. It would be hit only if the machine spent exactly one sample in each state. The hole tells you that this scenario (a one-cycle execute phase) has not been tested. |
| `bins stay_exec = (EXEC [*3]);` | Three consecutive samples of `EXEC`. |
| `bins fetch_to_done = (FETCH => DONE [->1]);` | Goto repetition: after `FETCH`, any number of other values, then `DONE`. It tolerates the three `EXEC` samples in between. |
| `bins to_idle[] = (FETCH, EXEC, DONE => IDLE);` | A set on the left produces three transitions; `[]` makes each a separate bin, so the report shows exactly which return path to `IDLE` is missing. |

### Value bins versus transition bins

| Property | Value bins | Transition bins |
|---|---|---|
| What is covered | A value at one sample | A sequence of values over consecutive samples |
| Syntax | `bins b = {1, 2};` (braces) | `bins b = (1 => 2);` (parentheses) |
| Automatic bins | Yes | No, they must be written |
| Needs history | No | Yes: previous samples are remembered |
| Typical use | Opcodes, data ranges, lengths | FSM transitions, back-to-back operations, command sequences |
| Alternative | | Temporal behaviour on signals can also be covered with `cover property` (Part 5) |

> **Interview trap:** "The FSM coverpoint shows that all four states were visited. Is the FSM covered?" No. State (value) coverage does not show that each legal **transition** was taken. An FSM needs transition bins for every arc of the state diagram, and usually `illegal_bins` for the arcs that must not exist.

> **Interview trap:** Braces versus parentheses. `bins b = {1, 2};` is a value bin hit by 1 or by 2. `bins b = (1 => 2);` is a transition bin hit by 1 followed by 2.

> **Common mistake:** Forgetting that transitions are counted between **samples**, not between clock cycles. If the covergroup is sampled once per transaction, `(ALU_ADD => ALU_SUB)` means "an ADD transaction followed by a SUB transaction", however many idle clocks were between them. If the covergroup is sampled on every clock, a state held for several cycles produces `EXEC => EXEC` transitions that you may have to allow for.

> **Verification application:** For the ALU, transition bins on the opcode check back-to-back behaviour: the same operation twice (`ALU_ADD => ALU_ADD`), and an operation that produces a carry followed by one that must not inherit it. For a FIFO testbench, transitions on a "fill level" classification (`EMPTY => PARTIAL => FULL => PARTIAL => EMPTY`) prove that the FIFO was filled and drained completely.

### Interview questions

**Q1. What is a transition bin?**
A bin that is hit when the coverpoint takes a specified sequence of values on consecutive samples, written as `(a => b => c)`.

**Q2. How many bins does `bins t[] = (1, 2 => 3, 4);` create, and which transitions?**
Four: 1=>3, 1=>4, 2=>3 and 2=>4. Without `[]` it would be one bin hit by any of the four.

**Q3. What does `(3 [*4])` mean?**
The value 3 on four consecutive samples: 3 => 3 => 3 => 3.

**Q4. What is the difference between `[*n]`, `[->n]` and `[=n]` in a transition bin?**
`[*n]` is consecutive repetition. `[->n]` (goto) means the value occurs n times, not necessarily consecutively, and the next element of the sequence follows immediately after the last occurrence. `[=n]` (non-consecutive) is the same, except that other values may also appear between the last occurrence and the next element.

**Q5. Are transition bins created automatically?**
No. Only value bins are created automatically. Every transition of interest must be declared.

**Q6. How would you cover all transitions of a four-state FSM?**
Declare a transition bin for each legal arc, for example `bins legal[] = (IDLE => FETCH), (FETCH => EXEC), (EXEC => EXEC), (EXEC => DONE), (DONE => IDLE);`, and declare the arcs that must never happen as `illegal_bins`.
