module ex03_packet;

  class packet;
    rand bit [7:0] payload[];
    rand bit       bad_csum;
    bit [7:0]      csum;

    constraint size_c { payload.size() inside {[1:16]}; }
    constraint err_c  { bad_csum dist {1 := 10, 0 := 90}; }

    function bit [7:0] calc_csum();
      bit [7:0] c = 0;
      foreach (payload[i]) c ^= payload[i];
      return c;
    endfunction

    function void post_randomize();
      csum = calc_csum();
      if (bad_csum) csum = ~csum;
    endfunction
  endclass

  packet p;
  int    errors, n_bad;

  initial begin
    p = new();
    repeat (1000) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      if (p.payload.size() < 1 || p.payload.size() > 16)            errors++;
      if (!p.bad_csum && p.csum != p.calc_csum())                    errors++;
      if ( p.bad_csum && p.csum == p.calc_csum())                    errors++;
      if (p.bad_csum) n_bad++;
    end
    $display("corrupted packets: %0d of 1000", n_bad);
    $display("ex03: errors=%0d", errors);
  end

endmodule
