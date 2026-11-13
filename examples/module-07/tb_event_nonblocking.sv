module tb_event_nonblocking;

  event ev;

  initial begin : trigger
    #10;
    ->> ev;                 // takes effect in the NBA region of time 10
  end

  initial begin : waiter
    #10;
    @(ev);                  // starts waiting in the Active region of time 10
    $display("[%0t] waiter: ev received", $time);
  end

endmodule
