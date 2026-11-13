module tb_task_timing;

  logic clk = 0;
  logic rst_n;
  logic ready = 0;

  always #5 clk = ~clk;

  initial #42 ready = 1;             // "DUT" raises ready at time 42

  task automatic reset_dut(input int cycles);
    rst_n = 1'b0;
    repeat (cycles) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    $display("[%0t] reset released", $time);
  endtask

  task automatic wait_ready();
    $display("[%0t] waiting for ready", $time);
    wait (ready);
    $display("[%0t] ready is high", $time);
    @(posedge clk);
    $display("[%0t] aligned to the clock", $time);
  endtask

  initial begin
    reset_dut(2);
    wait_ready();
    wait_ready();
    #3;
    $display("[%0t] end", $time);
    $finish;
  end

endmodule
