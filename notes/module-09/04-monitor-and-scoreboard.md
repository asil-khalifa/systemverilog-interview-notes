# Part 4: The Checking Side: Monitor and Scoreboard

## 4.1 The Monitor

### In plain English

The monitor is the testbench's eyes. It watches the DUT pins on every clock edge, recognises when an operation has taken place, and writes down what it saw as a transaction object: "inputs were 200, 100, ADD, and the result that came out was 300". It then sends that record to the scoreboard. It never drives anything.

### Technical definition

A monitor is a passive class that samples the DUT's interface signals at the correct clock edge through a virtual interface, reassembles pin-level activity into transaction objects according to the protocol, and sends each observed transaction to the scoreboard (and to coverage collectors) through a mailbox. It belongs to the command layer.

### Why a monitor is needed

The scoreboard works with transactions, but the DUT produces signal changes. Something has to translate back. More importantly, the checking path must be based on **what actually happened at the pins**, independent of what the stimulus side intended.

| If the scoreboard used the driver's or generator's transaction as "what the DUT received" | With an independent monitor |
|---|---|
| A driver that drives the wrong operand, or drives one cycle late, goes unnoticed: the scoreboard predicts from the intended values and compares with a result computed from different values, and reports a DUT bug that is not there, or misses one that is | The prediction is made from the values the DUT really sampled |
| A mis-wired port in `tb_top` is blamed on the DUT | The monitor sees the same wires the DUT sees |
| The checker cannot be reused when the ALU sits inside a larger design, because there is no driver there | Monitor and scoreboard are reused unchanged: they only need the signals |
| Protocol errors on the pins (`valid_out` at the wrong time) are never looked at | The monitor checks the protocol on every edge |

### Driver versus monitor

| Aspect | Driver | Monitor |
|---|---|---|
| Direction of conversion | Transaction → signals | Signals → transaction |
| Active or passive | Active: drives DUT inputs | Passive: only samples |
| Which signals | DUT inputs (may sample some outputs for handshaking) | Inputs and outputs |
| Clocking block | `drv_cb` (outputs and inputs) | `mon_cb` (inputs only) |
| Mailbox operation | `get()` from `gen2drv_mbx` | `put()` to `mon2scb_mbx` |
| Creates transaction objects | No | Yes, one new object per observed operation |
| Talks to | Generator (mailbox, `drv_done`) | Scoreboard (mailbox) |
| Activity when the bus is idle | Blocked on the mailbox | Still sampling every edge |
| Present when the block is reused inside a bigger design | No (real logic drives the block) | Yes |
| UVM: present in a passive agent | No | Yes |

### What the monitor has to get right

1. **Sample at the right moment.** It must see the same values the DUT's flip-flops see. Sampling through `mon_cb` (input skew `#1step`) gives the values from just before the clock edge, which is exactly that.
2. **Pair the right input with the right output.** The ALU has a one-cycle latency. The inputs sampled at edge N belong with the result sampled at edge N+1.
3. **Create a new object for each transaction.** Explained below.
4. **Ignore the bus during reset.**
5. **Check the protocol** while it is watching anyway.

### The latency alignment

```text
   edge             N-1          N          N+1         N+2
                     |           |           |           |
   sampled valid_in  0           1           0           1         (values seen by mon_cb
   sampled a, b, op  -          txn1        (old)       txn2        at each edge)
   sampled valid_out 0           0           1           0
   sampled result    -           -          res1         -

   monitor action:              create      complete    create
                                pending     pending     pending
                                = txn1      with res1,  = txn2
                                inputs      send it
```

The monitor keeps one handle, `pending`, for "an operation whose inputs I have seen and whose result I am waiting for". On each edge it does two things, in this order:

1. If there is a pending transaction, this edge must show `valid_out`. Take `result`, send the completed transaction, clear `pending`.
2. If `valid_in` was sampled high at this edge, create a new pending transaction from `a`, `b`, `op`.

