module tb_this;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    function new(bit [7:0] addr, bit [7:0] data);
      this.addr = addr;          // property = argument
      this.data = data;
    endfunction

    function void bad_set(bit [7:0] addr);
      addr = addr;               // BUG: assigns the argument to itself
    endfunction

    function void good_set(bit [7:0] addr);
      this.addr = addr;
    endfunction

    function packet get_self();
      return this;               // returns a handle to the current object
    endfunction
  endclass

  packet p, q;

  initial begin
    p = new(8'h11, 8'h22);
    $display("1. after new      : addr=%h data=%h", p.addr, p.data);

    p.bad_set(8'h99);
    $display("2. after bad_set  : addr=%h", p.addr);

    p.good_set(8'h99);
    $display("3. after good_set : addr=%h", p.addr);

    q = p.get_self();
    if (q == p) $display("4. get_self() returned the same object");
  end

endmodule
