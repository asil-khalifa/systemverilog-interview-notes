// Compile order: alu_pkg.sv, alu_tb_pkg.sv (which includes alu_txn.sv), this file
module tb_alu_txn_final;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  int unsigned n;
  alu_txn      t, c;

  function automatic void show(alu_op_e op, bit [7:0] a, bit [7:0] b);
    alu_txn x = new();
    x.id     = n++;
    x.op     = op;
    x.a      = a;
    x.b      = b;
    x.result = alu_predict(x);
    x.print("EXP");
  endfunction

  initial begin
    show(ALU_ADD, 8'd200, 8'd100);
    show(ALU_SUB, 8'd5,   8'd10);
    show(ALU_AND, 8'hF0,  8'h3C);
    show(ALU_NOT, 8'h0F,  8'h00);
    show(ALU_SHL, 8'h81,  8'h00);
    show(ALU_SHR, 8'h81,  8'h00);

    t = new();
    $display("new object     : %s  unary=%0d", t.convert2string(), t.is_unary());

    if (!t.randomize() with { op == ALU_XOR; a == 8'hAA; b == 8'h0F; })
      $fatal(1, "randomize() failed");
    t.result = alu_predict(t);
    c = t.copy();
    $display("copy equal     : %0d", t.compare(c));
    c.result = 'x;
    $display("X result equal : %0d", t.compare(c));
    t.print("XOR");
  end

endmodule
