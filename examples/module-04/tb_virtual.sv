module tb_virtual;

  class base_txn;
    function void show();                              // non-virtual
      $display("   base_txn::show   (non-virtual)");
    endfunction

    virtual function void print();                     // virtual
      $display("   base_txn::print  (virtual)");
    endfunction
  endclass

  class write_txn extends base_txn;
    function void show();
      $display("   write_txn::show  (non-virtual)");
    endfunction

    virtual function void print();
      $display("   write_txn::print (virtual)");
    endfunction
  endclass

  base_txn  b;
  write_txn w;

  initial begin
    w = new();
    b = w;                       // base handle -> write_txn object

    $display("1. base handle, write_txn object:");
    b.show();
    b.print();

    $display("2. write_txn handle, write_txn object:");
    w.show();
    w.print();

    b = new();                   // base handle -> base_txn object
    $display("3. base handle, base_txn object:");
    b.show();
    b.print();
  end

endmodule
