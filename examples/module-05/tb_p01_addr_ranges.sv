module tb_p01_addr_ranges;

  class addr_gen;
    rand bit [11:0] addr;

    constraint region_c { addr inside {[12'h100:12'h1FF], [12'h800:12'h8FF]}; }
    constraint align_c  { addr[1:0] == 2'b00; }
    constraint hole_c   { !(addr inside {[12'h140:12'h14F]}); }
  endclass

  addr_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (!((g.addr >= 12'h100 && g.addr <= 12'h1FF) ||
            (g.addr >= 12'h800 && g.addr <= 12'h8FF)))   errors++;
      if (g.addr % 4 != 0)                               errors++;
      if (g.addr >= 12'h140 && g.addr <= 12'h14F)        errors++;
    end
    $display("p01: errors=%0d", errors);
  end

endmodule
