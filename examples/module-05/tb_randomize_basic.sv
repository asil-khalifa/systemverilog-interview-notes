module tb_randomize_basic;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0]  a, b;
    rand alu_op_e   op;
    logic [8:0]     result;          // not random: filled in later by the monitor
    int unsigned    id;              // not random: a state variable

    constraint id_link_c { a >= id; }   // a state variable used in a constraint

    function void print(string tag = "");
      $display("%s id=%0d a=%0d b=%0d op=%s", tag, id, a, b, op.name());
    endfunction
  endclass

  alu_txn txn;
  int     status;

  initial begin
    txn = new();

    txn.id = 250;
    status = txn.randomize();
    $display("status=%0d", status);
    txn.print("[1]");

    txn.id = 300;                       // a (8 bits) can never be >= 300
    status = txn.randomize();
    $display("status=%0d", status);
    txn.print("[2]");
  end

endmodule
