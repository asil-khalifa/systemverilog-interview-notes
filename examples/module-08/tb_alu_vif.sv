module tb_alu_vif;
  import alu_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);                          // physical interface

  alu dut (                                  // DUT with ordinary ports
    .clk       (clk),
    .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),
    .a         (aif.a),
    .b         (aif.b),
    .op        (aif.op),
    .valid_out (aif.valid_out),
    .result    (aif.result)
  );

  alu_driver  drv;
  alu_monitor mon;

  initial begin
    // Reset is asynchronous, so the reset-time values are assigned directly
    aif.rst_n    = 0;
    aif.valid_in = 0;
    aif.a        = '0;
    aif.b        = '0;
    aif.op       = ALU_ADD;

    drv = new(aif);                          // physical -> virtual (modport DRV)
    mon = new(aif);                          // physical -> virtual (modport MON)

    repeat (2) @(negedge clk);
    aif.rst_n = 1;                           // released at time 20, away from the edge

    fork
      mon.run();                             // the monitor runs in the background
    join_none

    drv.drive(8'd200, 8'd100, ALU_ADD);
    drv.drive(8'd5,   8'd10,  ALU_SUB);
    drv.drive(8'hF0,  8'h3C,  ALU_XOR);

    repeat (3) @(posedge clk);
    $finish;
  end

endmodule
