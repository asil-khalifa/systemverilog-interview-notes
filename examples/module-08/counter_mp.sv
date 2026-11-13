interface cnt_mp_if (input logic clk);
  logic       rst_n;
  logic       en;
  logic [3:0] count;

  // View for the design: it reads the controls and drives the count
  modport DUT (input  clk, rst_n, en,
               output count);

  // View for the testbench: it drives the controls and reads the count
  modport TB  (input  clk, count,
               output rst_n, en);
endinterface

module counter_mp (cnt_mp_if.DUT cif);       // this module uses the DUT view

  always_ff @(posedge cif.clk or negedge cif.rst_n) begin
    if (!cif.rst_n)  cif.count <= '0;
    else if (cif.en) cif.count <= cif.count + 1'b1;
  end

  // assign cif.en = 1'b1;        // ILLEGAL: en is an input in modport DUT

endmodule
