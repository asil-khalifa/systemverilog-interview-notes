module tb_event_triggered;

  event ev;

  initial begin
    -> ev;                                      // the trigger happens FIRST, at time 0

    fork                                        // both waits start AFTER the trigger
      begin
        @(ev);
        $display("[%0t] thread 1: @(ev) passed", $time);
      end
      begin
        wait (ev.triggered);
        $display("[%0t] thread 2: wait (ev.triggered) passed", $time);
      end
    join_none

    #20;
    $display("[%0t] parent  : -> ev again", $time);
    -> ev;
  end

endmodule
