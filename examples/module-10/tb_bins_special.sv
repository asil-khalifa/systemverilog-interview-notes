module tb_bins_special;

  bit [3:0] cmd;

  covergroup cg_cmd;
    // classification by pattern
    cp_kind: coverpoint cmd {
      wildcard bins read   = {4'b00??};     // 0..3   one bin
      wildcard bins write  = {4'b01??};     // 4..7   one bin
      wildcard bins ctrl[] = {4'b10??};     // 8..11  four bins
    }
    // every legal value separately
    cp_val: coverpoint cmd {
      bins         val[]    = {[0:15]};
      ignore_bins  reserved = {[12:13]};
      illegal_bins bad      = {[14:15]};
    }
  endgroup

  cg_cmd cg = new();

  initial begin
    cmd = 1;   cg.sample();
    cmd = 5;   cg.sample();
    cmd = 9;   cg.sample();
    cmd = 12;  cg.sample();     // reserved: ignored, no error
    cmd = 12;  cg.sample();
    // cmd = 14; cg.sample();   // illegal: this line would cause a run-time error

    $display("cp_kind = %0.2f%%", cg.cp_kind.get_coverage());
    $display("cp_val  = %0.2f%%", cg.cp_val.get_coverage());
    $display("cg_cmd  = %0.2f%%", cg.get_coverage());
  end

endmodule
