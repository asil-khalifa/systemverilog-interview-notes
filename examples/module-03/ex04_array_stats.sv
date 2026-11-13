module ex04_array_stats;

  function automatic void stats(const ref int arr[],
                                output    int lo,
                                output    int hi,
                                output    real avg);
    int sum;
    lo  = arr[0];
    hi  = arr[0];
    sum = 0;
    foreach (arr[i]) begin
      if (arr[i] < lo) lo = arr[i];
      if (arr[i] > hi) hi = arr[i];
      sum += arr[i];
    end
    avg = real'(sum) / arr.size();
  endfunction

  int  values[] = '{4, 9, 2, 7};
  int  lo, hi;
  real avg;

  initial begin
    stats(values, lo, hi, avg);
    $display("min=%0d max=%0d avg=%0.2f", lo, hi, avg);
  end

endmodule
