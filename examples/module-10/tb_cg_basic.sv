module tb_cg_basic;

  bit [1:0] mode;        // 4 possible values
  bit [7:0] data;        // 256 possible values

  covergroup cg_basic;
    cp_mode: coverpoint mode;
    cp_data: coverpoint data;
  endgroup

  cg_basic cg = new();

  initial begin
    mode = 0;  data = 0;    cg.sample();
    mode = 1;  data = 3;    cg.sample();
    mode = 1;  data = 4;    cg.sample();
    mode = 3;  data = 255;  cg.sample();

    $display("cp_mode coverage    = %0.2f%%", cg.cp_mode.get_coverage());
    $display("cp_data coverage    = %0.2f%%", cg.cp_data.get_coverage());
    $display("covergroup coverage = %0.2f%%", cg.get_coverage());
  end

endmodule
