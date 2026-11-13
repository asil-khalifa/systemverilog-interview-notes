module tb_rand_2d;

  class grid;
    rand bit [3:0] m[3][4];                 // fixed 3 x 4
    rand int       d[][];                   // dynamic rows of dynamic columns

    constraint m_c {
      foreach (m[i, j]) m[i][j] inside {[1:9]};
    }
    constraint d_size_c {
      d.size() == 2;                        // number of rows
      foreach (d[i]) d[i].size() inside {[1:3]};   // length of each row
    }
    constraint d_val_c {
      foreach (d[i, j]) d[i][j] inside {[100:109]};
    }
  endclass

  grid g;

  initial begin
    g = new();
    if (!g.randomize()) $fatal(1, "randomize failed");
    foreach (g.m[i]) $display("m[%0d] = %p", i, g.m[i]);
    foreach (g.d[i]) $display("d[%0d] = %p", i, g.d[i]);
  end

endmodule
