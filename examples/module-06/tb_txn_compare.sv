module tb_txn_compare;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a = a;  c.b = b;  c.op = op;  c.result = result;  c.id = id;
      return c;
    endfunction

    virtual function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a      ==  rhs.a)  &&
             (b      ==  rhs.b)  &&
             (op     === rhs.op) &&
             (result === rhs.result);
    endfunction
  endclass

  alu_txn exp, act, same, none;

  initial begin
    exp        = new();
    exp.id     = 1;
    exp.op     = ALU_ADD;
    exp.a      = 8'd200;
    exp.b      = 8'd100;
    exp.result = 9'd300;

    act  = exp.copy();
    same = exp;

    $display("1. exp == act  (handles)       : %0d", exp == act);
    $display("2. exp == same (handles)       : %0d", exp == same);
    $display("3. exp.compare(act)            : %0d", exp.compare(act));

    act.id = 99;
    $display("4. different id                : %0d", exp.compare(act));

    act.result = 9'd301;
    $display("5. different result            : %0d", exp.compare(act));

    act.result = 'x;
    $display("6. result is X                 : %0d", exp.compare(act));
    $display("7. X with == gives %b, with === gives %b",
             exp.result == act.result, exp.result === act.result);

    $display("8. compare with a null handle  : %0d", exp.compare(none));
  end

endmodule
