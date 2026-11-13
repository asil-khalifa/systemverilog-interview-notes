module tb_function_no_time;

  // Legal: the function itself returns immediately; the forked thread runs later
  function automatic void start_watchdog(int timeout);
    fork
      begin
        #timeout;
        $display("[%0t] watchdog expired", $time);
      end
    join_none
    $display("[%0t] start_watchdog() returns", $time);
  endfunction

  // function automatic int bad(int x);
  //   #5;                      // ILLEGAL: delay in a function
  //   @(posedge clk);          // ILLEGAL: event control in a function
  //   return x;
  // endfunction

  initial begin
    $display("[%0t] calling function", $time);
    start_watchdog(20);
    $display("[%0t] back in the caller", $time);
    #30;
    $display("[%0t] done", $time);
  end

endmodule