The order matters when transactions arrive on consecutive cycles: the edge that carries the result of transaction 1 is also the edge that carries the inputs of transaction 2. Step 1 must finish with the old `pending` before step 2 replaces it.

### The file

```systemverilog file=alu_monitor.sv
class alu_monitor;

  virtual alu_if     vif;
  mailbox #(alu_txn) mon2scb_mbx;
  int unsigned       num_seen;

  function new(virtual alu_if vif, mailbox #(alu_txn) mon2scb_mbx);
    this.vif         = vif;
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction

  task run();
    alu_txn pending;      // inputs sampled at the previous edge, result still to come
    forever begin
      @(vif.mon_cb);

      if (vif.rst_n !== 1'b1) begin
        pending = null;   // nothing observed during reset counts
        continue;
      end

      // 1. Output side: complete the transaction whose inputs were seen one edge ago
      if (pending != null) begin
        if (vif.mon_cb.valid_out === 1'b1) begin
          pending.result = vif.mon_cb.result;
          pending.print("MON");
          mon2scb_mbx.put(pending);
        end
        else
          $error("[%0t] MON: valid_out missing for id=%0d", $time, pending.id);
        pending = null;
      end
      else if (vif.mon_cb.valid_out === 1'b1)
        $error("[%0t] MON: valid_out without a preceding valid_in", $time);

      // 2. Input side: start a new transaction if the DUT sampled one at this edge
      if (vif.mon_cb.valid_in === 1'b1) begin
        if ($isunknown({vif.mon_cb.a, vif.mon_cb.b, vif.mon_cb.op}))
          $error("[%0t] MON: X or Z on the DUT inputs while valid_in is 1", $time);
        pending    = new();
        num_seen++;
        pending.id = num_seen;
        pending.a  = vif.mon_cb.a;
        pending.b  = vif.mon_cb.b;
        pending.op = vif.mon_cb.op;
      end
    end
  endtask

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `virtual alu_if vif;` | Handle to the same interface instance the driver uses. |
| `mailbox #(alu_txn) mon2scb_mbx;` | The channel to the scoreboard. |
| `int unsigned num_seen;` | Counts observed operations; also used as the `id` of observed transactions. Because transactions are observed in the order they were sent, these ids match the generator's. |
| `alu_txn pending;` | A local handle, initially `null`. Class methods have automatic lifetime, so this variable belongs to this call of `run()`. |
| `forever begin @(vif.mon_cb);` | One iteration per rising clock edge, for the whole simulation. When the process resumes, the clocking block has already taken its samples. |
| `if (vif.rst_n !== 1'b1)` | Reset is read directly from the interface (it is asynchronous and not in a clocking block). `!==` makes an X on reset count as "in reset". |
| `pending = null; continue;` | Discard any half-observed operation and skip the rest of this iteration. |
| `if (pending != null)` | An input was sampled at the previous edge, so this edge must carry its result. |
| `vif.mon_cb.valid_out === 1'b1` | The sampled (pre-edge) value of `valid_out`. `===` so that X does not count as valid. |
| `pending.result = vif.mon_cb.result;` | Completes the record. `result` is `logic [8:0]` on both sides, so X bits are kept. |
| `mon2scb_mbx.put(pending);` | Sends the handle to the scoreboard. |
| `$error("... valid_out missing ...")` | Protocol check: the DUT did not answer after one cycle. |
| `pending = null;` | The monitor lets go of the object. The mailbox (and soon the scoreboard) still holds a handle, so the object stays alive. |
| `else if (vif.mon_cb.valid_out === 1'b1)` | Protocol check in the other direction: an answer without a request. |
| `if (vif.mon_cb.valid_in === 1'b1)` | The DUT sampled a transaction at this edge. |
| `$isunknown({...})` | The input fields of `alu_txn` are two-state, so an X on `a` would be stored as 0. Unknown inputs during a valid cycle are a testbench or connection fault; the monitor reports them instead of hiding them. |
| `pending = new();` | **A new object for every observed transaction.** |
| `pending.a = vif.mon_cb.a;` etc. | The sampled input values. |

