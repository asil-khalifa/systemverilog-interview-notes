module fx01_fifo_class;

  class fifo #(type T = int, int DEPTH = 4);
    local T items [$];

    function bit is_full();
      return items.size() == DEPTH;
    endfunction

    function bit is_empty();
      return items.size() == 0;
    endfunction

    function int count();
      return items.size();
    endfunction

    function bit push(T item);
      if (is_full()) return 0;
      items.push_back(item);
      return 1;
    endfunction

    function bit pop(output T item);
      if (is_empty()) return 0;
      item = items.pop_front();
      return 1;
    endfunction
  endclass

  fifo #(bit [7:0], 3) f = new();
  bit [7:0] d;
  bit       ok;

  initial begin
    for (int i = 1; i <= 4; i++) begin
      d  = 8'(i * 16);
      ok = f.push(d);
      $display("push %h -> ok=%b count=%0d full=%b", d, ok, f.count(), f.is_full());
    end
    while (f.pop(d))
      $display("pop  %h    count=%0d empty=%b", d, f.count(), f.is_empty());
  end

endmodule
