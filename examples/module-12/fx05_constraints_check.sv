module fx05_constraints_check;

  class sorted_arr;
    rand bit [7:0] a [];

    constraint size_c { a.size() inside {[4:8]}; }
    constraint elem_c { foreach (a[i]) { a[i] inside {[10:200]}; a[i] % 5 == 0; } }
    constraint asc_c  { foreach (a[i]) if (i > 0) a[i] > a[i-1]; }
    constraint sum_c  { a.sum() with (int'(item)) <= 600; }

    // The same rules written procedurally, as an independent check
    function bit is_legal();
      int total;
      total = 0;
      if (a.size() < 4 || a.size() > 8) return 0;
      foreach (a[i]) begin
        if (a[i] < 10 || a[i] > 200 || a[i] % 5 != 0) return 0;
        if (i > 0 && a[i] <= a[i-1])                  return 0;
        total += a[i];
      end
      return total <= 600;
    endfunction
  endclass

  sorted_arr s;
  int        solver_failures, illegal_results, ok;

  initial begin
    s = new();
    repeat (50) begin
      if (!s.randomize())      solver_failures++;
      else if (!s.is_legal())  illegal_results++;
    end
    $display("50 calls: solver failures=%0d illegal results=%0d",
             solver_failures, illegal_results);

    // Eight ascending multiples of 5 starting at 180 or more do not exist below 200
    ok = s.randomize() with { a.size() == 8; a[0] >= 180; };
    $display("over-constrained call returned %0d", ok);

    if (solver_failures == 0 && illegal_results == 0 && ok == 0) $display("TEST PASSED");
    else                                                         $display("TEST FAILED");
  end

endmodule
