module tb_operators;

  logic [3:0] a, b;
  logic [7:0] p, q, avg;
  bit         flag;
  int         n;

  initial begin
    a = 4'b1010;
    b = 4'b0101;
    $display("1.  logical : a && b = %b   a || b = %b   !a = %b", a && b, a || b, !a);
    $display("2.  bitwise : a & b = %b   a | b = %b   a ^ b = %b   ~a = %b",
             a & b, a | b, a ^ b, ~a);

    a = 4'b1011;
    $display("3.  reduction of 1011 : &a=%b  |a=%b  ^a=%b  ~&a=%b  ~|a=%b  ~^a=%b",
             &a, |a, ^a, ~&a, ~|a, ~^a);
    $display("4.  shift of 1011     : a << 1 = %b   a >> 1 = %b", a << 1, a >> 1);

    $display("5.  7 / 2 = %0d   -7 / 2 = %0d   -7 %% 2 = %0d   2 ** 10 = %0d",
             7 / 2, -7 / 2, -7 % 2, 2 ** 10);
    $display("6.  a / 0 = %b", a / 4'd0);

    flag = 1;
    n = ~flag;   $display("7.  int n = ~flag -> %0d", n);
    n = !flag;   $display("8.  int n = !flag -> %0d", n);

    p = 8'd200;
    q = 8'd100;
    avg = (p + q) >> 1;             $display("9.  (p + q) >> 1          = %0d", avg);
    avg = ({1'b0, p} + q) >> 1;     $display("10. ({1'b0, p} + q) >> 1  = %0d", avg);

    $display("11. max = %0d", (p > q) ? p : q);
    $display("12. {a, b} = %b   {2{a}} = %b", {a, b}, {2{a}});

    if (a inside {4'd3, [4'd9:4'd12]}) $display("13. a (=%0d) is inside {3, [9:12]}", a);

    $display("14. a & b == b   -> %b", a & b == b);
    $display("15. (a & b) == b -> %b", (a & b) == b);
  end

endmodule
