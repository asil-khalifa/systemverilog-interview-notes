module tb_wait_order;

  event req, gnt, done;

  initial begin : stimulus
    #10 -> req;        // time 10
    #10 -> gnt;        // time 20
    #10 -> done;       // time 30 : req, gnt, done  -> correct order

    #10 -> gnt;        // time 40 : gnt before req  -> wrong order
    #10 -> req;        // time 50
    #10 -> done;       // time 60
  end

  initial begin : order_check
    wait_order (req, gnt, done)
      $display("[%0t] PASS: req -> gnt -> done", $time);
    else
      $display("[%0t] FAIL: events out of order", $time);

    #5;                // start the second check at time 35

    wait_order (req, gnt, done)
      $display("[%0t] PASS: req -> gnt -> done", $time);
    else
      $display("[%0t] FAIL: events out of order", $time);
  end

endmodule
