module tb_solve_before;

  class no_order;
    rand bit       mode;
    rand bit [1:0] len;
    constraint imp_c { (mode == 1) -> (len == 3); }
  endclass

  class mode_first extends no_order;
    constraint order_c { solve mode before len; }
  endclass

  class len_first extends no_order;
    constraint order_c { solve len before mode; }
  endclass

  function automatic int count_mode_one(no_order h);
    int n = 0;
    repeat (1000) begin
      if (!h.randomize()) $fatal(1, "randomize failed");
      if (h.mode == 1) begin
        n++;
        if (h.len != 3) $error("illegal solution mode=1 len=%0d", h.len);
      end
    end
    return n;
  endfunction

  no_order   a;
  mode_first b;
  len_first  c;

  initial begin
    a = new();  b = new();  c = new();
    $display("no ordering           : mode=1 in %0d of 1000", count_mode_one(a));
    $display("solve mode before len : mode=1 in %0d of 1000", count_mode_one(b));
    $display("solve len before mode : mode=1 in %0d of 1000", count_mode_one(c));
  end

endmodule
