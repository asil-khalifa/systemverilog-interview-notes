module tb_func_vs_task;

  logic clk = 0;
  always #5 clk = ~clk;

  // Function: answer available immediately, usable inside an expression
  function automatic logic [8:0] add9(logic [7:0] x, logic [7:0] y);
    return {1'b0, x} + {1'b0, y};
  endfunction

  // Task: same calculation, but the answer is delivered one clock cycle later,
  // the way the real ALU delivers it
  task automatic add9_clocked(input  logic [7:0] x,
                              input  logic [7:0] y,
                              output logic [8:0] sum);
    @(posedge clk);
    sum = {1'b0, x} + {1'b0, y};
  endtask

  logic [8:0] r;

  initial begin
    r = add9(8'd200, 8'd100);
    $display("[%0t] function result = %0d", $time, r);

    if (add9(8'd255, 8'd1) == 9'd256)
      $display("[%0t] a function call can sit inside a condition", $time);

    add9_clocked(8'd200, 8'd100, r);
    $display("[%0t] task result     = %0d", $time, r);
    $finish;
  end

endmodule
