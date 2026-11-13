module tb_event_nb_single;

  event ev;

  initial begin
    ->> ev;
    $display("[%0t] 1. after ->> ev   : statement did not block", $time);
    @(ev);
    $display("[%0t] 2. @(ev) passed   : the trigger arrived in the NBA region", $time);

    ->> #15 ev;
    $display("[%0t] 3. after ->> #15 ev : statement did not block", $time);
    @(ev);
    $display("[%0t] 4. @(ev) passed", $time);
  end

endmodule
