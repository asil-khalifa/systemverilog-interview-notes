class alu_driver;

  virtual alu_if     vif;
  mailbox #(alu_txn) gen2drv_mbx;
  event              drv_done;
  int unsigned       num_driven;

  function new(virtual alu_if vif, mailbox #(alu_txn) gen2drv_mbx, event drv_done);
    this.vif         = vif;
    this.gen2drv_mbx = gen2drv_mbx;
    this.drv_done    = drv_done;
  endfunction

  // Put the bus into its idle state, then wait until reset has been released
  task reset();
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b0;
    vif.drv_cb.a        <= '0;
    vif.drv_cb.b        <= '0;
    vif.drv_cb.op       <= ALU_ADD;
    wait (vif.rst_n === 1'b1);
  endtask

  // Apply one transaction: valid_in is high across exactly one rising edge
  task drive(alu_txn txn);
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b1;
    vif.drv_cb.a        <= txn.a;
    vif.drv_cb.b        <= txn.b;
    vif.drv_cb.op       <= txn.op;
    @(vif.drv_cb);                      // the DUT samples the transaction at this edge
    vif.drv_cb.valid_in <= 1'b0;
  endtask

  task run();
    alu_txn txn;
    reset();
    forever begin
      gen2drv_mbx.get(txn);
      drive(txn);
      num_driven++;
      txn.print("DRV");
      -> drv_done;
    end
  endtask

endclass
