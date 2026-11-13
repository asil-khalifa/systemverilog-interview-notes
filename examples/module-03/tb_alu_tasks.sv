module tb_alu_tasks;
  import alu_pkg::*;

  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  int unsigned pass_cnt, fail_cnt;

  alu dut (.*);

  always #5 clk = ~clk;

  // ---------- low-level tasks ----------
  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task automatic reset_dut();
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    wait_cycles(2);                  // a task calling a task
    @(negedge clk);
    rst_n = 1'b1;
  endtask

  task automatic drive_op(input  logic [7:0] a_i,
                          input  logic [7:0] b_i,
                          input  alu_op_e    op_i,
                          output logic [8:0] res);
    @(negedge clk);
    a        = a_i;
    b        = b_i;
    op       = op_i;
    valid_in = 1'b1;
    @(negedge clk);
    valid_in = 1'b0;
    res      = result;
  endtask

  // ---------- functions ----------
  function automatic logic [8:0] alu_model(logic [7:0] a_i,
                                           logic [7:0] b_i,
                                           alu_op_e    op_i);
    case (op_i)
      ALU_ADD: return {1'b0, a_i} + {1'b0, b_i};
      ALU_SUB: return {1'b0, a_i} - {1'b0, b_i};
      ALU_AND: return {1'b0, a_i & b_i};
      ALU_OR : return {1'b0, a_i | b_i};
      ALU_XOR: return {1'b0, a_i ^ b_i};
      ALU_NOT: return {1'b0, ~a_i};
      ALU_SHL: return {a_i, 1'b0};
      ALU_SHR: return {2'b00, a_i[7:1]};
      default: return 'x;
    endcase
  endfunction

  function automatic void check(alu_op_e op_i, logic [8:0] actual, logic [8:0] expected);
    if (actual !== expected) begin
      fail_cnt++;
      $display("[%0t] FAIL %s: actual=%0d expected=%0d",
               $time, op_i.name(), actual, expected);
    end
    else begin
      pass_cnt++;
      $display("[%0t] PASS %s: result=%0d", $time, op_i.name(), actual);
    end
  endfunction

  // ---------- high-level task ----------
  task automatic do_op(input logic [7:0] a_i, input logic [7:0] b_i, input alu_op_e op_i);
    logic [8:0] actual;
    drive_op(a_i, b_i, op_i, actual);                  // task calling a task
    check(op_i, actual, alu_model(a_i, b_i, op_i));    // task calling functions
  endtask

  // ---------- the test ----------
  initial begin
    reset_dut();
    do_op(8'd200, 8'd100, ALU_ADD);
    do_op(8'd5,   8'd10,  ALU_SUB);
    do_op(8'hF0,  8'h3C,  ALU_AND);
    do_op(8'h81,  8'h00,  ALU_SHL);
    do_op(8'hAA,  8'h00,  ALU_NOT);
    $display("[%0t] %0d passed, %0d failed", $time, pass_cnt, fail_cnt);
    $finish;
  end

endmodule
