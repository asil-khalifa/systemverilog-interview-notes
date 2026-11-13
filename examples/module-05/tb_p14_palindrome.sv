module tb_p14_palindrome;

  class pal_gen;
    rand bit [3:0] a[];

    constraint size_c   { a.size() inside {[5:9]}; }
    constraint digit_c  { foreach (a[i]) a[i] < 10; }
    constraint mirror_c { foreach (a[i]) a[i] == a[a.size() - 1 - i]; }
  endclass

  pal_gen g;
  int     errors, n;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      n = g.a.size();
      if (n < 5 || n > 9) errors++;
      for (int i = 0; i < n; i++)
        if (g.a[i] != g.a[n - 1 - i] || g.a[i] > 9) errors++;
    end
    $display("p14: sample a=%p", g.a);
    $display("p14: errors=%0d", errors);
  end

endmodule
