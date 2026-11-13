module tb_rand_vs_randc;

  class dice;
    rand  bit [1:0] r;     // independent each time
    randc bit [1:0] c;     // cyclic
  endclass

  dice d;
  int  seen[4];            // how often each value of c was produced
  bit  ok;

  initial begin
    d = new();
    repeat (3) begin                      // three complete cycles
      seen = '{default: 0};
      repeat (4) begin
        if (!d.randomize()) $fatal(1, "randomize failed");
        $write("r=%0d c=%0d | ", d.r, d.c);
        seen[d.c]++;
      end
      ok = (seen[0] == 1) && (seen[1] == 1) && (seen[2] == 1) && (seen[3] == 1);
      $display(" every c value exactly once: %s", ok ? "yes" : "NO");
    end
  end

endmodule
