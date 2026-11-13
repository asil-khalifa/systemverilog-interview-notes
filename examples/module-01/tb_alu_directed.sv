module tb_alu_directed;
  import alu_pkg::*;

  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  always #5 clk = ~clk;

  initial begin
    rst_n    = 0;
    valid_in = 0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(posedge clk);
    rst_n = 1;

    @(negedge clk);
    a        = 8'd200;
    b        = 8'd100;
    op       = ALU_ADD;
    valid_in = 1;

    @(negedge clk);
    valid_in = 0;
    if (valid_out !== 1'b1 || result !== 9'd300)
      $error("[%0t] FAIL: %0d + %0d gave %0d (valid_out=%b)", $time, a, b, result, valid_out);
    else
      $display("[%0t] PASS: %0d + %0d = %0d", $time, a, b, result);

    $finish;
  end

endmodule
