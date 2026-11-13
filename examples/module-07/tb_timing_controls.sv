module tb_timing_controls;

  logic ready = 0;

  initial begin : stimulus
    #10 ready = 1;            // ready is 1 from time 10 ...
    #10 ready = 0;            // ... 0 from time 20 ...
    #10 ready = 1;            // ... and 1 again from time 30
  end

  initial begin : level_wait
    #15;
    wait (ready);
    $display("[%0t] wait (ready) passed", $time);
  end

  initial begin : edge_wait
    #15;
    @(posedge ready);
    $display("[%0t] @(posedge ready) passed", $time);
  end

  initial begin : delay_wait
    #18;
    $display("[%0t] #18 passed", $time);
  end

endmodule
