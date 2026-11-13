module tb_process_suspend;

  process p_worker;

  initial begin
    fork
      begin
        p_worker = process::self();
        for (int i = 1; i <= 4; i++)
          #10 $display("[%0t] worker step %0d", $time, i);
      end
    join_none

    wait (p_worker != null);

    #15 p_worker.suspend();
    $display("[%0t] worker suspended", $time);

    #30 p_worker.resume();
    $display("[%0t] worker resumed", $time);

    p_worker.await();
    $display("[%0t] worker finished", $time);
  end

endmodule
