# Part 6: Execution from Start to Finish

All the files now exist. This part follows the project as it runs: how data moves, what happens at each instant, what the log looks like, how new tests are added, and what a real failure looks like.

## 6.1 The Complete Communication Flow

### Stimulus path

```text
   Generator  ->  Mailbox  ->  Driver  ->  Interface  ->  DUT
```

| Step | Where | Code | What moves |
|---|---|---|---|
| 1 | `alu_generator::run` | `blueprint.randomize()` | Random values are chosen for `a`, `b`, `op` |
| 2 | `alu_generator::run` | `blueprint.copy()` | A new `alu_txn` object is created with those values |
| 3 | `alu_generator::send` | `gen2drv_mbx.put(txn)` | The **handle** of that object enters the mailbox |
| 4 | `alu_driver::run` | `gen2drv_mbx.get(txn)` | The handle leaves the mailbox; the driver now refers to the same object |
| 5 | `alu_driver::drive` | `vif.drv_cb.a <= txn.a;` etc. | Field values are copied onto interface signals, one time unit after a clock edge |
| 6 | `tb_top` | `.a (aif.a)` port connections | The interface signals are the wires on the DUT's input ports |
| 7 | `alu` | `always_ff @(posedge clk)` | The DUT samples the inputs at the next rising edge |
| 8 | `alu_driver::run` | `-> drv_done` | Control returns to the generator (`@(drv_done)` in `send`), which goes back to step 1 |

Up to step 4 the thing that moves is an object handle. From step 5 onward it is signal values. The driver is the boundary.

### Checking path

```text
   DUT  ->  Interface  ->  Monitor  ->  Mailbox  ->  Scoreboard
```

| Step | Where | Code | What moves |
|---|---|---|---|
| 1 | `alu` | `result <= result_nxt; valid_out <= valid_in;` | The DUT registers its outputs |
| 2 | `tb_top` | `.result (aif.result)` port connections | The DUT outputs drive the interface signals |
| 3 | `alu_if` | `clocking mon_cb` | At each rising edge the clocking block samples all signals (their pre-edge values) |
| 4 | `alu_monitor::run` | `pending = new(); pending.a = vif.mon_cb.a;` etc. | At the edge where `valid_in` is sampled high, a new object receives the input values |
| 5 | `alu_monitor::run` | `pending.result = vif.mon_cb.result;` | One edge later the same object receives the result |
| 6 | `alu_monitor::run` | `mon2scb_mbx.put(pending)` | The handle enters the second mailbox |
| 7 | `alu_scoreboard::run` | `mon2scb_mbx.get(txn)` | The handle leaves the mailbox |
| 8 | `alu_scoreboard::check_txn` | `alu_predict`, `compare` | Expected result computed and compared; PASS or FAIL recorded |
| 9 | `alu_env::run` | `wait (scb.num_checked == gen.num_sent)` | The environment notices when the last result has been checked |

Here the monitor is the boundary: signal values up to step 3, an object handle from step 4.

### The two paths never share an object

The object the generator created ends its life in the driver. The object the scoreboard checks was created by the monitor from the pins. The only thing that connects the stimulus path to the checking path is the DUT itself (and the interface wires). That is deliberate: if the two paths shared an object, a mistake on one side could hide a mistake on the other.

```text
   generator's object:   created in gen  ->  mailbox  ->  used by driver  ->  dropped
                                                              |
                                                          pin values
                                                              |
                                                             DUT
                                                              |
                                                          pin values
                                                              |
   monitor's object:                 created in mon  ->  mailbox  ->  checked by scoreboard
```

An object that no handle refers to any more is reclaimed automatically by the simulator; SystemVerilog has no `delete` for objects (Module 4).

## 6.2 Simulation Execution Order

### The threads

Once the test is running, these processes exist at the same time:

| Thread | Started by | Blocks on | Ends |
|---|---|---|---|
| Clock generator | `always` in `tb_top` | `#5` | Never (until `$finish`) |
| Reset block | `initial` in `tb_top` | Two falling clock edges | At time 20 |
| DUT `always_comb`, `always_ff` | The DUT | Input changes; clock and reset edges | Never |
| Test thread | Second `initial` in `tb_top` | `join_any`, then the drain `join_any` | Calls `$finish` |
| Generator | `fork` in `alu_env::run` | `@(drv_done)` | After the last transaction |
| Driver | `fork` in `alu_env::run` | Mailbox `get()`, clocking events | Killed by `disable fork` |
| Monitor | `fork` in `alu_env::run` | Clocking event | Killed by `disable fork` |
| Scoreboard | `fork` in `alu_env::run` | Mailbox `get()` | Killed by `disable fork` |
| Drain wait and watchdog | Second `fork` in `alu_env::run` | The counters; clock edges | One finishes, the other is killed |

### The phases of a run

