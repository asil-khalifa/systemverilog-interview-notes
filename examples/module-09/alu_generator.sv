class alu_generator;

  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  event              gen_done;
  alu_txn            blueprint;
  int unsigned       num_txns = 10;
  int unsigned       num_sent;

  function new(mailbox #(alu_txn) gen2drv_mbx, event drv_done, event gen_done);
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
    this.gen_done    = gen_done;
    blueprint        = new();
  endfunction

  // Send one transaction to the driver and wait until the driver has applied it
  task send(alu_txn txn);
    num_sent++;
    txn.id = num_sent;
    gen2drv_mbx.put(txn);
    txn.print("GEN");
    @(drv_done);
  endtask

  virtual task run();
    repeat (num_txns) begin
      if (!blueprint.randomize()) $fatal(1, "GEN: randomization failed");
      send(blueprint.copy());
    end
    -> gen_done;
  endtask

endclass
