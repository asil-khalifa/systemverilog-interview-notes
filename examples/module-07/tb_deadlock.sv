module tb_deadlock;

  semaphore key_a = new(1);
  semaphore key_b = new(1);

  initial begin : thread_1
    key_a.get();
    $display("[%0t] T1 holds A", $time);
    #5;
    $display("[%0t] T1 waits for B", $time);
    key_b.get();                                   // blocked: T2 holds B
    $display("[%0t] T1 holds A and B", $time);     // never reached
    key_b.put();
    key_a.put();
  end

  initial begin : thread_2
    #1;
    key_b.get();
    $display("[%0t] T2 holds B", $time);
    #5;
    $display("[%0t] T2 waits for A", $time);
    key_a.get();                                   // blocked: T1 holds A
    $display("[%0t] T2 holds A and B", $time);     // never reached
    key_a.put();
    key_b.put();
  end

  initial begin : watchdog
    #100;
    $display("[%0t] WATCHDOG: no progress, the threads are deadlocked", $time);
    $finish;
  end

endmodule