```text
   BEFORE TIME 0   elaboration: tb_top, aif, dut exist. clk = 0. No class object exists yet.

   TIME 0          reset block:   aif.rst_n = 0                (DUT resets asynchronously)
   (zero time)     test block:    read +TEST, test = new(aif)
                                    -> BUILD + CONNECT: env, mailboxes, gen, drv, mon, scb
                                  test.run()
                                    -> configure()                  (scenario settings)
                                    -> env.run(): fork four threads
                                         gen: randomize, put txn 1, wait for drv_done
                                         drv: reset(): wait for a clock edge
                                         mon: wait for a clock edge
                                         scb: wait on empty mailbox
                                       parent waits at join_any

   RESET           5, 15: clock edges; drv drives idle values (visible at 6); mon skips
                   20:    reset released; drv takes txn 1 from the mailbox

   MAIN LOOP       every 20 time units, one transaction:
                     drive -> DUT samples -> DUT answers -> monitor sends -> scb checks

   END OF STIMULUS gen has sent num_txns transactions; gen.run() returns; join_any releases
                   the test thread; "ENV: stimulus done" is printed

   DRAIN           the last transaction is still in the DUT; one clock later the monitor
                   sends it and the scoreboard checks it; the wait condition becomes true

   SHUTDOWN        disable fork kills drv, mon, scb and the watchdog; env.run() returns

   REPORT          scb.report() prints the summary; tb_top calls $finish
```

### What happens at time 0, in detail

Several things happen at time 0 without any time passing, and their order is worth understanding:

1. Both `initial` blocks of `tb_top` start. Their relative order is not defined, and it does not matter: one only writes `rst_n`, the other only builds objects.
2. `test = new(aif)` runs to completion (constructors are functions): every component and mailbox exists and is connected before anything runs.
3. `test.run()` → `configure()` → `env.run()` → `fork`. The four threads are created. The parent reaches `join_any` and blocks; only now do the children start executing.
4. Each child runs until it blocks. The generator randomizes, puts transaction 1 into the mailbox, prints its `GEN` line and waits for `drv_done`. The driver, monitor and scoreboard each block almost immediately.
5. Nothing more can happen at time 0. Simulation time advances to 5, the first rising clock edge.

Whichever order the simulator picks for the four children in step 4, the outcome is identical, because no child depends on another child's time-0 actions except through the mailbox, and the mailbox holds the transaction until the driver asks for it at time 20. A testbench is free of races when its behaviour does not depend on such ordering.

## 6.3 Cycle-by-Cycle Timeline of One Transaction

The transaction is `ALU_ADD`, `a` = 200, `b` = 100 (the first one in the directed test of the next section). Clock: rising edges at 5, 15, 25...; reset released at 20.

| Time | Component | Action |
|---|---|---|
| 0 | Generator | Creates transaction 1, `put()` into `gen2drv_mbx`, prints `GEN`, waits for `drv_done` |
| 0 | Driver | In `reset()`, waiting for the first clock edge |
| 5 | Driver | Clock edge: schedules idle values on `valid_in`, `a`, `b`, `op` |
| 6 | Interface | Idle values appear |
| 5, 15 | Monitor | `rst_n` is 0: ignores these edges |
| 20 | `tb_top` | `rst_n` goes to 1 |
| 20 | Driver | `wait` ends; `get()` returns transaction 1; `drive()` waits for a clock edge |
| 25 | Driver | Clock edge: schedules `valid_in` = 1, `a` = 200, `b` = 100, `op` = `ALU_ADD` |
| 25 | Monitor | Samples `valid_in` = 0, `valid_out` = 0: nothing to do |
| 26 | Interface | `valid_in` = 1 and the operands appear on the wires |
| 26 | DUT | `always_comb` recomputes `result_nxt` = 300 |
| 35 | DUT | Clock edge: samples `valid_in` = 1, so `result` ← 300 and `valid_out` ← 1 (visible just after the edge) |
| 35 | Monitor | The values it sampled just before this edge: `valid_in` = 1, 200, 100, `ALU_ADD`. Creates `pending` with id 1 |
| 35 | Driver | Schedules `valid_in` = 0; prints `DRV`; triggers `drv_done`; blocks in `get()` |
| 35 | Generator | Wakes; creates transaction 2; `put()`; prints `GEN`; waits again |
| 35 | Driver | `get()` returns transaction 2; `drive()` waits for a clock edge |
| 36 | Interface | `valid_in` = 0 |
| 45 | DUT | Clock edge: samples `valid_in` = 0, so `valid_out` ← 0; `result` keeps 300 |
| 45 | Monitor | Sampled just before this edge: `valid_out` = 1, `result` = 300. Completes transaction 1, prints `MON`, `put()` into `mon2scb_mbx` |
| 45 | Scoreboard | `get()` returns; `alu_predict` gives 300; `compare` succeeds; prints `SCB PASS`; `num_checked` = 1 |
| 45 | Driver | Schedules transaction 2 on the pins (visible at 46) |

From the moment the driver starts driving (25) to the scoreboard's verdict (45) is two clock cycles: one for the DUT to sample, one for the result to become visible to the monitor.

### What the clocking blocks see at each edge

The same story as a table of sampled values, that is, the values just before each rising edge. This is exactly what `vif.mon_cb.*` returns after `@(vif.mon_cb)`.

