module tb_p03_power_of_two;

  class pow2_gen;
    rand bit [15:0] p1, p2, p3;
    rand bit [3:0]  sh;

    constraint count_c { $countones(p1) == 1; }                 // exactly one bit set
    constraint trick_c { p2 != 0; (p2 & (p2 - 1)) == 0; }       // classic bit trick
    constraint shift_c { p3 == (16'd1 << sh); }                 // 1 shifted by a random amount
  endclass

  pow2_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (!$onehot(g.p1)) errors++;
      if (!$onehot(g.p2)) errors++;
      if (!$onehot(g.p3)) errors++;
    end
    $display("p03: errors=%0d", errors);
  end

endmodule
