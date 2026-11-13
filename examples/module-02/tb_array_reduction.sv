module tb_array_reduction;

  int       n [] = '{1, 2, 3, 4};
  bit [7:0] b [] = '{200, 100, 50};
  bit [3:0] m [] = '{4'b1100, 4'b1010, 4'b1001};
  int       e [$];                         // empty queue
  int       total;

  initial begin
    $display("1. sum = %0d   product = %0d", n.sum(), n.product());
    $display("2. and = %0d   or = %0d   xor = %0d", n.and(), n.or(), n.xor());

    total = b.sum();
    $display("3. b.sum()                    = %0d", total);
    total = b.sum() with (int'(item));
    $display("4. b.sum() with (int'(item))  = %0d", total);

    $display("5. count of n > 2 : wrong = %0d   right = %0d",
             n.sum() with (item > 2), n.sum() with (int'(item > 2)));

    $display("6. and = %b   or = %b   xor = %b", m.and(), m.or(), m.xor());

    $display("7. sum of squares     = %0d", n.sum() with (item * item));
    $display("8. sum of even values = %0d", n.sum() with (item % 2 == 0 ? item : 0));
    $display("9. sum of index*value = %0d", n.sum() with (item.index * item));

    $display("10. sum of an empty queue = %0d", e.sum());
    $display("11. average = %0.2f", real'(n.sum()) / n.size());
  end

endmodule
