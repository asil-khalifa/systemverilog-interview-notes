module tb_process_array;

  process jobs [$];
  int     killed;

  initial begin
    for (int i = 0; i < 3; i++) begin
      fork
        automatic int id = i;
        begin
          jobs.push_back(process::self());
          #(10 * (id + 1));
          $display("[%0t] worker %0d done", $time, id);
        end
      join_none
    end

    wait (jobs.size() == 3);        // all three threads have started and registered

    #25;
    foreach (jobs[k]) begin
      if (jobs[k].status() != process::FINISHED) begin
        jobs[k].kill();
        killed++;
      end
    end
    $display("[%0t] killed %0d unfinished worker(s)", $time, killed);
  end

endmodule
