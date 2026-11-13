module tb_shallow_copy;

  class header;
    bit [7:0] id;
  endclass

  class packet;
    bit [7:0] data;
    header    hdr;

    function new();
      hdr = new();
      $display("   packet::new() executed");
    endfunction
  endclass

  packet p1, p2, p3;

  initial begin
    p1 = new();
    p1.data   = 8'hAA;
    p1.hdr.id = 8'h01;

    p2 = p1;            // handle assignment: no new object
    p3 = new p1;        // shallow copy: a new packet object, constructor not called

    p3.data   = 8'hBB;  // changes only p3
    p3.hdr.id = 8'h99;  // changes the header shared by p1 and p3

    $display("p1: data=%h hdr.id=%h", p1.data, p1.hdr.id);
    $display("p2: data=%h hdr.id=%h", p2.data, p2.hdr.id);
    $display("p3: data=%h hdr.id=%h", p3.data, p3.hdr.id);
    $display("p1 == p2: %0d   p1 == p3: %0d   p1.hdr == p3.hdr: %0d",
             p1 == p2, p1 == p3, p1.hdr == p3.hdr);
  end

endmodule
