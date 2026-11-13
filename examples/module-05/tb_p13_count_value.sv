module tb_p13_count_value;

  class cnt_gen;
    rand bit [3:0] a[10];

    constraint three_fives_c { a.sum() with (int'(item == 5)) == 3; }
  endclass

  cnt_gen g;
  int     errors, fives;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      fives = 0;
      foreach (g.a[i]) if (g.a[i] == 5) fives++;
      if (fives != 3) errors++;
    end
    $display("p13: sample a=%p", g.a);
    $display("p13: errors=%0d", errors);
  end

endmodule
