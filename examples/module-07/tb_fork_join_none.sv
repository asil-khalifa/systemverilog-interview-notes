module tb_fork_join_none;

  initial begin
    $display("[%0t] parent: before fork", $time);
    fork
      $display("[%0t] thread D (no delay) runs", $time);
      begin #30 $display("[%0t] thread A done", $time); end
      begin #10 $display("[%0t] thread B done", $time); end
      begin #20 $display("[%0t] thread C done", $time); end
    join_none
    $display("[%0t] parent: after join_none", $time);
    #5;
    $display("[%0t] parent: continues its own work", $time);
  end

endmodule
