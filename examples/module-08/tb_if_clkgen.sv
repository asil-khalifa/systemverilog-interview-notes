interface clk_rst_if;

  logic clk = 0;
  logic rst_n;

  always #5 clk = ~clk;

  task automatic apply_reset(int unsigned cycles = 2);
    rst_n = 0;
    repeat (cycles) @(negedge clk);
    rst_n = 1;
  endtask

endinterface

module tb_if_clkgen;

  clk_rst_if cr  ();              // generates clock and reset
  cnt_if     cif (cr.clk);        // the counter bus uses that clock
  counter    dut (cif);

  assign cif.rst_n = cr.rst_n;    // the counter bus uses that reset

  initial begin
    cif.en = 1;
    cr.apply_reset(2);
    $display("[%0t] reset released", $time);

    repeat (4) @(negedge cr.clk);
    $display("[%0t] count = %0d", $time, cif.count);
    $finish;
  end

endmodule
