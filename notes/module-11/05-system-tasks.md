## 4.4 Simulator System Tasks and Functions

System tasks and functions are the built-in routines whose names start with `$`. They are part of the language, are executed by the simulator, and (with a few exceptions such as `$clog2` and `$bits` with constant arguments) are ignored or rejected by synthesis. This section is a reference for the ones a verification engineer uses constantly, with the behaviour differences that are asked in interviews.

### Printing: $display, $write, $strobe, $monitor

| Task | When it prints | Newline added | Values shown | Typical use |
|---|---|---|---|---|
| `$display` | Immediately, when the statement executes | Yes | Current values at that instant | General messages |
| `$write` | Immediately | No | Current values | Building one line from several calls |
| `$strobe` | At the **end of the current time step** (Postponed region) | Yes | Final, settled values of the time step, after nonblocking assignments | Printing the result of `<=` assignments |
| `$monitor` | At the end of every time step in which **any of its arguments changed** | Yes | Final values | Simple continuous tracing in small testbenches |

Additional facts:

- Each has variants that set the default radix of arguments printed without a format: `$displayb`, `$displayo`, `$displayh` (and the same for `$write`, `$strobe`, `$monitor`).
- Only **one** `$monitor` is active at a time; a new call replaces the previous one. `$monitoroff` and `$monitoron` pause and resume it.
- `$monitor` does not react to changes of `$time` itself.
- The file versions take a file descriptor first: `$fdisplay`, `$fwrite`, `$fstrobe`, `$fmonitor`.

```systemverilog file=tb_display_strobe.sv
module tb_display_strobe;

  logic [3:0] a;

  initial begin
    a = 4'd1;
    $display("[%0t] $display : a = %0d", $time, a);
    $strobe ("[%0t] $strobe  : a = %0d", $time, a);
    a = 4'd2;
    a <= 4'd3;
    $display("[%0t] $display : a = %0d", $time, a);
    #10;
    $display("[%0t] $display : a = %0d", $time, a);
  end

endmodule
```

```output
[0] $display : a = 1
[0] $display : a = 2
[0] $strobe  : a = 3
[10] $display : a = 3
```

| Line of output | Explanation |
|---|---|
| `$display : a = 1` | `$display` prints immediately: `a` is 1 at that moment. |
| `$display : a = 2` | The blocking assignment `a = 2` has happened. The nonblocking `a <= 3` is only scheduled, so `a` is still 2. |
| `$strobe : a = 3` | Although `$strobe` was called second in the code, it prints at the end of time step 0, after the nonblocking assignment has updated `a` to 3. |
| `[10] ... a = 3` | The value persists. |

```systemverilog file=tb_monitor.sv
module tb_monitor;

  int a, b;

  initial $monitor("[%0t] monitor: a=%0d b=%0d", $time, a, b);

  initial begin
    #5  a = 1;
    #5  b = 2;
        a = 3;
    #5  a = 3;          // no change: nothing is printed
    #5  $finish;
  end

endmodule
```

```output
[0] monitor: a=0 b=0
[5] monitor: a=1 b=0
[10] monitor: a=3 b=2
```

`$monitor` prints once when it is first called, then once per time step in which an argument changed. At time 10 two variables changed but only one line is printed, showing the final values. At time 15 the assignment does not change `a`, so nothing is printed.

### Format specifiers

| Specifier | Prints | Specifier | Prints |
|---|---|---|---|
| `%d` / `%0d` | Decimal / decimal without padding | `%s` | String |
| `%h` or `%x` | Hexadecimal | `%c` | One character |
| `%b` | Binary | `%t` | Time, formatted by `$timeformat` |
| `%o` | Octal | `%f`, `%e`, `%g` | Real: fixed, exponential, shorter of the two |
| `%p` / `%0p` | Any aggregate in assignment-pattern form (arrays, structs, enums by name) / compact form | `%m` | Hierarchical name of the current scope (takes no argument) |
| `%v` | Net value with strength | `%%` | A literal percent sign |

A width may be given (`%8h`, `%-10s` for left-justified). A leading `0` in `%0d`, `%0h`, `%0t` means "minimum width, no padding".

### Messages with severity

| Task | Severity | Effect on simulation | Typical use |
|---|---|---|---|
| `$info("...")` | Information | Continues | Progress messages |
| `$warning("...")` | Warning | Continues | Suspicious but tolerated situations |
| `$error("...")` | Error | Continues; the simulator counts it | Check failures (scoreboard mismatch) |
| `$fatal(n, "...")` | Fatal | **Terminates** the simulation | Unrecoverable problems: null `vif`, randomization failure, timeout |

