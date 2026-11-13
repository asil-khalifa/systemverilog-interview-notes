package a_pkg;
  int x = 1;
  int y = 10;
  typedef enum {RED, GREEN} colour_e;
endpackage

package b_pkg;
  int x = 2;
  int z = 30;
endpackage

module tb_import_rules;
  import a_pkg::*;
  import b_pkg::*;

  int y = 99;       // a local declaration hides the wildcard candidate a_pkg::y

  initial begin
    // $display("%0d", x);   // ILLEGAL: x is offered by two wildcard imports (ambiguous)
    $display("1. a_pkg::x = %0d, b_pkg::x = %0d", a_pkg::x, b_pkg::x);
    $display("2. y = %0d (local), a_pkg::y = %0d", y, a_pkg::y);
    $display("3. z = %0d", z);
    $display("4. GREEN = %0d", GREEN);
  end

endmodule
