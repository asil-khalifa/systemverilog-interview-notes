module tb_loop_foreach;

  int         arr [5]  = '{3, 8, 1, 6, 4};
  int         rev [3:1] = '{10, 20, 30};
  int         q [$]    = {7, 8};
  int         aa [string] = '{"b": 2, "a": 1};
  logic [3:0] nib      = 4'b1010;
  string      s        = "SV";
  int         max_val, max_idx;

  initial begin
    max_val = arr[0];
    max_idx = 0;
    foreach (arr[i])
      if (arr[i] > max_val) begin
        max_val = arr[i];
        max_idx = i;
      end
    $display("1. largest is %0d at index %0d", max_val, max_idx);

    $write("2. fixed [3:1] :");
    foreach (rev[i]) $write(" rev[%0d]=%0d", i, rev[i]);
    $display("");

    $write("3. queue       :");
    foreach (q[i]) $write(" q[%0d]=%0d", i, q[i]);
    $display("");

    $write("4. associative :");
    foreach (aa[k]) $write(" aa[%s]=%0d", k, aa[k]);
    $display("");

    $write("5. packed bits :");
    foreach (nib[i]) $write(" nib[%0d]=%b", i, nib[i]);
    $display("");

    $write("6. string      :");
    foreach (s[i]) $write(" s[%0d]=%c", i, s[i]);
    $display("");
  end

endmodule
