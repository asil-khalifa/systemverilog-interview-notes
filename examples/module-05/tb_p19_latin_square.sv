module tb_p19_latin_square;

  class latin_gen;
    rand bit [2:0] m[4][4];

    constraint range_c { foreach (m[i, j]) m[i][j] inside {[1:4]}; }
    constraint uniq_c {
      foreach (m[i, j])
        foreach (m[r, c]) {
          (r == i && c > j) -> m[i][j] != m[r][c];     // same row, later column
          (c == j && r > i) -> m[i][j] != m[r][c];     // same column, later row
        }
    }
  endclass

  latin_gen g;
  int       errors;

  initial begin
    g = new();
    repeat (50) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) begin
          if (g.m[i][j] < 1 || g.m[i][j] > 4) errors++;
          for (int k = j + 1; k < 4; k++) if (g.m[i][j] == g.m[i][k]) errors++;
          for (int k = i + 1; k < 4; k++) if (g.m[i][j] == g.m[k][j]) errors++;
        end
    end
    foreach (g.m[i]) $display("p19: sample row %0d = %p", i, g.m[i]);
    $display("p19: errors=%0d", errors);
  end

endmodule
