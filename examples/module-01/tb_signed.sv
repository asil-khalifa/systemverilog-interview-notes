module tb_signed;

  byte             s8;     // signed by default
  bit        [7:0] u8;     // unsigned by default
  bit signed [7:0] sv8;    // vector made signed
  int              i;
  int unsigned     ui;
  longint          li;

  initial begin
    s8 = 8'hFF;  u8 = 8'hFF;  sv8 = 8'hFF;
    $display("1. same bits FF     : s8=%0d  u8=%0d  sv8=%0d", s8, u8, sv8);

    i = s8;  $display("2. int = byte       : %0d  (sign-extended)", i);
    i = u8;  $display("3. int = bit [7:0]  : %0d  (zero-extended)", i);

    i  = -1;
    ui = 1;
    if (i < ui) $display("4. -1 < 1           : true");
    else        $display("4. -1 < 1           : false, -1 was treated as %0d", unsigned'(i));

    s8 = -8;
    $display("5. -8 >>> 1 = %0d    -8 >> 1 = %0d", s8 >>> 1, s8 >> 1);
    u8 = 8'hF8;
    $display("6. unsigned F8 >>> 1 = %0d", u8 >>> 1);

    $display("7. s8 = %0d   s8[7:0] = %0d", s8, s8[7:0]);

    i = 4'sb1111;  $display("8. int = 4'sb1111   : %0d", i);
    i = 4'b1111;   $display("9. int = 4'b1111    : %0d", i);

    li = -1;              $display("10. longint = -1            : %0d", li);
    li = unsigned'(-1);   $display("11. longint = unsigned'(-1) : %0d", li);
  end

endmodule
