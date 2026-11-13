module tb_if_basic;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);     // interface instance: creates rst_n, en and count
  counter dut (cif);     // one connection carries all the signals

  initial begin
    cif.rst_n = 0;
    cif.en    = 0;
    @(negedge clk);
    cif.rst_n = 1;
    cif.en    = 1;

    repeat (3) @(negedge clk);
    $display("[%0t] count = %0d", $time, cif.count);

    cif.en = 0;
    repeat (2) @(negedge clk);
    $display("[%0t] count = %0d", $time, cif.count);
    $finish;
  end

endmodule
