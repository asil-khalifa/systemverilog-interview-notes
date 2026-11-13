module tb_fork_loop_bug;

  initial begin
    for (int i = 0; i < 3; i++) begin
      fork
        begin
          #(10 * (i + 1));
          $display("[%0t] thread %0d finished", $time, i);
        end
      join_none
    end
    wait fork;
    $display("[%0t] parent: all threads finished", $time);
  end

endmodule