The first argument of `$fatal` is the finish number (0, 1 or 2, controlling how much is printed), not a message: write `$fatal(1, "text")`. The severity tasks print the file name, line number, scope and time automatically, which `$display` does not. They are also the action tasks used in assertions (M10). Regression scripts decide pass or fail by searching the log for the error and fatal counts.

### Ending and pausing simulation

| Task | Effect |
|---|---|
| `$finish;` or `$finish(n);` | Ends the simulation. `n` = 0, 1 or 2 selects how much diagnostic information is printed (default 1) |
| `$stop;` | Suspends the simulation and returns control to the interactive prompt; it can be continued. In batch mode many tools treat it like `$finish` |
| `$exit;` | Ends a `program` block and waits for other programs; rarely used outside program-based testbenches |
| `$fatal(...)` | Reports a fatal error and ends the simulation |

`final` blocks are executed when `$finish` is called; they run in zero time and are used to print summaries.

### Time

| Function / task | Returns or does |
|---|---|
| `$time` | Current time as a 64-bit integer in the time unit of the calling scope, rounded |
| `$realtime` | Current time as a `real`, including the fraction |
| `$stime` | Low 32 bits of the current time |
| `$timeformat(unit, precision, "suffix", min_width);` | Sets how `%t` prints. Call it once at the start of the test: `$timeformat(-9, 2, " ns", 10);` |
| `$printtimescale;` | Prints the time unit and precision of the current scope |

Details are in M1, Section 2.7.

### Random numbers

| Function | Returns | Notes |
|---|---|---|
| `$random` or `$random(seed)` | **Signed** 32-bit integer | Legacy Verilog. `$random % 10` lies in -9 to 9. The idiom `{$random} % 10` forces it non-negative |
| `$urandom` or `$urandom(seed)` | **Unsigned** 32-bit integer | SystemVerilog. Uses the per-process random generator, so results are stable when unrelated code is added (random stability, M5) |
| `$urandom_range(max, min)` | Unsigned integer in the inclusive range | `min` defaults to 0. If `max` is less than `min` the two are swapped |
| `std::randomize(var) with {...}` | 1 on success | Randomises ordinary variables with constraints (M5) |
| `$dist_uniform`, `$dist_normal`, `$dist_exponential`, `$dist_poisson` | Values with the named distribution | Take a seed variable as first argument |

In new testbench code use `$urandom`, `$urandom_range` and `randomize()`. The simulation seed is set from the simulator command line (the option name is tool-specific) so that a failing run can be reproduced.

### Command-line arguments: plusargs

Plusargs are options beginning with `+` on the simulator command line that the testbench can read at run time. They let one compiled testbench run many configurations without recompiling.

| Function | Returns | Behaviour |
|---|---|---|
| `$test$plusargs("STRING")` | Non-zero if a plusarg **starting with** STRING exists | A prefix match: `$test$plusargs("DEBUG")` is true for `+DEBUG` and also for `+DEBUG_LEVEL=3` |
| `$value$plusargs("NAME=%d", variable)` | Non-zero if a matching plusarg was found | Converts the text after the matched prefix according to the format (`%d`, `%h`, `%s`, `%f`...) and stores it in the variable. If not found, the variable is left unchanged |

```systemverilog file=tb_plusargs.sv
module tb_plusargs;

  int    num_txn = 10;            // defaults, used when the plusarg is absent
  string test_name = "default_test";
  bit    verbose;

  initial begin
    if (!$value$plusargs("NUM_TXN=%d", num_txn))
      $display("NUM_TXN not given, using default %0d", num_txn);

    void'($value$plusargs("TEST=%s", test_name));

    verbose = $test$plusargs("VERBOSE") ? 1'b1 : 1'b0;

    $display("test=%s num_txn=%0d verbose=%b", test_name, num_txn, verbose);
  end

endmodule
```

Run without any plusargs:

```output
NUM_TXN not given, using default 10
test=default_test num_txn=10 verbose=0
```

Run with `+NUM_TXN=250 +TEST=corner_test +VERBOSE` added to the simulator's run command:

```output
test=corner_test num_txn=250 verbose=1
```

