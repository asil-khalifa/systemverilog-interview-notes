module tb_rand_mode;

  class pkt;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    constraint addr_c { addr < 16; }
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    $display("1. modes: addr=%0d data=%0d", p.addr.rand_mode(), p.data.rand_mode());

    p.addr.rand_mode(0);              // freeze addr
    p.addr = 8'h05;
    repeat (3) begin
      status = p.randomize();
      $display("2. frozen at 05   : status=%0d addr=%h", status, p.addr);
    end

    p.addr = 8'hF0;                   // a frozen value that violates addr_c
    status = p.randomize();
    $display("3. frozen at F0   : status=%0d addr=%h", status, p.addr);

    p.addr_c.constraint_mode(0);      // remove the violated constraint
    status = p.randomize();
    $display("4. constraint off : status=%0d addr=%h", status, p.addr);

    p.rand_mode(0);                   // nothing is random any more
    $display("5. modes: addr=%0d data=%0d", p.addr.rand_mode(), p.data.rand_mode());
  end

endmodule
