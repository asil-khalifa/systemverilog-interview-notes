module tb_event_basic;

  event ev;

  initial begin : waiter
    $display("[%0t] waiter : waiting for ev", $time);
    @(ev);
    $display("[%0t] waiter : ev received", $time);
    @(ev);
    $display("[%0t] waiter : ev received again", $time);
  end

  initial begin : trigger
    #10;
    $display("[%0t] trigger: -> ev", $time);
    -> ev;
    #10;
    $display("[%0t] trigger: -> ev", $time);
    -> ev;
  end

endmodule
