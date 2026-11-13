module tb_procedural_blocks;

  logic clk = 0;
  int   count;

  always #5 clk = ~clk;

  initial begin
    $display("[%0t] initial block 1 starts", $time);
    #12;
    $display("[%0t] initial block 1 ends", $time);
  end

  initial begin
    #3;
    $display("[%0t] initial block 2 runs in parallel", $time);
  end

  always @(posedge clk) begin
    count++;
    $display("[%0t] always block, count=%0d", $time, count);
  end

  initial #27 $finish;

  final $display("[%0t] final block, count=%0d", $time, count);

endmodule
