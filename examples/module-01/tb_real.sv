module tb_real;

  real r;
  int  i;

  initial begin
    $display("1. default real      = %0f", r);

    r = 3.7;
    i = r;         $display("2. i = r      (3.7)  = %0d", i);
    i = int'(r);   $display("3. int'(r)    (3.7)  = %0d", i);
    i = $rtoi(r);  $display("4. $rtoi(r)   (3.7)  = %0d", i);
    i = int'(2.5); $display("5. int'(2.5)         = %0d", i);
    i = int'(-2.5);$display("6. int'(-2.5)        = %0d", i);

    r = 7 / 2;     $display("7. r = 7 / 2         = %0.2f", r);
    r = 7 / 2.0;   $display("8. r = 7 / 2.0       = %0.2f", r);

    r = 0.1 + 0.2;
    if (r == 0.3) $display("9. 0.1 + 0.2 == 0.3");
    else          $display("9. 0.1 + 0.2 != 0.3, it is %0.17f", r);

    if ((r - 0.3) < 1.0e-9 && (0.3 - r) < 1.0e-9)
      $display("10. equal within a tolerance of 1e-9");
  end

endmodule
