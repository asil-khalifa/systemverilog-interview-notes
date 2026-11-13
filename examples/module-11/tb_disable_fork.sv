module tb_disable_fork;

  task automatic background(string name, int n);
    repeat (n) #20 $display("[%0t] %s tick", $time, name);
  endtask

  task automatic wait_with_timeout(int work_time, int timeout);
    fork                                 // isolating fork
      begin
        fork
          #work_time $display("[%0t] work done", $time);
          #timeout   $display("[%0t] TIMEOUT", $time);
        join_any
        disable fork;                    // kills only the loser of this race
      end
    join
  endtask

  initial begin
    fork
      background("monitor", 4);          // must keep running throughout
    join_none

    wait_with_timeout(30, 50);           // the work wins
    wait_with_timeout(70, 25);           // the timeout wins

    wait fork;                           // wait for the background thread
    $display("[%0t] all threads finished", $time);
  end

endmodule
