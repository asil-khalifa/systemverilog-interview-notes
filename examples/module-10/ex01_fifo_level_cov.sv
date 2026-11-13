module ex01_fifo_level_cov;

  covergroup cg_level with function sample(int unsigned level);
    cp_class: coverpoint level {
      bins empty   = {0};
      bins partial = {[1:15]};
      bins full    = {16};
    }
    cp_trans: coverpoint level {
      bins start_fill = (0 => [1:15]);
      bins reach_full = ([1:15] => 16);
      bins leave_full = (16 => [1:15]);
      bins drain      = ([1:15] => 0);
      bins stay_full  = (16 [*3]);
    }
  endgroup

  cg_level cg = new();

  initial begin
    cg.sample(0);
    cg.sample(5);
    cg.sample(16);
    cg.sample(16);
    cg.sample(3);
    cg.sample(0);
    $display("cp_class = %0.2f%%", cg.cp_class.get_coverage());
    $display("cp_trans = %0.2f%%", cg.cp_trans.get_coverage());
    $display("cg_level = %0.2f%%", cg.get_coverage());
  end

endmodule
