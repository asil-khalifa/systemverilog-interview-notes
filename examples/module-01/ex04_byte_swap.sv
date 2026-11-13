module ex04_byte_swap;

  logic [31:0]     w = 32'h1122_3344;
  logic [31:0]     r1, r2;
  logic [3:0][7:0] v, r3;

  initial begin
    // 1. concatenation of part-selects
    r1 = {w[7:0], w[15:8], w[23:16], w[31:24]};

    // 2. streaming operator, 8 bits at a time, right to left
    r2 = {<<8{w}};

    // 3. packed array of bytes and a loop
    v = w;
    for (int i = 0; i < 4; i++) r3[i] = v[3 - i];

    $display("%h %h %h", r1, r2, r3);
  end

endmodule
