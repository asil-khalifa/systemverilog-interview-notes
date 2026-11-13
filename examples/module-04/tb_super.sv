module tb_super;

  class base_txn;
    string    name;
    bit [7:0] addr;
    int       x = 1;

    function new(string name, bit [7:0] addr);
      this.name = name;
      this.addr = addr;
      $display("   base_txn::new   x=%0d", x);
      x = 2;
    endfunction

    function void print();
      $display("%s: addr=%h", name, addr);
    endfunction
  endclass

  class write_txn extends base_txn;
    bit [7:0] data;
    int       y = x + 10;                       // initialiser uses an inherited property

    function new(string name, bit [7:0] addr, bit [7:0] data);
      super.new(name, addr);                    // must be first: builds the base part
      this.data = data;
      $display("   write_txn::new  x=%0d y=%0d", x, y);
    endfunction

    function void print();                      // overrides base_txn::print
      super.print();                            // reuse the base-class version
      $display("%s: data=%h", name, data);      // then add what is new
    endfunction
  endclass

  write_txn w;

  initial begin
    w = new("wr0", 8'h40, 8'h7E);
    w.print();
  end

endmodule