```text
   rising edge at      5      15      25      35      45      55      65
   -----------------------------------------------------------------------
   rst_n               0       0       1       1       1       1       1
   valid_in            x       0       0       1       0       1       0
   a, b, op            x     idle    idle    txn 1   txn 1   txn 2   txn 2
   valid_out           0       0       0       0       1       0       1
   result              0       0       0       0      300     300    res 2
   -----------------------------------------------------------------------
   monitor           (reset) (reset)   -     create  send    create  send
                                             txn 1   txn 1   txn 2   txn 2
   scoreboard                                        check           check
                                                     txn 1           txn 2
```

Things to notice:

- At edge 5 the inputs are still X, because the driver's first drive only appears at time 6. The DUT is in reset and the monitor is skipping, so it does not matter.
- At edge 45 the operands still show transaction 1. The driver removed `valid_in` but did not change `a`, `b` and `op`; they are irrelevant while `valid_in` is 0.
- `valid_out` at each edge equals `valid_in` at the previous edge. That is the one-cycle latency.
- `result` keeps its last value (300) at edge 55 even though `valid_out` is 0. The monitor does not look at it then.

## 6.4 A Directed Test, with Its Exact Log

### Why a directed test in a random testbench

Random stimulus cannot be predicted, so it cannot be used to show an exact log, and a few specific cases are worth guaranteeing in every regression (the first sanity check after any change to the RTL, for example). A directed test supplies fixed transactions through the same components. Nothing in the driver, monitor, scoreboard or environment changes.

### How it is done

The stimulus loop lives in `alu_generator::run`, which is virtual. A derived generator overrides `run()` with a fixed list of transactions, and a derived test puts that generator in place of the default one.

