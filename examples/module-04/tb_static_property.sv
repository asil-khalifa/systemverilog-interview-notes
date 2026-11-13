module tb_static_property;

  class packet;
    static int count = 0;        // shared by all packet objects
    int        id;               // unique to each object

    function new();
      count++;
      id = count;
    endfunction
  endclass

  packet p1, p2, p3;

  initial begin
    $display("1. before any object exists: count=%0d", packet::count);

    p1 = new();
    p2 = new();
    p3 = new();
    $display("2. ids: p1=%0d p2=%0d p3=%0d", p1.id, p2.id, p3.id);
    $display("3. count seen from: class=%0d p1=%0d p3=%0d",
             packet::count, p1.count, p3.count);

    p2.count = 10;               // written through one handle...
    $display("4. after p2.count = 10: class=%0d p1=%0d", packet::count, p1.count);
  end

endmodule
