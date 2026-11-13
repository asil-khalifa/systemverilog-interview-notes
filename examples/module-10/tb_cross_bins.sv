module tb_cross_bins;

  bit [1:0] kind;
  bit       dir;

  covergroup cg_xfer;
    cp_kind: coverpoint kind;
    cp_dir : coverpoint dir;

    x_kind_dir: cross cp_kind, cp_dir {
      // kind 0 with any direction counts as one scenario
      bins        kind0_any = binsof(cp_kind) intersect {0};
      // kind 3 is read-only: a write of kind 3 cannot happen
      ignore_bins kind3_wr  = binsof(cp_kind) intersect {3} && binsof(cp_dir) intersect {1};
    }
  endgroup

  cg_xfer cg = new();

  initial begin
    kind = 0;  dir = 0;  cg.sample();
    kind = 0;  dir = 1;  cg.sample();
    kind = 1;  dir = 0;  cg.sample();
    kind = 3;  dir = 1;  cg.sample();     // ignored cross product
    kind = 0;  dir = 0;  cg.sample();

    $display("x_kind_dir = %0.2f%%", cg.x_kind_dir.get_coverage());
  end

endmodule
