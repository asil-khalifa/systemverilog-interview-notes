module tb_constraint_traps;

  class traps;
    rand bit [7:0] a, b;        // for the overflow trap
    rand bit [3:0] p, q;        // for the subtraction trap
    rand bit [7:0] x;           // for the chained comparison

    constraint narrow_c { a + b == 8'd10; }
    constraint sub_c    { p - q > 0; }
    constraint chain_c  { 10 < x < 20; }
  endclass

  traps t;
  int   wrapped, p_less, x_outside;

  initial begin
    t = new();
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize failed");
      if (int'(t.a) + int'(t.b) != 10) wrapped++;
      if (t.p < t.q)                   p_less++;
      if (!(t.x inside {[11:19]}))     x_outside++;
    end
    $display("a + b was not really 10 : %0d of 1000", wrapped);
    $display("p was less than q       : %0d of 1000", p_less);
    $display("x was outside 11..19    : %0d of 1000", x_outside);
  end

endmodule
