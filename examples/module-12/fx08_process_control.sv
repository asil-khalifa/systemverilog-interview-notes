module fx08_process_control;

  string  names [3] = '{"fast", "medium", "slow"};
  int     durs  [3] = '{10, 40, 90};
  process p [3];

  task automatic job(string name, int dur);
    #dur;
    $display("[%0t] %s finished", $time, name);
  endtask

  initial begin
    foreach (p[i])
      fork
        automatic int k = i;
        begin
          p[k] = process::self();     // remember the handle of this thread
          job(names[k], durs[k]);
        end
      join_none

    #50;                              // the deadline
    foreach (p[i])
      if (p[i].status() == process::FINISHED)
        $display("[%0t] %s: finished in time", $time, names[i]);
      else begin
        $display("[%0t] %s: still running, killed", $time, names[i]);
        p[i].kill();
      end

    #100 $display("[%0t] end of test", $time);
  end

endmodule
