module tb_soft;

  class pkt;
    rand bit [7:0] len;
    rand bit [7:0] gap;

    constraint range_c { len inside {[1:64]}; }             // hard
    constraint dflt_c  { soft len == 8; }                   // soft default
    constraint gap_c   { soft gap == 1; soft gap == 2; }    // two soft constraints in conflict
  endclass

  pkt p;
  int status;

  initial begin
    p = new();

    status = p.randomize();
    $display("1. no override          : status=%0d len=%0d gap=%0d", status, p.len, p.gap);

    status = p.randomize() with { len == 20; };
    $display("2. hard inline len==20  : status=%0d len=%0d", status, p.len);

    status = p.randomize() with { soft len == 3; };
    $display("3. soft inline len==3   : status=%0d len=%0d", status, p.len);

    status = p.randomize() with { len > 60; };
    $display("4. hard inline len>60   : status=%0d len in 61..64: %s",
             status, (p.len inside {[61:64]}) ? "yes" : "NO");

    status = p.randomize() with { len == 100; };
    $display("5. hard inline len==100 : status=%0d", status);
  end

endmodule
