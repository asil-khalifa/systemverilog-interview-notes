module tb_loop_while;

  int q [$] = {5, 12, 7, 20, 3};
  int count, x, idx, n;

  initial begin
    // repeat: a fixed number of passes
    count = 0;
    repeat (4) count += 2;
    $display("1. repeat (4)          : count = %0d", count);

    // the repeat count is evaluated once
    count = 3;
    repeat (count) count++;
    $display("2. repeat (count)      : count = %0d", count);

    // while: search for the first element greater than 10
    idx = 0;
    while (idx < q.size() && q[idx] <= 10) idx++;
    $display("3. first element > 10  : q[%0d] = %0d", idx, q[idx]);

    // while may run zero times, do-while runs at least once
    x = 100;
    count = 0;
    while (x < 10) count++;
    $display("4. while (false)       : %0d passes", count);
    count = 0;
    do count++; while (x < 10);
    $display("5. do-while (false)    : %0d pass", count);

    // while: drain a queue
    $write("6. drained             :");
    while (q.size() > 0) begin
      x = q.pop_front();
      $write(" %0d", x);
    end
    $display("");

    // continue and break
    $write("7. continue and break  :");
    for (int i = 0; i < 10; i++) begin
      if (i % 2 == 1) continue;        // skip odd numbers
      if (i > 6)      break;           // stop the loop
      $write(" %0d", i);
    end
    $display("");

    // forever with break
    n = 0;
    forever begin
      n++;
      if (n == 5) break;
    end
    $display("8. forever with break  : n = %0d", n);
  end

endmodule
