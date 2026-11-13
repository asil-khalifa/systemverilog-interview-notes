module tb_mailbox_bounded;

  mailbox #(int) mbx = new(2);                 // bounded: at most 2 messages

  initial begin : producer
    for (int i = 1; i <= 4; i++) begin
      mbx.put(i);                              // blocks while the mailbox is full
      $display("[%0t] producer: put(%0d) completed", $time, i);
    end
  end

  initial begin : consumer
    int v;
    repeat (4) begin
      #10;
      mbx.get(v);                              // frees one place every 10 time units
    end
  end

endmodule
