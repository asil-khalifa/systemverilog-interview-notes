module tb_inheritance;

  class base_txn;
    bit [7:0] addr;

    function new();
      $display("   base_txn::new");
    endfunction

    function void print();
      $display("addr=%h", addr);
    endfunction
  endclass

  class write_txn extends base_txn;           // single inheritance
    bit [7:0] data;

    function new();
      $display("   write_txn::new");
    endfunction

    function void print_all();
      print();                                // inherited method, used directly
      $display("data=%h", data);
    endfunction
  endclass

  class burst_txn extends write_txn;          // multilevel inheritance
    int len;

    function new();
      $display("   burst_txn::new");
    endfunction
  endclass

  burst_txn b;

  initial begin
    $display("creating a burst_txn:");
    b = new();

    b.addr = 8'h10;       // declared in base_txn
    b.data = 8'hCD;       // declared in write_txn
    b.len  = 4;           // declared in burst_txn

    b.print_all();        // method from write_txn, which calls print() from base_txn
    $display("len=%0d", b.len);
  end

endmodule
