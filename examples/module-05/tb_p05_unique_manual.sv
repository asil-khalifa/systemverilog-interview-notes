module tb_p05_unique_manual;

  class uniq_gen;
    rand bit [3:0] a[8];

    constraint uniq_c {
      foreach (a[i])
        foreach (a[j])
          if (i < j) a[i] != a[j];
    }
  endclass

  uniq_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 8; j++)
          if (g.a[i] == g.a[j]) errors++;
    end
    $display("p05: sample a=%p", g.a);
    $display("p05: errors=%0d", errors);
  end

endmodule
