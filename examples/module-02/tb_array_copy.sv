module tb_array_copy;

  class item_c;
    int val;
    function new(int v);
      val = v;
    endfunction
  endclass

  int    a [3] = '{1, 2, 3};
  int    b [3];
  item_c h1 [2];
  item_c h2 [2];
  item_c h3 [2];

  initial begin
    // arrays of values: a real copy
    b    = a;
    b[0] = 100;
    $display("1. values : a[0] = %0d   b[0] = %0d", a[0], b[0]);

    // arrays of class handles
    h1[0] = new(10);
    h1[1] = new(20);

    h2 = h1;                                  // shallow copy: only the handles are copied
    h2[0].val = 99;
    $display("2. shallow: h1[0].val = %0d   h2[0].val = %0d", h1[0].val, h2[0].val);

    foreach (h1[i]) h3[i] = new(h1[i].val);   // deep copy: a new object per element
    h3[1].val = 77;
    $display("3. deep   : h1[1].val = %0d   h3[1].val = %0d", h1[1].val, h3[1].val);

    $display("4. h1 == h2 : %b    h1 == h3 : %b", h1 == h2, h1 == h3);
  end

endmodule
