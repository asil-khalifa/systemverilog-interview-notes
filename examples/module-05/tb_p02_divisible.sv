module tb_p02_divisible;

  class div_gen;
    rand bit [7:0] x, y;

    constraint even_c { x[0] == 1'b0; }
    constraint five_c { y inside {[1:200]}; y % 5 == 0; y % 10 != 0; }
  endclass

  div_gen g;
  int     errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (g.x % 2 != 0)                                 errors++;
      if (g.y < 1 || g.y > 200)                         errors++;
      if (!(g.y % 5 == 0 && g.y % 10 != 0))             errors++;
    end
    $display("p02: errors=%0d", errors);
  end

endmodule
