module tb_race;

  logic clk = 0, d = 0, q;
  always #5 clk = ~clk;

  dff dut (.*);

  initial begin
    @(posedge clk);          // time 5: wake up at the rising edge
    d = 1;                   // change the DUT input at that same edge (blocking)
    @(posedge clk);          // time 15
    $display("[%0t] q = %b", $time, q);
    $finish;
  end

endmodule
