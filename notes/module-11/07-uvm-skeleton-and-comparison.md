## 5.8 A Minimal UVM Skeleton for the ALU

The code below is a complete but minimal UVM testbench for the course DUT. Read it side by side with the M9 testbench. **It cannot run by itself:** it needs a simulator with the UVM library enabled, and the files `alu_pkg.sv`, `alu.sv` (M1) and `alu_if.sv` (M8, summarised in Section 2.4) compiled before it. Treat it as an annotated reading exercise.

```systemverilog file=alu_uvm_skeleton.sv
// Requires: the UVM library, alu_pkg.sv, alu.sv and alu_if.sv.

package alu_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_pkg::*;

  // ------------------------------------------------------------------ transaction
  class alu_seq_item extends uvm_sequence_item;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;

    `uvm_object_utils(alu_seq_item)

    function new(string name = "alu_seq_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("op=%s a=%0d b=%0d result=%0d", op.name(), a, b, result);
    endfunction
  endclass

  // ------------------------------------------------------------------ sequence
  class alu_sequence extends uvm_sequence #(alu_seq_item);
    `uvm_object_utils(alu_sequence)

    int unsigned num_items = 20;

    function new(string name = "alu_sequence");
      super.new(name);
    endfunction

    task body();
      repeat (num_items) begin
        req = alu_seq_item::type_id::create("req");
        start_item(req);                      // wait until the driver asks for an item
        if (!req.randomize()) `uvm_error("SEQ", "randomization failed")
        finish_item(req);                     // hand over; returns after item_done()
      end
    endtask
  endclass

  // ------------------------------------------------------------------ sequencer
  typedef uvm_sequencer #(alu_seq_item) alu_sequencer;

  // ------------------------------------------------------------------ driver
  class alu_uvm_driver extends uvm_driver #(alu_seq_item);
    `uvm_component_utils(alu_uvm_driver)

    virtual alu_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set for the driver")
    endfunction

    task run_phase(uvm_phase phase);
      vif.drv_cb.valid_in <= 1'b0;
      wait (vif.rst_n === 1'b1);
      forever begin
        seq_item_port.get_next_item(req);     // blocks until a sequence provides an item
        @(vif.drv_cb);
        vif.drv_cb.a        <= req.a;
        vif.drv_cb.b        <= req.b;
        vif.drv_cb.op       <= req.op;
        vif.drv_cb.valid_in <= 1'b1;
        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b0;
        seq_item_port.item_done();            // tell the sequence the item was driven
      end
    endtask
  endclass

  // ------------------------------------------------------------------ monitor
  class alu_uvm_monitor extends uvm_monitor;
    `uvm_component_utils(alu_uvm_monitor)

    virtual alu_if                    vif;
    uvm_analysis_port #(alu_seq_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set for the monitor")
    endfunction

    task run_phase(uvm_phase phase);
      alu_seq_item item;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid_in === 1'b1) begin
          item    = alu_seq_item::type_id::create("item");
          item.a  = vif.mon_cb.a;
          item.b  = vif.mon_cb.b;
          item.op = vif.mon_cb.op;
          @(vif.mon_cb);                      // the result is registered: one cycle later
          item.result = vif.mon_cb.result;
          ap.write(item);                     // broadcast to all subscribers
        end
      end
    endtask
  endclass

  // ------------------------------------------------------------------ agent
  class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)

    alu_sequencer   sqr;
    alu_uvm_driver  drv;
    alu_uvm_monitor mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = alu_uvm_monitor::type_id::create("mon", this);
      if (get_is_active() == UVM_ACTIVE) begin
        sqr = alu_sequencer::type_id::create("sqr", this);
        drv = alu_uvm_driver::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (get_is_active() == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ------------------------------------------------------------------ scoreboard
  class alu_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_uvm_scoreboard)

    uvm_analysis_imp #(alu_seq_item, alu_uvm_scoreboard) item_export;
    int unsigned n_pass, n_fail;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      item_export = new("item_export", this);
    endfunction

    // Called by the monitor's ap.write(item)
    function void write(alu_seq_item item);
      logic [8:0] exp;
      case (item.op)
        ALU_ADD: exp = item.a + item.b;
        ALU_SUB: exp = item.a - item.b;
        ALU_AND: exp = {1'b0, item.a & item.b};
        ALU_OR : exp = {1'b0, item.a | item.b};
        ALU_XOR: exp = {1'b0, item.a ^ item.b};
        ALU_NOT: exp = {1'b0, ~item.a};
        ALU_SHL: exp = {item.a, 1'b0};
        ALU_SHR: exp = {2'b00, item.a[7:1]};
      endcase
      if (item.result !== exp) begin
        n_fail++;
        `uvm_error("SCB", $sformatf("MISMATCH %s expected=%0d", item.convert2string(), exp))
      end
      else n_pass++;
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf("pass=%0d fail=%0d", n_pass, n_fail), UVM_LOW)
    endfunction
  endclass

  // ------------------------------------------------------------------ environment
  class alu_uvm_env extends uvm_env;
    `uvm_component_utils(alu_uvm_env)

    alu_agent          agent;
    alu_uvm_scoreboard scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = alu_agent::type_id::create("agent", this);
      scb   = alu_uvm_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agent.mon.ap.connect(scb.item_export);
    endfunction
  endclass

  // ------------------------------------------------------------------ test
  class alu_base_test extends uvm_test;
    `uvm_component_utils(alu_base_test)

    alu_uvm_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = alu_uvm_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      alu_sequence seq;
      seq = alu_sequence::type_id::create("seq");
      phase.raise_objection(this);            // the test has work to do
      seq.start(env.agent.sqr);               // blocks until the sequence has finished
      #100;                                   // let the last result reach the scoreboard
      phase.drop_objection(this);             // the run phase may now end
    endtask
  endclass

endpackage : alu_uvm_pkg

// -------------------------------------------------------------------- top module
module tb_top_uvm;
  import uvm_pkg::*;
  import alu_uvm_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if alu_vif (clk);

  alu dut (
    .clk       (clk),
    .rst_n     (alu_vif.rst_n),
    .valid_in  (alu_vif.valid_in),
    .a         (alu_vif.a),
    .b         (alu_vif.b),
    .op        (alu_vif.op),
    .valid_out (alu_vif.valid_out),
    .result    (alu_vif.result)
  );

  initial begin
    alu_vif.rst_n = 1'b0;
    repeat (2) @(posedge clk);
    alu_vif.rst_n = 1'b1;
  end

  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "*", "vif", alu_vif);
    run_test("alu_base_test");
  end
endmodule
```

### Reading guide

| Element in the skeleton | SystemVerilog feature at work | Where you learned it |
|---|---|---|
| `class alu_seq_item extends uvm_sequence_item;` | Inheritance | M4 |
| `rand bit [7:0] a, b; rand alu_op_e op;` | Random variables, enum | M5, M1 |
| `` `uvm_object_utils(alu_seq_item) `` | A macro that registers the class with the factory and adds the nested `type_id` type | Section 5.5 |
| `function new(string name = "alu_seq_item"); super.new(name);` | Constructor with a default argument, call to the base constructor | M4, M3 |
| `class alu_sequence extends uvm_sequence #(alu_seq_item);` | Extending a specialisation of a parameterized class | Section 2.1 |
| `req = alu_seq_item::type_id::create("req");` | Scope resolution twice, static method; `req` is a handle inherited from the base class | Section 1.3 |
| `start_item(req); ... finish_item(req);` | Blocking tasks that perform the handshake with the driver | M7 (blocking communication) |
| `typedef uvm_sequencer #(alu_seq_item) alu_sequencer;` | `typedef` of a specialisation | Section 2.1 |
| `function new(string name, uvm_component parent);` | The component constructor signature | Section 5.3 |
| `function void build_phase(uvm_phase phase); super.build_phase(phase);` | Overriding a virtual method and calling the base version | M4 |
| `uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif)` | Static method of a parameterized class; virtual interface | Sections 2.1, 2.3 |
| `task run_phase(uvm_phase phase);` | A virtual task, forked by the library for every component | M7 |
| `vif.drv_cb.a <= req.a; @(vif.drv_cb);` | Clocking block drive and synchronisation, unchanged from M8/M9 | M8 |
| `seq_item_port.get_next_item(req); ... item_done();` | TLM replacing `gen2drv_mbx.get()` and the `drv_done` event | Section 5.7 |
| `uvm_analysis_port #(alu_seq_item) ap; ap.write(item);` | Parameterized class; broadcast replacing `mon2scb_mbx.put()` | Section 5.7 |
| `get_is_active() == UVM_ACTIVE` | A component property deciding whether the agent drives or only observes | Section 5.7 |
| `drv.seq_item_port.connect(sqr.seq_item_export);` | Connecting two components in `connect_phase` | Section 5.4 |
| `function void write(alu_seq_item item);` in the scoreboard | The function that the analysis connection calls; the reference model is the same `case` as in M9 | M9 |
| `item.result !== exp` | Case inequality so that X is detected | M1 |
| `phase.raise_objection(this); ... phase.drop_objection(this);` | End-of-test control | Section 5.7 |
| `seq.start(env.agent.sqr);` | Runs the sequence's `body()` on the given sequencer | Section 5.7 |
| `run_test("alu_base_test");` | The library creates the test by name through the factory and starts the phases | Sections 5.4, 5.5 |

The monitor in this skeleton relies on the driver leaving one idle cycle between transactions. A production monitor handles back-to-back transactions with a small pipeline; that refinement is the same in UVM and in plain SystemVerilog.

## 5.9 SystemVerilog versus UVM

| Aspect | SystemVerilog | UVM |
|---|---|---|
| What it is | A language (IEEE 1800) | A methodology and class library (IEEE 1800.2) written in that language |
| Provides | Data types, classes, randomization, coverage, assertions, interfaces, IPC | Base classes, phases, factory, configuration database, sequences, TLM, reporting, register layer |
| Testbench structure | Whatever the engineer designs (M9 is one design) | Prescribed: test, environment, agents, sequencer, driver, monitor, scoreboard |
| Component creation | `new()` | Factory `type_id::create()` |
| Component communication | Mailboxes, events, semaphores | TLM ports, exports, analysis ports, FIFOs |
| Stimulus | Generator class or procedural code | Sequences running on sequencers |
| Start-up and ordering | Coded by hand with `fork` | Automatic phases |
| End of test | Events, counters, `$finish` | Objections |
| Passing the virtual interface | Constructor or direct assignment | `uvm_config_db` |
| Messaging | `$display`, `$error`, `$fatal` | `` `uvm_info ``, `` `uvm_warning ``, `` `uvm_error ``, `` `uvm_fatal `` with verbosity and counts |
| Changing behaviour per test | Edit or extend the environment | Factory overrides, configuration, different sequences |
| Reuse between projects | Depends on private conventions | High, because conventions are standard |
| Learning effort | The language itself | The language first, then the library |
| Best suited to | Learning, small blocks, quick directed checks | Any testbench that must be maintained, shared or scaled |

> **Key point:** UVM does not replace SystemVerilog knowledge; it assumes it. Almost every UVM debugging session ends at a SystemVerilog concept: a null handle, a `$cast` that failed, a type-parameter mismatch, a blocking call that never returns, a race at a clock edge, a constraint conflict. That is why interviews for junior verification roles concentrate on SystemVerilog.

> **Common mistake:** Memorising UVM class names without being able to say what each one does in plain terms. An interviewer who hears "sequencer" will ask "what would you use if UVM did not exist?" The answer is "a mailbox between a generator and a driver", and Module 9 is where you built it.

### Interview questions

**Q1. What is the difference between SystemVerilog and UVM?**
SystemVerilog is the language. UVM is a methodology and a class library written in SystemVerilog that standardises how a testbench is structured, built, connected, run and reported.

**Q2. Can you build a testbench without UVM?**
Yes. A layered class-based testbench with a generator, driver, monitor, scoreboard and environment communicating through mailboxes does the same job. UVM adds standardisation, reuse, the factory, configuration, sequences and phasing.

**Q3. What does UVM give you that mailboxes and `fork`...`join` do not?**
A common architecture that makes components interoperable; automatic phasing; replacement of classes from the test through the factory; hierarchical configuration; stimulus as reusable sequences; one-to-many analysis connections; a standard end-of-test mechanism; and uniform reporting.

**Q4. Name three UVM mechanisms and the SystemVerilog feature behind each.**
The factory (static methods, inheritance, polymorphism and `$cast`); `uvm_config_db` (a parameterized class with static methods); phases (virtual methods called by the library on every component, with `run_phase` tasks forked as parallel processes).
