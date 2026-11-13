module ex05_job_pool;

  semaphore pool = new(2);                  // two keys: two jobs at a time

  initial begin
    for (int i = 0; i < 4; i++) begin
      automatic int id = i;
      fork
        begin
          #(id + 1);
          pool.get();
          $display("[%0t] job %0d starts", $time, id);
          #10;
          $display("[%0t] job %0d ends", $time, id);
          pool.put();
        end
      join_none
    end
    wait fork;
    $display("[%0t] all jobs done", $time);
  end

endmodule