| Code | Explanation |
|---|---|
| `int num_txn = 10;` | The variable is given its default first, because `$value$plusargs` leaves it untouched when the plusarg is missing. |
| `$value$plusargs("NUM_TXN=%d", num_txn)` | Searches the command line for `+NUM_TXN=`, converts what follows as a decimal number and stores it. The return value tells whether it was found. |
| `void'(...)` | The return value is deliberately discarded for `TEST`: a missing plusarg simply keeps the default. |
| `$test$plusargs("VERBOSE")` | A presence check for a flag with no value. |

This is how a test name, a transaction count, a verbosity level or a watchdog limit is selected per run. UVM selects the test class in the same way, with `+UVM_TESTNAME=`.

### Loading memories: $readmemh and $readmemb

| Task | Reads |
|---|---|
| `$readmemh("file", mem);` | Hexadecimal values from a text file into an unpacked array |
| `$readmemb("file", mem);` | Binary values |
| `$readmemh("file", mem, start, end);` | Only into the given address range |
| `$writememh("file", mem);` / `$writememb` | Writes the array contents to a file |

File format: values separated by white space or newlines; `@<hex address>` sets the address of the next value; `//` and `/* */` comments are allowed; `_` may separate digits; `x` and `z` are allowed.

```text
   // mem_init.hex
   @0
   de ad be ef       // addresses 0, 1, 2, 3
   @10
   55                // address 0x10
```

Typical uses: preloading a RAM or ROM model with a program, loading test vectors, initialising a reference memory. A runnable example is Exercise 6 in Section 6.5.

### File input and output

| Function / task | Purpose | Returns |
|---|---|---|
| `fd = $fopen("name", "mode");` | Opens a file. Modes: `"r"` read, `"w"` write (truncate), `"a"` append, also `"r+"`, `"w+"`, `"a+"` | A file descriptor (`int`); **0 if the open failed** |
| `$fclose(fd);` | Closes the file and flushes its buffer | |
| `$fdisplay(fd, ...)`, `$fwrite(fd, ...)` | Formatted output to the file | |
| `$fgets(str, fd)` | Reads one line into a string | Number of characters read; 0 at end of file |
| `$fscanf(fd, "format", args...)` | Formatted input | Number of items successfully read; -1 at end of file |
| `$sscanf(str, "format", args...)` | The same, reading from a string | Number of items read |
| `$feof(fd)` | End-of-file test | Non-zero at end of file |
| `$fflush(fd);` | Forces buffered output to disk | |

```systemverilog file=tb_file_io.sv
module tb_file_io;

  int fd;
  int idx, a, b;

  initial begin
    // ---- write ----
    fd = $fopen("alu_vectors.txt", "w");
    if (fd == 0) $fatal(1, "cannot open alu_vectors.txt for writing");
    for (int i = 0; i < 3; i++)
      $fdisplay(fd, "%0d %0d %0d", i, i * 10, i * i);
    $fclose(fd);

    // ---- read back ----
    fd = $fopen("alu_vectors.txt", "r");
    if (fd == 0) $fatal(1, "cannot open alu_vectors.txt for reading");
    while ($fscanf(fd, "%d %d %d", idx, a, b) == 3)
      $display("vector %0d: a=%0d b=%0d", idx, a, b);
    $fclose(fd);
  end

endmodule
```

```output
vector 0: a=0 b=0
vector 1: a=10 b=1
vector 2: a=20 b=4
```

| Code | Explanation |
|---|---|
| `fd = $fopen("alu_vectors.txt", "w");` | Opens (creates) the file for writing. |
| `if (fd == 0) $fatal(...)` | Always check the descriptor. Writing to descriptor 0 silently does nothing. |
| `$fdisplay(fd, ...)` | Like `$display`, but to the file. Three lines are written. |
| `$fclose(fd);` | Required before reading the file back, so that the data is flushed. |
| `while ($fscanf(...) == 3)` | Reads three numbers per iteration; the loop ends when fewer than three are read (end of file). |

### String formatting

| Function / task | Use |
|---|---|
| `s = $sformatf("format", args...);` | A **function** that returns the formatted string. The most used of the three: `$sformatf("txn %0d: a=%0h", id, a)` |
| `$sformat(s, "format", args...);` | A **task** that writes the formatted text into its first argument |
| `$swrite(s, args...);` | Like `$write`, into a string |
| `$psprintf(...)` | A vendor extension equivalent to `$sformatf`; not in the standard. Use `$sformatf` |

