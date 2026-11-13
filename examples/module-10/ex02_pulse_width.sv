module ex02_pulse_width;

  logic clk = 0;
  logic p;

  // cycles 0..9 : a 2-cycle pulse at cycles 1-2, a 3-cycle pulse at cycles 5-7
  bit [0:9] p_v = 10'b0110011100;

  always #5 clk = ~clk;

  a_width: assert property (@(posedge clk) $rose(p) |-> p [*2] ##1 !p)
    else $display("[%0t] a_width FAILED: pulse is not exactly 2 cycles wide", $time);

  initial begin
    for (int i = 0; i < 10; i++) begin
      p = p_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
