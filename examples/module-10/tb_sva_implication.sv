module tb_sva_implication;

  logic clk = 0;
  logic req, ack;

  // stimulus for cycles 0..6 (cycle k is the posedge at time 10k+5)
  bit [0:6] req_v = 7'b0101010;
  bit [0:6] ack_v = 7'b0110001;

  always #5 clk = ~clk;

  // overlapped: ack in the SAME cycle as req
  a_overlap: assert property (@(posedge clk) req |-> ack)
    else $display("[%0t] a_overlap    FAILED: req without ack in the same cycle", $time);

  // non-overlapped: ack in the cycle AFTER req
  a_nonoverlap: assert property (@(posedge clk) req |=> ack)
    else $display("[%0t] a_nonoverlap FAILED: req not followed by ack", $time);

  initial begin
    for (int i = 0; i < 7; i++) begin
      req = req_v[i];
      ack = ack_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
