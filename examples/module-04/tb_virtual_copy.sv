module tb_virtual_copy;

  class base_txn;
    bit [7:0] addr;

    virtual function void copy_fields(base_txn rhs);
      this.addr = rhs.addr;
    endfunction

    virtual function base_txn copy();
      base_txn t = new();               // an object of THIS class
      t.copy_fields(this);
      return t;
    endfunction

    virtual function void print(string tag = "");
      $display("[%s] base_txn  addr=%h", tag, addr);
    endfunction
  endclass

  class write_txn extends base_txn;
    bit [7:0] data;

    virtual function void copy_fields(base_txn rhs);
      write_txn rhs_w;
      super.copy_fields(rhs);                        // inherited fields first
      if ($cast(rhs_w, rhs)) this.data = rhs_w.data; // then the fields added here
    endfunction

    virtual function base_txn copy();
      write_txn t = new();              // an object of THIS class
      t.copy_fields(this);
      return t;                         // upcast to the declared return type
    endfunction

    virtual function void print(string tag = "");
      $display("[%s] write_txn addr=%h data=%h", tag, addr, data);
    endfunction
  endclass

  base_txn  orig, dup;
  write_txn w, w_dup;

  initial begin
    w = new();
    w.addr = 8'h40;
    w.data = 8'h7E;

    orig = w;                           // all the caller has is a base handle
    dup  = orig.copy();                 // virtual: write_txn::copy runs
    dup.print("dup");

    w.data = 8'h00;                     // changing the original...
    dup.print("dup");                   // ...does not change the copy

    if ($cast(w_dup, dup))              // downcast to reach data directly
      $display("w_dup.data=%h  same object as w: %0d", w_dup.data, w_dup == w);
  end

endmodule
