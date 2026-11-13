module tb_p15_gray;

  class gray_gen;
    rand bit [3:0] g[8];
    rand bit [7:0] x, y;

    constraint step_c { foreach (g[i]) if (i > 0) $countones(g[i] ^ g[i-1]) == 1; }
    constraint uniq_c { unique {g}; }
    constraint dist_c { $countones(x ^ y) == 2; }
  endclass

  gray_gen h;
  int      errors;

  initial begin
    h = new();
    repeat (200) begin
      if (!h.randomize()) $fatal(1, "randomize failed");
      for (int i = 1; i < 8; i++)
        if ($countones(h.g[i] ^ h.g[i-1]) != 1) errors++;
      for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 8; j++)
          if (h.g[i] == h.g[j]) errors++;
      if ($countones(h.x ^ h.y) != 2) errors++;
    end
    $display("p15: sample g=%p", h.g);
    $display("p15: errors=%0d", errors);
  end

endmodule
