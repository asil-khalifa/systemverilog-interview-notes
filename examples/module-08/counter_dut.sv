// The bundle of signals between the counter and whatever drives it
interface cnt_if (input logic clk);
  logic       rst_n;      // active-low asynchronous reset
  logic       en;         // count enable
  logic [3:0] count;      // counter value
endinterface

// The design: one interface port instead of four separate ports
module counter (cnt_if cif);

  always_ff @(posedge cif.clk or negedge cif.rst_n) begin
    if (!cif.rst_n)  cif.count <= '0;
    else if (cif.en) cif.count <= cif.count + 1'b1;
  end

endmodule
