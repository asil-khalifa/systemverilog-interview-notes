module fx06_mailbox_pipeline;

  mailbox #(int) stage1_mbx = new();
  mailbox #(int) stage2_mbx = new();

  task automatic producer(int n);
    for (int i = 1; i <= n; i++) begin
      #10;
      stage1_mbx.put(i);
      $display("[%0t] producer : sent %0d", $time, i);
    end
  endtask

  task automatic doubler();
    int v;
    forever begin
      stage1_mbx.get(v);        // blocks while there is no work
      #3;
      stage2_mbx.put(2 * v);
    end
  endtask

  task automatic consumer(int n);
    int v;
    repeat (n) begin
      stage2_mbx.get(v);
      $display("[%0t] consumer : got %0d", $time, v);
    end
  endtask

  initial begin
    fork
      producer(3);
      doubler();
    join_none
    consumer(3);                // returns after the third item
    $display("[%0t] done", $time);
    $finish;
  end

endmodule