### Why the monitor creates a new object for every sample

This is asked in almost every interview. A mailbox holds handles. If the monitor created one object before the loop and reused it, every entry in the mailbox would be a handle to that same object:

```text
   WRONG                                         RIGHT
   t = new();                                    forever begin
   forever begin                                   ...
     ...                                           t = new();
     t.a = ...; t.result = ...;                    t.a = ...; t.result = ...;
     mbx.put(t);                                   mbx.put(t);
   end                                           end

   mailbox: [h] [h] [h]                          mailbox: [h1] [h2] [h3]
             \   |   /                                      |    |    |
              v  v  v                                       v    v    v
            +---------+                                   +---+ +---+ +---+
            | 1 object|   <- holds only the               | 1 | | 2 | | 3 |
            +---------+      LATEST sample                +---+ +---+ +---+
```

With the wrong version, the scoreboard may be processing transaction 1 while the monitor overwrites the same object with transaction 2. The scoreboard would then read operands from one operation and a result from another. The bug depends on timing, so it appears and disappears as the testbench changes, which makes it very hard to find. The rule: **`new()` inside the loop, once per transaction put into a mailbox.**

### Step-by-step execution for the first transaction

Same timing as in Section 3.2 (driver drives at 25, the signals change at 26):

| Edge at | Sampled values (just before the edge) | Monitor action |
|---|---|---|
| 5, 15 | `rst_n` = 0 | In reset: skip |
| 25 | `valid_in` = 0, `valid_out` = 0 | Nothing pending, nothing valid: no action |
| 35 | `valid_in` = 1, operands of transaction 1, `valid_out` = 0 | No pending. `valid_in` is 1: create `pending` with `a`, `b`, `op`, `id` = 1 |
| 45 | `valid_in` = 0, `valid_out` = 1, `result` of transaction 1 | Pending exists and `valid_out` is 1: store `result`, print `MON`, `put()`. No new input |
| 55 | `valid_in` = 1, operands of transaction 2, `valid_out` = 0 | Create `pending` for transaction 2 |
| 65 | `valid_out` = 1, `result` of transaction 2 | Complete and send transaction 2 |

Notice edge 35: the DUT and the monitor sample the same inputs at the same edge. And edge 45: the result that the DUT registered at 35 is visible to the monitor one edge later.

> **Common mistake:** Sampling inputs and result at the same edge and putting them into one transaction. The result on the pins at edge N belongs to the inputs of edge N-1 (or is a stale value). The scoreboard then reports mismatches on almost every transaction even though the DUT is correct. A scoreboard failure pattern of "the actual result is the expected result of the previous transaction" points to this alignment mistake.

> **Common mistake:** Writing a monitor that only looks at the DUT outputs and takes the inputs from the driver's transaction. That is a half-monitor: it cannot detect driver or connection faults.

> **Verification application:** In a full environment the monitor's output goes to more than one place: the scoreboard, a functional coverage collector, and sometimes a protocol checker or a logger. In plain SystemVerilog that means one mailbox per consumer (the monitor puts a copy, or the same handle if consumers do not modify it, into each). In UVM the monitor has an *analysis port*, which broadcasts each transaction to any number of subscribers.

### Interview questions

**Q1. What is a monitor?**
A passive component that samples the DUT signals through a virtual interface at the correct clock edge, converts the pin activity into transaction objects, and sends them to the scoreboard (and coverage) through a mailbox.

**Q2. What is the difference between a driver and a monitor?**
The driver is active: it converts transactions into signal activity on the DUT inputs. The monitor is passive: it converts signal activity on inputs and outputs back into transactions and never drives a signal.

**Q3. Why does the monitor sample the DUT inputs as well? The driver already knows them.**
So that the checking path is independent of the stimulus path. The scoreboard then predicts from what the DUT actually received, which catches driver bugs, connection errors and timing errors, and lets monitor and scoreboard be reused where no driver exists.

