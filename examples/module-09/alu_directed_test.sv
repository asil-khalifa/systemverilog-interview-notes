class alu_directed_gen extends alu_generator;

  function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done, event gen_done);
    super.new(gen2drv_mbx, drv_done, gen_done);
  endfunction

  task send_values(bit [7:0] a, bit [7:0] b, alu_op_e op);
    alu_txn txn;
    txn    = new();
    txn.a  = a;
    txn.b  = b;
    txn.op = op;
    send(txn);
  endtask

  virtual task run();
    send_values(8'd200, 8'd100, ALU_ADD);
    send_values(8'd5,   8'd10,  ALU_SUB);
    send_values(8'hF0,  8'h3C,  ALU_AND);
    send_values(8'hF0,  8'h3C,  ALU_OR);
    send_values(8'hF0,  8'h3C,  ALU_XOR);
    send_values(8'hF0,  8'h00,  ALU_NOT);
    send_values(8'h81,  8'h00,  ALU_SHL);
    send_values(8'h81,  8'h00,  ALU_SHR);
    -> gen_done;
  endtask

endclass

class alu_directed_test extends alu_test;

  function new(virtual alu_if vif);
    super.new(vif);
    name = "alu_directed_test";
  endfunction

  virtual function void configure();
    alu_directed_gen dgen;
    dgen    = new(env.gen2drv_mbx, env.drv_done, env.gen_done);
    env.gen = dgen;
  endfunction

endclass
