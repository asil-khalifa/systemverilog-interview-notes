module tb_multidim;

  int m [2][3] = '{ '{1, 2, 3}, '{4, 5, 6} };
  int row [3];
  int jag [][];
  int total;

  initial begin
    $display("1. m[1][2] = %0d", m[1][2]);

    row = m[0];                               // copy one whole row
    $display("2. row = %p", row);

    foreach (m[i, j]) m[i][j] = m[i][j] * 10;
    foreach (m[i]) $display("3. row %0d : %0d %0d %0d", i, m[i][0], m[i][1], m[i][2]);

    $display("4. rows = %0d, columns = %0d", $size(m, 1), $size(m, 2));

    total = 0;
    for (int i = 0; i < $size(m, 1); i++)
      for (int j = 0; j < $size(m, 2); j++)
        total += m[i][j];
    $display("5. total = %0d", total);

    m    = '{default: 0};
    m[1] = '{7, 8, 9};
    $display("6. m = %p", m);

    // jagged array: every row has a different length
    jag = new[3];
    foreach (jag[i]) begin
      jag[i] = new[i + 1];
      for (int j = 0; j < jag[i].size(); j++) jag[i][j] = i * 10 + j;
    end
    foreach (jag[i]) $display("7. jag[%0d] has %0d elements: %p", i, jag[i].size(), jag[i]);
  end

endmodule
