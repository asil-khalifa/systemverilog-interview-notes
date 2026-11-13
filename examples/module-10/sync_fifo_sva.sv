module sync_fifo_sva #(
  parameter int DEPTH = 16
) (
  input logic                 clk,
  input logic                 rst_n,
  input logic                 wr_en,
  input logic                 rd_en,
  input logic [7:0]           din,
  input logic                 full,
  input logic                 empty,
  input logic [$clog2(DEPTH):0] count       // internal signal of the FIFO
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // ---------------- reset (must NOT be disabled by reset) ----------------
  a_reset_state: assert property (disable iff (1'b0)
    !rst_n |-> (empty && !full && count == 0));

  // ---------------- invariants ----------------
  a_not_full_and_empty: assert property (!(full && empty));
  a_count_range       : assert property (count <= DEPTH);
  a_full_flag         : assert property (full  == (count == DEPTH));
  a_empty_flag        : assert property (empty == (count == 0));

  // ---------------- no unknown values ----------------
  a_ctrl_known: assert property (!$isunknown({wr_en, rd_en, full, empty}));
  a_din_known : assert property (wr_en |-> !$isunknown(din));

  // ---------------- counting ----------------
  a_wr_incr: assert property (
    (wr_en && !full && !(rd_en && !empty)) |=> count == $past(count) + 1);

  a_rd_decr: assert property (
    (rd_en && !empty && !(wr_en && !full)) |=> count == $past(count) - 1);

  a_rw_same: assert property (
    (wr_en && !full && rd_en && !empty) |=> $stable(count));

  a_idle_stable: assert property ((!wr_en && !rd_en) |=> $stable(count));

  // ---------------- overflow / underflow protection ----------------
  a_full_hold : assert property ((full  && wr_en && !rd_en) |=> full);
  a_empty_hold: assert property ((empty && rd_en && !wr_en) |=> empty);

  // ---------------- cause of flag changes ----------------
  a_full_fell : assert property ($fell(full)  |-> $past(rd_en));
  a_empty_fell: assert property ($fell(empty) |-> $past(wr_en));

  // ---------------- rules for the environment ----------------
  a_wr_when_full: assert property (wr_en |-> !full)
    else $display("[%0t] a_wr_when_full FAILED: write attempted while the FIFO is full",
                  $time);

  a_rd_when_empty: assert property (rd_en |-> !empty)
    else $display("[%0t] a_rd_when_empty FAILED: read attempted while the FIFO is empty",
                  $time);

  // ---------------- coverage of interesting scenarios ----------------
  c_became_full  : cover property ($rose(full));
  c_full_to_empty: cover property (full ##[1:$] empty);
  c_simul_rw     : cover property (wr_en && rd_en && !full && !empty);

endmodule
