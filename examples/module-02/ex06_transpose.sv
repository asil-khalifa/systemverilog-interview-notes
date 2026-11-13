module ex06_transpose;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int t [3][2];

  initial begin
    foreach (m[i, j]) t[j][i] = m[i][j];
    foreach (t[i]) $display("%0d %0d", t[i][0], t[i][1]);
  end

endmodule
