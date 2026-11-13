module ex02_histogram;

  class len_gen;
    rand bit [3:0] len;
    constraint c { len dist {1 := 30, [2:9] :/ 40, 10 := 30}; }
  endclass

  len_gen g;
  int     hist[int];           // associative array: value -> count
  int     n = 2000;
  int     errors;

  initial begin
    g = new();
    repeat (n) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      hist[g.len]++;
      if (!(g.len inside {[1:10]})) errors++;
    end
    foreach (hist[v])
      $display("len=%2d : %4d  (%0.1f%%)", v, hist[v], 100.0 * hist[v] / n);
    $display("ex02: errors=%0d", errors);
  end

endmodule
