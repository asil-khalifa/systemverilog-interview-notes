class alu_monitor;

  virtual alu_if     vif;
  mailbox #(alu_txn) mon2scb_mbx;
  int unsigned       num_seen;

  function new(virtual alu_if vif, mailbox #(alu_txn) mon2scb_mbx);
    this.vif         = vif;
    this.mon2scb_mbx = mon2scb_mbx;
  endfunction

  task run();
    alu_txn pending;      // inputs sampled at the previous edge, result still to come
    forever begin
      @(vif.mon_cb);

      if (vif.rst_n !== 1'b1) begin
        pending = null;   // nothing observed during reset counts
        continue;
      end

      // 1. Output side: complete the transaction whose inputs were seen one edge ago
      if (pending != null) begin
        if (vif.mon_cb.valid_out === 1'b1) begin
          pending.result = vif.mon_cb.result;
          pending.print("MON");
          mon2scb_mbx.put(pending);
        end
        else
          $error("[%0t] MON: valid_out missing for id=%0d", $time, pending.id);
        pending = null;
      end
      else if (vif.mon_cb.valid_out === 1'b1)
        $error("[%0t] MON: valid_out without a preceding valid_in", $time);

      // 2. Input side: start a new transaction if the DUT sampled one at this edge
      if (vif.mon_cb.valid_in === 1'b1) begin
        if ($isunknown({vif.mon_cb.a, vif.mon_cb.b, vif.mon_cb.op}))
          $error("[%0t] MON: X or Z on the DUT inputs while valid_in is 1", $time);
        pending    = new();
        num_seen++;
        pending.id = num_seen;
        pending.a  = vif.mon_cb.a;
        pending.b  = vif.mon_cb.b;
        pending.op = vif.mon_cb.op;
      end
    end
  endtask

endclass
