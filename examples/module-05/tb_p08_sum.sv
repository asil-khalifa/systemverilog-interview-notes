module tb_p08_sum;

  class sum_gen;
    rand bit [7:0] a[5];

    constraint each_c { foreach (a[i]) a[i] inside {[1:40]}; }
    constraint sum_c  { a.sum() with (int'(item)) == 100; }
  endclass

  sum_gen g;
  int     errors, total;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      total = 0;
      foreach (g.a[i]) begin
        total += g.a[i];
        if (g.a[i] < 1 || g.a[i] > 40) errors++;
      end
      if (total != 100) errors++;
    end
    $display("p08: sample a=%p", g.a);
    $display("p08: errors=%0d", errors);
  end

endmodule
