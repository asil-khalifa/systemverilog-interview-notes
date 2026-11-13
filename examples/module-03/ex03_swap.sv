module ex03_swap;

  task automatic swap(ref int x, ref int y);
    int tmp;
    tmp = x;
    x   = y;
    y   = tmp;
  endtask

  int a, b;

  initial begin
    a = 3;
    b = 7;
    swap(a, b);
    $display("a=%0d b=%0d", a, b);
  end

endmodule
