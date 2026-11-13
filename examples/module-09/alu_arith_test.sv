class alu_arith_txn extends alu_txn;

  constraint arith_c {
    op inside {ALU_ADD, ALU_SUB};
  }

endclass

class alu_arith_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_arith_test";
  endfunction

  virtual function void configure();
    alu_arith_txn arith_txn;
    arith_txn         = new();
    env.gen.blueprint = arith_txn;
    env.gen.num_txns  = 20;
  endfunction

endclass
