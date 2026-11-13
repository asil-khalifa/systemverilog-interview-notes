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
  logic [AW:0]      count;
  logic             do_wr, do_rd;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign do_wr = wr_en && !full;      // a write when full is ignored
  assign do_rd = rd_en && !empty;     // a read when empty is ignored

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
      case ({do_wr, do_rd})
        2'b10  : count <= count + 1'b1;
        2'b01  : count <= count - 1'b1;
        default: ;                    // both or neither: count unchanged
      endcase
    end
  end
endmodule

module fx02_sync_fifo_tb;

  logic       clk = 0;
  logic       rst_n, wr_en, rd_en;
  logic [7:0] din, dout;
  logic       full, empty;

  logic [7:0] model [$];              // reference model
  int         checks, errors;

  sync_fifo dut (.*);

  always #5 clk = ~clk;

  // Stimulus changes on the falling edge, so it is stable at the rising edge.
  task automatic write(input logic [7:0] data);
    @(negedge clk);
    wr_en = 1;
    din   = data;
    if (!full) model.push_back(data); // the DUT will accept it only if not full
    @(negedge clk);
    wr_en = 0;
  endtask

  task automatic read();
    logic [7:0] expected;
    bit         accepted;
    @(negedge clk);
    rd_en    = 1;
    accepted = !empty;
    if (accepted) expected = model.pop_front();
    @(negedge clk);                   // dout was updated at the rising edge in between
    rd_en = 0;
    if (accepted) begin
      checks++;
      if (dout !== expected) begin
        errors++;
        $display("[%0t] FAIL: dout=%h expected=%h", $time, dout, expected);
      end
    end
  endtask

  initial begin
    rst_n = 0;  wr_en = 0;  rd_en = 0;  din = '0;
    repeat (2) @(negedge clk);
    rst_n = 1;
    $display("after reset    : full=%b empty=%b", full, empty);

    for (int i = 0; i < 16; i++) write(8'hA0 + i);
    $display("after 16 writes: full=%b empty=%b", full, empty);

    write(8'hFF);                     // overflow attempt: must be ignored
    repeat (16) read();
    $display("after 16 reads : full=%b empty=%b", full, empty);

    read();                           // underflow attempt: must be ignored
    write(8'h11);
    read();

    $display("checks=%0d errors=%0d model_left=%0d", checks, errors, model.size());
    if (errors == 0 && checks == 17 && model.size() == 0) $display("TEST PASSED");
    else                                                  $display("TEST FAILED");
    $finish;
  end

endmodule
