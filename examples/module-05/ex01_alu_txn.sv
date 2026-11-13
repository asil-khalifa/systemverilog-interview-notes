module ex01_alu_txn;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 3, ALU_SUB := 3,
                ALU_AND := 2, ALU_OR := 2, ALU_XOR := 2, ALU_NOT := 2,
                ALU_SHL := 1, ALU_SHR := 1 };
    }
    constraint not_b_c { (op == ALU_NOT) -> (b == 0); }

    function void print(string tag = "");
      $display("%s id=%0d op=%-7s a=%3d b=%3d result=%h", tag, id, op.name(), a, b, result);
    endfunction

    function alu_txn copy();
      alu_txn t = new();
      t.a = a;  t.b = b;  t.op = op;  t.result = result;  t.id = id;
      return t;
    endfunction

    function bit compare(alu_txn rhs);
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction
  endclass

  alu_txn txn, cpy;
  int     errors;

  initial begin
    txn = new();
    for (int i = 0; i < 5; i++) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      txn.id = i;
      txn.print("[gen]");
      if (txn.op == ALU_NOT && txn.b != 0) errors++;
    end
    cpy = txn.copy();
    $display("copy equals original : %0d", txn.compare(cpy));
    cpy.a = ~cpy.a;
    $display("after changing copy  : %0d", txn.compare(cpy));
    $display("ex01: errors=%0d", errors);
  end

endmodule
