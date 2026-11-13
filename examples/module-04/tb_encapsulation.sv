module tb_encapsulation;

  class fifo_model;
    local bit [7:0] mem [$];            // hidden storage
    local int       depth;              // hidden configuration
    local int       overflow_count;     // hidden statistics

    function new(int depth = 16);
      this.depth = depth;
    endfunction

    function bit push(bit [7:0] value);
      if (is_full()) begin
        overflow_count++;
        return 0;                       // rejected: the model stays consistent
      end
      mem.push_back(value);
      return 1;
    endfunction

    function bit pop(output bit [7:0] value);
      if (is_empty()) return 0;
      value = mem.pop_front();
      return 1;
    endfunction

    function bit is_full();   return mem.size() == depth; endfunction
    function bit is_empty();  return mem.size() == 0;     endfunction
    function int used();      return mem.size();          endfunction
    function int overflows(); return overflow_count;      endfunction
  endclass

  fifo_model fifo;
  bit [7:0]  v;
  bit        ok;

  initial begin
    fifo = new(2);                                   // a 2-entry model

    ok = fifo.push(8'h11);  $display("push 11: ok=%0d used=%0d", ok, fifo.used());
    ok = fifo.push(8'h22);  $display("push 22: ok=%0d used=%0d", ok, fifo.used());
    ok = fifo.push(8'h33);  $display("push 33: ok=%0d used=%0d", ok, fifo.used());

    ok = fifo.pop(v);       $display("pop    : ok=%0d value=%h", ok, v);
    ok = fifo.pop(v);       $display("pop    : ok=%0d value=%h", ok, v);
    ok = fifo.pop(v);       $display("pop    : ok=%0d (empty)", ok);

    $display("overflows=%0d", fifo.overflows());
    // fifo.mem.push_back(8'hFF);                    // ILLEGAL: mem is local
    // fifo.depth = 100;                             // ILLEGAL: depth is local
  end

endmodule
