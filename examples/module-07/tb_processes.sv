module tb_processes;

  initial begin : thread_a
    $display("[%0t] A: step 1", $time);
    #10;
    $display("[%0t] A: step 2", $time);
    #20;
    $display("[%0t] A: step 3", $time);
  end

  initial begin : thread_b
    #5;
    $display("[%0t] B: step 1", $time);
    #10;
    $display("[%0t] B: step 2", $time);
  end

endmodule
