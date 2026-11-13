module ex01_reverse_bits;

  function automatic bit [7:0] reverse8(bit [7:0] d);
    bit [7:0] r;
    for (int i = 0; i < 8; i++) r[i] = d[7 - i];
    return r;
  endfunction

  initial begin
    $display("%b -> %b", 8'b1011_0001, reverse8(8'b1011_0001));
    $display("%b -> %b", 8'b0000_0001, reverse8(8'b0000_0001));
  end

endmodule
