module tb_immediate;

  int         a, b;
  logic [3:0] grant;
  logic       unknown;

  initial begin
    a = 5;
    b = 5;
    a_equal: assert (a == b)
      $display("[%0t] a_equal passed: a=%0d b=%0d", $time, a, b);
    else
      $display("[%0t] a_equal FAILED: a=%0d b=%0d", $time, a, b);

    #10 b = 6;
    a_equal_again: assert (a == b)
      $display("[%0t] a_equal_again passed", $time);
    else
      $display("[%0t] a_equal_again FAILED: a=%0d b=%0d", $time, a, b);

    #10 grant = 4'b0110;
    a_onehot: assert ($onehot(grant))
      else $display("[%0t] a_onehot FAILED: grant=%b", $time, grant);

    grant = 4'b0100;
    a_onehot_again: assert ($onehot(grant))
      $display("[%0t] a_onehot_again passed: grant=%b", $time, grant);

    a_known: assert (unknown)
      else $display("[%0t] a_known FAILED: an X condition counts as false", $time);
  end

endmodule
