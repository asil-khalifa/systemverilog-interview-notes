module ex10_row_col_sums;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int col;

  initial begin
    foreach (m[i]) $display("row %0d total = %0d", i, m[i].sum());

    for (int j = 0; j < $size(m, 2); j++) begin
      col = 0;
      for (int i = 0; i < $size(m, 1); i++) col += m[i][j];
      $display("column %0d total = %0d", j, col);
    end
  end

endmodule
