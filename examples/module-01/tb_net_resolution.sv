module tb_net_resolution;

  logic       en_a, en_b;
  logic [3:0] data_a, data_b;
  wire  [3:0] bus;                         // must be a net: it has two drivers

  assign bus = en_a ? data_a : 4'bzzzz;    // driver A
  assign bus = en_b ? data_b : 4'bzzzz;    // driver B

  initial begin
    data_a = 4'b1100;
    data_b = 4'b1010;

    en_a = 0; en_b = 0; #1 $display("nobody drives : bus=%b", bus);
    en_a = 1; en_b = 0; #1 $display("A drives      : bus=%b", bus);
    en_a = 0; en_b = 1; #1 $display("B drives      : bus=%b", bus);
    en_a = 1; en_b = 1; #1 $display("A and B drive : bus=%b", bus);
  end

endmodule
