package alu_pkg;
  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;
endpackage

module alu
  import alu_pkg::*;
(
  input  logic       clk, rst_n, valid_in,
  input  logic [7:0] a, b,
  input  alu_op_e    op,
  output logic       valid_out,
  output logic [8:0] result
);
  logic [8:0] result_nxt;

  always_comb begin
    result_nxt = '0;
    case (op)
      ALU_ADD: result_nxt = a + b;
      ALU_SUB: result_nxt = a - b;
      ALU_AND: result_nxt = {1'b0, a & b};
      ALU_OR : result_nxt = {1'b0, a | b};
      ALU_XOR: result_nxt = {1'b0, a ^ b};
      ALU_NOT: result_nxt = {1'b0, ~a};
      ALU_SHL: result_nxt = {a, 1'b0};
      ALU_SHR: result_nxt = {2'b00, a[7:1]};
      default: result_nxt = 'x;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      valid_out <= 1'b0;
      result    <= '0;
    end
    else begin
      valid_out <= valid_in;
      if (valid_in) result <= result_nxt;
    end
endmodule

interface alu_if (input logic clk);
  import alu_pkg::*;
  logic       rst_n, valid_in, valid_out;
  logic [7:0] a, b;
  alu_op_e    op;
  logic [8:0] result;

  clocking drv_cb @(posedge clk);
    output valid_in, a, b, op;
  endclocking

  clocking mon_cb @(posedge clk);
    input valid_in, a, b, op, valid_out, result;
  endclocking
endinterface

package alu_tb_pkg;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;
  endclass

  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    int unsigned       num_txn;

    function new(mailbox #(alu_txn) mbx, int unsigned num_txn);
      this.gen2drv_mbx = mbx;
      this.num_txn     = num_txn;
    endfunction

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();                         // one object per transaction
        txn.id = i;
        if (!txn.randomize()) $fatal(1, "randomize failed");
        gen2drv_mbx.put(txn);
      end
    endtask
  endclass

  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    virtual alu_if     vif;

    function new(mailbox #(alu_txn) mbx, virtual alu_if vif);
      this.gen2drv_mbx = mbx;
      this.vif         = vif;
    endfunction

    task run();
      alu_txn txn;
      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;              // idle value during reset
      wait (vif.rst_n === 1'b1);
      forever begin
        gen2drv_mbx.get(txn);
        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b1;
        vif.drv_cb.a        <= txn.a;
        vif.drv_cb.b        <= txn.b;
        vif.drv_cb.op       <= txn.op;
        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b0;            // one idle cycle between transactions
      end
    endtask
  endclass

  class alu_monitor;
    mailbox #(alu_txn) mon2scb_mbx;
    virtual alu_if     vif;

    function new(mailbox #(alu_txn) mbx, virtual alu_if vif);
      this.mon2scb_mbx = mbx;
      this.vif         = vif;
    endfunction

    task run();
      alu_txn txn;                              // inputs seen, result still to come
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid_out === 1'b1 && txn != null) begin
          txn.result = vif.mon_cb.result;       // result of the inputs captured earlier
          mon2scb_mbx.put(txn);
          txn = null;
        end
        if (vif.mon_cb.valid_in === 1'b1) begin
          txn    = new();
          txn.a  = vif.mon_cb.a;
          txn.b  = vif.mon_cb.b;
          txn.op = vif.mon_cb.op;
        end
      end
    endtask
  endclass

  class alu_scoreboard;
    mailbox #(alu_txn) mon2scb_mbx;
    int unsigned       pass_cnt, fail_cnt;

    function new(mailbox #(alu_txn) mbx);
      this.mon2scb_mbx = mbx;
    endfunction

    function logic [8:0] predict(bit [7:0] a, bit [7:0] b, alu_op_e op);
      logic [8:0] r;
      case (op)
        ALU_ADD: r = a + b;
        ALU_SUB: r = a - b;
        ALU_AND: r = {1'b0, a & b};
        ALU_OR : r = {1'b0, a | b};
        ALU_XOR: r = {1'b0, a ^ b};
        ALU_NOT: r = {1'b0, ~a};
        ALU_SHL: r = {a, 1'b0};
        ALU_SHR: r = {2'b00, a[7:1]};
        default: r = 'x;
      endcase
      return r;
    endfunction

    task run();
      alu_txn     txn;
      logic [8:0] expected;
      forever begin
        mon2scb_mbx.get(txn);
        expected = predict(txn.a, txn.b, txn.op);
        if (txn.result !== expected) begin
          fail_cnt++;
          $error("a=%0d b=%0d op=%s: result=%0d expected=%0d",
                 txn.a, txn.b, txn.op.name(), txn.result, expected);
        end
        else pass_cnt++;
      end
    endtask

    function void report(int unsigned sent);
      $display("scoreboard: sent=%0d checked=%0d passed=%0d failed=%0d",
               sent, pass_cnt + fail_cnt, pass_cnt, fail_cnt);
      if (fail_cnt == 0 && pass_cnt == sent) $display("TEST PASSED");
      else                                   $display("TEST FAILED");
    endfunction
  endclass

  class alu_env;
    alu_generator      gen;
    alu_driver         drv;
    alu_monitor        mon;
    alu_scoreboard     scb;
    mailbox #(alu_txn) gen2drv_mbx, mon2scb_mbx;
    int unsigned       num_txn;

    function new(virtual alu_if vif, int unsigned num_txn);
      this.num_txn = num_txn;
      gen2drv_mbx  = new();
      mon2scb_mbx  = new();
      gen = new(gen2drv_mbx, num_txn);
      drv = new(gen2drv_mbx, vif);
      mon = new(mon2scb_mbx, vif);
      scb = new(mon2scb_mbx);
    endfunction

    task run();
      fork
        gen.run();
        drv.run();
        mon.run();
        scb.run();
      join_none
      fork
        wait (scb.pass_cnt + scb.fail_cnt == num_txn);
        begin
          #100000;
          $error("timeout: the scoreboard did not receive all transactions");
        end
      join_any
      disable fork;                             // end of test: stop all components
      scb.report(num_txn);
    endtask
  endclass

  class alu_test;
    alu_env env;

    function new(virtual alu_if vif);
      env = new(vif, 20);
    endfunction

    task run();
      env.run();
    endtask
  endclass

endpackage

module fx10_alu_layered_tb;
  import alu_tb_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if vif (clk);

  alu dut (
    .clk       (clk),
    .rst_n     (vif.rst_n),
    .valid_in  (vif.valid_in),
    .a         (vif.a),
    .b         (vif.b),
    .op        (vif.op),
    .valid_out (vif.valid_out),
    .result    (vif.result)
  );

  alu_test test;

  initial begin
    vif.rst_n = 0;
    repeat (2) @(negedge clk);
    vif.rst_n = 1;
  end

  initial begin
    test = new(vif);
    test.run();
    $finish;
  end
endmodule
