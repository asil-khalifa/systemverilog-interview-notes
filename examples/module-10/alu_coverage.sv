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
