module ex02_second_largest;

  int a [5] = '{12, 45, 7, 45, 30};
  int first, second;
  int r [$];

  initial begin
    first  = -1;
    second = -1;
    foreach (a[i]) begin
      if (a[i] > first) begin
        second = first;
        first  = a[i];
      end
      else if (a[i] > second && a[i] != first)
        second = a[i];
    end
    $display("loop    : largest = %0d, second largest = %0d", first, second);

    r = a.unique();
    r.rsort();
    $display("methods : largest = %0d, second largest = %0d", r[0], r[1]);
  end

endmodule
