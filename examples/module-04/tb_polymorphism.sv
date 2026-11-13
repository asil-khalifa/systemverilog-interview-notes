module tb_polymorphism;

  class bus_txn;
    bit [7:0] addr;

    function new(bit [7:0] addr);
      this.addr = addr;
    endfunction

    virtual function void print();
      $display("BUS   addr=%h", addr);
    endfunction

    virtual function int size_in_bytes();
      return 1;
    endfunction
  endclass

  class read_txn extends bus_txn;
    function new(bit [7:0] addr);
      super.new(addr);
    endfunction

    virtual function void print();
      $display("READ  addr=%h", addr);
    endfunction
  endclass

  class write_txn extends bus_txn;
    bit [7:0] data;

    function new(bit [7:0] addr, bit [7:0] data);
      super.new(addr);
      this.data = data;
    endfunction

    virtual function void print();
      $display("WRITE addr=%h data=%h", addr, data);
    endfunction

    virtual function int size_in_bytes();
      return 2;
    endfunction
  endclass

  // Generic code: written once, for the base class only
  function automatic void process(bus_txn t);
    t.print();
    $display("      size=%0d byte(s)", t.size_in_bytes());
  endfunction

  bus_txn   txns [3];          // an array of base-class handles
  read_txn  r;
  write_txn w;

  initial begin
    r = new(8'h10);
    w = new(8'h20, 8'hAB);

    txns[0] = new(8'h00);      // a bus_txn object
    txns[1] = r;               // a read_txn object  (upcast)
    txns[2] = w;               // a write_txn object (upcast)

    foreach (txns[i]) process(txns[i]);
  end

endmodule
