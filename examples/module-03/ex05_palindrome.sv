module ex05_palindrome;

  function automatic bit is_pal_range(string s, int lo, int hi);
    if (lo >= hi)       return 1;                 // base case: 0 or 1 characters left
    if (s[lo] != s[hi]) return 0;                 // base case: mismatch
    return is_pal_range(s, lo + 1, hi - 1);       // recursive case: the inner part
  endfunction

  function automatic bit is_palindrome(string s);
    return is_pal_range(s, 0, s.len() - 1);
  endfunction

  initial begin
    $display("level -> %b", is_palindrome("level"));
    $display("hello -> %b", is_palindrome("hello"));
    $display("noon  -> %b", is_palindrome("noon"));
  end

endmodule
