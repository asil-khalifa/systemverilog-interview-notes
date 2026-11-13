module tb_foreach_sum;

  class arr_demo;
    rand bit [7:0] d[];
    rand bit [7:0] w[4];

    constraint size_c  { d.size() inside {[4:6]}; }
    constraint asc_c   { foreach (d[i]) if (i > 0) d[i] > d[i-1]; }
    constraint total_c { d.sum() with (int'(item)) == 100; }

    constraint wrap_c  { w.sum() == 20; }           // the trap: 8-bit sum
  endclass

  arr_demo a;
  int      true_sum, wrapped;

  initial begin
    a = new();
    repeat (200) begin
      if (!a.randomize()) $fatal(1, "randomize failed");

      // check d: strictly ascending, true sum 100
      true_sum = 0;
      foreach (a.d[i]) begin
        true_sum += a.d[i];
        if (i > 0 && a.d[i] <= a.d[i-1]) $error("d is not ascending: %p", a.d);
      end
      if (true_sum != 100) $error("sum of d is %0d", true_sum);

      // check w: count how often the real sum is not 20
      true_sum = 0;
      foreach (a.w[i]) true_sum += a.w[i];
      if (true_sum != 20) wrapped++;
    end
    $display("last d = %p", a.d);
    $display("w.sum() == 20 was satisfied by a wrapped sum in %0d of 200 calls", wrapped);
  end

endmodule
