module tb_semaphore_keys;

  semaphore sem;

  initial begin
    sem = new(3);                                             // 3 keys

    if (sem.try_get(2))  $display("1. got 2 keys              : 1 left");
    if (!sem.try_get(2)) $display("2. cannot get 2 keys       : only 1 left, none taken");
    if (sem.try_get(1))  $display("3. got the last key        : 0 left");
    if (!sem.try_get())  $display("4. cannot get a key        : 0 left");

    sem.put(3);
    $display("5. returned 3 keys         : 3 available");

    sem.put(2);
    $display("6. put 2 keys never taken  : 5 available (created with 3)");

    if (sem.try_get(5))  $display("7. got 5 keys at once      : 0 left");
  end

endmodule
