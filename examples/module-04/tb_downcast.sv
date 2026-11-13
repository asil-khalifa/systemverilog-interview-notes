module tb_downcast;

  class bus_txn;
    bit [7:0] addr;
    virtual function void print();
      $display("BUS   addr=%h", addr);
    endfunction
  endclass

  class read_txn extends bus_txn;
    virtual function void print();
      $display("READ  addr=%h", addr);
    endfunction
  endclass

  class write_txn extends bus_txn;
    bit [7:0] data;
    virtual function void print();
      $display("WRITE addr=%h data=%h", addr, data);
    endfunction
  endclass

  bus_txn   b;
  read_txn  r;
  write_txn w, w2;

  initial begin
    w = new();
    w.addr = 8'h20;
    w.data = 8'hAB;

    b = w;                               // upcast: always legal
    // w2 = b;                           // COMPILE ERROR: base handle to derived handle
    // $display("%h", b.data);           // COMPILE ERROR: bus_txn has no member data

    if ($cast(w2, b))
      $display("1. cast to write_txn succeeded: data=%h, same object as w: %0d",
               w2.data, w2 == w);

    if (!$cast(r, b))
      $display("2. cast to read_txn failed: the object is a write_txn; r is null: %0d",
               r == null);

    b = new();                           // now b refers to a plain bus_txn
    if (!$cast(w2, b))
      $display("3. cast to write_txn failed: the object is only a bus_txn");
    $display("4. w2 is unchanged: data=%h", w2.data);

    // $cast(w2, b);                     // task form: this line would be a run-time error
  end

endmodule
