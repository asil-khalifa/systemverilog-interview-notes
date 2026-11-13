module ex07_serial;

  logic clk    = 0;
  logic sdata  = 0;
  logic svalid = 0;

  always #5 clk = ~clk;

  task automatic send_serial(input bit [7:0] data);
    for (int i = 0; i < 8; i++) begin
      @(negedge clk);              // drive on the falling edge
      svalid = 1'b1;
      sdata  = data[i];
    end
    @(negedge clk);
    svalid = 1'b0;
  endtask

  task automatic recv_serial(output bit [7:0] data);
    int i;
    i = 0;
    while (i < 8) begin
      @(posedge clk);              // sample on the rising edge
      if (svalid) begin
        data[i] = sdata;
        i++;
      end
    end
  endtask

  bit [7:0] rx;

  initial begin
    fork
      send_serial(8'hA5);
      recv_serial(rx);
    join
    $display("[%0t] sent a5, received %h", $time, rx);
    $finish;
  end

endmodule
