module tb_display_strobe;

  logic [3:0] a;

  initial begin
    a = 4'd1;
    $display("[%0t] $display : a = %0d", $time, a);
    $strobe ("[%0t] $strobe  : a = %0d", $time, a);
    a = 4'd2;
    a <= 4'd3;
    $display("[%0t] $display : a = %0d", $time, a);
    #10;
    $display("[%0t] $display : a = %0d", $time, a);
  end

endmodule
