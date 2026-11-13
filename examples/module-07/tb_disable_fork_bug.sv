module tb_disable_fork_bug;

  initial begin
    fork                                             // a background thread
      forever #10 $display("[%0t] heartbeat", $time);
    join_none

    fork                                             // a timeout structure
      begin #25 $display("[%0t] response received", $time); end
      begin #15 $display("[%0t] timeout", $time); end
    join_any
    disable fork;                                    // intended: stop the slower of the two
    $display("[%0t] disable fork executed", $time);

    #30;
    $display("[%0t] end of test", $time);
    $finish;
  end

endmodule
