module tb_mailbox_typeless;

  mailbox mbx = new();                 // typeless
  int     i_val = 42;
  string  s_val = "hello";
  int     i_out;
  string  s_out;
  int     rc;

  initial begin
    mbx.put(i_val);                    // first message  : an int
    mbx.put(s_val);                    // second message : a string

    mbx.get(i_out);                    // int message into an int variable: fine
    $display("1. got int    : %0d", i_out);

    rc = mbx.try_get(i_out);           // string message into an int variable
    if (rc < 0)
      $display("2. try_get returned a negative value: type mismatch, nothing taken");

    mbx.get(s_out);                    // the string is still there
    $display("3. got string : %s", s_out);

    // mbx.put(s_val);
    // mbx.get(i_out);                 // blocking get with the wrong type: RUN-TIME ERROR
  end

endmodule
