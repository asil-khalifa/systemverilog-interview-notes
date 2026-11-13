class cnt_driver;

  virtual cnt_if vif;                       // handle to the counter interface

  function new(virtual cnt_if vif);
    this.vif = vif;                         // store the handle passed in by the creator
  endfunction

  task reset();
    vif.rst_n = 0;
    vif.en    = 0;
    @(negedge vif.clk);
    vif.rst_n = 1;
  endtask

  task count_for(int unsigned cycles);
    vif.en = 1;
    repeat (cycles) @(negedge vif.clk);
    vif.en = 0;
  endtask

endclass

module tb_vif_basic;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);                        // physical interface
  counter dut (cif);

  cnt_driver drv;                           // class handle (null until new)

  initial begin
    drv = new(cif);                         // the physical interface is handed to the class

    drv.reset();
    drv.count_for(3);
    $display("[%0t] count = %0d", $time, cif.count);

    drv.count_for(2);
    $display("[%0t] count = %0d (through the handle: %0d)",
             $time, cif.count, drv.vif.count);
    $finish;
  end

endmodule
