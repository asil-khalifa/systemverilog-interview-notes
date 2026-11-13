module tb_array_compare;

  logic [7:0] exp_data [4] = '{8'h11, 8'h22, 8'h33, 8'h44};
  logic [7:0] act_data [4] = '{8'h11, 8'h22, 8'h3F, 8'h44};
  logic [7:0] x_data   [4] = '{8'h11, 8'h22, 8'hxx, 8'h44};
  int         q1 [$] = {1, 2, 3};
  int         q2 [$] = {1, 2, 3, 4};

  initial begin
    if (act_data == exp_data) $display("1. arrays match");
    else                      $display("1. arrays differ");

    foreach (exp_data[i])
      if (act_data[i] !== exp_data[i])
        $display("2.   mismatch at [%0d]: actual=%h expected=%h",
                 i, act_data[i], exp_data[i]);

    $display("3. first two elements equal : %b", act_data[0:1] == exp_data[0:1]);

    if (x_data != exp_data)  $display("4. using != : mismatch reported");
    else                     $display("4. using != : no mismatch reported");
    if (x_data !== exp_data) $display("5. using !== : mismatch reported");

    $display("6. different sizes equal? %b", q1 == q2);
    q2.delete(3);
    $display("7. after delete(3) equal? %b", q1 == q2);
  end

endmodule
