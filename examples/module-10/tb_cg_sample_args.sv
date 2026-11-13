module tb_cg_sample_args;

  covergroup cg_xfer with function sample(bit [7:0] addr, bit wr);
    cp_addr: coverpoint addr {
      bins lo = {[0:127]};
      bins hi = {[128:255]};
    }
    cp_wr: coverpoint wr;
    x_addr_wr: cross cp_addr, cp_wr;
  endgroup

  cg_xfer cg = new();

  initial begin
    cg.sample(8'h10, 1'b1);      // low address, write
    cg.sample(8'hF0, 1'b0);      // high address, read
    $display("cp_addr   = %0.2f%%", cg.cp_addr.get_coverage());
    $display("cp_wr     = %0.2f%%", cg.cp_wr.get_coverage());
    $display("x_addr_wr = %0.2f%%", cg.x_addr_wr.get_coverage());
    $display("cg_xfer   = %0.2f%%", cg.get_coverage());
  end

endmodule
