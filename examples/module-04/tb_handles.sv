module tb_handles;

  class packet;
    bit [7:0] addr;
  endclass

  packet p1, p2, p3;

  initial begin
    p1 = new();  p1.addr = 8'h01;        // object A
    p2 = new();  p2.addr = 8'h02;        // object B

    p3 = p1;                             // p3 refers to object A too
    p3.addr = 8'h33;
    $display("1. p1.addr=%h p2.addr=%h p3.addr=%h", p1.addr, p2.addr, p3.addr);

    if (p1 == p3) $display("2. p1 and p3 refer to the same object");
    if (p1 != p2) $display("3. p1 and p2 refer to different objects");

    p1 = null;                           // object A is still reachable through p3
    $display("4. p3.addr=%h (object A is alive)", p3.addr);

    p3 = p2;                             // nothing refers to object A now
    $display("5. p3.addr=%h (p3 now refers to object B)", p3.addr);

    if (p1 == null) $display("6. p1 is null: p1.addr would be a fatal error");
    // p1.addr = 8'h55;                  // run-time error: null object access
  end

endmodule
