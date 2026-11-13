module tb_fork_nested;

  initial begin
    fork
      begin : branch_1
        fork
          #10 $display("[%0t] 1a done", $time);
          #20 $display("[%0t] 1b done", $time);
        join
        $display("[%0t] branch 1 complete (waited for 1a and 1b)", $time);
      end

      begin : branch_2
        #5;
        fork
          #10 $display("[%0t] 2a done", $time);
          #30 $display("[%0t] 2b done", $time);
        join_any
        $display("[%0t] branch 2 complete (waited for 2a only)", $time);
      end
    join
    $display("[%0t] parent: outer join complete", $time);
  end

endmodule