```systemverilog file=alu_directed_test.sv
class alu_directed_gen extends alu_generator;

  function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done, event gen_done);
    super.new(gen2drv_mbx, drv_done, gen_done);
  endfunction

  task send_values(bit [7:0] a, bit [7:0] b, alu_op_e op);
    alu_txn txn;
    txn    = new();
    txn.a  = a;
    txn.b  = b;
    txn.op = op;
    send(txn);
  endtask

  virtual task run();
    send_values(8'd200, 8'd100, ALU_ADD);
    send_values(8'd5,   8'd10,  ALU_SUB);
    send_values(8'hF0,  8'h3C,  ALU_AND);
    send_values(8'hF0,  8'h3C,  ALU_OR);
    send_values(8'hF0,  8'h3C,  ALU_XOR);
    send_values(8'hF0,  8'h00,  ALU_NOT);
    send_values(8'h81,  8'h00,  ALU_SHL);
    send_values(8'h81,  8'h00,  ALU_SHR);
    -> gen_done;
  endtask

endclass

class alu_directed_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_directed_test";
  endfunction

  virtual function void configure();
    alu_directed_gen dgen;
    dgen    = new(env.gen2drv_mbx, env.drv_done, env.gen_done);
    env.gen = dgen;
  endfunction

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `class alu_directed_gen extends alu_generator;` | Inherits the mailbox handle, the events, `num_sent` and the `send()` task. |
| `super.new(gen2drv_mbx, drv_done, gen_done);` | The base constructor has arguments, so the derived constructor must call it explicitly and pass them on. |
| `task send_values(...)` | Builds one transaction with fixed values and hands it to the inherited `send()`, which numbers it, puts it in the mailbox, prints it and waits for the driver. |
| `virtual task run();` | Overrides the random loop of the base class. |
| Eight `send_values` calls | One transaction per operation. |
| `-> gen_done;` | The same end-of-stimulus signal as the base class. |
| `class alu_directed_test extends alu_test;` | A new test. |
| `super.new(vif);` | Builds the standard environment (including a default generator). |
| `name = "alu_directed_test";` | For the log. |
| `dgen = new(env.gen2drv_mbx, env.drv_done, env.gen_done);` | The replacement generator is connected to the **same** mailbox and events the environment already created, so it talks to the same driver. |
| `env.gen = dgen;` | A derived-class handle is assigned to a base-class handle. From now on `env.gen.run()` executes `alu_directed_gen::run`, because `run` is virtual, and `env.gen.num_sent` refers to the new object. The original generator object is no longer referenced. |

`configure()` is called from `alu_test::run` before `env.run()`, so the replacement is in place before the threads are forked.

### Expected values

| id | Operation | `a` | `b` | Calculation | `result` |
|---|---|---|---|---|---|
| 1 | `ALU_ADD` | 200 | 100 | 200 + 100 = 300 (needs bit 8) | 300 |
| 2 | `ALU_SUB` | 5 | 10 | 5 - 10 = -5; in 9 bits 512 - 5 | 507 |
| 3 | `ALU_AND` | 240 (`F0`) | 60 (`3C`) | `1111_0000 & 0011_1100` = `0011_0000` | 48 |
| 4 | `ALU_OR` | 240 | 60 | `1111_1100` | 252 |
| 5 | `ALU_XOR` | 240 | 60 | `1100_1100` | 204 |
| 6 | `ALU_NOT` | 240 | 0 | `~1111_0000` = `0000_1111` | 15 |
| 7 | `ALU_SHL` | 129 (`81`) | 0 | `1000_0001` → `1_0000_0010` | 258 |
| 8 | `ALU_SHR` | 129 | 0 | `1000_0001` → `0100_0000` | 64 |

### The log

Run with `+TEST=alu_directed_test`.

```output
[0] TEST: alu_directed_test started
[0] GEN id=1 op=ALU_ADD a=200 b=100 result=x
[35] DRV id=1 op=ALU_ADD a=200 b=100 result=x
[35] GEN id=2 op=ALU_SUB a=5 b=10 result=x
[45] MON id=1 op=ALU_ADD a=200 b=100 result=300
[45] SCB PASS id=1 op=ALU_ADD a=200 b=100 result=300
[55] DRV id=2 op=ALU_SUB a=5 b=10 result=x
[55] GEN id=3 op=ALU_AND a=240 b=60 result=x
[65] MON id=2 op=ALU_SUB a=5 b=10 result=507
[65] SCB PASS id=2 op=ALU_SUB a=5 b=10 result=507
[75] DRV id=3 op=ALU_AND a=240 b=60 result=x
[75] GEN id=4 op=ALU_OR a=240 b=60 result=x
[85] MON id=3 op=ALU_AND a=240 b=60 result=48
[85] SCB PASS id=3 op=ALU_AND a=240 b=60 result=48
[95] DRV id=4 op=ALU_OR a=240 b=60 result=x
[95] GEN id=5 op=ALU_XOR a=240 b=60 result=x
[105] MON id=4 op=ALU_OR a=240 b=60 result=252
[105] SCB PASS id=4 op=ALU_OR a=240 b=60 result=252
[115] DRV id=5 op=ALU_XOR a=240 b=60 result=x
[115] GEN id=6 op=ALU_NOT a=240 b=0 result=x
[125] MON id=5 op=ALU_XOR a=240 b=60 result=204
[125] SCB PASS id=5 op=ALU_XOR a=240 b=60 result=204
[135] DRV id=6 op=ALU_NOT a=240 b=0 result=x
[135] GEN id=7 op=ALU_SHL a=129 b=0 result=x
[145] MON id=6 op=ALU_NOT a=240 b=0 result=15
[145] SCB PASS id=6 op=ALU_NOT a=240 b=0 result=15
[155] DRV id=7 op=ALU_SHL a=129 b=0 result=x
[155] GEN id=8 op=ALU_SHR a=129 b=0 result=x
[165] MON id=7 op=ALU_SHL a=129 b=0 result=258
[165] SCB PASS id=7 op=ALU_SHL a=129 b=0 result=258
[175] DRV id=8 op=ALU_SHR a=129 b=0 result=x
[175] ENV: stimulus done, waiting for 8 results
[185] MON id=8 op=ALU_SHR a=129 b=0 result=64
[185] SCB PASS id=8 op=ALU_SHR a=129 b=0 result=64
------------------------------------------------------------
SCOREBOARD SUMMARY: checked=8 pass=8 fail=0
TEST PASSED
------------------------------------------------------------
```

### Reading the log

| Lines | What they show |
|---|---|
| `[0] GEN id=1 ... result=x` | The generator creates the first transaction before reset is even released. `result` is X: nobody knows it yet. |
| `[35] DRV id=1` | Printed by the driver at the edge where the DUT sampled the transaction (driven from 26, sampled at 35). `result` is still X in the generator's object; the driver never touches it. |
| `[35] GEN id=2` | Same time step: `drv_done` woke the generator. The order `DRV` then `GEN` is fixed, because the first causes the second. |
| `[45] MON id=1 ... result=300` | One clock later the monitor has both halves. This is a *different object* from the one in the `GEN` and `DRV` lines; its values came from the pins. |
| `[45] SCB PASS id=1` | The scoreboard received it in the same time step. `MON` then `SCB` is also a fixed order. |
| Period of 20 | Each transaction takes two clock cycles on the stimulus side. |
| `[175] ENV: stimulus done` | The last `drv_done` let the generator's `run()` return, which released `join_any`. At this moment transaction 8 has been sampled by the DUT but not yet checked. |
| `[185]` | Drain: one more clock, the last result is checked, the wait in the environment ends, the threads are killed, the report is printed. |

Every pair of lines with the same time stamp is cause and effect within one chain of events, so the order of the lines is the same in every simulator. (A testbench in which two unrelated threads print at the same time step can legally print them in either order.)

## 6.5 The Random Test

Run with no `+TEST` argument (or `+TEST=alu_test`). The base test sends ten random transactions. The times and the structure of the log are identical to the directed test; the operations and operands depend on the seed and the simulator.

Sample output; operand values differ per seed and simulator:

```output
[0] TEST: alu_test started
[0] GEN id=1 op=ALU_XOR a=173 b=58 result=x
[35] DRV id=1 op=ALU_XOR a=173 b=58 result=x
[35] GEN id=2 op=ALU_SUB a=12 b=200 result=x
[45] MON id=1 op=ALU_XOR a=173 b=58 result=151
[45] SCB PASS id=1 op=ALU_XOR a=173 b=58 result=151
[55] DRV id=2 op=ALU_SUB a=12 b=200 result=x
[55] GEN id=3 op=ALU_SHL a=255 b=7 result=x
[65] MON id=2 op=ALU_SUB a=12 b=200 result=324
[65] SCB PASS id=2 op=ALU_SUB a=12 b=200 result=324
[75] DRV id=3 op=ALU_SHL a=255 b=7 result=x
[75] GEN id=4 op=ALU_AND a=0 b=91 result=x
[85] MON id=3 op=ALU_SHL a=255 b=7 result=510
[85] SCB PASS id=3 op=ALU_SHL a=255 b=7 result=510
    ... (transactions 4 to 9) ...
