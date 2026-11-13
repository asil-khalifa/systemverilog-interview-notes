module tb_task_basic;

  logic       clk = 0;
  logic       valid = 0;
  logic [7:0] data;

  always #5 clk = ~clk;

  // A task with an input argument and timing control
  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  // A task that drives module-level signals over two clock cycles
  task automatic send_byte(input logic [7:0] value);
    @(posedge clk);
    valid <= 1'b1;
    data  <= value;
    @(posedge clk);
    valid <= 1'b0;
  endtask

  // A task with no timing control: legal, but it should have been a void function
  task automatic show(input string msg);
    $display("[%0t] %s", $time, msg);
  endtask

  // A simple monitor
  always @(posedge clk)
    if (valid) $display("[%0t] monitor saw data = %h", $time, data);

  initial begin
    show("start");
    wait_cycles(2);
    show("after wait_cycles(2)");
    send_byte(8'hA5);
    #1;
    show("after send_byte");
    $finish;
  end

endmodule
