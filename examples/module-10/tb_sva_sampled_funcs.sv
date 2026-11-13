module tb_sva_sampled_funcs;

  logic clk = 0;
  bit   sig;

  // stimulus for cycles 0..5 (cycle k is the posedge at time 10k+5)
  bit [0:5] sig_v = 6'b011001;

  always #5 clk = ~clk;

  always @(posedge clk)
    $display("[%0t] sig=%b  rose=%b fell=%b stable=%b changed=%b  past=%b past2=%b",
             $time, sig, $rose(sig), $fell(sig), $stable(sig), $changed(sig),
             $past(sig), $past(sig, 2));

  initial begin
    for (int i = 0; i < 6; i++) begin
      sig = sig_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
