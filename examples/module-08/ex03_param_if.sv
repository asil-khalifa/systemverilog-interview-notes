interface mem_if #(parameter int AW = 4, parameter int DW = 8) (input logic clk);
  logic          we;
  logic [AW-1:0] addr;
  logic [DW-1:0] wdata;
  logic [DW-1:0] rdata;
endinterface

module ram #(parameter int AW = 4, parameter int DW = 8) (mem_if mif);
  logic [DW-1:0] mem [2**AW];
  always_ff @(posedge mif.clk) begin
    if (mif.we) mem[mif.addr] <= mif.wdata;
    mif.rdata <= mem[mif.addr];
  end
endmodule

// One name for the exact interface type this driver works with
typedef virtual mem_if #(.AW(6), .DW(16)) mem_vif_t;

class mem_driver;

  mem_vif_t vif;

  function new(mem_vif_t vif);
    this.vif = vif;
  endfunction

  task write(bit [5:0] addr, bit [15:0] data);
    @(negedge vif.clk);
    vif.we    = 1;
    vif.addr  = addr;
    vif.wdata = data;
    @(negedge vif.clk);
    vif.we    = 0;
  endtask

  task read(bit [5:0] addr, output logic [15:0] data);
    @(negedge vif.clk);
    vif.addr = addr;
    @(negedge vif.clk);
    data = vif.rdata;
  endtask

endclass

module ex03_param_if;

  logic clk = 0;
  always #5 clk = ~clk;

  mem_if #(.AW(6), .DW(16)) mif (clk);
  ram    #(.AW(6), .DW(16)) dut (mif);

  mem_driver   drv;
  logic [15:0] data;

  initial begin
    mif.we = 0;
    drv = new(mif);

    drv.write(6'd40, 16'hBEEF);
    drv.write(6'd41, 16'h1234);

    drv.read(6'd40, data);  $display("[%0t] mem[40] = %h", $time, data);
    drv.read(6'd41, data);  $display("[%0t] mem[41] = %h", $time, data);
    drv.read(6'd5,  data);  $display("[%0t] mem[5]  = %h", $time, data);
    $finish;
  end

endmodule
