module tb_regions;

  int x;

  initial begin
    x = 1;
    x <= 2;
    $strobe ("3. $strobe   (Postponed region)   : x=%0d", x);
    $display("1. $display  (Active region)      : x=%0d", x);
    #0;
    $display("2. after #0  (via Inactive region): x=%0d", x);
  end

endmodule
