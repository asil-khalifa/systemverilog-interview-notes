module tb_class_basic;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    function void print(string tag = "");
      $display("[%s] addr=%h data=%h", tag, addr, data);
    endfunction
  endclass

  packet p1;                       // a handle; no object yet

  initial begin
    if (p1 == null) $display("p1 is null before new()");

    p1 = new();                    // the object is created here
    p1.print("after new");

    p1.addr = 8'h10;
    p1.data = 8'hAB;
    p1.print("after set");
  end

endmodule
