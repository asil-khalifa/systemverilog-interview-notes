module tb_txn_basic;
  import alu_pkg::*;

  class alu_txn;
    // ---- stimulus: chosen by the testbench, therefore rand ----
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;

    // ---- response: sampled from the DUT, therefore four-state, not rand ----
    logic [8:0]    result;

    // ---- bookkeeping ----
    int unsigned   id;
  endclass

  alu_txn t1, t2;

  initial begin
    t1 = new();
    t2 = new();

    t1.id = 1;
    t1.a  = 8'd200;
    t1.b  = 8'd100;
    t1.op = ALU_ADD;

    $display("t1: id=%0d a=%0d b=%0d op='%s' result=%h",
             t1.id, t1.a, t1.b, t1.op.name(), t1.result);
    $display("t2: id=%0d a=%0d b=%0d op='%s' result=%h",
             t2.id, t2.a, t2.b, t2.op.name(), t2.result);
  end

endmodule
