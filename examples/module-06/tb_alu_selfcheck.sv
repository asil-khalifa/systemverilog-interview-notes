// Compile order: alu_pkg.sv, alu.sv, alu_tb_pkg.sv (includes alu_txn.sv), this file
module tb_alu_selfcheck;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  // ---------------- DUT connections ----------------
  logic       clk = 0;
  logic       rst_n;
  logic       valid_in;
  logic [7:0] a, b;
  alu_op_e    op;
  logic       valid_out;
  logic [8:0] result;

  alu dut (.*);

  always #5 clk = ~clk;

  // ---------------- bookkeeping ----------------
  int unsigned n_txn;         // transactions checked
  int unsigned n_err;         // mismatches found
  bit [7:0]    op_seen;       // one bit per opcode: a hand-made coverage record
  alu_txn      t;

  // ---------------- drive one transaction and check the response ----------------
  task automatic drive_and_check(alu_txn txn);
    logic [8:0] expected;

    @(negedge clk);                       // drive away from the sampling edge
    a        = txn.a;
    b        = txn.b;
    op       = txn.op;
    valid_in = 1'b1;

    @(negedge clk);                       // the DUT sampled at the posedge in between
    valid_in   = 1'b0;
    txn.result = result;                  // ACTUAL  : captured from the DUT
    expected   = alu_predict(txn);        // EXPECTED: from the reference model

    n_txn++;
    op_seen[txn.op] = 1'b1;

    if (valid_out !== 1'b1 || txn.result !== expected) begin
      n_err++;
      $error("[%0t] MISMATCH {%s} expected=0x%h valid_out=%b",
             $time, txn.convert2string(), expected, valid_out);
    end
  endtask

  // ---------------- a directed transaction: every value chosen by hand ----------------
  task automatic directed(alu_op_e op_i, bit [7:0] a_i, bit [7:0] b_i);
    alu_txn d = new();
    d.id = n_txn;
    d.op = op_i;
    d.a  = a_i;
    d.b  = b_i;
    drive_and_check(d);
  endtask

  // ---------------- the test ----------------
  initial begin
    // reset
    rst_n    = 1'b0;
    valid_in = 1'b0;
    a        = '0;
    b        = '0;
    op       = ALU_ADD;
    repeat (2) @(posedge clk);
    if (valid_out !== 1'b0 || result !== 9'd0) begin
      n_err++;
      $error("[%0t] outputs not zero during reset", $time);
    end
    rst_n = 1'b1;

    // directed corner cases
    directed(ALU_ADD, 8'hFF, 8'hFF);
    directed(ALU_ADD, 8'h00, 8'h00);
    directed(ALU_SUB, 8'h00, 8'hFF);
    directed(ALU_SUB, 8'h7F, 8'h7F);
    directed(ALU_SHL, 8'h80, 8'h00);
    directed(ALU_SHR, 8'h01, 8'h00);

    // constrained-random
    repeat (200) begin
      t    = new();
      t.id = n_txn;
      if (!t.randomize()) $fatal(1, "randomize() failed");
      drive_and_check(t);
    end

    // end-of-test report
    $display("transactions : %0d", n_txn);
    $display("opcodes seen : %0d of 8", $countones(op_seen));
    $display("errors       : %0d", n_err);
    if (n_err == 0 && n_txn > 0 && $countones(op_seen) == 8) $display("TEST PASSED");
    else                                                     $display("TEST FAILED");
    $finish;
  end

endmodule
