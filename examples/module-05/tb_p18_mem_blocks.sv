module tb_p18_mem_blocks;

  class alloc_gen;
    rand bit [9:0] base[4];        // start address of each block
    rand bit [7:0] blen[4];        // length of each block

    constraint len_c   { foreach (blen[i]) blen[i] inside {[16:128]}; }
    constraint align_c { foreach (base[i]) base[i][3:0] == 4'h0; }
    constraint fit_c   { foreach (base[i]) int'(base[i]) + int'(blen[i]) <= 1024; }
    constraint order_c {
      foreach (base[i])
        if (i > 0) int'(base[i]) >= int'(base[i-1]) + int'(blen[i-1]);
    }
  endclass

  alloc_gen g;
  int       errors;

  initial begin
    g = new();
    repeat (200) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 4; i++) begin
        if (g.blen[i] < 16 || g.blen[i] > 128) errors++;
        if (g.base[i] % 16 != 0)               errors++;
        if (g.base[i] + g.blen[i] > 1024)      errors++;
        for (int j = i + 1; j < 4; j++)        // overlap test for every pair
          if (g.base[i] < g.base[j] + g.blen[j] && g.base[j] < g.base[i] + g.blen[i])
            errors++;
      end
    end
    $display("p18: sample base=%p blen=%p", g.base, g.blen);
    $display("p18: errors=%0d", errors);
  end

endmodule
