import alu_pkg::*;

class alu_checker;

  virtual alu_if.MON vif;
  int unsigned pass_cnt, fail_cnt;

  function new(virtual alu_if.MON vif);
    this.vif = vif;
  endfunction

  // Reference model: the same widths as the DUT (9-bit result)
  function logic [8:0] model(logic [7:0] a, logic [7:0] b, alu_op_e op);
    case (op)
      ALU_ADD: return {1'b0, a} + {1'b0, b};
      ALU_SUB: return {1'b0, a} - {1'b0, b};
      ALU_AND: return {1'b0, a & b};
      ALU_OR : return {1'b0, a | b};
      ALU_XOR: return {1'b0, a ^ b};
      ALU_NOT: return {1'b0, ~a};
      ALU_SHL: return {a, 1'b0};
      ALU_SHR: return {2'b00, a[7:1]};
      default: return 'x;
    endcase
  endfunction

  task run();
    logic [7:0] a, b;
    alu_op_e    op;
    logic [8:0] expected;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid_out) begin
        expected = model(a, b, op);
        if (vif.mon_cb.result !== expected) begin
          fail_cnt++;
          $display("[%0t] FAIL %s a=%0d b=%0d result=%0d expected=%0d",
                   $time, op.name(), a, b, vif.mon_cb.result, expected);
        end
        else begin
          pass_cnt++;
          $display("[%0t] PASS %s a=%0d b=%0d result=%0d",
                   $time, op.name(), a, b, vif.mon_cb.result);
        end
      end
      if (vif.mon_cb.valid_in) begin
        a  = vif.mon_cb.a;
        b  = vif.mon_cb.b;
        op = vif.mon_cb.op;
      end
    end
  endtask

endclass

module ex04_alu_checker;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);
  alu dut (
    .clk       (clk),           .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),  .a         (aif.a),
    .b         (aif.b),         .op        (aif.op),
    .valid_out (aif.valid_out), .result    (aif.result)
  );

  alu_driver  drv;
  alu_checker chk;

  initial begin
    aif.rst_n = 0;  aif.valid_in = 0;  aif.a = '0;  aif.b = '0;  aif.op = ALU_ADD;
    drv = new(aif);
    chk = new(aif);
    repeat (2) @(negedge clk);
    aif.rst_n = 1;

    fork
      chk.run();
    join_none

    drv.drive(8'd255, 8'd1, ALU_ADD);
    drv.drive(8'h80,  8'd0, ALU_SHL);
    drv.drive(8'h0F,  8'd0, ALU_NOT);
    drv.drive(8'd9,   8'd0, ALU_SHR);

    repeat (2) @(posedge clk);
    $display("[%0t] checker: %0d passed, %0d failed", $time, chk.pass_cnt, chk.fail_cnt);
    $finish;
  end

endmodule
