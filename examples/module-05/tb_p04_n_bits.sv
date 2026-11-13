module tb_p04_n_bits;

  class bits_gen;
    rand bit [31:0] any5;
    rand bit [31:0] run5;
    rand bit [4:0]  pos;

    constraint any_c { $countones(any5) == 5; }
    constraint run_c { pos <= 27; run5 == (32'h0000_001F << pos); }
  endclass

  bits_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if ($countones(g.any5) != 5)              errors++;
      if ($countones(g.run5) != 5)              errors++;
      if (((g.run5 >> g.pos) & 32'h1F) != 5'h1F) errors++;
    end
    $display("p04: errors=%0d", errors);
  end

endmodule
