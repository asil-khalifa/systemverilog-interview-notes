module tb_inline;

  class bus_txn;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    bit [7:0]      tag;                       // not declared rand
    constraint addr_c { addr inside {[0:99]}; }
  endclass

  bus_txn t;
  int     status;

  task automatic send(bit [7:0] addr);
    status = t.randomize() with { addr == local::addr; };
    $display("2. local::addr=%0d  : status=%0d t.addr=%0d", addr, status, t.addr);
  endtask

  initial begin
    t = new();

    status = t.randomize() with { addr == 42; data == 8'hFF; };
    $display("1. inline         : status=%0d addr=%0d data=%h", status, t.addr, t.data);

    send(17);

    status = t.randomize() with { addr == 150; };
    $display("3. conflict       : status=%0d t.addr=%0d", status, t.addr);

    t.data = 8'hAA;
    status = t.randomize(addr) with { addr == 5; };
    $display("4. randomize(addr): status=%0d addr=%0d data=%h", status, t.addr, t.data);

    status = t.randomize(tag) with { tag == 8'h3C; };
    $display("5. randomize(tag) : status=%0d tag=%h addr=%0d", status, t.tag, t.addr);

    status = t.randomize(null);
    $display("6. check, addr=5  : status=%0d", status);
    t.addr = 150;
    status = t.randomize(null);
    $display("7. check, addr=150: status=%0d addr=%0d", status, t.addr);
  end

endmodule
