module ex02_linked_list;

  class node;
    int  value;
    node next;                         // a handle of the class's own type

    function new(int value);
      this.value = value;
    endfunction
  endclass

  class int_list;
    local node head;
    local node tail;
    local int  count;

    function void append(int value);
      node n = new(value);
      if (head == null) head = n;      // first node
      else              tail.next = n; // link after the current last node
      tail = n;
      count++;
    endfunction

    function int sum();
      int  total = 0;
      node n     = head;
      while (n != null) begin
        total += n.value;
        n = n.next;
      end
      return total;
    endfunction

    function void print();
      string s = "";
      node   n = head;
      while (n != null) begin
        s = {s, $sformatf("%0d ", n.value)};
        n = n.next;
      end
      $display("list: %s(count=%0d)", s, count);
    endfunction
  endclass

  int_list lst;

  initial begin
    lst = new();
    lst.append(5);
    lst.append(7);
    lst.append(9);
    lst.print();
    $display("sum = %0d", lst.sum());
  end

endmodule
