module counter_sva (
  input logic       clk,
  input logic       rst_n,
  input logic       en,
  input logic [3:0] count
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_reset: assert property (disable iff (1'b0) !rst_n |-> count == 4'd0);

  a_incr : assert property (en |=> count == $past(count) + 4'd1);

  a_hold : assert property (!en |=> $stable(count));

  a_wrap : assert property (en && count == 4'hF |=> count == 4'h0);

  a_known: assert property (!$isunknown(count));

  // WRONG on purpose: the literal 1 is 32 bits wide, so the sum does not wrap at 15
  a_incr_bad: assert property (en |=> count == $past(count) + 1)
    else $display("[%0t] a_incr_bad FAILED: the assertion is wrong, not the counter",
                  $time);

  c_wrap: cover property (en && count == 4'hF ##1 count == 4'h0);

endmodule
