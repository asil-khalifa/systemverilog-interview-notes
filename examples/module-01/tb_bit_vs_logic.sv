module tb_bit_vs_logic;

  logic       clk = 0;
  logic [3:0] count_logic;   // four-state counter, no reset
  bit   [3:0] count_bit;     // two-state counter, no reset

  always #5 clk = ~clk;

  always_ff @(posedge clk) count_logic <= count_logic + 1'b1;
  always_ff @(posedge clk) count_bit   <= count_bit   + 1'b1;

  initial begin
    repeat (3) @(negedge clk);
    $display("count_logic = %b   count_bit = %b", count_logic, count_bit);
    $finish;
  end

endmodule
