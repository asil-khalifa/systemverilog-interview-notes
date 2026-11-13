module ex01_count_ones;

  bit [7:0] data = 8'b1011_0010;
  int       count;

  initial begin
    count = 0;
    for (int i = 0; i < $bits(data); i++)
      count += data[i];
    $display("%b has %0d ones ($countones says %0d)", data, count, $countones(data));
  end

endmodule
