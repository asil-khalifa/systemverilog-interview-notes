module tb_multi_process_sync;

  class alu_txn;
    bit [7:0]    a, b;
    logic [8:0]  result;
    int unsigned id;
  endclass

  class alu_generator;
    mailbox #(alu_txn) gen2drv_mbx;
    int unsigned       num_txn = 3;

    task run();
      alu_txn txn;
      for (int unsigned i = 1; i <= num_txn; i++) begin
        txn    = new();
        txn.id = i;
        txn.a  = 8'(i);
        txn.b  = 8'(2 * i);
        $display("[%0t] GEN: put id=%0d", $time, txn.id);
        gen2drv_mbx.put(txn);
      end
    endtask
  endclass

  class alu_driver;
    mailbox #(alu_txn) gen2drv_mbx;
    mailbox #(alu_txn) mon2scb_mbx;

    task run();
      alu_txn txn;
      forever begin
        gen2drv_mbx.get(txn);
        #10;                                         // one transfer takes 10 time units
        txn.result = txn.a + txn.b;                  // stands in for the DUT
        $display("[%0t] DRV: drove id=%0d, result=%0d", $time, txn.id, txn.result);
        mon2scb_mbx.put(txn);                        // stands in for the monitor
      end
    endtask
  endclass

  class alu_scoreboard;
    mailbox #(alu_txn) mon2scb_mbx;
    int unsigned       num_checked;

    task run();
      alu_txn txn;
      forever begin
        mon2scb_mbx.get(txn);
        if (txn.result !== txn.a + txn.b)
          $display("[%0t] SCB: id=%0d FAIL", $time, txn.id);
        else
          $display("[%0t] SCB: id=%0d PASS", $time, txn.id);
        num_checked++;
      end
    endtask
  endclass

  mailbox #(alu_txn) gen2drv_mbx, mon2scb_mbx;
  alu_generator      gen;
  alu_driver         drv;
  alu_scoreboard     scb;

  initial begin
    // build
    gen2drv_mbx = new();
    mon2scb_mbx = new();
    gen = new();
    drv = new();
    scb = new();

    // connect
    gen.gen2drv_mbx = gen2drv_mbx;
    drv.gen2drv_mbx = gen2drv_mbx;
    drv.mon2scb_mbx = mon2scb_mbx;
    scb.mon2scb_mbx = mon2scb_mbx;

    // run
    fork
      gen.run();
      drv.run();
      scb.run();
    join_none

    // end of test: all transactions checked, or timeout
    fork
      begin
        fork
          wait (scb.num_checked == gen.num_txn);
          begin
            #1000;
            $display("[%0t] TEST: TIMEOUT", $time);
          end
        join_any
        disable fork;
      end
    join

    $display("[%0t] TEST: %0d of %0d transactions checked",
             $time, scb.num_checked, gen.num_txn);
    $finish;
  end

endmodule
