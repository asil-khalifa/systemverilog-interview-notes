// compile order: handshake_sva.sv  tb_handshake_sva.sv
module tb_handshake_sva;

  logic       clk = 0;
  logic       rst_n, valid, ready;
  logic [7:0] data;

  // stimulus for cycles 0..11 (cycle k is the posedge at time 10k+5)
  bit [0:11]  rst_v   = 12'b0111_1111_1111;
  bit [0:11]  valid_v = 12'b0111_0100_1110;
  bit [0:11]  ready_v = 12'b0001_0000_0110;
  logic [7:0] data_v [12] = '{8'h00, 8'hA1, 8'hA1, 8'hA1, 8'h00, 8'hB2,
                              8'hB2, 8'h00, 8'hC3, 8'hC4, 8'hC4, 8'h00};

  handshake_sva u_sva (.*);

  always #5 clk = ~clk;

  initial begin
    for (int i = 0; i < 12; i++) begin
      rst_n = rst_v[i];
      valid = valid_v[i];
      ready = ready_v[i];
      data  = data_v[i];
      @(negedge clk);
    end
    $finish;
  end

endmodule
