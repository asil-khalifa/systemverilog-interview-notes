module tb_cb_skew;

  logic       clk = 0;
  logic [3:0] count = 0;

  always #5 clk = ~clk;

  // A stand-in for the DUT: a register that changes at every rising edge
  always @(posedge clk) count <= count + 1'b1;

  clocking cb_step @(posedge clk);
    input #1step count;          // the value just before the edge
  endclocking

  clocking cb_zero @(posedge clk);
    input #0 count;              // the value after the edge has been processed
  endclocking

  initial begin
    repeat (3) begin
      @(negedge clk);            // look at the samples in the quiet middle of the cycle
      $display("[%0t] count now = %0d   #1step sample = %0d   #0 sample = %0d",
               $time, count, cb_step.count, cb_zero.count);
    end
    $finish;
  end

endmodule
