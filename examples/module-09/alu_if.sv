interface alu_if (input logic clk);
  import alu_pkg::*;

  logic       rst_n;
  logic       valid_in;
  logic [7:0] a;
  logic [7:0] b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  // Driver's view: drive the DUT inputs, sample the DUT outputs
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid_in, a, b, op;
    input  valid_out, result;
  endclocking

  // Monitor's view: sample everything, drive nothing
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid_in, a, b, op, valid_out, result;
  endclocking

  modport DUT (input clk, rst_n, valid_in, a, b, op, output valid_out, result);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);

endinterface
