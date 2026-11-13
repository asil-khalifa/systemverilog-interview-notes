module tb_p11_patterns;

  class pat_gen;
    rand bit b[8];
    rand int a[];
    int      n = 4;

    // value of the pattern 1,2,2,3,3,3,... at position idx
    function automatic int val_at(int idx);
      int v   = 1;
      int end_of_group = 1;                  // number of elements up to and including group v
      while (idx >= end_of_group) begin
        v++;
        end_of_group += v;
      end
      return v;
    endfunction

    constraint alt_c  { foreach (b[i]) b[i] == i % 2; }
    constraint size_c { a.size() == n * (n + 1) / 2; }
    constraint tri_c  { foreach (a[i]) a[i] == val_at(i); }
  endclass

  pat_gen g;

  initial begin
    g = new();
    if (!g.randomize()) $fatal(1, "randomize failed");
    $write("p11: b =");
    foreach (g.b[i]) $write(" %0d", g.b[i]);
    $write("\np11: a =");
    foreach (g.a[i]) $write(" %0d", g.a[i]);
    $write("\n");
  end

endmodule
