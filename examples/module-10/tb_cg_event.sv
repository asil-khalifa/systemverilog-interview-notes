module tb_cg_event;

  logic     clk = 0;
  bit       valid;
  bit [1:0] mode;

  // stimulus for cycles 0..4 (index 0 is the leftmost bit / first element)
  bit [0:4] valid_v     = 5'b01011;
  bit [1:0] mode_v [5]  = '{2'd0, 2'd1, 2'd2, 2'd3, 2'd1};

  covergroup cg_mode @(posedge clk);
    cp_mode: coverpoint mode iff (valid);
  endgroup

  cg_mode cg = new();

  always #5 clk = ~clk;

  initial begin
    for (int i = 0; i < 5; i++) begin
      valid = valid_v[i];
      mode  = mode_v[i];
      @(negedge clk);
    end
    $display("cp_mode coverage = %0.2f%%", cg.get_coverage());
    $finish;
  end

endmodule
