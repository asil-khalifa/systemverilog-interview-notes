module tb_rand_intro;

  class simple_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;

    constraint small_a_c { a < 10; }
  endclass

  simple_txn txn;

  initial begin
    txn = new();
    repeat (5) begin
      if (!txn.randomize()) $fatal(1, "randomize failed");
      $display("a=%0d b=%0d", txn.a, txn.b);
    end
    $display("$urandom_range(5, 1) = %0d", $urandom_range(5, 1));
  end

endmodule
