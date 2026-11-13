module tb_constructor;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;
    int       len = 4;                     // declaration initialiser

    function new(bit [7:0] a = 8'h00, bit [7:0] d = 8'hFF);
      $display("   new() starts with len=%0d", len);
      addr = a;
      data = d;
      len  = len * 2;
    endfunction

    function void print(string tag = "");
      $display("[%s] addr=%h data=%h len=%0d", tag, addr, data, len);
    endfunction
  endclass

  packet p1, p2, p3, p4;

  initial begin
    p1 = new();              p1.print("p1");
    p2 = new(8'h10);         p2.print("p2");
    p3 = new(8'h20, 8'h55);  p3.print("p3");
    p4 = new(.d(8'h77));     p4.print("p4");
  end

endmodule
