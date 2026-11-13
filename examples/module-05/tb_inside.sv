module tb_inside;

  class sel;
    rand bit [7:0] x, y, z;
    bit [7:0] legal_q[$] = '{8'd3, 8'd7, 8'd42};   // state variable: a list of legal values
    bit [7:0] used_q[$]  = '{8'd100, 8'd101};

    constraint x_c { x inside {0, [10:19], 255}; }
    constraint y_c { y inside {legal_q}; }
    constraint z_c { z inside {[100:103]}; !(z inside {used_q}); }
  endclass

  sel s;
  int x_zero;

  initial begin
    s = new();
    repeat (1200) begin
      if (!s.randomize()) $fatal(1, "randomize failed");
      if (s.x == 0) x_zero++;
      if (!(s.y inside {3, 7, 42}))  $error("y illegal: %0d", s.y);
      if (!(s.z inside {102, 103}))  $error("z illegal: %0d", s.z);
    end
    $display("last: x=%0d y=%0d z=%0d", s.x, s.y, s.z);
    $display("x was 0 in %0d of 1200 calls", x_zero);
  end

endmodule