**Q4. At which point in time does the monitor sample?**
At the clocking event of `mon_cb`, with input skew `#1step`: it gets the values the signals had immediately before the rising clock edge, which are the values the DUT's flip-flops capture at that edge.

**Q5. Why must the monitor create a new transaction object each time?**
Because the mailbox stores handles. Reusing one object means every handle in the mailbox refers to the same object, which the monitor keeps overwriting, so the scoreboard sees corrupted or duplicated data.

**Q6. The DUT has a latency of one cycle. How does the monitor deal with it?**
It keeps the inputs it sampled at edge N in a pending transaction, and at edge N+1, when `valid_out` is sampled high, it adds the result and sends the completed transaction. For a longer or variable latency the pending transactions would be kept in a queue.

**Q7. Can a monitor drive signals?**
No. It is passive by definition. In this project its clocking block declares only inputs, so an attempt to drive would not compile.

**Q8. What checks can be placed in a monitor?**
Protocol checks that depend only on the signals: here, that `valid_out` appears exactly one cycle after `valid_in` and never otherwise, and that inputs are not X when valid. Data correctness is the scoreboard's job.

**Q9. What happens if the monitor is slower than the DUT, or the scoreboard is slower than the monitor?**
The monitor must never block for longer than a clock cycle, or it will miss edges; that is why it only does zero-time work and puts into an unbounded mailbox, where `put()` never blocks. The scoreboard may lag; the mailbox buffers the transactions.

**Q10. How would the monitor change for a DUT with a variable latency?**
Inputs would be pushed into a queue when `valid_in` is seen, and when `valid_out` is seen the oldest entry would be popped, completed and sent (assuming results come out in order). Alternatively the monitor sends input transactions and output transactions separately and the scoreboard does the matching.

## 4.2 The Scoreboard

### In plain English

The scoreboard is the judge. For each operation the monitor reports, it works out what the result *should* have been, compares that with what the DUT actually produced, and records PASS or FAIL. At the end of the test it reports the totals.

### Technical definition

A scoreboard is a class that receives observed transactions from the monitor, obtains the expected response from a **reference model** (also called a predictor or golden model), compares expected with actual, reports each mismatch, and keeps statistics for the end-of-test verdict. It belongs to the functional layer. It is what makes the testbench **self-checking**.

### Why it is needed

A testbench without a scoreboard produces waveforms and a log that a human has to inspect. That is impossible for thousands of random transactions and for the hundreds of tests in a nightly regression. With a scoreboard, every test ends in one machine-readable line: passed or failed.

Random stimulus *requires* a scoreboard. In a directed test the engineer knows the inputs in advance and can write the expected output next to them. With random inputs nobody knows the values in advance, so the expected value has to be computed at run time.

### The parts of a scoreboard

```text
                           mon2scb_mbx
     monitor  -------------------------------->  observed transaction
                                                 (a, b, op, result)
                                                      |
                              +-----------------------+----------------------+
                              |                                              |
                              v                                              v
                    +-------------------+                           actual = result
                    |  reference model  |
                    |  alu_predict()    |
                    |  uses a, b, op    |
                    +-------------------+
                              |
                              v
                     expected result  ----------->   compare (===)  <--------+
                                                          |
                                             +------------+------------+
                                             v                         v
                                           PASS                      FAIL
                                         num_pass++                num_fail++
                                                               message with all values
```

| Part | In this project |
|---|---|
| Input channel | `mon2scb_mbx` |
| Reference model | `alu_predict()` |
| Comparator | `alu_txn::compare()`, which uses `===` on the result |
| Reporting | One line per transaction, `$error` on mismatch |
| Statistics | `num_checked`, `num_pass`, `num_fail`, `report()` |

### The reference model

The reference model computes the expected result from the inputs. Three rules:

