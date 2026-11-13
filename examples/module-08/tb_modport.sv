// A stimulus module that uses the testbench view of the interface
module cnt_stim (cnt_mp_if.TB cif);

  initial begin
    cif.rst_n = 0;
    cif.en    = 0;
    @(negedge cif.clk);
    cif.rst_n = 1;
    cif.en    = 1;

    repeat (5) @(negedge cif.clk);
    $display("[%0t] count = %0d", $time, cif.count);

    // cif.count = 4'd0;          // ILLEGAL: count is an input in modport TB
    $finish;
  end

endmodule

module tb_modport;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_mp_if  cif  (clk);
  counter_mp dut  (cif);          // modport DUT was chosen in the module header
  cnt_stim   stim (cif.TB);       // the modport may also be named at the instance

endmodule
