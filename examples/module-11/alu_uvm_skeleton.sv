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
