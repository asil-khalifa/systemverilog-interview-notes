module tb_loop_delete;

  int q1 [$] = {1, 2, 4, 5, 6};
  int q2 [$] = {1, 2, 4, 5, 6};
  int q3 [$] = {1, 2, 4, 5, 6};

  initial begin
    // WRONG: forward loop, deleting even values
    for (int i = 0; i < q1.size(); i++)
      if (q1[i] % 2 == 0) q1.delete(i);
    $display("1. forward delete  : %p", q1);

    // RIGHT: walk backwards, so the shifted elements have already been visited
    for (int i = q2.size() - 1; i >= 0; i--)
      if (q2[i] % 2 == 0) q2.delete(i);
    $display("2. backward delete : %p", q2);

    // RIGHT: build the result with a locator method
    q3 = q3.find with (item % 2 != 0);
    $display("3. find            : %p", q3);
  end

endmodule
