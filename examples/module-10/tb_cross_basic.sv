module tb_cross_basic;

  bit [1:0] kind;
  bit       dir;       // 0 = read, 1 = write

  covergroup cg_xfer;
    cp_kind   : coverpoint kind;              // 4 bins
    cp_dir    : coverpoint dir;               // 2 bins
    x_kind_dir: cross cp_kind, cp_dir;        // 8 cross bins
  endgroup

  cg_xfer cg = new();

  initial begin
    kind = 0;  dir = 0;  cg.sample();
    kind = 0;  dir = 1;  cg.sample();
    kind = 1;  dir = 0;  cg.sample();
    kind = 3;  dir = 1;  cg.sample();
    kind = 0;  dir = 0;  cg.sample();

    $display("cp_kind    = %0.2f%%", cg.cp_kind.get_coverage());
    $display("cp_dir     = %0.2f%%", cg.cp_dir.get_coverage());
    $display("x_kind_dir = %0.2f%%", cg.x_kind_dir.get_coverage());
    $display("cg_xfer    = %0.2f%%", cg.get_coverage());
  end

endmodule
