module tb_sva_sampling;

  logic clk = 0;
  logic sig = 0;

  always #5 clk = ~clk;

  // "sig must be 1 at every rising clock edge"
  a_sig: assert property (@(posedge clk) sig)
    else $display("[%0t] a_sig FAILED: sampled sig=%b, current sig=%b",
                  $time, $sampled(sig), sig);

  initial begin
    @(posedge clk);  sig = 1;      // time 5 : changes at the clock edge
    @(posedge clk);  sig = 0;      // time 15
    @(posedge clk);  sig = 1;      // time 25
    @(posedge clk);                // time 35
    @(negedge clk);  $finish;      // time 40
  end

endmodule
