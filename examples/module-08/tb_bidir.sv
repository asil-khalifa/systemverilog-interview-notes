interface bidir_if (input logic clk);
  logic       wr;              // testbench -> DUT: store the value that is on the bus
  logic       rd;              // testbench -> DUT: put the stored value on the bus
  wire  [7:0] data;            // shared bus: a net, because it has two drivers

  logic [7:0] data_drv;        // value the testbench wants on the bus
  logic       data_oe;         // 1 = the testbench is driving the bus

  assign data = data_oe ? data_drv : 'z;       // the testbench's tri-state driver
endinterface

module bidir_reg (input logic clk, input logic wr, input logic rd, inout wire [7:0] data);
  logic [7:0] store;
  always_ff @(posedge clk) if (wr) store <= data;
  assign data = rd ? store : 'z;               // the DUT's tri-state driver
endmodule

class bidir_driver;

  virtual bidir_if vif;

  function new(virtual bidir_if vif);
    this.vif = vif;
  endfunction

  task write(bit [7:0] value);
    @(negedge vif.clk);
    vif.data_drv = value;
    vif.data_oe  = 1;          // take the bus
    vif.wr       = 1;
    @(negedge vif.clk);
    vif.wr       = 0;
    vif.data_oe  = 0;          // release the bus
  endtask

  task read(output logic [7:0] value);
    @(negedge vif.clk);
    vif.rd = 1;                // the DUT drives the bus now
    @(negedge vif.clk);
    value  = vif.data;         // reading a net through the handle is allowed
    vif.rd = 0;
  endtask

endclass

module tb_bidir;

  logic clk = 0;
  always #5 clk = ~clk;

  bidir_if     bif (clk);
  bidir_reg    dut (.clk(clk), .wr(bif.wr), .rd(bif.rd), .data(bif.data));
  bidir_driver drv;
  logic [7:0]  value;

  initial begin
    bif.wr = 0;  bif.rd = 0;  bif.data_oe = 0;  bif.data_drv = '0;
    drv = new(bif);

    #1 $display("[%0t] bus idle       : data = %h", $time, bif.data);
    drv.write(8'hA5);
    #1 $display("[%0t] after the write: data = %h", $time, bif.data);
    drv.read(value);
    $display("[%0t] value read back: %h", $time, value);
    #1 $display("[%0t] bus idle again : data = %h", $time, bif.data);
    $finish;
  end

endmodule
