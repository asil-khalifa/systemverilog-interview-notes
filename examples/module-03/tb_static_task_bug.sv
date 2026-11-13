module tb_static_task_bug;

  // Static by default: ONE copy of id and dly for all callers
  task send_static(input int id, input int dly);
    #dly;
    $display("[%0t] static   : finished id=%0d", $time, id);
  endtask

  // Automatic: each call has its own id and dly
  task automatic send_auto(input int id, input int dly);
    #dly;
    $display("[%0t] automatic: finished id=%0d", $time, id);
  endtask

  initial begin
    fork
      send_static(1, 10);
      send_static(2, 5);
    join

    fork
      send_auto(1, 10);
      send_auto(2, 5);
    join
  end

endmodule
