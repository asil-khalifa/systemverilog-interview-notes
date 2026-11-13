module tb_process_class;

  process p_main, p_fast, p_slow;

  function automatic string st(process p);
    process::state s = p.status();
    return s.name();
  endfunction

  initial begin
    p_main = process::self();

    fork
      begin
        p_fast = process::self();
        #10 $display("[%0t] fast thread finished", $time);
      end
      begin
        p_slow = process::self();
        #100 $display("[%0t] slow thread finished", $time);
      end
    join_none

    wait (p_fast != null && p_slow != null);
    $display("[%0t] main=%s fast=%s slow=%s", $time, st(p_main), st(p_fast), st(p_slow));

    p_fast.await();
    $display("[%0t] after await : fast=%s slow=%s", $time, st(p_fast), st(p_slow));

    #5 p_slow.kill();
    $display("[%0t] after kill  : slow=%s", $time, st(p_slow));

    #200 $display("[%0t] end (the slow thread never printed)", $time);
  end

endmodule
