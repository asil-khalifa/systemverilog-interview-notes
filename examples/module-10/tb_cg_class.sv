module tb_cg_class;

  class packet_cov;
    bit [1:0] kind;
    bit [3:0] len;

    covergroup pkt_cg;
      cp_kind: coverpoint kind;
      cp_len : coverpoint len {
        bins small = {[0:3]};
        bins large = {[4:15]};
      }
    endgroup

    function new();
      pkt_cg = new();            // an embedded covergroup must be constructed here
    endfunction

    function void sample(bit [1:0] k, bit [3:0] l);
      kind = k;
      len  = l;
      pkt_cg.sample();
    endfunction
  endclass

  packet_cov cov;

  initial begin
    cov = new();
    cov.sample(2'd0, 4'd2);
    cov.sample(2'd1, 4'd9);
    cov.sample(2'd1, 4'd3);
    $display("pkt_cg coverage = %0.2f%%", cov.pkt_cg.get_coverage());
  end

endmodule
