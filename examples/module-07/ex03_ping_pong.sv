module ex03_ping_pong;

  event ping_e, pong_e;

  initial begin
    fork
      begin : ping_thread
        repeat (3) begin
          #5;
          $display("[%0t] ping", $time);
          -> ping_e;
          @(pong_e);
        end
      end

      begin : pong_thread
        forever begin
          @(ping_e);
          #5;
          $display("[%0t] pong", $time);
          -> pong_e;
        end
      end
    join_any
    disable fork;
    $display("[%0t] game over", $time);
  end

endmodule
