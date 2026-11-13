module tb_debug_fail;

  class bus_txn;
    rand bit [7:0] addr;
    rand bit [7:0] len;
    int unsigned   max_len = 16;

    constraint len_c   { len inside {[1:max_len]}; }
    constraint align_c { addr[1:0] == 2'b00; }           // word aligned
    constraint odd_c   { addr[0] == 1'b1; }              // added later by somebody else
  endclass

  bus_txn t;

  initial begin
    t = new();
    if (!t.randomize()) begin
      $display("randomize FAILED. State: max_len=%0d", t.max_len);

      t.len_c.constraint_mode(0);
      $display("  without len_c   : status=%0d", t.randomize());
      t.len_c.constraint_mode(1);

      t.align_c.constraint_mode(0);
      $display("  without align_c : status=%0d", t.randomize());
      t.align_c.constraint_mode(1);

      t.odd_c.constraint_mode(0);
      $display("  without odd_c   : status=%0d", t.randomize());
      t.odd_c.constraint_mode(1);

      t.addr = 8'h10;  t.len = 4;                         // values we believe are legal
      $display("  addr=10 len=4 legal? status=%0d", t.randomize(null));
    end
  end

endmodule
