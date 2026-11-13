module tb_event_classes;

  class reset_agent;
    event reset_done;

    task run();
      $display("[%0t] RST: asserting reset", $time);
      #25;
      $display("[%0t] RST: reset released", $time);
      -> reset_done;
    endtask
  endclass

  class alu_driver;
    event reset_done;                     // will refer to the reset agent's event

    task run();
      wait (reset_done.triggered);
      $display("[%0t] DRV: reset finished, start driving", $time);
    endtask
  endclass

  class alu_monitor;
    event reset_done;

    function new(event reset_done);       // alternative: receive the event at construction
      this.reset_done = reset_done;
    endfunction

    task run();
      wait (reset_done.triggered);
      $display("[%0t] MON: reset finished, start sampling", $time);
    endtask
  endclass

  reset_agent rst;
  alu_driver  drv;
  alu_monitor mon;

  initial begin
    rst = new();
    drv = new();
    drv.reset_done = rst.reset_done;      // method 1: assign the handle
    mon = new(rst.reset_done);            // method 2: pass it to the constructor

    fork                                  // only now start the threads
      rst.run();
      drv.run();
      mon.run();
    join
    $display("[%0t] TOP: all components finished", $time);
  end

endmodule
