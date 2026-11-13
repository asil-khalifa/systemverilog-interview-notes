module tb_fork_join;

  initial begin
    $display("[%0t] parent: before fork", $time);
    fork
      begin #30 $display("[%0t] thread A done", $time); end
      begin #10 $display("[%0t] thread B done", $time); end
      begin #20 $display("[%0t] thread C done", $time); end
    join
    $display("[%0t] parent: after join", $time);
  end

endmodule