1. **It is written from the specification, not from the RTL.** If you copy the DUT's code into the model, a bug in that code is in both, and the comparison passes. The model should be an independent implementation by (ideally) a different person, written in the most obviously-correct way.
2. **It works at a higher level of abstraction.** No clocks, no pipeline registers: just "given these inputs, the output is this". The ALU's one-cycle latency does not appear in the model at all; the monitor has already dealt with it.
3. **It must model widths and signedness exactly as the specification states them** (Module 1, Sections 2.6 and 4.4). This is where most reference-model bugs are.

For a simple DUT the model is a function inside the scoreboard, as here. For a complex DUT it is a separate class, or a C/C++ model called through DPI (Module 11).

### Where do the model's inputs come from?

| Source of the model's inputs | Used here? | Consequence |
|---|---|---|
| The monitor: inputs sampled from the pins | Yes | The check is "given what the DUT received, was its output right?". Independent of generator and driver |
| The generator or driver, through a second mailbox | No | The check becomes "given what we meant to send...". Any fault between generator and pins corrupts the check. It also couples the scoreboard to the stimulus components, so it cannot be reused without them |

Some scoreboards use both: expected transactions from the stimulus side and observed transactions from the monitor, compared field by field. That additionally verifies the driver, and it is the usual structure when the DUT transforms or reorders data (for example a router). It needs a matching scheme (in-order queues, or lookup by id). For a DUT like the ALU, where each output depends only on its own inputs, predicting from the monitored inputs is simpler and stronger.

### The file

```systemverilog file=alu_scoreboard.sv
class alu_scoreboard;

  mailbox #(alu_txn) mon2scb_mbx;
  int unsigned       num_checked;
  int unsigned       num_pass;
  int unsigned       num_fail;

  function new(mailbox #(alu_txn) mon2scb_mbx);
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction

  // Reference model: the expected 9-bit result, written from the specification
  function logic [8:0] alu_predict(alu_txn t);
    logic [8:0] r;
    case (t.op)
      ALU_ADD: r = t.a + t.b;
      ALU_SUB: r = t.a - t.b;
      ALU_AND: r = t.a & t.b;
      ALU_OR : r = t.a | t.b;
      ALU_XOR: r = t.a ^ t.b;
      ALU_NOT: r = {1'b0, ~t.a};
      ALU_SHL: r = t.a << 1;
      ALU_SHR: r = t.a >> 1;
      default: r = 'x;
    endcase
    return r;
  endfunction

  function void check_txn(alu_txn actual);
    alu_txn expected;
    expected        = actual.copy();
    expected.result = alu_predict(actual);
    if (actual.compare(expected)) begin
      num_pass++;
      $display("[%0t] SCB PASS id=%0d op=%s a=%0d b=%0d result=%0d",
               $time, actual.id, actual.op.name(), actual.a, actual.b, actual.result);
    end
    else begin
      num_fail++;
      $error("[%0t] SCB FAIL id=%0d op=%s a=%0d b=%0d actual=%0d expected=%0d",
             $time, actual.id, actual.op.name(), actual.a, actual.b,
             actual.result, expected.result);
    end
    num_checked++;
  endfunction

  task run();
    alu_txn txn;
    forever begin
      mon2scb_mbx.get(txn);
      check_txn(txn);
    end
  endtask

  function void report();
    $display("------------------------------------------------------------");
    $display("SCOREBOARD SUMMARY: checked=%0d pass=%0d fail=%0d",
             num_checked, num_pass, num_fail);
    if (num_checked == 0)   $display("TEST FAILED: nothing was checked");
    else if (num_fail == 0) $display("TEST PASSED");
    else                    $display("TEST FAILED");
    $display("------------------------------------------------------------");
  endfunction

endclass
```

### Line by line

