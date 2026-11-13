module sync_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             wr_en,
  input  logic             rd_en,
  input  logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout,
  output logic             full,
  output logic             empty
);

  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW-1:0]    wr_ptr, rd_ptr;
  logic [AW:0]      count;              // 0 .. DEPTH
  logic             do_wr, do_rd;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign do_wr = wr_en && !full;
  assign do_rd = rd_en && !empty;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
      dout   <= '0;
    end
    else begin
      if (do_wr) begin
        mem[wr_ptr] <= din;
        wr_ptr      <= wr_ptr + 1'b1;
      end
      if (do_rd) begin
        dout   <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
      if (do_wr && !do_rd)      count <= count + 1'b1;
      else if (do_rd && !do_wr) count <= count - 1'b1;
    end
  end

endmodule
