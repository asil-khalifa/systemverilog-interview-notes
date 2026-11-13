module tb_no_ipc;

  int shared_data;
  bit new_data;

  initial begin : producer
    for (int i = 1; i <= 4; i++) begin
      $display("[%0t] producer writes %0d", $time, i * 11);
      shared_data = i * 11;
      new_data    = 1;
      #5;                              // produces one item every 5 time units
    end
  end

  initial begin : consumer
    forever begin
      wait (new_data);                 // wait until something has been written
      new_data = 0;
      $display("[%0t] consumer reads  %0d", $time, shared_data);
      #12;                             // needs 12 time units to process one item
    end
  end

endmodule
