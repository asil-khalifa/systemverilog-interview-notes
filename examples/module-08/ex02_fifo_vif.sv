class fifo_driver;

  virtual fifo_if.DRV vif;

  function new(virtual fifo_if.DRV vif);
    this.vif = vif;
  endfunction

  task push(bit [7:0] value);
    @(vif.drv_cb);
    vif.drv_cb.wr_en <= 1'b1;
    vif.drv_cb.din   <= value;
    @(vif.drv_cb);                   // the FIFO stores the value at this edge
    vif.drv_cb.wr_en <= 1'b0;
  endtask

  task pop(output logic [7:0] value);
    @(vif.drv_cb);
    vif.drv_cb.rd_en <= 1'b1;
    @(vif.drv_cb);                   // the FIFO samples rd_en = 1 at this edge
    vif.drv_cb.rd_en <= 1'b0;
    @(vif.drv_cb);                   // dout, updated by that edge, is in the sample now
    value = vif.drv_cb.dout;
  endtask

endclass

module ex02_fifo_vif;

  logic clk = 0;
  always #5 clk = ~clk;

  fifo_if   fif (clk);
  sync_fifo dut (
    .clk   (clk),       .rst_n (fif.rst_n),
    .wr_en (fif.wr_en), .rd_en (fif.rd_en),
    .din   (fif.din),   .dout  (fif.dout),
    .full  (fif.full),  .empty (fif.empty)
  );

  fifo_driver drv;
  logic [7:0] value;

  initial begin
    fif.rst_n = 0;  fif.wr_en = 0;  fif.rd_en = 0;  fif.din = '0;
    drv = new(fif);
    repeat (2) @(negedge clk);
    fif.rst_n = 1;

    drv.push(8'h11);
    drv.push(8'h22);
    drv.push(8'h33);

    repeat (3) begin
      drv.pop(value);
      $display("[%0t] popped %h", $time, value);
    end

    @(fif.drv_cb);
    $display("[%0t] empty=%b full=%b", $time, fif.drv_cb.empty, fif.drv_cb.full);
    $finish;
  end

endmodule