[215] DRV id=10 op=ALU_ADD a=255 b=255 result=x
[215] ENV: stimulus done, waiting for 10 results
[225] MON id=10 op=ALU_ADD a=255 b=255 result=510
[225] SCB PASS id=10 op=ALU_ADD a=255 b=255 result=510
------------------------------------------------------------
SCOREBOARD SUMMARY: checked=10 pass=10 fail=0
TEST PASSED
------------------------------------------------------------
```

Check the arithmetic of a sample line yourself; it is good practice for reading real logs: 173 is `1010_1101`, 58 is `0011_1010`, XOR gives `1001_0111` = 151. 12 - 200 = -188, and 512 - 188 = 324. 255 shifted left is `1_1111_1110` = 510.

Nobody computed these expected values in advance. The reference model did, at run time, for whatever the generator produced. That is the point of the architecture.

> **Key point:** A failing random test is only useful if it can be reproduced. Always record the seed (simulators print it, or it is given on the command line), and rerun with the same seed to get the same stimulus.

## 6.6 Adding a Test Without Touching the Components

### The requirement

"Stress the adder and subtractor: send 20 transactions that are only `ALU_ADD` or `ALU_SUB`."

### The solution: extend the transaction and the test

```systemverilog file=alu_arith_test.sv
class alu_arith_txn extends alu_txn;

  constraint arith_c {
    op inside {ALU_ADD, ALU_SUB};
  }

endclass

class alu_arith_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_arith_test";
  endfunction

  virtual function void configure();
    alu_arith_txn arith_txn;
    arith_txn         = new();
    env.gen.blueprint = arith_txn;
    env.gen.num_txns  = 20;
  endfunction

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `class alu_arith_txn extends alu_txn;` | A transaction with everything `alu_txn` has, plus one more constraint. |
| `constraint arith_c { op inside {ALU_ADD, ALU_SUB}; }` | Added to the inherited `operand_c`. Both must hold when the object is randomized. |
| `env.gen.blueprint = arith_txn;` | The generator's blueprint handle (type `alu_txn`) now refers to an `alu_arith_txn` object. |
| `env.gen.num_txns = 20;` | A scenario setting. |

### Why this works

```text
   generator code (unchanged):      blueprint.randomize()
                                         |
                                         v
   blueprint handle type : alu_txn       randomize() acts on the OBJECT, and the object
   object it refers to   : alu_arith_txn is an alu_arith_txn, so operand_c AND arith_c
                                         are both applied

                                    send(blueprint.copy())
                                         |
                                         v
                                    copy() creates a plain alu_txn carrying the
                                    already-constrained values of a, b, op
```

- `randomize()` always uses the constraints of the object's actual class, whatever the type of the handle through which it is called (Module 5).
- The copy that travels through the mailbox is a plain `alu_txn`. That is fine: the derived class adds only a constraint, which has done its work by the time the values are copied. A derived transaction that added **fields** would also override `copy()`, which is why `copy()` is virtual.

### What changed, and what did not

| File | Changed? |
|---|---|
| `alu_arith_test.sv` | New |
| `alu_tb_pkg.sv` | One `` `include `` line |
| `tb_top.sv` | One `case` branch (with UVM's factory, not even that) |
| `alu_txn.sv`, `alu_generator.sv`, `alu_driver.sv`, `alu_monitor.sv`, `alu_scoreboard.sv`, `alu_env.sv`, `alu_test.sv` | **No** |

The scoreboard checks the new stimulus without modification, because it predicts from whatever the monitor reports.

Sample output with `+TEST=alu_arith_test`; operand values differ per seed and simulator:

```output
[0] TEST: alu_arith_test started
[0] GEN id=1 op=ALU_ADD a=37 b=255 result=x
[35] DRV id=1 op=ALU_ADD a=37 b=255 result=x
[35] GEN id=2 op=ALU_SUB a=0 b=142 result=x
[45] MON id=1 op=ALU_ADD a=37 b=255 result=292
[45] SCB PASS id=1 op=ALU_ADD a=37 b=255 result=292
[55] DRV id=2 op=ALU_SUB a=0 b=142 result=x
[55] GEN id=3 op=ALU_ADD a=255 b=255 result=x
[65] MON id=2 op=ALU_SUB a=0 b=142 result=370
[65] SCB PASS id=2 op=ALU_SUB a=0 b=142 result=370
    ... (transactions 3 to 19) ...
