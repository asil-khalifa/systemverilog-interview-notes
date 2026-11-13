module ex01_fifo_txn;

  typedef enum bit [1:0] {FIFO_IDLE, FIFO_WRITE, FIFO_READ, FIFO_WRITE_READ} fifo_kind_e;

  class fifo_txn;
    // stimulus
    rand fifo_kind_e kind;
    rand bit [7:0]   din;
    // response
    logic [7:0]      dout;
    logic            full;
    logic            empty;
    // bookkeeping
    int unsigned     id;

    constraint kind_dist_c {
      kind dist { FIFO_IDLE := 1, FIFO_WRITE := 4, FIFO_READ := 4, FIFO_WRITE_READ := 1 };
    }

    function bit is_write();
      return kind inside {FIFO_WRITE, FIFO_WRITE_READ};
    endfunction

    function bit is_read();
      return kind inside {FIFO_READ, FIFO_WRITE_READ};
    endfunction

    virtual function string convert2string();
      return $sformatf("id=%0d kind=%s din=0x%h dout=0x%h full=%b empty=%b",
                       id, kind.name(), din, dout, full, empty);
    endfunction

    virtual function void print(string tag = "");
      $display("%s: %s", tag, convert2string());
    endfunction

    virtual function fifo_txn copy();
      fifo_txn c = new();
      c.kind  = kind;
      c.din   = din;
      c.dout  = dout;
      c.full  = full;
      c.empty = empty;
      c.id    = id;
      return c;
    endfunction

    virtual function bit compare(fifo_txn rhs);
      if (rhs == null) return 0;
      return (kind  ==  rhs.kind)  &&
             (din   ==  rhs.din)   &&
             (dout  === rhs.dout)  &&
             (full  === rhs.full)  &&
             (empty === rhs.empty);
    endfunction
  endclass

  fifo_txn t, c;

  initial begin
    t       = new();
    t.id    = 3;
    t.kind  = FIFO_WRITE;
    t.din   = 8'hA5;
    t.dout  = 8'h00;
    t.full  = 1'b0;
    t.empty = 1'b1;
    t.print("WR");

    c = t.copy();
    $display("copy equal: %0d   is_write=%0d is_read=%0d",
             t.compare(c), t.is_write(), t.is_read());

    c.full = 1'bx;
    $display("after corrupting full: %0d", t.compare(c));
  end

endmodule
