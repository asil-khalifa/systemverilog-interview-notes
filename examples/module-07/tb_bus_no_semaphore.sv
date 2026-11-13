module tb_bus_no_semaphore;

  logic [7:0] bus;

  task automatic send(string name, logic [7:0] data, int unsigned hold);
    bus = data;
    $display("[%0t] %s drives %h", $time, name, data);
    #hold;
    $display("[%0t] %s finished: bus = %h, expected %h", $time, name, bus, data);
  endtask

  initial begin
    fork
      send("DRV_A", 8'hAA, 20);
      begin
        #5;
        send("DRV_B", 8'hBB, 20);
      end
    join
  end

endmodule
