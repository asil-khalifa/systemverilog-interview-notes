module tb_race_lost_update;

  int       shared_count = 0;
  semaphore key          = new(1);

  task automatic add_unsafe();
    int tmp;
    tmp = shared_count;             // read
    #1;                             // suspended in the middle (models work that takes time)
    shared_count = tmp + 1;         // write back
  endtask

  task automatic add_safe();
    int tmp;
    key.get();                      // only one thread at a time from here ...
    tmp = shared_count;
    #1;
    shared_count = tmp + 1;
    key.put();                      // ... to here
  endtask

  initial begin
    fork
      add_unsafe();
      add_unsafe();
    join
    $display("[%0t] unsafe: shared_count = %0d (expected 2)", $time, shared_count);

    shared_count = 0;
    fork
      add_safe();
      add_safe();
    join
    $display("[%0t] safe  : shared_count = %0d (expected 2)", $time, shared_count);
  end

endmodule
