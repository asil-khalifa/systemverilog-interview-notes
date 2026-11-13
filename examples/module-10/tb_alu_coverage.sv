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
