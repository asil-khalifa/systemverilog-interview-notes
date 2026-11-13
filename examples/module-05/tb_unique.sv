module tb_unique;

  class uniq_demo;
    rand bit [2:0] perm[8];
    rand bit [3:0] a, b, c;

    constraint perm_c    { unique {perm}; }
    constraint scalars_c { unique {a, b, c}; a < 3; b < 3; c < 3; }
  endclass

  uniq_demo u;
  int       seen[8];
  bit       ok;

  initial begin
    u = new();
    repeat (3) begin
      if (!u.randomize()) $fatal(1, "randomize failed");

      seen = '{default: 0};
      foreach (u.perm[i]) seen[u.perm[i]]++;
      ok = 1;
      foreach (seen[v]) if (seen[v] != 1) ok = 0;

      $display("perm=%p  is a permutation of 0..7: %s", u.perm, ok ? "yes" : "NO");
      $display("a+b+c=%0d", u.a + u.b + u.c);
    end
  end

endmodule
