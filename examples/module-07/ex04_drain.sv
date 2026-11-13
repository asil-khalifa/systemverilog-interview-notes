module ex04_drain;

  mailbox #(int) mbx = new();

  function automatic int drain();
    int v;
    int n = 0;
    while (mbx.try_get(v)) begin            // a function may only use the try_ methods
      $display("  drained %0d", v);
      n++;
    end
    return n;
  endfunction

  initial begin
    int n;
    for (int i = 1; i <= 3; i++) mbx.put(i * 100);
    n = drain();
    $display("drained %0d messages, %0d left", n, mbx.num());
  end

endmodule