| Code | Explanation |
|---|---|
| `mailbox #(alu_txn) mon2scb_mbx;` | The same mailbox the monitor puts into. |
| `num_checked`, `num_pass`, `num_fail` | Statistics. `num_checked` is also what the environment watches to decide that the test is over. |
| `function logic [8:0] alu_predict(alu_txn t);` | A function: the model takes no simulation time. It returns a 9-bit four-state value. |
| `logic [8:0] r;` | The result variable is 9 bits wide. Every `r = ...` assignment below is therefore evaluated in a 9-bit context: the 8-bit operands are zero-extended to 9 bits **before** the operation (Module 1, Section 4.4). |
| `ALU_ADD: r = t.a + t.b;` | 9-bit addition; bit 8 is the carry. |
| `ALU_SUB: r = t.a - t.b;` | 9-bit subtraction; if `b` is larger than `a` the result wraps and bit 8 is 1 (the borrow). |
| `ALU_AND: r = t.a & t.b;` | Both operands zero-extended; bit 8 is `0 & 0` = 0. The same for OR and XOR. |
| `ALU_NOT: r = {1'b0, ~t.a};` | **Not** `r = ~t.a;`. In a 9-bit context `t.a` would first be extended to `0_aaaaaaaa` and then inverted, giving a 1 in bit 8. The concatenation forces the inversion to be done on 8 bits. |
| `ALU_SHL: r = t.a << 1;` | The left operand of a shift takes the context width, so `a` is 9 bits wide before shifting and its old bit 7 lands in bit 8. |
| `ALU_SHR: r = t.a >> 1;` | Logical shift right; bit 0 is lost, zeros enter from the left. |
| `default: r = 'x;` | An opcode that is not one of the eight names (possible only if `op` holds X). The model answers "unknown", and the comparison then fails unless the DUT also outputs X. |
| `function void check_txn(alu_txn actual);` | Checks one observed transaction. A function, so it cannot block. |
| `expected = actual.copy();` | A separate object for the expected values, with the same inputs and id. A copy, not `expected = actual;`, which would make both handles point to one object. |
| `expected.result = alu_predict(actual);` | Only the result differs between expected and actual. |
| `if (actual.compare(expected))` | Field-by-field comparison, `===` on the result. |
| `$display("... SCB PASS ...")` | One line per passing transaction. In a long regression this is normally switched off or reduced; here it shows the flow. |
| `$error("... SCB FAIL ... actual=%0d expected=%0d")` | A mismatch message must contain everything needed to reproduce the case: time, id, operation, operands, actual and expected. `$error` raises the simulator's error count, which regression scripts read. |
| `num_checked++;` | Incremented last, after the message, so that a process waiting on this counter sees a fully processed transaction. |
| `task run();` ... `forever` | Blocks on the mailbox, checks, repeats. |
| `function void report();` | Called by the test after the run. |
| `if (num_checked == 0)` | A test in which nothing was checked must not be reported as passed. |

The model above is deliberately written differently from the DUT: `<<` and `>>` instead of concatenations, plain `&` instead of `{1'b0, a & b}`. Two independent descriptions that agree are evidence that both are right.

### Why expected is a copy

```text
   WRONG:  expected = actual;
           expected.result = alu_predict(actual);

      actual ----+
                 +--> [ a b op result=300 ]     one object; the DUT's result (44) has been
      expected --+                              overwritten by the prediction; compare()
                                                compares the object with itself: always PASS

   RIGHT:  expected = actual.copy();
           expected.result = alu_predict(actual);

      actual ----> [ a b op result=44  ]
      expected --> [ a b op result=300 ]        44 !== 300: FAIL reported
```

The first version turns the scoreboard into a checker that can never fail, and it does so silently. The concept behind it is handle assignment versus object copy (Module 4).

### Handling multiple transactions

- The scoreboard processes transactions strictly in the order the monitor sent them; the mailbox is a FIFO.
- It may fall behind the monitor without losing anything, because the mailbox is unbounded.
- Each transaction arrives complete (inputs and result together), so no matching between separate input and output streams is needed here.
- When inputs and outputs arrive as **separate** streams (for example in a FIFO or router testbench), the scoreboard stores expected items in a queue, or in an associative array indexed by an id or address, and pops the matching one when an output arrives. Section 6.8 shows the queue version.

