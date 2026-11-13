module tb_dynamic_array;

  int d [];
  int e [];
  int f [4] = '{1, 2, 3, 4};

  initial begin
    $display("1. size = %0d", d.size());

    d = new[4];
    foreach (d[i]) d[i] = (i + 1) * 10;
    $display("2. d = %p  size = %0d", d, d.size());

    d = new[6](d);                       // grow, keep contents
    $display("3. d = %p", d);

    d = new[2](d);                       // shrink, keep the first two
    $display("4. d = %p", d);

    d = new[3];                          // no source: contents are lost
    $display("5. d = %p", d);

    e    = d;                            // independent copy, e is resized to 3
    e[0] = 5;
    $display("6. d[0] = %0d  e[0] = %0d", d[0], e[0]);

    d = '{7, 8, 9, 10, 11};              // the pattern sets the size
    $display("7. size = %0d", d.size());

    d = f;                               // fixed-size array copied into a dynamic array
    $display("8. d = %p", d);

    d.delete();
    $display("9. size = %0d", d.size());
  end

endmodule