`$sformatf` is what builds the message strings of UVM's reporting macros, and what a transaction's `print` or `convert2string` method uses.

### Bit and vector utility functions

| Function | Returns | Example |
|---|---|---|
| `$bits(x)` | Number of bits of an expression or type | `$bits(int)` = 32, `$bits(logic [8:0])` = 9 |
| `$clog2(n)` | Ceiling of log base 2 of `n`: the number of address bits needed for `n` locations | `$clog2(8)` = 3, `$clog2(9)` = 4, `$clog2(1)` = 0 |
| `$countones(v)` | Number of bits that are 1 | `$countones(8'b0010_1000)` = 2 |
| `$countbits(v, '1, 'x)` | Number of bits having any of the listed values | Counts ones and X bits |
| `$onehot(v)` | 1 if **exactly one** bit is 1 | True for `0001_0000` |
| `$onehot0(v)` | 1 if **at most one** bit is 1 (zero allowed) | True for `0000_0000` and `0001_0000` |
| `$isunknown(v)` | 1 if any bit is X or Z | |
| `$size`, `$dimensions`, `$left`, `$right`, `$low`, `$high` | Array queries | M2 |
| `$typename(x)` | A string describing the type of `x` | The exact text is tool-dependent; useful for debugging parameterized classes |
| `$signed(x)`, `$unsigned(x)` | Reinterpretation of signedness | M1 |
| `$cast(dst, src)` | Checked dynamic cast | M1 (enums), M4 (class handles) |

`$clog2` and `$bits` are constant functions when their arguments are constant, so they are used in synthesizable RTL for sizing: `localparam int AW = $clog2(DEPTH);`.

```systemverilog file=tb_utility_functions.sv
module tb_utility_functions;

  logic [7:0] v;
  string      s;
  int         r;

  initial begin
    $display("1. $clog2(1)=%0d  $clog2(8)=%0d  $clog2(9)=%0d  $clog2(1024)=%0d",
             $clog2(1), $clog2(8), $clog2(9), $clog2(1024));

    v = 8'b0010_1000;
    $display("2. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0001_0000;
    $display("3. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0000_0000;
    $display("4. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0000_x001;
    $display("5. %b : isunknown=%b", v, $isunknown(v));

    s = $sformatf("txn %0d: a=%0h op=%s", 7, 8'hA5, "ALU_ADD");
    $display("6. %s (length %0d)", s, s.len());

    r = $urandom_range(10, 5);
    $display("7. $urandom_range(10, 5) is within 5..10: %b", r inside {[5:10]});
  end

endmodule
```

```output
1. $clog2(1)=0  $clog2(8)=3  $clog2(9)=4  $clog2(1024)=10
2. 00101000 : countones=2 onehot=0 onehot0=0
3. 00010000 : countones=1 onehot=1 onehot0=1
4. 00000000 : countones=0 onehot=0 onehot0=1
5. 0000x001 : isunknown=1
6. txn 7: a=a5 op=ALU_ADD (length 22)
7. $urandom_range(10, 5) is within 5..10: 1
```

Line 4 is the one to remember: for an all-zero vector `$onehot` is 0 and `$onehot0` is 1.

### Waveform dumping

| Task | Effect |
|---|---|
| `$dumpfile("waves.vcd");` | Names the VCD (Value Change Dump) file |
| `$dumpvars;` | Dumps every signal in the design |
| `$dumpvars(0, tb_top);` | Dumps `tb_top` and **all** levels below it |
| `$dumpvars(1, tb_top);` | Dumps only the signals directly in `tb_top` |
| `$dumpvars(2, tb_top.dut);` | Dumps `dut` and one level below it |
| `$dumpoff;` / `$dumpon;` | Pause and resume dumping, to limit file size |
| `$dumpall;`, `$dumpflush;`, `$dumplimit(bytes);` | Checkpoint, flush, and size limit |

```systemverilog
initial begin
  $dumpfile("alu.vcd");
  $dumpvars(0, tb_top);
end
```

VCD is the standard, portable format, and it is what EDA Playground displays. It records nets and variables of the static hierarchy only; class objects and dynamic arrays are not dumped. Each vendor also has a faster proprietary format with its own system tasks, which you will meet on the job.

### Mathematical functions

