module ex03_frame_copy;

  class header;
    bit [7:0] id;
    function header copy();
      header h = new();
      h.id = this.id;
      return h;
    endfunction
  endclass

  class frame;
    header    hdr;
    bit [7:0] payload [];

    function new(int size = 0);
      hdr     = new();
      payload = new[size];
    endfunction

    function frame copy();
      frame f = new();
      f.hdr     = this.hdr.copy();     // nested object: must be copied explicitly
      f.payload = this.payload;        // array: assignment copies all elements
      return f;
    endfunction

    function bit compare(frame rhs);
      if (rhs == null) return 0;
      return (hdr.id == rhs.hdr.id) && (payload == rhs.payload);
    endfunction
  endclass

  frame f1, f2, f3;

  initial begin
    f1 = new(3);
    f1.hdr.id  = 8'd7;
    f1.payload = '{8'd1, 8'd2, 8'd3};

    f2 = f1.copy();                                    // deep copy
    $display("after deep copy: equal=%0d", f1.compare(f2));

    f2.hdr.id     = 8'd8;
    f2.payload[0] = 8'd9;
    $display("f1: id=%0d payload[0]=%0d   f2: id=%0d payload[0]=%0d   equal=%0d",
             f1.hdr.id, f1.payload[0], f2.hdr.id, f2.payload[0], f1.compare(f2));

    f3 = new f1;                                       // shallow copy
    f3.payload[1] = 8'd50;                             // array was duplicated
    f3.hdr.id     = 8'd99;                             // header is shared
    $display("after shallow copy: f1.payload[1]=%0d f1.hdr.id=%0d",
             f1.payload[1], f1.hdr.id);
  end

endmodule
