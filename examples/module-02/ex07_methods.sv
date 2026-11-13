module ex07_methods;

  int d [] = '{4, 9, 2, 9, 7, 2, 5};
  int r [$], ix [$];

  initial begin
    $display("sum of even values       = %0d", d.sum() with (item % 2 == 0 ? item : 0));
    $display("number of values above 5 = %0d", d.sum() with (int'(item > 5)));

    r  = d.max();
    ix = d.find_first_index with (item == r[0]);
    $display("largest = %0d at index %0d", r[0], ix[0]);

    r = d.unique();
    r.sort();
    $display("second-smallest distinct = %0d", r[1]);

    r = d.find with (item >= 10);
    $display("all values below 10      : %s", (r.size() == 0) ? "yes" : "no");
    $display("contains 7               : %s", (7 inside {d}) ? "yes" : "no");
  end

endmodule