[415] DRV id=20 op=ALU_SUB a=90 b=17 result=x
[415] ENV: stimulus done, waiting for 20 results
[425] MON id=20 op=ALU_SUB a=90 b=17 result=73
[425] SCB PASS id=20 op=ALU_SUB a=90 b=17 result=73
------------------------------------------------------------
SCOREBOARD SUMMARY: checked=20 pass=20 fail=0
TEST PASSED
------------------------------------------------------------
```

### Three ways a test can change the stimulus

| Technique | What the test does | Used in |
|---|---|---|
| Change a knob | `env.gen.num_txns = 20;` | Every test |
| Replace the blueprint | `env.gen.blueprint = <derived transaction>;` | `alu_arith_test` |
| Replace the generator | `env.gen = <derived generator>;` | `alu_directed_test` |

All three rely on the same two OOP facts from Module 4: a base-class handle can refer to a derived-class object, and a virtual method (or `randomize()`) executes according to the object, not the handle.

> **Interview trap:** "To add a test for only ADD operations, I would add an `if` in the generator." That works once. After twenty tests the generator is a tangle of test-specific branches that every test depends on. The interviewer wants to hear: extend the transaction with a constraint, extend the test, set the blueprint. Components stay closed to modification and open to extension.

## 6.7 A Seeded Bug: What a Failure Looks Like

A testbench that has never reported a failure has not been shown to work. A standard practice is to put a deliberate bug into the DUT and confirm that the testbench finds it. It also teaches how to read a failure.

### The bug

In `alu.sv`, change the addition line to:

```systemverilog
ALU_ADD: result_nxt = {1'b0, a + b};      // BUG: the carry is lost
```

It looks harmless, and it is a real kind of mistake. Inside a concatenation each operand is self-determined, so `a + b` is computed in 8 bits and the carry is discarded before the zero is placed in front (Module 1, Section 4.4).

### The directed test now prints

The message text is shown; `$error` also adds a simulator-specific prefix with severity, file and line.

```output
[0] TEST: alu_directed_test started
[0] GEN id=1 op=ALU_ADD a=200 b=100 result=x
[35] DRV id=1 op=ALU_ADD a=200 b=100 result=x
[35] GEN id=2 op=ALU_SUB a=5 b=10 result=x
[45] MON id=1 op=ALU_ADD a=200 b=100 result=44
[45] SCB FAIL id=1 op=ALU_ADD a=200 b=100 actual=44 expected=300
[55] DRV id=2 op=ALU_SUB a=5 b=10 result=x
    ... (transactions 2 to 8 pass exactly as before) ...
------------------------------------------------------------
SCOREBOARD SUMMARY: checked=8 pass=7 fail=1
TEST FAILED
------------------------------------------------------------
```

### Localising the bug from the log alone

| Question | Evidence in the log | Conclusion |
|---|---|---|
| Did the stimulus reach the DUT correctly? | `GEN`, `DRV` and `MON` lines for id 1 all show `ALU_ADD`, 200, 100 | Yes. Generator, driver and wiring are fine: the monitor saw on the pins what the generator intended |
| What did the DUT output? | `MON ... result=44` | 44, sampled from the pins |
| What should it have been? | `expected=300` | 200 + 100 |
| How do they differ? | 300 - 44 = 256 = 2^8 | Exactly bit 8 is missing; the low 8 bits are right |
| Which operations fail? | Only id 1; the other seven pass | Only `ALU_ADD` |
| Is the model or the DUT wrong? | The specification says bit 8 of an addition is the carry | The model agrees with the specification; the DUT is wrong |

Conclusion before opening a waveform: *the ALU drops the carry out of bit 7 for `ALU_ADD`*. That points at one line of RTL.

With the random arithmetic test the same bug shows a second pattern. Sample output; operand values differ per seed and simulator:

```output
[45] SCB FAIL id=1 op=ALU_ADD a=37 b=255 actual=36 expected=292
[65] SCB PASS id=2 op=ALU_SUB a=0 b=142 result=370
[85] SCB FAIL id=3 op=ALU_ADD a=255 b=255 actual=254 expected=510
[105] SCB PASS id=4 op=ALU_ADD a=3 b=9 result=12
```

Additions fail only when the sum exceeds 255 (37 + 255, 255 + 255), and pass otherwise (3 + 9). The pattern across many random transactions narrows the cause faster than any single directed case. It also shows why the constraint `operand_c` makes 255 a frequent operand: without it, a small random sample might contain few overflowing additions.

### When the testbench is the one that is wrong

Suppose instead the reference model had been written as `ALU_NOT: r = ~t.a;`. The directed test would print:

```output
[145] SCB FAIL id=6 op=ALU_NOT a=240 b=0 actual=15 expected=271
```

The same reasoning applies, with the opposite conclusion. Expected minus actual is 256 again, but now the specification says the result of NOT is `~a`, an 8-bit quantity, so bit 8 must be 0. The DUT's 15 is right and the model's 271 is wrong: in a 9-bit context `~t.a` inverts the extended zero in bit 8 as well.

> **Key point:** A scoreboard mismatch means "DUT and model disagree". It does not say which one is wrong. The specification decides. A noticeable fraction of the failures in a new testbench are testbench bugs, and an engineer who assumes the DUT is always the guilty one wastes the designer's time.

### A debugging order that works

1. Read the first failure, not the last. Later failures are often consequences.
2. From the `FAIL` line: which operation, which operands, how do actual and expected differ (one bit? off by one? shifted? the previous transaction's value?).
3. Compare the `GEN`/`DRV` lines with the `MON` line for the same id. If they differ, the problem is on the stimulus path (driver, interface, connections), not in the DUT's function.
4. Compute the correct answer by hand from the specification. That tells you whether DUT or model is wrong.
5. Only then open the waveform, at the time given in the log, to see why.
6. Rerun with the same seed after the fix, then run the whole regression.

## 6.8 The Same Structure for a Different DUT: a Synchronous FIFO

The architecture does not depend on the ALU. To show what is general and what is specific, here is how the same structure maps onto an 8-bit synchronous FIFO, `sync_fifo`, with ports `clk`, `rst_n`, `wr_en`, `rd_en`, `din[7:0]`, `dout[7:0]`, `full` and `empty`. The code below is a sketch (fragments, not a complete project); it assumes that `dout` is registered, so that the data for a read accepted at one clock edge is visible at the next.

### What stays and what changes

| Item | ALU project | FIFO project | Same structure? |
|---|---|---|---|
| Top module | Clock, reset, `alu_if`, `alu` | Clock, reset, `fifo_if`, `sync_fifo` | Yes |
| Interface | `alu_if` with `drv_cb`, `mon_cb` | `fifo_if` with `drv_cb`, `mon_cb` | Yes |
| Transaction | `a`, `b`, `op`, `result` | `kind` (write or read), `data` | Fields differ |
| Generator | Random transactions via blueprint | The same code, different transaction class | Yes |
| Driver | `valid_in` for one cycle | `wr_en` or `rd_en` for one cycle | Protocol differs |
| Monitor | Pairs inputs with the result one cycle later | Reports accepted writes; reports accepted reads with the data one cycle later | Protocol differs |
| Scoreboard | Stateless model `alu_predict` | **Stateful** model: a queue | Model differs |
| Environment, test | As shown | Identical in shape | Yes |
| End of test | Checked count equals sent count | Same, plus "model queue matches the DUT's fill level" | Yes |

The important difference is in the scoreboard. The ALU's output depends only on the current inputs, so its model is a pure function. A FIFO's output depends on history: what comes out now is what went in earlier. Its reference model must **remember**, and the natural SystemVerilog structure for "first in, first out" is a queue (Module 2).

### Transaction and scoreboard sketch

```systemverilog
typedef enum bit {FIFO_WRITE, FIFO_READ} fifo_kind_e;

class fifo_txn;
  rand fifo_kind_e kind;
  rand bit [7:0]   data;       // WRITE: the value to write
  logic [7:0]      rdata;      // READ : the value the monitor saw on dout
endclass

class fifo_scoreboard;

  mailbox #(fifo_txn) mon2scb_mbx;
  bit [7:0]           model_q [$];       // reference model: the expected FIFO contents
  int unsigned        num_checked;
  int unsigned        num_fail;

  function new(mailbox #(fifo_txn) mon2scb_mbx);
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction

  task run();
    fifo_txn  txn;
    bit [7:0] expected_data;
    forever begin
      mon2scb_mbx.get(txn);
      case (txn.kind)
        FIFO_WRITE: model_q.push_back(txn.data);          // remember what went in
        FIFO_READ : begin
          if (model_q.size() == 0) begin
            num_fail++;
            $error("[%0t] SCB FAIL: DUT produced data but the model is empty", $time);
          end
          else begin
            expected_data = model_q.pop_front();          // the oldest value must come out
            if (txn.rdata !== expected_data) begin
              num_fail++;
              $error("[%0t] SCB FAIL: read %0h, expected %0h",
                     $time, txn.rdata, expected_data);
            end
          end
          num_checked++;
        end
      endcase
    end
  endtask

endclass
```

### How the pieces behave

| Component | FIFO behaviour |
|---|---|
| Monitor | At each clock edge: if it sampled `wr_en` = 1 and `full` = 0, it sends a `FIFO_WRITE` transaction with `din`. If it sampled `rd_en` = 1 and `empty` = 0, it notes a pending read and, at the next edge, sends a `FIFO_READ` transaction with `dout`. Writes when full and reads when empty are not sent, because the DUT ignores them |
| Scoreboard, on a write | `push_back` the data onto the model queue |
| Scoreboard, on a read | `pop_front` the oldest value and compare with what the DUT output |
| Flags | `model_q.size() == 0` should agree with `empty`, and `model_q.size() == DEPTH` with `full`. These can be checked in the scoreboard (if the monitor reports the flags) or by assertions (Module 10) |
| End of test | The number of reads checked equals the number of accepted reads, and the model queue holds exactly the data still inside the DUT |

Simultaneous read and write in the same cycle is the classic FIFO corner case. The monitor sends both transactions for that edge; sending the write first is correct for a FIFO whose simultaneous read returns the previously oldest entry, as long as the model was not empty.

> **How to say it in an interview:** "For a FIFO I would keep the same generator, driver, monitor, scoreboard, environment structure. The transaction has a kind (write or read) and data. The scoreboard's reference model is a SystemVerilog queue: on every write the monitor reports, I `push_back` the data; on every read, I `pop_front` and compare with `dout`. I would also check `full` and `empty` against the queue size, and at the end of the test check that nothing unexpected is left."

## 6.9 The Classic Design Questions, Answered in One Place

| Question | Short answer | Section |
|---|---|---|
| How does the test end? | Generator finishes (`join_any`), then wait until the scoreboard has checked as many transactions as were sent, guarded by a timeout; then `disable fork`, report, `$finish` | 5.1 |
| Why does the monitor create a new object per transaction? | The mailbox stores handles; reusing one object would overwrite transactions still waiting to be checked | 4.1 |
| Why does the scoreboard predict from the monitor's inputs and not the generator's? | To check what the DUT actually received; it keeps the checking path independent of the stimulus path and reusable without it | 4.2 |
| Where is the reference model? | In the scoreboard (`alu_predict`), written from the specification, with no timing | 4.2 |
| How is the one-cycle latency handled? | In the monitor: inputs sampled at edge N are held in a pending transaction and completed with the result sampled at edge N+1 | 4.1 |
| What happens during reset? | `tb_top` drives `rst_n`; the driver drives idle values and waits for release; the monitor ignores edges while reset is active | 3.2, 4.1, 5.4 |
| How is PASS or FAIL decided? | Scoreboard counters; fail if any mismatch, if nothing was checked, or if the drain times out | 4.2, 5.1 |
| How do you add a test? | Extend the test; change knobs, replace the blueprint or replace the generator in `configure()` | 6.6 |
| How does a class reach the pins? | Virtual interface handle passed from `tb_top` through test and environment to driver and monitor | 2.4, 5.4 |
| How do you avoid races between testbench and DUT? | Clocking blocks: sample just before the edge, drive after it; reset changed on the opposite edge | 2.4 |
| Why a mailbox and not a direct method call? | It decouples the two sides, buffers items and blocks the receiver when empty | 3.1 |
| Why a copy of the blueprint? | Each transaction in the mailbox must be a separate object | 3.1 |

### Interview questions

**Q1. Explain the flow of one transaction through your testbench.**
The generator randomizes a transaction and puts a copy in a mailbox. The driver gets it, waits for a clock edge and drives the fields onto the interface through its clocking block, with `valid_in` high for one cycle. The DUT samples the inputs at the next rising edge and produces the result one cycle later. The monitor, sampling through its own clocking block, captures the inputs at the edge the DUT sampled them and the result one edge later, puts both in a new transaction and sends it through a second mailbox to the scoreboard. The scoreboard computes the expected result with its reference model, compares using case equality and records pass or fail.

**Q2. How many objects does one operation create, and who creates them?**
Two that matter: the generator's copy of the blueprint, which carries the stimulus to the driver, and the monitor's object, which carries the observation to the scoreboard. (The scoreboard also makes a temporary copy to hold the expected values.)

**Q3. In the log, the `GEN` line shows `result=x` and the `MON` line shows `result=300`. Why?**
They are different objects. The generator's transaction never receives a result: `result` keeps its default X. The monitor's transaction is built from the pins, including the DUT's result.

**Q4. What exactly happens at the end of the test?**
The generator's `run()` returns, releasing `join_any`. The environment then waits for `scb.num_checked == gen.num_sent`, in parallel with a timeout. When the condition is met, `disable fork` kills the driver, monitor, scoreboard and watchdog threads; the test prints the scoreboard report; and the top module calls `$finish`.

**Q5. You need a test that sends only shift operations. What do you write?**
A transaction class derived from `alu_txn` with a constraint `op inside {ALU_SHL, ALU_SHR}`, and a test derived from `alu_test` whose `configure()` assigns an object of that class to `env.gen.blueprint`. No component changes.

**Q6. Why can the generator randomize a derived transaction through a base-class handle?**
`randomize()` is a built-in virtual method: it solves the constraints of the actual object the handle refers to, including those added by the derived class.

**Q7. The scoreboard reports a mismatch. How do you decide whether the DUT or the testbench is wrong?**
Compare the stimulus lines (`GEN`/`DRV`) with the monitor line to rule out the stimulus path; then compute the correct answer by hand from the specification and see whether the DUT's actual value or the model's expected value matches it.

**Q8. Why is it useful to inject a bug into the DUT deliberately?**
To prove that the testbench can fail. A testbench with a broken scoreboard, a monitor that samples nothing, or a test that ends too early also reports "no errors".

**Q9. How would the scoreboard differ for a FIFO?**
The reference model must hold state. A queue stores the data written; each read pops the front of the queue and compares it with the DUT's output. Flags are checked against the queue size.

**Q10. Two log lines have the same time stamp. Can you rely on their order?**
Only if one causes the other (for example the monitor's `put()` waking the scoreboard). Lines printed by independent threads in the same time step can appear in either order, and a testbench must not depend on that order.

**Q11. If the DUT were changed to a two-cycle latency, what would you change?**
The monitor's pairing logic (hold pending inputs for two edges, most simply with a queue of pending transactions). The driver, generator, scoreboard, environment and tests would not change; the reference model has no notion of latency.

**Q12. What would you add to this testbench next?**
Functional coverage on the monitored transactions (operations, corner operands, crosses), assertions in the interface for the `valid_in`/`valid_out` protocol and X checks, back-to-back transactions without the idle cycle, reset in the middle of a test, and more tests built from constrained transactions.
