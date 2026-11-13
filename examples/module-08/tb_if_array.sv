module tb_if_array;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if cif [2] (clk);                   // two interface instances

  for (genvar i = 0; i < 2; i++) begin : g_dut
    counter dut (cif[i]);                 // one counter per interface instance
  end

  initial begin
    cif[0].rst_n = 0;   cif[1].rst_n = 0;
    cif[0].en    = 1;   cif[1].en    = 0;
    @(negedge clk);
    cif[0].rst_n = 1;   cif[1].rst_n = 1;

    repeat (2) @(negedge clk);
    cif[1].en = 1;                        // the second counter starts later

    repeat (2) @(negedge clk);
    $display("[%0t] count0 = %0d  count1 = %0d", $time, cif[0].count, cif[1].count);
    $finish;
  end

endmodule
