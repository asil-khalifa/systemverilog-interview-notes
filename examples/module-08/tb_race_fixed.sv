interface dff_if (input logic clk);
  logic d = 0;
  logic q;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output d;                 // the testbench drives d
    input  q;                 // the testbench samples q
  endclocking
endinterface

module tb_race_fixed;

  logic clk = 0;
  always #5 clk = ~clk;

  dff_if dif (clk);
  dff    dut (.clk(clk), .d(dif.d), .q(dif.q));

  initial begin
    @(dif.cb);                // time 5
    dif.cb.d <= 1;            // applied at time 6: after the DUT has sampled
    @(dif.cb);                // time 15
    $display("[%0t] sampled q = %b", $time, dif.cb.q);
    @(dif.cb);                // time 25
    $display("[%0t] sampled q = %b", $time, dif.cb.q);
    $finish;
  end

endmodule
