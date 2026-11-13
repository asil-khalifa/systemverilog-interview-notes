module tb_dist_knobs;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;

    // weights are ordinary variables: a test can change them at run time
    int unsigned w_arith = 6;
    int unsigned w_logic = 3;
    int unsigned w_shift = 1;

    constraint op_dist_c {
      op dist { ALU_ADD := w_arith, ALU_SUB := w_arith,
                ALU_AND := w_logic, ALU_OR  := w_logic, ALU_XOR := w_logic, ALU_NOT := w_logic,
                ALU_SHL := w_shift, ALU_SHR := w_shift };
    }
    constraint corner_c {
      a dist { 8'h00 := 10, 8'hFF := 10, [8'h01:8'hFE] :/ 80 };   // 10% / 10% / 80%
    }
  endclass

  alu_txn txn;
  int     n_shift, n_a_min, n_a_max;

  initial begin
    txn = new();
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (txn.op inside {ALU_SHL, ALU_SHR}) n_shift++;
      if (txn.a == 8'h00) n_a_min++;
      if (txn.a == 8'hFF) n_a_max++;
    end
    $display("default weights : shifts=%0d a_min=%0d a_max=%0d", n_shift, n_a_min, n_a_max);

    txn.w_arith = 0;                  // a "shift only" test: remove the other opcodes
    txn.w_logic = 0;
    n_shift = 0;
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (txn.op inside {ALU_SHL, ALU_SHR}) n_shift++;
    end
    $display("shift-only test : shifts=%0d", n_shift);
  end

endmodule
