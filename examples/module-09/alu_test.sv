class alu_test;

  alu_env env;
  string  name = "alu_test";

  function new(virtual alu_if vif);
    env = new(vif);
  endfunction

  // Scenario settings. Derived tests override this.
  virtual function void configure();
    env.gen.num_txns = 10;
  endfunction

  task run();
    configure();
    $display("[%0t] TEST: %s started", $time, name);
    env.run();
    env.scb.report();
  endtask

endclass
