module ex06_lock_step;

  mailbox #(int) gen2drv_mbx = new(1);      // bound of 1

  initial begin : generator
    for (int i = 1; i <= 3; i++) begin
      gen2drv_mbx.put(i);
      $display("[%0t] GEN: put %0d accepted", $time, i);
    end
  end

  initial begin : driver
    int item;
    forever begin
      gen2drv_mbx.peek(item);               // look: the mailbox stays full
      #10;                                  // drive the item
      gen2drv_mbx.get(item);                // remove: the generator may continue
    end
  end

endmodule
