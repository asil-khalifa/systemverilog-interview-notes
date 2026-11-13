module tb_cycle_delay;

  logic       clk = 0;
  logic [3:0] d   = 0;

  always #5 clk = ~clk;

  default clocking cb @(posedge clk);
    default input #1step output #2;
    output d;
  endclocking

  always @(d) $display("[%0t] d changed to %0d", $time, d);

  initial begin
    ##1;                            // wait for 1 clocking event: time 5
    $display("[%0t] after ##1", $time);
    cb.d <= 4'd7;                   // applied at 5 + 2 = 7

    ##3;                            // three more events: 15, 25, 35
    $display("[%0t] after ##3", $time);
    cb.d <= ##2 4'd9;               // two events later (55), plus skew: 57

    ##3;                            // 45, 55, 65
    $display("[%0t] done", $time);
    $finish;
  end

endmodule
