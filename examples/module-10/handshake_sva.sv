module handshake_sva #(
  parameter int MAX_WAIT = 3
) (
  input logic       clk,
  input logic       rst_n,
  input logic       valid,
  input logic       ready,
  input logic [7:0] data
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_reset_valid: assert property (disable iff (1'b0) !rst_n |-> !valid);

  a_valid_hold: assert property (valid && !ready |=> valid)
    else $display("[%0t] a_valid_hold    FAILED: valid dropped before ready", $time);

  a_data_stable: assert property (valid && !ready |=> $stable(data))
    else $display("[%0t] a_data_stable   FAILED: data changed while waiting for ready",
                  $time);

  a_ready_timeout: assert property ($rose(valid) |-> ##[0:MAX_WAIT] ready)
    else $display("[%0t] a_ready_timeout FAILED: no ready within %0d cycles",
                  $time, MAX_WAIT);

  a_ctrl_known: assert property (!$isunknown({valid, ready}));
  a_data_known: assert property (valid |-> !$isunknown(data));

  // scenarios worth seeing
  c_transfer    : cover property (valid && ready);
  c_stall       : cover property (valid && !ready);
  c_back_to_back: cover property ((valid && ready) [*2]);

endmodule
