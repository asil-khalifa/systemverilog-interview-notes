module tb_p21_queens;

  class queens_gen;
    rand bit [2:0] col[8];                 // col[r] = column of the queen in row r

    constraint cols_c { unique {col}; }    // no two queens in the same column
    constraint diag_c {
      foreach (col[i])
        foreach (col[j])
          if (i < j) {
            int'(col[i]) - int'(col[j]) != i - j;     // not on the same diagonal
            int'(col[i]) - int'(col[j]) != j - i;     // not on the same anti-diagonal
          }
    }
  endclass

  queens_gen g;
  int        errors, dc;

  initial begin
    g = new();
    if (!g.randomize()) $fatal(1, "randomize failed");
    for (int i = 0; i < 8; i++)
      for (int j = i + 1; j < 8; j++) begin
        dc = int'(g.col[i]) - int'(g.col[j]);
        if (dc == 0 || dc == i - j || dc == j - i) errors++;
      end
    foreach (g.col[r]) begin
      for (int c = 0; c < 8; c++) $write("%s", (g.col[r] == c) ? " Q" : " .");
      $write("\n");
    end
    $display("p21: errors=%0d", errors);
  end

endmodule
