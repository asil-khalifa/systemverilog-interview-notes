import alu_pkg::*;

class alu_driver;

  virtual alu_if.DRV vif;

  function new(virtual alu_if.DRV vif);
    this.vif = vif;
  endfunction

  // Drive one operation: one cycle with valid_in = 1, then valid_in = 0
  task drive(bit [7:0] a, bit [7:0] b, alu_op_e op);
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b1;
    vif.drv_cb.a        <= a;
    vif.drv_cb.b        <= b;
    vif.drv_cb.op       <= op;
    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b0;
    $display("[%0t] DRV: %s a=%0d b=%0d accepted by the DUT", $time, op.name(), a, b);
  endtask

endclass

class alu_monitor;

  virtual alu_if.MON vif;

  function new(virtual alu_if.MON vif);
    this.vif = vif;
  endfunction

  task run();
    logic [7:0] a, b;        // the most recent request seen on the DUT inputs
    alu_op_e    op;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid_out)
        $display("[%0t] MON: %s a=%0d b=%0d -> result=%0d",
                 $time, op.name(), a, b, vif.mon_cb.result);
      if (vif.mon_cb.valid_in) begin
        a  = vif.mon_cb.a;
        b  = vif.mon_cb.b;
        op = vif.mon_cb.op;
      end
    end
  endtask

endclass
