module tb_p06_ascending;

  class asc_gen;
    rand bit [7:0] a[6];

    constraint asc_c { foreach (a[i]) if (i > 0) a[i] > a[i-1]; }
  endclass

  asc_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 6; i++)
        if (g.a[i] <= g.a[i-1]) errors++;
    end
    $display("p06: sample a=%p", g.a);
    $display("p06: errors=%0d", errors);
  end

endmodule
