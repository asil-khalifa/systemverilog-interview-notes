module sync_fifo (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       wr_en,
  input  logic       rd_en,
  input  logic [7:0] din,
  output logic [7:0] dout,
  output logic       full,
  output logic       empty
);

  logic [7:0] mem [16];
  logic [3:0] wr_ptr, rd_ptr;
  logic [4:0] count;
  logic       do_wr, do_rd;

  assign full  = (count == 5'd16);
  assign empty = (count == 5'd0);
  assign do_wr = wr_en && !full;
  assign do_rd = rd_en && !empty;

  always_ff @(posedge clk)
    if (do_wr) mem[wr_ptr] <= din;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
      dout   <= '0;
    end
    else begin
      if (do_wr) wr_ptr <= wr_ptr + 1'b1;
      if (do_rd) begin
        dout   <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
      if      (do_wr && !do_rd) count <= count + 1'b1;
      else if (do_rd && !do_wr) count <= count - 1'b1;
    end
  end

endmodule