`$ln`, `$log10`, `$exp`, `$sqrt`, `$pow(x, y)`, `$floor`, `$ceil`, `$sin`, `$cos`, `$tan`, `$asin`, `$acos`, `$atan`, `$atan2`, `$hypot`, `$sinh`, `$cosh`, `$tanh` take and return `real` values. They are used in real-number models and in checkers that compute expected analogue-like quantities.

### Quick comparison of the most confused pairs

| Pair | Difference |
|---|---|
| `$display` vs `$strobe` | Immediate values vs values at the end of the time step |
| `$display` vs `$write` | Newline vs no newline |
| `$display` vs `$monitor` | Prints once vs prints on every change |
| `$finish` vs `$stop` | Ends the simulation vs pauses it |
| `$error` vs `$fatal` | Reports and continues vs reports and terminates |
| `$random` vs `$urandom` | Signed, legacy vs unsigned, random-stable |
| `$time` vs `$realtime` | Rounded integer vs real with fraction |
| `$test$plusargs` vs `$value$plusargs` | Presence check (prefix match) vs presence check plus value extraction |
| `$sformatf` vs `$sformat` | Function returning a string vs task writing into a string argument |
| `$onehot` vs `$onehot0` | Exactly one bit set vs zero or one bit set |
| `$readmemh` vs `$fscanf` | Loads a whole array in a fixed format vs reads arbitrary formatted text item by item |

> **Interview trap:** "A variable is assigned with `<=` and printed with `$display` on the next line. Which value is printed?" The old value. The nonblocking update happens later in the time step. `$strobe` prints the new value.

> **Interview trap:** "`$test$plusargs("TEST")` returns true although only `+TESTNAME=smoke` was given. Why?" It matches by prefix: any plusarg that begins with the string satisfies it.

> **Common mistake:** `$fatal("message")`. The first argument must be the finish number: `$fatal(1, "message")`.

> **Common mistake:** `x = $random % 8;` used as an array index. `$random` is signed, so the remainder can be negative. Use `$urandom_range(7)`.

> **Common mistake:** Using a file descriptor without checking it, or never calling `$fclose`. A failed `$fopen` returns 0 and all later writes vanish; an unclosed file may be incomplete on disk if the simulation is killed.

### Interview questions

**Q1. What is the difference between `$display`, `$write`, `$strobe` and `$monitor`?**
`$display` prints immediately and appends a newline. `$write` prints immediately without a newline. `$strobe` prints once at the end of the current time step, showing final values. `$monitor` is set up once and then prints at the end of every time step in which one of its arguments changed.

**Q2. What is the difference between `$finish` and `$stop`?**
`$finish` terminates the simulation. `$stop` suspends it and returns to the interactive prompt, from which it can be resumed.

**Q3. What is the difference between `$random` and `$urandom`?**
`$random` returns a signed 32-bit value and comes from Verilog. `$urandom` returns an unsigned 32-bit value, uses the per-thread random number generator and therefore has random stability. `$urandom_range(max, min)` returns an unsigned value within an inclusive range.

**Q4. How do you pass a value from the command line into a testbench?**
With a plusarg: add `+NAME=value` to the simulation command and read it with `$value$plusargs("NAME=%d", var)`. For a simple flag, `$test$plusargs("NAME")`.

**Q5. How do you initialise a memory from a file?**
`$readmemh("file.hex", mem);` for hexadecimal data or `$readmemb` for binary, where `mem` is an unpacked array.

**Q6. What does `$clog2` return and where is it used?**
The ceiling of the base-2 logarithm, which is the number of bits needed to address that many items. It is used to derive address or counter widths from a depth parameter: `localparam AW = $clog2(DEPTH);`.

**Q7. What is the difference between `$onehot` and `$onehot0`?**
`$onehot` is true when exactly one bit is 1. `$onehot0` is true when at most one bit is 1, so it also accepts all zeros.

**Q8. What is the difference between `$sformatf` and `$display`?**
`$display` prints to the log. `$sformatf` returns the formatted text as a string, which can be stored, passed to a function or included in another message.

**Q9. Why use `$error` instead of `$display("ERROR ...")`?**
`$error` records the message with error severity: it adds the file, line, scope and time, increments the simulator's error count, and can be controlled by simulator options. A plain `$display` is just text that a script would have to search for.

**Q10. How do you generate a waveform file?**
`$dumpfile("name.vcd");` followed by `$dumpvars(0, top_module);` in an `initial` block, or the vendor-specific equivalent for the tool's own format.
