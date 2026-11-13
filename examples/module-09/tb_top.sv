module tb_top;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  // ---------------- clock ----------------
  logic clk = 0;
  always #5 clk = ~clk;

  // ---------------- interface and DUT ----------------
  alu_if aif (clk);

  alu dut (
    .clk       (clk),
    .rst_n     (aif.rst_n),
    .valid_in  (aif.valid_in),
    .a         (aif.a),
    .b         (aif.b),
    .op        (aif.op),
    .valid_out (aif.valid_out),
    .result    (aif.result)
  );

  // ---------------- reset ----------------
  initial begin
    aif.rst_n = 1'b0;
    repeat (2) @(negedge clk);
    aif.rst_n = 1'b1;
  end

  // ---------------- test ----------------
  initial begin
    alu_test          test;
    alu_arith_test    arith_test;
    alu_directed_test directed_test;
    string            test_name;

    if (!$value$plusargs("TEST=%s", test_name)) test_name = "alu_test";

    case (test_name)
      "alu_test"          : test = new(aif);
      "alu_arith_test"    : begin arith_test = new(aif);    test = arith_test;    end
      "alu_directed_test" : begin directed_test = new(aif); test = directed_test; end
      default             : $fatal(1, "Unknown test name '%s'", test_name);
    endcase

    test.run();
    $finish;
  end

endmodule
