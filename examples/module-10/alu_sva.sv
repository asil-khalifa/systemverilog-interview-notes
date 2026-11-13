module alu_sva
  import alu_pkg::*;
(
  input logic       clk,
  input logic       rst_n,
  input logic       valid_in,
  input logic [7:0] a,
  input logic [7:0] b,
  input alu_op_e    op,
  input logic       valid_out,
  input logic [8:0] result
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // ---------------- reset ----------------
  a_reset: assert property (disable iff (1'b0)
    !rst_n |-> (!valid_out && result == 9'd0));

  // ---------------- valid_out follows valid_in by exactly one cycle ----------------
  a_valid_follow     : assert property ( valid_in |=>  valid_out);
  a_no_spurious_valid: assert property (!valid_in |=> !valid_out);

  // ---------------- result only changes after valid_in ----------------
  a_result_hold: assert property (!valid_in |=> $stable(result));

  // ---------------- no X ----------------
  a_valid_known : assert property (!$isunknown(valid_out));
  a_result_known: assert property (valid_out |-> !$isunknown(result));
  a_inputs_known: assert property (valid_in  |-> !$isunknown({a, b, op}));

  // ---------------- two functional checks ----------------
  a_add: assert property (
    (valid_in && op == ALU_ADD) |=> result == $past(a) + $past(b));

  a_not: assert property (
    (valid_in && op == ALU_NOT) |=> result == {1'b0, ~$past(a)});

  // ---------------- scenarios ----------------
  c_carry       : cover property (valid_out && result[8]);
  c_back_to_back: cover property (valid_in ##1 valid_in);
  c_idle_gap    : cover property (valid_in ##1 !valid_in ##1 valid_in);

endmodule
