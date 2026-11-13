module tb_p10_no_repeat;

  class no_repeat;
    rand bit [3:0] v;
    bit [3:0]      hist[$];                 // values already used in this cycle

    constraint fresh_c { !(v inside {hist}); }

    function void post_randomize();
      hist.push_back(v);
      if (hist.size() == 16) hist.delete(); // all values used: start a new cycle
    endfunction
  endclass

  no_repeat g;
  int       seen[16];
  int       errors;

  initial begin
    g = new();
    repeat (3) begin                        // three complete cycles
      seen = '{default: 0};
      repeat (16) begin
        if (!g.randomize()) $fatal(1, "randomize failed");
        seen[g.v]++;
      end
      foreach (seen[i]) if (seen[i] != 1) errors++;
    end
    $display("p10: errors=%0d", errors);
  end

endmodule
