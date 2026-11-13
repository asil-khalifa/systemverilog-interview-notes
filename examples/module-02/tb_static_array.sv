module tb_static_array;

  int         a [5];                          // indices 0 to 4
  int         b [5] = '{10, 20, 30, 40, 50};
  logic [7:0] mem [0:3];
  int         idx;

  initial begin
    $display("1. defaults: a[0]=%0d  mem[0]=%h", a[0], mem[0]);

    a    = '{default: 7};
    a[2] = 99;
    $display("2. a = %p", a);

    a    = b;                 // whole-array copy
    a[0] = -1;
    $display("3. a[0]=%0d  b[0]=%0d", a[0], b[0]);

    $display("4. a == b : %b    a[1:3] == b[1:3] : %b", a == b, a[1:3] == b[1:3]);
    $display("5. $size(a) = %0d", $size(a));

    foreach (mem[i]) mem[i] = 8'h10 + i;
    $display("6. mem[3]=%h  mem[1][0]=%b", mem[3], mem[1][0]);

    idx = 9;
    $display("7. out of range: a[9]=%0d  mem[9]=%h", a[idx], mem[idx]);
  end

endmodule
