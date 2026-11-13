module tb_assoc_scoreboard;

  logic [8:0] exp_by_id [int];

  function automatic void check(int id, logic [8:0] actual);
    if (!exp_by_id.exists(id)) begin
      $display("FAIL: id %0d was not expected", id);
      return;
    end
    if (actual !== exp_by_id[id])
      $display("FAIL: id %0d actual=%0d expected=%0d", id, actual, exp_by_id[id]);
    else
      $display("PASS: id %0d = %0d", id, actual);
    exp_by_id.delete(id);                  // this expectation has been consumed
  endfunction

  initial begin
    exp_by_id[1] = 9'd30;
    exp_by_id[2] = 9'd40;
    exp_by_id[3] = 9'd50;

    check(3, 9'd50);                       // responses arrive out of order
    check(1, 9'd31);
    check(7, 9'd0);

    $display("still pending: %0d", exp_by_id.num());
    foreach (exp_by_id[id]) $display("  no response received for id %0d", id);
  end

endmodule
