module tb_txn_randomize;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    function void print(string tag = "");
      $display("%s: id=%0d op=%s a=0x%h b=0x%h", tag, id, op.name(), a, b);
    endfunction
  endclass

  alu_txn      t;
  int unsigned n_legal_op, n_id_kept;

  initial begin
    // 1. Four random transactions, a new object for each
    for (int i = 0; i < 4; i++) begin
      t    = new();
      t.id = i;
      if (!t.randomize()) $fatal(1, "randomize() failed");
      t.print("RAND");
    end

    // 2. Properties that hold on every run, checked over 500 randomizations
    t    = new();
    t.id = 77;
    repeat (500) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op.name() != "") n_legal_op++;     // op is always a declared member
      if (t.id == 77)        n_id_kept++;      // a non-rand field is never touched
    end
    $display("legal opcode in %0d of 500, id unchanged in %0d of 500",
             n_legal_op, n_id_kept);
  end

endmodule
