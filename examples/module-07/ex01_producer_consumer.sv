module ex01_producer_consumer;

  mailbox #(int) mbx = new(1);

  initial begin : producer
    for (int i = 1; i <= 4; i++)
      mbx.put(i * i);                       // blocks while the mailbox is full
  end

  initial begin : consumer
    int v;
    repeat (4) begin
      #5;
      mbx.get(v);
      $display("[%0t] consumer got %0d", $time, v);
    end
  end

endmodule
