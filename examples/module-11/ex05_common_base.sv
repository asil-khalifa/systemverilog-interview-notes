virtual class item_base;
  pure virtual function string describe();
endclass

class typed_item #(type T = int) extends item_base;
  T value;

  function new(T value);
    this.value = value;
  endfunction

  virtual function string describe();
    return $sformatf("%0d-bit item with value %0d", $bits(value), value);
  endfunction
endclass

module ex05_common_base;

  item_base                q [$];
  typed_item #(int)        i_item;
  typed_item #(byte)       b_item;
  typed_item #(bit [11:0]) v_item;

  initial begin
    i_item = new(100);
    b_item = new(-5);
    v_item = new(12'hABC);

    q.push_back(i_item);        // derived handle stored in a base-class queue (upcast)
    q.push_back(b_item);
    q.push_back(v_item);

    foreach (q[k]) $display("%0d: %s", k, q[k].describe());
  end

endmodule
