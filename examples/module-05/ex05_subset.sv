module ex05_subset;

  class pick;
    bit [7:0]      legal[8] = '{8'h00, 8'h04, 8'h08, 8'h10, 8'h14, 8'h20, 8'h40, 8'h80};
    rand bit [7:0] chosen[4];

    constraint member_c { foreach (chosen[i]) chosen[i] inside {legal}; }
    constraint uniq_c   { unique {chosen}; }
  endclass

  pick p;
  int  errors;

  initial begin
    p = new();
    repeat (200) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      foreach (p.chosen[i]) begin
        if (!(p.chosen[i] inside {p.legal})) errors++;
        for (int j = i + 1; j < 4; j++)
          if (p.chosen[i] == p.chosen[j]) errors++;
      end
    end
    $display("ex05: sample chosen=%p", p.chosen);
    $display("ex05: errors=%0d", errors);
  end

endmodule
