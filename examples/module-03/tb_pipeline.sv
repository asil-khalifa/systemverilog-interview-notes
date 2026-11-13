module tb_pipeline;

  logic     clk = 0;
  bit [3:0] d = 4'd5;
  bit [3:0] q1, q2, q3;      // written with nonblocking assignments
  bit [3:0] b1, b2, b3;      // written with blocking assignments

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    q1 <= d;
    q2 <= q1;
    q3 <= q2;
  end

  always @(posedge clk) begin
    b1 = d;
    b2 = b1;
    b3 = b2;
  end

  initial begin
    repeat (3) begin
      @(negedge clk);
      $display("[%0t] nonblocking q1 q2 q3 = %0d %0d %0d    blocking b1 b2 b3 = %0d %0d %0d",
               $time, q1, q2, q3, b1, b2, b3);
    end
    $finish;
  end

endmodule
