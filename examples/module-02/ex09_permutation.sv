module ex09_permutation;

  function automatic bit is_permutation(int x [], int y []);
    if (x.size() != y.size()) return 0;
    x.sort();                  // x and y are copies: the caller's arrays are not changed
    y.sort();
    return (x == y);
  endfunction

  int a [] = '{3, 1, 2};
  int b [] = '{2, 3, 1};
  int c [] = '{3, 1, 1};

  initial begin
    $display("a and b : %b", is_permutation(a, b));
    $display("a and c : %b", is_permutation(a, c));
    $display("a is still %p", a);
  end

endmodule
