module ex01_mini_layered;

  class item;
    int unsigned id;
    bit [7:0]    din;
    bit [8:0]    dout;
  endclass

  class producer;
    mailbox #(item) out_mbx;
    int unsigned    count = 3;

    function new(mailbox #(item) out_mbx);
      this.out_mbx = out_mbx;
    endfunction

    task run();
      item it;
      for (int unsigned i = 1; i <= count; i++) begin
        it     = new();                  // a new object for every item
        it.id  = i;
        it.din = 50 * i;
        out_mbx.put(it);
        $display("[%0t] PRODUCER sent id=%0d din=%0d", $time, it.id, it.din);
        #10;
      end
    endtask
  endclass

  class doubler;                         // stands in for driver + DUT + monitor
    mailbox #(item) in_mbx;
    mailbox #(item) out_mbx;

    function new(mailbox #(item) in_mbx, mailbox #(item) out_mbx);
      this.in_mbx  = in_mbx;
      this.out_mbx = out_mbx;
    endfunction

    task run();
      item it;
      forever begin
        in_mbx.get(it);
        #3;
        it.dout = it.din * 2;
        out_mbx.put(it);
      end
    endtask
  endclass

  class result_checker;
    mailbox #(item) in_mbx;
    int unsigned    num_checked;
    int unsigned    num_fail;

    function new(mailbox #(item) in_mbx);
      this.in_mbx = in_mbx;
    endfunction

    task run();
      item      it;
      bit [8:0] expected;
      forever begin
        in_mbx.get(it);
        expected = it.din * 2;
        if (it.dout !== expected) begin
          num_fail++;
          $display("[%0t] CHECKER id=%0d din=%0d dout=%0d FAIL, expected %0d",
                   $time, it.id, it.din, it.dout, expected);
        end
        else
          $display("[%0t] CHECKER id=%0d din=%0d dout=%0d PASS",
                   $time, it.id, it.din, it.dout);
        num_checked++;
      end
    endtask
  endclass

  mailbox #(item) p2d_mbx = new();
  mailbox #(item) d2c_mbx = new();
  producer        prod;
  doubler         dbl;
  result_checker  chk;

  initial begin
    prod = new(p2d_mbx);
    dbl  = new(p2d_mbx, d2c_mbx);
    chk  = new(d2c_mbx);

    fork
      prod.run();
      dbl.run();
      chk.run();
    join_any
    wait (chk.num_checked == prod.count);
    disable fork;
    $display("[%0t] checked=%0d fail=%0d", $time, chk.num_checked, chk.num_fail);
  end

endmodule
