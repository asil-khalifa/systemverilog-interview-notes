module tb_sva_disable_iff;

  logic clk = 0;
  logic rst_n, req, ack;

  // stimulus for cycles 0..5 (cycle k is the posedge at time 10k+5)
  bit [0:5] rst_v = 6'b011101;      // reset active in cycle 0 and again in cycle 4
  bit [0:5] req_v = 6'b101100;
  bit [0:5] ack_v = 6'b000100;

  always #5 clk = ~clk;

  a_with_disable: assert property (@(posedge clk) disable iff (!rst_n) req |=> ack)
    else $display("[%0t] a_with_disable FAILED", $time);

  a_no_disable: assert property (@(posedge clk) req |=> ack)
    else $display("[%0t] a_no_disable   FAILED", $time);

  initial begin
    for (int i = 0; i < 6; i++) begin
      rst_n = rst_v[i];
      req   = req_v[i];
      ack   = ack_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
