module tb_loop_nested;

  int arr [5] = '{5, 2, 9, 1, 7};
  int tmp, swaps;
  bit found;

  initial begin
    // 1. triangle: the inner bound depends on the outer variable
    for (int i = 1; i <= 3; i++) begin
      $write("1. row %0d:", i);
      for (int j = 1; j <= i; j++) $write(" %0d", i * j);
      $display("");
    end

    // 2. bubble sort
    swaps = 0;
    for (int i = 0; i < $size(arr) - 1; i++)
      for (int j = 0; j < $size(arr) - 1 - i; j++)
        if (arr[j] > arr[j + 1]) begin
          tmp        = arr[j];
          arr[j]     = arr[j + 1];
          arr[j + 1] = tmp;
          swaps++;
        end
    $display("2. sorted = %p after %0d swaps", arr, swaps);

    // 3. find the first pair of elements that adds up to 10
    found = 0;
    for (int i = 0; i < $size(arr) && !found; i++)
      for (int j = i + 1; j < $size(arr); j++)
        if (arr[i] + arr[j] == 10) begin
          $display("3. %0d + %0d = 10", arr[i], arr[j]);
          found = 1;
          break;                       // leaves the inner loop only
        end
  end

endmodule
