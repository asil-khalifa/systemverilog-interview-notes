class alu_scoreboard;

  mailbox #(alu_txn) mon2scb_mbx;
  int unsigned       num_checked;
  int unsigned       num_pass;
  int unsigned       num_fail;

  function new(mailbox #(alu_txn) mon2scb_mbx);
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction

  // Reference model: the expected 9-bit result, written from the specification
  function logic [8:0] alu_predict(alu_txn t);
    logic [8:0] r;
    case (t.op)
      ALU_ADD: r = t.a + t.b;
      ALU_SUB: r = t.a - t.b;
      ALU_AND: r = t.a & t.b;
      ALU_OR : r = t.a | t.b;
      ALU_XOR: r = t.a ^ t.b;
      ALU_NOT: r = {1'b0, ~t.a};
      ALU_SHL: r = t.a << 1;
      ALU_SHR: r = t.a >> 1;
      default: r = 'x;
    endcase
    return r;
  endfunction

  function void check_txn(alu_txn actual);
    alu_txn expected;
    expected        = actual.copy();
    expected.result = alu_predict(actual);
    if (actual.compare(expected)) begin
      num_pass++;
      $display("[%0t] SCB PASS id=%0d op=%s a=%0d b=%0d result=%0d",
               $time, actual.id, actual.op.name(), actual.a, actual.b, actual.result);
    end
    else begin
      num_fail++;
      $error("[%0t] SCB FAIL id=%0d op=%s a=%0d b=%0d actual=%0d expected=%0d",
             $time, actual.id, actual.op.name(), actual.a, actual.b,
             actual.result, expected.result);
    end
    num_checked++;
  endfunction

  task run();
    alu_txn txn;
    forever begin
      mon2scb_mbx.get(txn);
      check_txn(txn);
    end
  endtask

  function void report();
    $display("------------------------------------------------------------");
    $display("SCOREBOARD SUMMARY: checked=%0d pass=%0d fail=%0d",
             num_checked, num_pass, num_fail);
    if (num_checked == 0)   $display("TEST FAILED: nothing was checked");
    else if (num_fail == 0) $display("TEST PASSED");
    else                    $display("TEST FAILED");
    $display("------------------------------------------------------------");
  endfunction

endclass
