module tb_const;

  class packet;
    static const int MAX_LEN = 64;      // global constant: value fixed in the declaration
    const int        id;                // instance constant: value fixed in new()
    bit [7:0]        data;

    function new(int id);
      this.id = id;                     // the one permitted assignment
    endfunction
  endclass

  packet p1, p2;

  initial begin
    p1 = new(1);
    p2 = new(2);
    $display("p1.id=%0d p2.id=%0d MAX_LEN=%0d", p1.id, p2.id, packet::MAX_LEN);

    p1.data = 8'h5A;                    // ordinary property: writable
    // p1.id = 7;                       // ILLEGAL: assignment to a const property
    // packet::MAX_LEN = 128;           // ILLEGAL: assignment to a const property
  end

endmodule
