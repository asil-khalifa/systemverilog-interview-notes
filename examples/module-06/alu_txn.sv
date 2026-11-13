// alu_txn.sv
// Not compiled by itself: it is `included inside package alu_tb_pkg,
// which has already imported alu_pkg.

class alu_txn;

  // ---------------- stimulus ----------------
  rand bit [7:0] a;
  rand bit [7:0] b;
  rand alu_op_e  op;

  // ---------------- response ----------------
  logic [8:0]    result;

  // ---------------- bookkeeping ----------------
  int unsigned   id;

  // ---------------- constraints ----------------
  constraint op_dist_c {
    op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
              ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
  }

  constraint corner_c {
    a dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
    b dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
  }

  // ---------------- methods ----------------
  function new();
    op     = ALU_ADD;      // a legal opcode instead of the default X
    result = 'x;           // no response captured yet
  endfunction

  function void post_randomize();
    result = 'x;
  endfunction

  function bit is_unary();
    return op inside {ALU_NOT, ALU_SHL, ALU_SHR};
  endfunction

  virtual function string convert2string();
    return $sformatf("id=%0d op=%s a=0x%h b=0x%h result=0x%h",
                     id, op.name(), a, b, result);
  endfunction

  virtual function void print(string tag = "");
    $display("[%0t] %s: %s", $time, tag, convert2string());
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

  // id is bookkeeping and is deliberately not compared
  virtual function bit compare(alu_txn rhs);
    if (rhs == null) return 0;
    return (a      ==  rhs.a)  &&
           (b      ==  rhs.b)  &&
           (op     === rhs.op) &&
           (result === rhs.result);
  endfunction

endclass


// Reference model: the expected result for the inputs held in a transaction.
// Written from the specification, not copied from the RTL.
function automatic logic [8:0] alu_predict(alu_txn t);
  case (t.op)
    ALU_ADD: return {1'b0, t.a} + {1'b0, t.b};
    ALU_SUB: return {1'b0, t.a} - {1'b0, t.b};
    ALU_AND: return {1'b0, t.a & t.b};
    ALU_OR : return {1'b0, t.a | t.b};
    ALU_XOR: return {1'b0, t.a ^ t.b};
    ALU_NOT: return {1'b0, ~t.a};
    ALU_SHL: return {t.a, 1'b0};
    ALU_SHR: return {2'b00, t.a[7:1]};
    default: return 'x;
  endcase
endfunction
