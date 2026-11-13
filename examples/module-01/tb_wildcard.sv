module tb_wildcard;

  logic [3:0]  a;
  logic [15:0] addr;

  initial begin
    a = 4'b1010;
    $display("1. 1010 ==? 1xx0 : %b", a ==? 4'b1xx0);
    $display("2. 1010 ==? 0xxx : %b", a ==? 4'b0xxx);
    $display("3. 1010 ==? 1?1? : %b", a ==? 4'b1?1?);
    $display("4. 1010 !=? 1xx0 : %b", a !=? 4'b1xx0);

    a = 4'b1x10;
    $display("5. 1x10 ==? 1010 : %b", a ==? 4'b1010);
    $display("6. 1x10 ==? 1?10 : %b", a ==? 4'b1?10);
    $display("7. 1x10 ==? 0xxx : %b", a ==? 4'b0xxx);

    $display("8. 1010 ==? 1xx0 : %b   but   1xx0 ==? 1010 : %b",
             4'b1010 ==? 4'b1xx0, 4'b1xx0 ==? 4'b1010);

    addr = 16'hA07C;
    if (addr ==? 16'hA0??) $display("9. address %h is in the A0xx block", addr);

    a = 4'b1010;
    if (a inside {4'b0???, 4'b1??0}) $display("10. inside also uses wildcard matching");
  end

endmodule
