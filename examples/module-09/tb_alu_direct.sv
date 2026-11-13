module tb_alu_direct;
  import alu_pkg::*;

  logic        clk = 0;
  logic        rst_n;
  logic        valid_in;
  logic [7:0]  a, b;
  alu_op_e     op;
  logic        valid_out;
  logic [8:0]  result;
  int unsigned errors;

  alu dut (.*);

  always #5 clk = ~clk;

  task automatic apply(input logic [7:0] a_i,
                       input logic [7:0] b_i,
                       input alu_op_e    op_i,
                       input logic [8:0] exp_i);
    @(negedge clk);
    a        = a_i;
    b        = b_i;
    op       = op_i;
    valid_in = 1'b1;
    @(negedge clk);
    valid_in = 1'b0;
    if (valid_out !== 1'b1 || result !== exp_i) begin
      errors++;
      $display("[%0t] FAIL %s a=%0d b=%0d result=%0d expected=%0d",
               $time, op_i.name(), a_i, b_i, result, exp_i);
    end
    else
      $display("[%0t] PASS %s a=%0d b=%0d result=%0d",
               $time, op_i.name(), a_i, b_i, result);
  endtask

  initial begin
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    apply(8'd200, 8'd100, ALU_ADD, 9'd300);
    apply(8'd5,   8'd10,  ALU_SUB, 9'd507);
    apply(8'hF0,  8'h3C,  ALU_AND, 9'h030);
    apply(8'h81,  8'h00,  ALU_SHL, 9'h102);

    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED with %0d errors", errors);
    $finish;
  end

endmodule
