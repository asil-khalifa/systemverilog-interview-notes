module tb_p16_no_adjacent_ones;

  class bits_gen;
    rand bit [15:0] x;

    constraint spread_c { (x & (x >> 1)) == 0; }
    constraint four_c   { $countones(x) == 4; }
  endclass

  bits_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (300) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      for (int i = 0; i < 15; i++)
        if (g.x[i] && g.x[i+1]) errors++;
      if ($countones(g.x) != 4) errors++;
    end
    $display("p16: sample x=%b", g.x);
    $display("p16: errors=%0d", errors);
  end

endmodule
