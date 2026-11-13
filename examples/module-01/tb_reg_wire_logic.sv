module tb_reg_wire_logic;

  logic       a, b;
  wire        w_and;        // net
  logic       l_or;         // variable driven by one continuous assignment
  logic       l_xor;        // variable assigned procedurally
  logic [3:0] sum;

  assign w_and = a & b;                 // legal: continuous assignment to a net
  assign l_or  = a | b;                 // legal: ONE continuous assignment to a variable

  always_comb l_xor = a ^ b;            // legal: procedural assignment to a variable

  // assign l_or = a;                   // ILLEGAL: second continuous driver on a variable
  // always_comb w_and = a;             // ILLEGAL: procedural assignment to a net
  // assign l_xor = a;                  // ILLEGAL: variable driven both procedurally and continuously

  initial begin
    a = 1; b = 0;
    #1 $display("a=%b b=%b : and=%b or=%b xor=%b", a, b, w_and, l_or, l_xor);
    a = 1; b = 1;
    #1 $display("a=%b b=%b : and=%b or=%b xor=%b", a, b, w_and, l_or, l_xor);
  end

endmodule
