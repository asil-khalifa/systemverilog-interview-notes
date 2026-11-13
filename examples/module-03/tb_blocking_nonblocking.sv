module tb_blocking_nonblocking;

  int a, b, c, d;

  initial begin
    a = 1;  b = 2;
    a = b;
    b = a;
    $display("1. blocking            : a=%0d b=%0d", a, b);

    c = 1;  d = 2;
    c <= d;
    d <= c;
    $display("2. nonblocking, before : c=%0d d=%0d", c, d);
    #1;
    $display("3. nonblocking, after  : c=%0d d=%0d", c, d);
  end

endmodule
