module ex03_timeout;

  task automatic do_work(int duration);
    #duration;
  endtask

  task automatic run_with_timeout(int duration, int limit, output bit timed_out);
    process p_work;

    fork                                   // start the work as its own process
      begin
        p_work = process::self();
        do_work(duration);
      end
    join_none
    wait (p_work != null);

    fork                                   // isolating fork around the race
      begin
        fork
          p_work.await();
          #limit;
        join_any
        disable fork;
      end
    join

    timed_out = (p_work.status() != process::FINISHED);
    if (timed_out) p_work.kill();
  endtask

  bit expired;

  initial begin
    run_with_timeout(30, 50, expired);
    $display("[%0t] work=30 limit=50 : timed_out=%b", $time, expired);

    run_with_timeout(80, 50, expired);
    $display("[%0t] work=80 limit=50 : timed_out=%b", $time, expired);

    #100 $display("[%0t] end", $time);
  end

endmodule
