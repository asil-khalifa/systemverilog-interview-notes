module tb_sva_delay_rep;

  logic clk = 0;
  logic start, busy, done;

  // stimulus for cycles 0..11 (cycle k is the posedge at time 10k+5)
  bit [0:11] start_v = 12'b0100_0010_0000;
  bit [0:11] busy_v  = 12'b0011_0001_0000;
  bit [0:11] done_v  = 12'b0001_0000_0000;

  always #5 clk = ~clk;

  // done must arrive 1 to 3 cycles after start rises
  a_range: assert property (@(posedge clk) $rose(start) |-> ##[1:3] done)
    else $display("[%0t] a_range FAILED: no done within 3 cycles of start", $time);

  // after start rises, busy must be high for exactly 2 cycles and then low
  a_busy: assert property (@(posedge clk) $rose(start) |=> busy [*2] ##1 !busy)
    else $display("[%0t] a_busy  FAILED: busy was not high for 2 cycles", $time);

  initial begin
    for (int i = 0; i < 12; i++) begin
      start = start_v[i];
      busy  = busy_v[i];
      done  = done_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
