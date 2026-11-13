class generic_fifo #(type T = int, int DEPTH = 4);

  protected T q [$];

  function bit is_full();   return (q.size() == DEPTH);  endfunction
  function bit is_empty();  return (q.size() == 0);      endfunction
  function int level();     return q.size();             endfunction

  function bit push(T item);
    if (is_full()) return 0;
    q.push_back(item);
    return 1;
  endfunction

  function bit pop(output T item);
    if (is_empty()) return 0;
    item = q.pop_front();
    return 1;
  endfunction

endclass

module tb_generic_fifo;

  typedef struct {
    bit [7:0] addr;
    bit [7:0] data;
  } bus_item_t;

  generic_fifo #(bit [7:0], 3) byte_fifo;
  generic_fifo #(bus_item_t)   item_fifo;

  bit [7:0]  b;
  bus_item_t it;

  initial begin
    byte_fifo = new();
    item_fifo = new();

    for (int i = 0; i < 4; i++) begin
      b = 8'hA0 + i;
      if (!byte_fifo.push(b)) $display("1. push of %h refused, FIFO full", b);
    end
    $display("2. level = %0d, full = %b", byte_fifo.level(), byte_fifo.is_full());

    while (byte_fifo.pop(b)) $display("3. popped %h", b);
    $display("4. empty = %b", byte_fifo.is_empty());

    void'(item_fifo.push('{addr: 8'h10, data: 8'hAA}));
    void'(item_fifo.push('{addr: 8'h14, data: 8'hBB}));
    void'(item_fifo.pop(it));
    $display("5. item: addr=%h data=%h, %0d left", it.addr, it.data, item_fifo.level());
  end

endmodule
