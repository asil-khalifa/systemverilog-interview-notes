module tb_gen_drv_mailbox;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  // ----------------------------------------------------------------- transaction
  class alu_txn;
    bit [7:0]    a, b;
    alu_op_e     op;
    int unsigned id;

    function void print(string tag = "");
      $display("[%0t] %s id=%0d a=%0d b=%0d op=%s", $time, tag, id, a, b, op.name());
    endfunction
  endclass

  // ------------------------------------------------------------------- generator
  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    event              drv_done;
    event              gen_done;
    int unsigned       num_txn = 3;

    function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done);
      this.gen2drv_mbx = gen2drv_mbx;
      this.drv_done    = drv_done;
    endfunction

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();                        // a new object for every transaction
        txn.id = i;
        txn.a  = 8'(10 * i);
        txn.b  = 8'(i);
        txn.op = (i % 2) ? ALU_ADD : ALU_SUB;
        txn.print("GEN: put");
        gen2drv_mbx.put(txn);
        @(drv_done);                           // wait until the driver has finished it
      end
      $display("[%0t] GEN: all %0d transactions sent", $time, num_txn);
      -> gen_done;
    endtask
  endclass

  // ---------------------------------------------------------------------- driver
  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    event              drv_done;

    function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done);
      this.gen2drv_mbx = gen2drv_mbx;
      this.drv_done    = drv_done;
    endfunction

    task run();
      alu_txn txn;
      forever begin
        gen2drv_mbx.get(txn);                  // blocks until a transaction arrives
        txn.print("DRV: got");
        #10;                                   // stands for driving the DUT pins
        $display("[%0t] DRV: done id=%0d", $time, txn.id);
        -> drv_done;
      end
    endtask
  endclass

  // ------------------------------------------------------------------- top level
  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  alu_generator      gen;
  alu_driver         drv;

  initial begin
    gen2drv_mbx = new();                       // ONE mailbox ...
    gen = new(gen2drv_mbx, drv_done);          // ... shared by both components
    drv = new(gen2drv_mbx, drv_done);

    fork
      gen.run();
      drv.run();
    join_none

    @(gen.gen_done);
    $display("[%0t] TOP: generator finished, %0d items left in the mailbox",
             $time, gen2drv_mbx.num());
    $finish;
  end

endmodule
