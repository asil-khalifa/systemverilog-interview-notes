module tb_alu_txn;

  // In the real testbench this type comes from alu_pkg (Module 1).
  // It is repeated here so that the file runs on its own.
  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;       // filled in by the monitor from the DUT
    int unsigned   id;

    function void print(string tag = "");
      $display("[%s] id=%0d a=%0d b=%0d op=%s result=%0d",
               tag, id, a, b, op.name(), result);
    endfunction

    function alu_txn copy();
      alu_txn t = new();
      t.a      = this.a;
      t.b      = this.b;
      t.op     = this.op;
      t.result = this.result;
      t.id     = this.id;
      return t;
    endfunction

    function bit compare(alu_txn rhs);
      if (rhs == null) return 0;
      return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
    endfunction
  endclass

  alu_txn t1, t2;

  initial begin
    t1 = new();
    t1.id     = 1;
    t1.a      = 8'd200;
    t1.b      = 8'd100;
    t1.op     = ALU_ADD;
    t1.result = 9'd300;
    t1.print("t1");

    t2 = t1.copy();
    t2.print("t2");
    $display("same object? %0d   same contents? %0d", t1 == t2, t1.compare(t2));

    t2.b = 8'd101;
    $display("after t2.b = 101: same contents? %0d", t1.compare(t2));
    t1.print("t1");
  end

endmodule
