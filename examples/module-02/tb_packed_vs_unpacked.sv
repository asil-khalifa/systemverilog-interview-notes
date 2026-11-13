module tb_packed_vs_unpacked;

  logic [3:0][7:0] p;           // packed: one 32-bit vector made of 4 bytes
  logic [7:0]      u [4];       // unpacked: 4 separate bytes, indices 0 to 3

  initial begin
    p = 32'hA1B2_C3D4;                       // assign as a number
    u = '{8'hA1, 8'hB2, 8'hC3, 8'hD4};       // assign per element

    $display("1. p[3]=%h p[0]=%h   u[0]=%h u[3]=%h", p[3], p[0], u[0], u[3]);
    $display("2. p + 1 = %h", p + 1);        // legal only for the packed array

    foreach (p[i]) $write("p[%0d]=%h ", i, p[i]);
    $display("");
    foreach (u[i]) $write("u[%0d]=%h ", i, u[i]);
    $display("");

    $display("3. $bits(p)=%0d  $bits(u)=%0d  $size(p)=%0d  $size(u)=%0d",
             $bits(p), $bits(u), $size(p), $size(u));
  end

endmodule
