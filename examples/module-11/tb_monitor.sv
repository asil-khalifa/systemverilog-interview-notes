module tb_monitor;

  int a, b;

  initial $monitor("[%0t] monitor: a=%0d b=%0d", $time, a, b);

  initial begin
    #5  a = 1;
    #5  b = 2;
        a = 3;
    #5  a = 3;          // no change: nothing is printed
    #5  $finish;
  end

endmodule
