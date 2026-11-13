module tb_mailbox_methods;

  mailbox #(int) mbx;
  int            v;

  initial begin
    mbx = new();                               // unbounded

    mbx.put(10);
    mbx.put(20);
    mbx.put(30);
    $display("1. after three puts : num = %0d", mbx.num());

    mbx.peek(v);
    $display("2. peek    -> %0d    : num = %0d  (message stays)", v, mbx.num());

    mbx.get(v);
    $display("3. get     -> %0d    : num = %0d  (message removed)", v, mbx.num());

    mbx.get(v);
    $display("4. get     -> %0d    : num = %0d", v, mbx.num());

    if (mbx.try_get(v))
      $display("5. try_get -> %0d    : num = %0d", v, mbx.num());

    if (!mbx.try_get(v))
      $display("6. try_get on an empty mailbox returned 0 and did not block");

    if (!mbx.try_peek(v))
      $display("7. try_peek on an empty mailbox returned 0 and did not block");
  end

endmodule
