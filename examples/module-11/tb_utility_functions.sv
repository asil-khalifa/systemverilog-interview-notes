module tb_utility_functions;

  logic [7:0] v;
  string      s;
  int         r;

  initial begin
    $display("1. $clog2(1)=%0d  $clog2(8)=%0d  $clog2(9)=%0d  $clog2(1024)=%0d",
             $clog2(1), $clog2(8), $clog2(9), $clog2(1024));

    v = 8'b0010_1000;
    $display("2. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0001_0000;
    $display("3. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0000_0000;
    $display("4. %b : countones=%0d onehot=%b onehot0=%b",
             v, $countones(v), $onehot(v), $onehot0(v));
    v = 8'b0000_x001;
    $display("5. %b : isunknown=%b", v, $isunknown(v));

    s = $sformatf("txn %0d: a=%0h op=%s", 7, 8'hA5, "ALU_ADD");
    $display("6. %s (length %0d)", s, s.len());

    r = $urandom_range(10, 5);
    $display("7. $urandom_range(10, 5) is within 5..10: %b", r inside {[5:10]});
  end

endmodule
