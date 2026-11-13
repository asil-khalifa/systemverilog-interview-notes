module tb_bins_auto;

  typedef enum bit [1:0] {CMD_IDLE, CMD_RD, CMD_WR} cmd_e;

  bit [2:0] level;      //    8 values
  bit [9:0] len;        // 1024 values
  cmd_e     cmd;        //    3 named values

  covergroup cg_auto;
    cp_level: coverpoint level;
    cp_len  : coverpoint len { option.auto_bin_max = 4; }
    cp_cmd  : coverpoint cmd;
  endgroup

  cg_auto cg = new();

  initial begin
    level = 7;  len = 300;   cmd = CMD_RD;  cg.sample();
    level = 0;  len = 1000;  cmd = CMD_RD;  cg.sample();

    $display("cp_level = %0.2f%%", cg.cp_level.get_coverage());
    $display("cp_len   = %0.2f%%", cg.cp_len.get_coverage());
    $display("cp_cmd   = %0.2f%%", cg.cp_cmd.get_coverage());
  end

endmodule
