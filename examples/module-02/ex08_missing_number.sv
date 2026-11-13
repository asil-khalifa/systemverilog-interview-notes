module ex08_missing_number;

  int arr [] = '{1, 2, 4, 5, 6};
  int n, missing;

  initial begin
    n       = arr.size() + 1;                 // the complete set would have n numbers
    missing = n * (n + 1) / 2 - arr.sum();    // sum of 1..n minus the actual sum
    $display("N = %0d, missing number = %0d", n, missing);
  end

endmodule
