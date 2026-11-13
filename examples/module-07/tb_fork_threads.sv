module tb_fork_threads;

  initial begin
    fork
      #10 $display("[%0t] thread 1 (a single statement)", $time);

      begin
        #5  $display("[%0t] thread 2: first statement", $time);
        #20 $display("[%0t] thread 2: second statement", $time);
      end

      #15 $display("[%0t] thread 3 (a single statement)", $time);
    join
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
