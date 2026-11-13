class alu_txn;

  rand bit [7:0] a;
  rand bit [7:0] b;
  rand alu_op_e  op;
  logic [8:0]    result;
  int unsigned   id;

  // Make the corner operands 0 and 255 more likely than uniform random would
  constraint operand_c {
    a dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};
    b dist {8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8};
  }

  function void print(string tag = "");
    $display("[%0t] %s id=%0d op=%s a=%0d b=%0d result=%0d",
             $time, tag, id, op.name(), a, b, result);
  endfunction

  virtual function alu_txn copy();
    alu_txn c;
    c        = new();
    c.a      = a;
    c.b      = b;
    c.op     = op;
    c.result = result;
    c.id     = id;
    return c;
  endfunction

  function bit compare(alu_txn rhs);
    if (rhs == null) return 0;
    return (a == rhs.a) && (b == rhs.b) && (op == rhs.op) && (result === rhs.result);
  endfunction

endclass
