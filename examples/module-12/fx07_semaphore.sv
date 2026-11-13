module fx07_semaphore;

  semaphore slots = new(2);

  task automatic user(string name, int start);
    #start;
    slots.get(1);
    $display("[%0t] %s enters", $time, name);
    #10;
    $display("[%0t] %s leaves", $time, name);
    slots.put(1);
  endtask

  initial begin
    fork
      user("A", 0);
      user("B", 1);
      user("C", 2);
    join
    $display("[%0t] all done", $time);
  end

endmodule
