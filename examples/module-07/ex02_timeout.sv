module ex02_timeout;

  event resp;

  task automatic wait_resp(input time limit, output bit ok);
    ok = 0;
    fork                                    // guard thread
      begin
        fork
          begin
            @(resp);
            ok = 1;
          end
          #limit;
        join_any
        disable fork;                       // stops only the two threads above
      end
    join
  endtask

  initial begin
    bit ok;

    fork
      #30 -> resp;                          // the response arrives at time 30
    join_none

    wait_resp(50, ok);
    $display("[%0t] first wait : ok = %b", $time, ok);

    wait_resp(50, ok);
    $display("[%0t] second wait: ok = %b", $time, ok);
  end

endmodule
