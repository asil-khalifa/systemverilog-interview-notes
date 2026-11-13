module tb_fork_loop_fixed;

  initial begin
    for (int i = 0; i < 3; i++) begin
      automatic int id = i;            // a new variable for each iteration, copied NOW
      fork
        begin
          #(10 * (id + 1));
          $display("[%0t] thread %0d finished", $time, id);
        end
      join_none
    end
    wait fork;
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
