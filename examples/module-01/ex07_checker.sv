module ex07_checker;

  function automatic void check(string what, logic [8:0] actual, logic [8:0] expected);
    if ($isunknown(actual))
      $display("FAIL %s: output contains X/Z (%b)", what, actual);
    else if (actual !== expected)
      $display("FAIL %s: actual=%0d expected=%0d", what, actual, expected);
    else
      $display("PASS %s: %0d", what, actual);
  endfunction

  initial begin
    check("add", 9'd300,        9'd300);
    check("sub", 9'd5,          9'd6);
    check("xor", 9'bx_0000_1111, 9'd15);
  end

endmodule
