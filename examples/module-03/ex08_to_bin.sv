module ex08_to_bin;

  function automatic string to_bin(int unsigned n);
    string digit;
    digit = (n % 2) ? "1" : "0";
    if (n < 2) return digit;                  // base case: a single digit
    return {to_bin(n / 2), digit};            // higher digits first, then this one
  endfunction

  initial begin
    $display("0   -> %s", to_bin(0));
    $display("10  -> %s", to_bin(10));
    $display("255 -> %s", to_bin(255));
  end

endmodule