| DUT behaviour | Scoreboard storage for expected data |
|---|---|
| One output per input, fixed latency (this ALU) | None: the monitor delivers complete transactions |
| One output per input, in order, variable latency (FIFO, pipeline with stalls) | Queue: `push_back` on input, `pop_front` on output |
| Outputs can come out of order (router, cache, out-of-order bus) | Associative array indexed by id, tag or address |
| Outputs may be dropped legally | As above, plus an end-of-test rule for leftover entries |

### End-of-test checks

A scoreboard should fail the test not only on mismatches but also when the bookkeeping does not add up:

| Check | Why |
|---|---|
| Number checked is greater than 0 | A test that checks nothing proves nothing, yet "0 failures" looks like a pass |
| Number checked equals number sent | A lost transaction is a bug even if every received one was correct |
| No expected items left in the queue (when a queue is used) | The DUT failed to produce some outputs |

In this project the first is in `report()`, and the second is enforced by the environment, which waits for the count to match and reports a timeout if it never does (Section 5.1).

> **Interview trap:** "My scoreboard reports no errors, so the DUT is correct." Not necessarily. Ask: how many transactions did it check? Does it use `!==`? Is the model independent of the RTL? Does the monitor sample the real pins? Does the test end only after everything is checked? A silent scoreboard is the most dangerous testbench bug, because it looks like success.

> **Common mistake:** Printing only "MISMATCH" on failure. Without the operands, operation, actual and expected values, the engineer debugging a nightly regression failure has to rerun the simulation just to find out what went wrong.

> **Common mistake:** Putting timing into the scoreboard, for example waiting a clock cycle "for the result to be ready". The scoreboard has no virtual interface and should not need one. Timing is the monitor's business.

### Interview questions

**Q1. What is a scoreboard?**
The component that checks DUT correctness automatically. It receives observed transactions from the monitor, computes the expected result with a reference model, compares the two, and reports pass or fail with statistics.

**Q2. What is a reference model?**
An independent, higher-level implementation of the DUT's intended function, written from the specification, which computes the expected outputs for given inputs. It contains no timing.

**Q3. Where does the scoreboard get the inputs for its prediction, and why?**
From the monitor, that is, from what was actually sampled at the DUT pins. This makes the check independent of the generator and driver, catches stimulus-path faults, and allows reuse of monitor and scoreboard at higher levels.

**Q4. Why must the reference model not be copied from the RTL?**
A bug in the RTL would be reproduced in the model, both would give the same wrong answer, and the scoreboard would pass. Independence is what gives the comparison its value.

**Q5. Which comparison operator does a scoreboard use?**
Case equality, `===` / `!==`, so that X or Z in the DUT output is treated as a mismatch.

**Q6. What information should a scoreboard error message contain?**
Simulation time, transaction id, the stimulus (operation and operands), the actual result and the expected result.

**Q7. How does the scoreboard handle a DUT with variable latency?**
It stores expected results in a queue when inputs are observed and pops the front entry when an output is observed, comparing the two. Order is preserved by the queue.

**Q8. How does the scoreboard handle out-of-order outputs?**
It stores expected items in an associative array indexed by something that identifies the transaction (id, tag, address) and looks up the matching entry when an output arrives.

**Q9. What checks are made at the end of a test?**
That at least one transaction was checked, that the number checked equals the number sent, that no expected items remain unmatched, and that the failure count is zero.

**Q10. What is the difference between a monitor and a scoreboard?**
The monitor observes: it converts pins into transactions and knows the protocol but has no opinion about data correctness. The scoreboard judges: it knows the intended function but nothing about pins or timing.

**Q11. Why is `expected = actual.copy()` used instead of `expected = actual`?**
Handle assignment would make both names refer to the same object. Writing the predicted result into `expected` would overwrite the DUT's result in `actual`, and the comparison would always pass.

**Q12. Can the scoreboard contain the functional coverage?**
It can sample coverage, since it sees every observed transaction, but it is cleaner to put coverage in a separate component fed by the monitor, so that checking and measuring are independent.
