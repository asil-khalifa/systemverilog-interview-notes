module tb_mailbox_reuse_bug;

  class alu_txn;
    bit [7:0]    a;
    int unsigned id;
  endclass

  mailbox #(alu_txn) gen2drv_mbx = new();
  alu_txn            txn, got;

  initial begin
    txn = new();                               // BUG: one object, created once

    for (int i = 1; i <= 3; i++) begin         // "generator"
      txn.id = i;
      txn.a  = 8'(i * 16);
      gen2drv_mbx.put(txn);                    // puts the same handle three times
    end

    repeat (3) begin                           // "driver"
      gen2drv_mbx.get(got);
      $display("driver got id=%0d a=%h", got.id, got.a);
    end
  end

endmodule
