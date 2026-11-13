module tb_four_state;

  logic       sel;
  logic [3:0] a, b, y;

  initial begin
    a   = 4'b1100;
    b   = 4'b1010;
    sel = 1'bx;

    if (sel) y = a;
    else     y = b;
    $display("1. if-else with X select : y = %b", y);

    y = sel ? a : b;
    $display("2. ?: with X select      : y = %b", y);

    case (sel)
      1'b0   : $display("3. case: matched 0");
      1'b1   : $display("3. case: matched 1");
      default: $display("3. case: X matched neither 0 nor 1, default taken");
    endcase

    $display("4. 0&x=%b  1&x=%b  0|x=%b  1|x=%b  1^x=%b  ~x=%b  1&z=%b",
             1'b0 & 1'bx, 1'b1 & 1'bx, 1'b0 | 1'bx, 1'b1 | 1'bx, 1'b1 ^ 1'bx, ~1'bx,
             1'b1 & 1'bz);

    y = 4'b1x00;
    $display("5. 1x00 + 1 = %b", y + 4'b0001);
    $display("6. 1x00 > 0 = %b", y > 4'b0000);
    $display("7. &1x00 = %b   |1x00 = %b   ^1x00 = %b", &y, |y, ^y);
    $display("8. $isunknown(1x00) = %b   $countones(1x00) = %0d", $isunknown(y), $countones(y));
  end

endmodule
