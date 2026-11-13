module tb_p09_even_odd_index;

  class eo_gen;
    rand bit [7:0] a[8];

    constraint parity_c { foreach (a[i]) a[i] % 2 == i % 2; }
  endclass

  eo_gen g;
  int    errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      foreach (g.a[i])
        if ((g.a[i] % 2) != (i % 2)) errors++;
    end
    $display("p09: sample a=%p", g.a);
    $display("p09: errors=%0d", errors);
  end

endmodule
