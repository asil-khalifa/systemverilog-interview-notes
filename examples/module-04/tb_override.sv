module tb_override;

  class base_txn;
    int kind = 1;

    function void print();
      $display("base_txn::print   kind=%0d", kind);
    endfunction
  endclass

  class write_txn extends base_txn;
    int kind = 2;                              // hides base_txn::kind

    function void print();                     // overrides base_txn::print (non-virtual)
      $display("write_txn::print  kind=%0d  super.kind=%0d", kind, super.kind);
    endfunction
  endclass

  base_txn  b;
  write_txn w;

  initial begin
    w = new();
    w.print();                                 // called through a write_txn handle

    b = w;                                     // base handle, SAME write_txn object
    b.print();                                 // called through a base_txn handle

    $display("b.kind=%0d  w.kind=%0d", b.kind, w.kind);
  end

endmodule
