module tb_ref_wait;

  logic clk   = 0;
  logic ready = 0;
  bit   timed_out;

  always #5 clk = ~clk;

  initial #42 ready = 1;

  // WRONG: sig is a copy of the signal taken when the task was called
  task automatic wait_by_value(input logic sig, input int max_cycles, output bit timeout);
    timeout = 1;
    for (int i = 1; i <= max_cycles; i++) begin
      @(posedge clk);
      if (sig) begin
        $display("[%0t] by value: signal seen after %0d cycles", $time, i);
        timeout = 0;
        return;
      end
    end
    $display("[%0t] by value: timed out after %0d cycles", $time, max_cycles);
  endtask

  // RIGHT: sig is the caller's signal itself
  task automatic wait_by_ref(ref logic sig, input int max_cycles, output bit timeout);
    timeout = 1;
    for (int i = 1; i <= max_cycles; i++) begin
      @(posedge clk);
      if (sig) begin
        $display("[%0t] by ref  : signal seen after %0d cycles", $time, i);
        timeout = 0;
        return;
      end
    end
    $display("[%0t] by ref  : timed out after %0d cycles", $time, max_cycles);
  endtask

  initial begin
    wait_by_value(ready, 6, timed_out);
    $display("        timed_out = %b", timed_out);
    wait_by_ref(ready, 6, timed_out);
    $display("        timed_out = %b", timed_out);
    $finish;
  end

endmodule
