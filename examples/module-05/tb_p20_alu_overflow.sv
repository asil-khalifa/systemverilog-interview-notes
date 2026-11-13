module tb_p20_alu_overflow;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    rand bit       ovf;                      // helper: does this transaction overflow?

    constraint op_c       { op inside {ALU_ADD, ALU_SUB}; }
    constraint ovf_dist_c { ovf dist {1 := 80, 0 := 20}; }
    constraint ovf_c {
      if (op == ALU_ADD) ovf == (a + b > 255);
      else               ovf == (a < b);
    }
    constraint order_c    { solve op, ovf before a, b; }
  endclass

  alu_txn txn;
  int     errors, n_ovf;
  bit     really;

  initial begin
    txn = new();
    repeat (1000) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      if (!(txn.op inside {ALU_ADD, ALU_SUB})) errors++;
      really = (txn.op == ALU_ADD) ? (int'(txn.a) + int'(txn.b) > 255) : (txn.a < txn.b);
      if (really != txn.ovf) errors++;
      if (really) n_ovf++;
    end
    $display("p20: carry/borrow in %0d of 1000", n_ovf);
    $display("p20: errors=%0d", errors);
  end

endmodule
