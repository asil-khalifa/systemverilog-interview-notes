module tb_constraint_bidir;

  class pair;
    rand bit [3:0] x, y, z;

    constraint rel_c  { y == x + 2; }      // looks like "compute y from x"
    constraint pin_c  { y == 7; }          // but this fixes y, which forces x
    constraint z_lo_c { z > y; }
    constraint z_hi_c { z < 9; }
  endclass

  pair p;

  initial begin
    p = new();
    repeat (3) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      $display("x=%0d y=%0d z=%0d", p.x, p.y, p.z);
    end
  end

endmodule
