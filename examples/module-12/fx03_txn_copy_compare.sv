package fx03_pkg;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  class alu_txn;
    rand bit [7:0] a, b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function void print(string tag);
      $display("%s: id=%0d a=%0d b=%0d op=%s result=%0d", tag, id, a, b, op.name(), result);
    endfunction

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      return c;
    endfunction

    virtual function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a == rhs.a) && (b == rhs.b) && (op === rhs.op) && (result === rhs.result);
    endfunction
  endclass

endpackage

module fx03_txn_copy_compare;
  import fx03_pkg::*;

  alu_txn t1, t2, t3;

  initial begin
    t1 = new();
    t1.id = 1;  t1.a = 200;  t1.b = 100;  t1.op = ALU_ADD;  t1.result = 300;

    t2 = t1;                 // second handle to the same object
    t3 = t1.copy();          // second object

    t2.a = 5;                // also changes what t1 sees
    t3.b = 7;                // changes only the copy

    t1.print("t1");
    t2.print("t2");
    t3.print("t3");
    $display("t1 == t2 (handles): %b   t1 == t3 (handles): %b", t1 == t2, t1 == t3);
    $display("t1.compare(t2): %b   t1.compare(t3): %b", t1.compare(t2), t1.compare(t3));
  end
endmodule
