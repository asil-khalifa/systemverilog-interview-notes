module tb_recursion;

  function automatic longint unsigned factorial(int unsigned n);
    if (n <= 1) return 1;                       // base case
    return n * factorial(n - 1);                // recursive case
  endfunction

  function automatic int fib(int n);
    if (n < 2) return n;                        // fib(0) = 0, fib(1) = 1
    return fib(n - 1) + fib(n - 2);
  endfunction

  function automatic int gcd(int x, int y);
    if (y == 0) return x;
    return gcd(y, x % y);
  endfunction

  // Sum of 1..n, automatic: correct
  function automatic int sum_auto(int n);
    int partial;
    if (n == 0) return 0;
    partial = sum_auto(n - 1);
    return partial + n;
  endfunction

  // The same code with static lifetime: broken
  function int sum_static(int n);
    int partial;
    if (n == 0) return 0;
    partial = sum_static(n - 1);
    return partial + n;
  endfunction

  // A recursive task that consumes time
  task automatic countdown(int n);
    if (n == 0) begin
      $display("[%0t] lift-off", $time);
      return;
    end
    $display("[%0t] %0d", $time, n);
    #10;
    countdown(n - 1);
  endtask

  initial begin
    $display("factorial(5)  = %0d", factorial(5));
    $display("factorial(20) = %0d", factorial(20));
    $display("fib(10)       = %0d", fib(10));
    $display("gcd(48, 18)   = %0d", gcd(48, 18));
    $display("sum_auto(3)   = %0d", sum_auto(3));
    $display("sum_static(3) = %0d", sum_static(3));
    countdown(3);
  end

endmodule
