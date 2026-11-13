module tb_loop_for;

  int arr [5] = '{3, 8, 1, 6, 4};
  int total;
  int tmp;

  initial begin
    total = 0;
    for (int i = 0; i < $size(arr); i++) total += arr[i];
    $display("1. total = %0d", total);

    $write("2. backwards            :");
    for (int i = $high(arr); i >= $low(arr); i--) $write(" %0d", arr[i]);
    $display("");

    $write("3. every second element :");
    for (int i = 0; i < $size(arr); i += 2) $write(" %0d", arr[i]);
    $display("");

    // two loop variables: reverse the array in place
    for (int lo = 0, hi = $size(arr) - 1; lo < hi; lo++, hi--) begin
      tmp     = arr[lo];
      arr[lo] = arr[hi];
      arr[hi] = tmp;
    end
    $display("4. reversed in place    : %p", arr);
  end

endmodule
