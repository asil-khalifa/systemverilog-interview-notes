module tb_semaphore_bus;

  logic [7:0] bus;

  class bus_driver;
    string    name;
    semaphore bus_key;                           // handle to the shared semaphore

    function new(string name, semaphore bus_key);
      this.name    = name;
      this.bus_key = bus_key;
    endfunction

    task send(logic [7:0] data, int unsigned hold);
      $display("[%0t] %s requests the bus", $time, name);
      bus_key.get(1);                            // blocks while the other driver has it
      $display("[%0t] %s granted", $time, name);
      bus = data;                                // ---- critical section starts ----
      #hold;
      $display("[%0t] %s releasing, bus = %h", $time, name, bus);
      bus_key.put(1);                            // ---- critical section ends ------
    endtask
  endclass

  semaphore  bus_key;
  bus_driver drv_a, drv_b;

  initial begin
    bus_key = new(1);                            // ONE semaphore with ONE key
    drv_a   = new("DRV_A", bus_key);
    drv_b   = new("DRV_B", bus_key);

    fork
      begin
        drv_a.send(8'hAA, 20);
        #3;
        drv_a.send(8'hAA, 20);
      end
      begin
        #5;
        drv_b.send(8'hBB, 20);
        #7;
        drv_b.send(8'hBB, 20);
      end
    join
    $display("[%0t] TOP: all transfers complete", $time);
  end

endmodule
