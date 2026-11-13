module ex02_clog2;

  function automatic int clog2(int unsigned n);
    int r;
    r = 0;
    while ((1 << r) < n) r++;
    return r;
  endfunction

  initial begin
    $display("clog2(1)=%0d clog2(2)=%0d clog2(16)=%0d clog2(17)=%0d clog2(1000)=%0d",
             clog2(1), clog2(2), clog2(16), clog2(17), clog2(1000));
  end

endmodule
