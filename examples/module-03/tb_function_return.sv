module tb_function_return;

  typedef struct {
    int quotient;
    int remainder;
  } divmod_t;

  int unsigned error_count;

  // Void function: acts, returns nothing
  function automatic void report(string msg, bit is_error = 0);
    if (is_error) begin
      error_count++;
      $display("ERROR: %s", msg);
    end
    else $display("INFO : %s", msg);
  endfunction

  // Two results, method 1: return a struct
  function automatic divmod_t divmod(int x, int y);
    divmod_t r;
    r.quotient  = x / y;
    r.remainder = x % y;
    return r;
  endfunction

  // Two results, method 2: status as the return value, data through an output argument
  function automatic bit safe_div(input int x, input int y, output int q);
    if (y == 0) return 0;      // q keeps its default value
    q = x / y;
    return 1;
  endfunction

  // A void function may use "return;" to leave early
  function automatic void print_if_odd(int x);
    if (x % 2 == 0) return;
    $display("%0d is odd", x);
  endfunction

  divmod_t dm;
  int      q;

  initial begin
    report("starting");
    dm = divmod(17, 5);
    $display("17 / 5 = %0d remainder %0d", dm.quotient, dm.remainder);

    if (safe_div(20, 4, q))  $display("20 / 4 = %0d", q);
    if (!safe_div(20, 0, q)) report("division by zero rejected", 1);

    print_if_odd(4);
    print_if_odd(7);

    void'(safe_div(9, 3, q));
    $display("q = %0d, errors = %0d", q, error_count);
  end

endmodule
