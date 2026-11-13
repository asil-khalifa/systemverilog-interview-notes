module ex01_stack;

  class int_stack;
    local int items [$];
    local int max_depth;

    function new(int max_depth = 4);
      this.max_depth = max_depth;
    endfunction

    function bit push(int value);
      if (items.size() >= max_depth) return 0;
      items.push_back(value);
      return 1;
    endfunction

    function bit pop(output int value);
      if (items.size() == 0) return 0;
      value = items.pop_back();
      return 1;
    endfunction

    function int depth();
      return items.size();
    endfunction
  endclass

  int_stack s;
  int       v;
  bit       ok;

  initial begin
    s = new(3);
    ok = s.push(10);
    ok = s.push(20);
    ok = s.push(30);
    ok = s.push(40);   $display("push 40 accepted? %0d", ok);
    ok = s.pop(v);     $display("pop -> %0d", v);
    ok = s.pop(v);     $display("pop -> %0d", v);
    $display("depth = %0d", s.depth());
  end

endmodule
