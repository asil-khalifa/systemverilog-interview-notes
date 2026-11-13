module tb_constraint_mode;

  class pkt;
    rand bit [7:0] len;
    constraint small_c { len < 10; }
    constraint big_c   { len > 200; }
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    $display("1. initial modes : small_c=%0d big_c=%0d",
             p.small_c.constraint_mode(), p.big_c.constraint_mode());

    status = p.randomize();
    $display("2. both on       : status=%0d", status);

    p.big_c.constraint_mode(0);
    status = p.randomize();
    $display("3. big_c off     : status=%0d len<10: %s", status, (p.len < 10) ? "yes" : "NO");

    p.small_c.constraint_mode(0);
    p.big_c.constraint_mode(1);
    status = p.randomize();
    $display("4. small_c off   : status=%0d len>200: %s", status, (p.len > 200) ? "yes" : "NO");

    p.constraint_mode(0);
    status = p.randomize();
    $display("5. all off       : status=%0d modes: small_c=%0d big_c=%0d",
             status, p.small_c.constraint_mode(), p.big_c.constraint_mode());
  end

endmodule
