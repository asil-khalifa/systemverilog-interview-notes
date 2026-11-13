module tb_txn_reuse;
  import alu_pkg::*;

  // ---------------- base transaction: written once ----------------
  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
                ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
    }

    virtual function string convert2string();
      return $sformatf("id=%0d op=%s a=0x%h b=0x%h", id, op.name(), a, b);
    endfunction

    virtual function alu_txn copy();
      alu_txn c = new();
      c.a = a;  c.b = b;  c.op = op;  c.result = result;  c.id = id;
      return c;
    endfunction
  endclass

  // ---------------- test-specific transactions: added later ----------------
  class alu_carry_txn extends alu_txn;
    constraint carry_c { op == ALU_ADD; a + b > 255; }           // added
  endclass

  class alu_shift_txn extends alu_txn;
    constraint op_dist_c { op inside {ALU_SHL, ALU_SHR}; }       // replaces the base block
  endclass

  // ---------------- "generator": knows only the base class ----------------
  function automatic void make_stimulus(alu_txn blueprint, int unsigned n,
                                        ref alu_txn out_q[$]);
    for (int unsigned i = 0; i < n; i++) begin
      if (!blueprint.randomize()) $fatal(1, "randomize() failed");
      blueprint.id = i;
      out_q.push_back(blueprint.copy());
    end
  endfunction

  alu_txn       q[$];
  alu_carry_txn carry_bp;
  alu_shift_txn shift_bp;
  int unsigned  n_ok;

  initial begin
    // Test 1: additions with carry
    carry_bp = new();
    make_stimulus(carry_bp, 50, q);
    n_ok = 0;
    foreach (q[i]) if (q[i].op == ALU_ADD && (q[i].a + q[i].b) > 255) n_ok++;
    $display("carry test: %0d of %0d transactions are ADD with carry", n_ok, q.size());
    $display("  first   : %s", q[0].convert2string());

    // Test 2: shifts only
    q.delete();
    shift_bp = new();
    make_stimulus(shift_bp, 50, q);
    n_ok = 0;
    foreach (q[i]) if (q[i].op inside {ALU_SHL, ALU_SHR}) n_ok++;
    $display("shift test: %0d of %0d transactions are shifts", n_ok, q.size());
    $display("  first   : %s", q[0].convert2string());
  end

endmodule
