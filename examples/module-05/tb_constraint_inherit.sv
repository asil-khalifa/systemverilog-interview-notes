module tb_constraint_inherit;

  class base_txn;
    rand bit [7:0] len;
    constraint len_c  { len inside {[1:10]}; }
    constraint even_c { len[0] == 1'b0; }
  endclass

  class long_txn extends base_txn;                 // OVERRIDE: same block name
    constraint len_c { len inside {[100:110]}; }
  endclass

  class tiny_txn extends base_txn;                 // EXTEND: new block name
    constraint tiny_c { len < 3; }
  endclass

  class bad_txn extends base_txn;                  // EXTEND with a conflicting constraint
    constraint big_c { len > 50; }
  endclass

  base_txn b, h;
  long_txn l;
  tiny_txn t;
  bad_txn  x;
  int      status;

  initial begin
    b = new();  l = new();  t = new();  x = new();

    status = b.randomize();
    $display("1. base_txn : status=%0d even and in 1..10: %s", status,
             (b.len inside {2, 4, 6, 8, 10}) ? "yes" : "NO");

    status = l.randomize();
    $display("2. long_txn : status=%0d even and in 100..110: %s", status,
             (l.len inside {100, 102, 104, 106, 108, 110}) ? "yes" : "NO");

    status = t.randomize();
    $display("3. tiny_txn : status=%0d len=%0d", status, t.len);

    status = x.randomize();
    $display("4. bad_txn  : status=%0d", status);

    h = l;                                         // base handle, derived object
    status = h.randomize();
    $display("5. base handle to long_txn : status=%0d len>=100: %s", status,
             (h.len >= 100) ? "yes" : "NO");
  end

endmodule
