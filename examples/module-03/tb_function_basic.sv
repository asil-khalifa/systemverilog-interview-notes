module tb_function_basic;

  // 1. Return with the return statement
  function automatic int add(int x, int y);
    return x + y;
  endfunction

  // 2. Return by assigning to the function name (Verilog style)
  function automatic int max3(int x, int y, int z);
    max3 = x;
    if (y > max3) max3 = y;
    if (z > max3) max3 = z;
  endfunction

  // 3. Return type omitted: the function returns ONE BIT of type logic
  function automatic add_one_bit(int x, int y);
    return x + y;
  endfunction

  // 4. A function with no arguments
  function automatic string banner();
    return "=== ALU test ===";
  endfunction

  // 5. A function that never sets its return value
  function automatic int forgot_return(int x);
    int unused;
    unused = x * 2;
  endfunction

  int r;

  initial begin
    r = add(3, 4);                 $display("1. add(3, 4)            = %0d", r);
    r = add(add(1, 2), 10) * 2;    $display("2. add(add(1, 2), 10)*2 = %0d", r);
    r = max3(7, 42, 19);           $display("3. max3(7, 42, 19)      = %0d", r);
    r = add_one_bit(3, 4);         $display("4. add_one_bit(3, 4)    = %0d", r);
    $display("5. %s", banner());
    r = forgot_return(5);          $display("6. forgot_return(5)     = %0d", r);
  end

endmodule
