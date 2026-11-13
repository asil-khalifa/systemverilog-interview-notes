// compile order: alu_pkg.sv  alu.sv  alu_sva.sv  tb_alu_sva.sv
module tb_alu_sva;
  import alu_pkg::*;

  logic       clk      = 0;
  logic       rst_n    = 1;
  logic       valid_in = 0;
  logic [7:0] a        = '0;
  logic [7:0] b        = '0;
  alu_op_e    op       = ALU_ADD;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  bind alu alu_sva u_alu_sva (.*);

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;
    @(negedge clk);  rst_n = 1;                                      // time 10

    @(negedge clk);  valid_in = 1;  a = 8'd200;  b = 8'd100;         // time 20
                     op = ALU_ADD;

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     a = 8'h0F;  op = ALU_NOT;                       // time 30

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     valid_in = 0;                                   // time 40

    @(negedge clk);  $display("[%0t] valid_out=%b result=%0d", $time, valid_out, result);
                     $finish;                                        // time 50
  end

endmodule
