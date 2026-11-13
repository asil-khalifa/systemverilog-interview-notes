// compile order: counter.sv  counter_sva.sv  tb_counter_sva.sv
module tb_counter_sva;

  logic       clk   = 0;
  logic       rst_n = 1;
  logic       en    = 0;
  logic [3:0] count;

  counter dut (.*);

  bind counter counter_sva u_counter_sva (.*);

  always #5 clk = ~clk;

  initial begin
    #1 rst_n = 0;
    @(negedge clk);                    // time 10
    rst_n = 1;
    en    = 1;
    repeat (17) @(negedge clk);        // 17 enabled clock edges: 15, 25, ... 175
    en = 0;                            // time 180
    repeat (2) @(negedge clk);         // time 200
    $display("[%0t] count=%0d", $time, count);
    $finish;
  end

endmodule
