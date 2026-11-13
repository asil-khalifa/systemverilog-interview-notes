class alu_env;

  virtual alu_if     vif;

  mailbox #(alu_txn) gen2drv_mbx;
  mailbox #(alu_txn) mon2scb_mbx;
  event              drv_done;
  event              gen_done;

  alu_generator      gen;
  alu_driver         drv;
  alu_monitor        mon;
  alu_scoreboard     scb;

  int unsigned       drain_timeout = 100;    // clock cycles

  function new(virtual alu_if vif);
    this.vif    = vif;
    gen2drv_mbx = new();
    mon2scb_mbx = new();
    gen = new(gen2drv_mbx, drv_done, gen_done);
    drv = new(vif, gen2drv_mbx, drv_done);
    mon = new(vif, mon2scb_mbx);
    scb = new(mon2scb_mbx);
  endfunction

  task run();
    // Start all components. Only gen.run() ever returns.
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
    join_any
    $display("[%0t] ENV: stimulus done, waiting for %0d results", $time, gen.num_sent);

    // Drain: wait until every transaction that was sent has been checked
    fork
      wait (scb.num_checked == gen.num_sent);
      begin
        repeat (drain_timeout) @(posedge vif.clk);
        $error("[%0t] ENV: timeout, %0d of %0d results checked",
               $time, scb.num_checked, gen.num_sent);
      end
    join_any

    disable fork;                           // stop driver, monitor, scoreboard, watchdog
  endtask

endclass
