module tb_class_methods;

  class counter;
    int    count;
    string name = "cnt";

    function void incr(int step = 1);
      count += step;
    endfunction

    function int get();
      return count;
    endfunction

    task wait_then_incr(int delay);
      #delay;
      count++;
      $display("[%0t] %s: count=%0d", $time, name, count);
    endtask
  endclass

  counter c;

  initial begin
    c = new();
    c.incr();                    // step defaults to 1
    c.incr(5);
    $display("[%0t] %s: count=%0d", $time, c.name, c.get());

    c.wait_then_incr(10);        // a task: simulation time advances
    c.wait_then_incr(5);
  end

endmodule
