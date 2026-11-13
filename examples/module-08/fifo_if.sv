interface fifo_if (input logic clk);

  logic       rst_n;
  logic       wr_en;
  logic       rd_en;
  logic [7:0] din;
  logic [7:0] dout;
  logic       full;
  logic       empty;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output wr_en, rd_en, din;
    input  dout, full, empty;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input wr_en, rd_en, din, dout, full, empty;
  endclocking

  modport DUT (input clk, rst_n, wr_en, rd_en, din, output dout, full, empty);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);

endinterface
