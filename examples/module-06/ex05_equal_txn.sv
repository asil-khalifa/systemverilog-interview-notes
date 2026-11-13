module ex05_equal_txn;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  class alu_equal_txn extends alu_txn;
    constraint equal_c { op == ALU_SUB; a == b; }
  endclass

  alu_equal_txn t;
  int unsigned  n_ok;

  initial begin
    t = new();
    repeat (100) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op == ALU_SUB && t.a == t.b && alu_predict(t) === 9'h000) n_ok++;
    end
    $display("%0d of 100: SUB with a == b and predicted result 0", n_ok);
  end

endmodule
