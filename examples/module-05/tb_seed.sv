module tb_seed;

  class item;
    rand bit [15:0] v;
  endclass

  item a, b;
  bit  same = 1;

  initial begin
    a = new();
    b = new();
    a.srandom(123);                   // give both objects the same seed
    b.srandom(123);
    repeat (5) begin
      void'(a.randomize());
      void'(b.randomize());
      if (a.v != b.v) same = 0;
    end
    $display("two objects with the same seed produced the same 5 values: %s",
             same ? "yes" : "NO");
  end

endmodule
