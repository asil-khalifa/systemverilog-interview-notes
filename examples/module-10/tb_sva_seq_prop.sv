module tb_sva_seq_prop;

  logic clk = 0;
  logic req, gnt;

  // stimulus for cycles 0..7 (cycle k is the posedge at time 10k+5)
  bit [0:7] req_v = 8'b0100_1000;
  bit [0:7] gnt_v = 8'b0010_0001;

  always #5 clk = ~clk;

  // Layer 2: sequences
  sequence s_gnt_within_2;
    ##[1:2] gnt;
  endsequence

  sequence s_req_then_gnt;
    req ##1 gnt;
  endsequence

  // Layer 3: property
  property p_req_gnt;
    @(posedge clk) req |-> s_gnt_within_2;
  endproperty

  // Layer 4: directives
  a_req_gnt: assert property (p_req_gnt)
    else $display("[%0t] a_req_gnt FAILED: no gnt within 2 cycles of req", $time);

  c_req_gnt: cover property (@(posedge clk) s_req_then_gnt)
    $display("[%0t] c_req_gnt covered: gnt came one cycle after req", $time);

  initial begin
    for (int i = 0; i < 8; i++) begin
      req = req_v[i];
      gnt = gnt_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
