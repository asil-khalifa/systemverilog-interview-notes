module tb_event_handles;

  event a, b, c;

  initial begin
    $display("1. a == b : %b   (two separate event objects)", a == b);

    b = a;                                    // merge: b now refers to the object of a
    $display("2. a == b : %b   (after b = a)", a == b);

    fork
      begin
        @(b);
        $display("[%0t] 3. the waiter on b was woken by -> a", $time);
      end
    join_none

    #10 -> a;

    #10;
    c = null;
    $display("[%0t] 4. c == null : %b", $time, c == null);
    -> c;                                     // triggering a null event does nothing
    $display("[%0t] 5. -> c on a null event had no effect", $time);
  end

endmodule
