module tb_mailbox_try_put;

  mailbox #(int) mbx = new(2);

  initial begin
    if (mbx.try_put(1))  $display("1. try_put(1) stored    : num = %0d", mbx.num());
    if (mbx.try_put(2))  $display("2. try_put(2) stored    : num = %0d", mbx.num());
    if (!mbx.try_put(3)) $display("3. try_put(3) refused   : mailbox full, num = %0d",
                                  mbx.num());
  end

endmodule
