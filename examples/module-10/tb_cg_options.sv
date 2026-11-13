module tb_cg_options;

  bit [1:0] sel;
  bit       flag;

  covergroup cg_opt;
    option.per_instance = 1;
    option.comment      = "demonstrates at_least and weight";

    cp_sel: coverpoint sel {
      option.at_least = 2;        // a bin needs two hits
      option.weight   = 3;        // three times as important as cp_flag
    }
    cp_flag: coverpoint flag;     // at_least = 1, weight = 1
  endgroup

  cg_opt cg = new();

  initial begin
    sel = 0;  flag = 0;  cg.sample();
    sel = 0;  flag = 0;  cg.sample();
    sel = 1;  flag = 0;  cg.sample();
    sel = 2;  flag = 1;  cg.sample();
    sel = 2;  flag = 0;  cg.sample();

    $display("cp_sel   = %0.2f%%", cg.cp_sel.get_inst_coverage());
    $display("cp_flag  = %0.2f%%", cg.cp_flag.get_inst_coverage());
    $display("instance = %0.2f%%", cg.get_inst_coverage());
  end

endmodule
