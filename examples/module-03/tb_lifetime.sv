module tb_lifetime;

  // Automatic function, automatic local: re-created and re-initialised on each call
  function automatic int count_auto();
    int n = 0;
    n++;
    return n;
  endfunction

  // Automatic function with an explicitly static local: one copy, initialised once
  function automatic int count_static_var();
    static int n = 0;
    n++;
    return n;
  endfunction

  // Static function (the module default): its locals are static
  function int count_static_func();
    int n;                 // static, starts at 0, keeps its value between calls
    n++;
    return n;
  endfunction

  initial begin
    $display("call  auto  static_var  static_func");
    for (int i = 1; i <= 3; i++)
      $display("%0d     %0d     %0d           %0d",
               i, count_auto(), count_static_var(), count_static_func());
  end

endmodule
