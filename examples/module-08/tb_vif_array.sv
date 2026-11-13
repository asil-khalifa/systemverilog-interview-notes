module tb_vif_array;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if cif [2] (clk);

  for (genvar i = 0; i < 2; i++) begin : g_dut
    counter dut (cif[i]);
  end

  virtual cnt_if vifs [2];                 // one handle per interface instance

  initial begin
    vifs[0] = cif[0];
    vifs[1] = cif[1];

    foreach (vifs[i]) begin                // a variable index is fine on the handles
      vifs[i].rst_n = 0;
      vifs[i].en    = 0;
    end
    @(negedge clk);
    foreach (vifs[i]) vifs[i].rst_n = 1;

    vifs[0].en = 1;
    repeat (3) @(negedge clk);
    vifs[1].en = 1;
    repeat (2) @(negedge clk);

    foreach (vifs[i])
      $display("[%0t] counter %0d = %0d", $time, i, vifs[i].count);
    $finish;
  end

endmodule
