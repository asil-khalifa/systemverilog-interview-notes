module tb_p07_no_consecutive;

  class seq_gen;
    rand bit [1:0] a[10];
    rand bit       b[12];

    constraint no_pair_c {
      foreach (a[i]) if (i > 0) a[i] != a[i-1];
    }
    constraint no_triple_c {
      foreach (b[i]) if (i > 1) !(b[i] == b[i-1] && b[i] == b[i-2]);
    }
  endclass

  seq_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 10; i++)
        if (g.a[i] == g.a[i-1]) errors++;
      for (int i = 2; i < 12; i++)
        if (g.b[i] == g.b[i-1] && g.b[i] == g.b[i-2]) errors++;
    end
    $display("p07: sample a=%p b=%p", g.a, g.b);
    $display("p07: errors=%0d", errors);
  end

endmodule
