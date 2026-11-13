module tb_txn_copy;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a      = a;
      c.b      = b;
      c.op     = op;
      c.result = result;
      c.id     = id;
      return c;
    endfunction
  endclass

  alu_txn t;
  alu_txn q_bad  [$];
  alu_txn q_good [$];

  initial begin
    t = new();
    for (int i = 0; i < 3; i++) begin
      t.id = i;
      t.a  = 10 * i;
      q_bad.push_back(t);             // BUG : the same handle is stored three times
      q_good.push_back(t.copy());     // GOOD: three separate objects are stored
    end

    foreach (q_bad[i])
      $display("q_bad [%0d]: id=%0d a=%0d", i, q_bad[i].id, q_bad[i].a);
    foreach (q_good[i])
      $display("q_good[%0d]: id=%0d a=%0d", i, q_good[i].id, q_good[i].a);

    $display("q_bad[0]  and q_bad[2]  are the same object: %0d", q_bad[0]  == q_bad[2]);
    $display("q_good[0] and q_good[2] are the same object: %0d", q_good[0] == q_good[2]);
  end

endmodule
