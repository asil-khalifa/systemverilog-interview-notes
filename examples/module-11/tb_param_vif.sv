interface bus_if #(parameter int W = 8) (input logic clk);
  logic [W-1:0] data;
  logic         valid;
endinterface

class bus_driver #(int W = 8);

  virtual bus_if #(W) vif;              // the class parameter selects the interface type

  function new(virtual bus_if #(W) vif);
    this.vif = vif;
  endfunction

  task send(logic [W-1:0] value);
    @(posedge vif.clk);
    vif.data  <= value;
    vif.valid <= 1'b1;
    @(posedge vif.clk);
    vif.valid <= 1'b0;
  endtask

endclass

module tb_param_vif;

  logic clk = 0;
  always #5 clk = ~clk;

  bus_if #(8)  if8  (clk);
  bus_if #(16) if16 (clk);

  bus_driver #(8)  drv8;
  bus_driver #(16) drv16;

  initial begin
    drv8  = new(if8);
    drv16 = new(if16);
    // drv8 = new(if16);    // ILLEGAL: virtual bus_if #(8) cannot refer to a bus_if #(16)

    fork
      drv8.send(8'hA5);
      drv16.send(16'hBEEF);
    join

    $display("[%0t] if8.data=%h (%0d bits)  if16.data=%h (%0d bits)",
             $time, if8.data, $bits(if8.data), if16.data, $bits(if16.data));
    $finish;
  end

endmodule
