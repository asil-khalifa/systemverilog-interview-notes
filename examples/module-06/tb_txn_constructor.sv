module tb_txn_constructor;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    function new(alu_op_e op = ALU_ADD, bit [7:0] a = 0, bit [7:0] b = 0);
      this.op = op;
      this.a  = a;
      this.b  = b;
    endfunction

    function bit is_unary();
      return op inside {ALU_NOT, ALU_SHL, ALU_SHR};
    endfunction
  endclass

  alu_txn t;

  initial begin
    t = new();
    $display("1. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());

    t = new(ALU_SUB, 8'd5, 8'd10);
    $display("2. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());

    t = new(ALU_NOT, 8'h0F);
    $display("3. op=%s a=%0d b=%0d unary=%0d", t.op.name(), t.a, t.b, t.is_unary());
  end

endmodule
