interface alu_if (input logic clk);
  import alu_pkg::*;

  // ---- signals ----
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  // ---- timing for the driver ----
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid_in, a, b, op;
    input  valid_out, result;
  endclocking

  // ---- timing for the monitor ----
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid_in, a, b, op, valid_out, result;
  endclocking

  // ---- views ----
  modport DUT (input clk, rst_n, valid_in, a, b, op, output valid_out, result);
  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);
endinterface
