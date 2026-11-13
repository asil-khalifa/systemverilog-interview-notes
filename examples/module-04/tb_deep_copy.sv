module tb_deep_copy;

  class header;
    bit [7:0] id;

    function header copy();
      header h = new();
      h.id = this.id;
      return h;
    endfunction
  endclass

  class packet;
    bit [7:0] data;
    header    hdr;

    function new();
      hdr = new();
    endfunction

    function packet copy();
      packet p = new();              // 1. a new packet (its constructor creates a header)
      p.data = this.data;            // 2. copy the ordinary properties
      p.hdr  = this.hdr.copy();      // 3. deep-copy the nested object
      return p;
    endfunction
  endclass

  packet p1, p3;

  initial begin
    p1 = new();
    p1.data   = 8'hAA;
    p1.hdr.id = 8'h01;

    p3 = p1.copy();                  // deep copy

    p3.data   = 8'hBB;
    p3.hdr.id = 8'h99;

    $display("p1: data=%h hdr.id=%h", p1.data, p1.hdr.id);
    $display("p3: data=%h hdr.id=%h", p3.data, p3.hdr.id);
    $display("p1 == p3: %0d   p1.hdr == p3.hdr: %0d", p1 == p3, p1.hdr == p3.hdr);
  end

endmodule
