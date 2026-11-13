// compile order: sync_fifo.sv  sync_fifo_sva.sv  tb_fifo_sva.sv
module tb_fifo_sva;

  logic       clk   = 0;
  logic       rst_n = 1;
  logic       wr_en = 0;
  logic       rd_en = 0;
  logic [7:0] din   = '0;
  logic [7:0] dout;
  logic       full, empty;

  sync_fifo dut (.*);

  // attach the checker to every instance of sync_fifo; 'count' is internal to the FIFO
  bind sync_fifo sync_fifo_sva #(.DEPTH(DEPTH)) u_sync_fifo_sva (
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en), .din(din),
    .full(full), .empty(empty), .count(count)
  );

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;                      // assert reset at time 1
    @(negedge clk);  rst_n = 1;        // release at time 10

    // 17 writes into a 16-entry FIFO: the last one is attempted while full
    for (int i = 0; i < 17; i++) begin
      wr_en = 1;
      din   = 8'hA0 + i;
      @(negedge clk);
    end
    wr_en = 0;

    rd_en = 1;                         // one read
    @(negedge clk);
    rd_en = 0;
    @(negedge clk);

    $display("[%0t] full=%b empty=%b dout=%h", $time, full, empty, dout);
    $finish;
  end

endmodule
