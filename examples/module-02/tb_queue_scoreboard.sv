module tb_queue_scoreboard;

  logic [8:0] exp_q [$];
  int         pass_cnt, fail_cnt;

  function automatic void add_expected(logic [8:0] value);
    exp_q.push_back(value);
  endfunction

  function automatic void check_actual(logic [8:0] actual);
    logic [8:0] expected;
    if (exp_q.size() == 0) begin
      $display("FAIL: unexpected output %0d (nothing was expected)", actual);
      fail_cnt++;
      return;
    end
    expected = exp_q.pop_front();
    if (actual !== expected) begin
      $display("FAIL: actual=%0d expected=%0d", actual, expected);
      fail_cnt++;
    end
    else begin
      $display("PASS: %0d", actual);
      pass_cnt++;
    end
  endfunction

  initial begin
    add_expected(9'd300);
    add_expected(9'd17);
    add_expected(9'd255);
    $display("pending = %0d", exp_q.size());

    check_actual(9'd300);
    check_actual(9'd18);
    check_actual(9'd255);
    check_actual(9'd1);

    $display("pass=%0d fail=%0d leftover=%0d", pass_cnt, fail_cnt, exp_q.size());
  end

endmodule
