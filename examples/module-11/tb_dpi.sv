module tb_dpi;

  // C functions callable from SystemVerilog
  import "DPI-C" pure    function int  c_alu_model(input int op, input int a, input int b);
  import "DPI-C"         function void c_minmax(input int a, input int b,
                                                output int lo, output int hi);
  import "DPI-C" context function void c_greet(input string name);

  // SystemVerilog function callable from C
  export "DPI-C" function sv_log;

  function void sv_log(input string msg);
    $display("[SV] %s", msg);
  endfunction

  int lo, hi;

  initial begin
    $display("1. c_alu_model(ADD, 200, 100) = %0d", c_alu_model(0, 200, 100));
    $display("2. c_alu_model(SUB, 5, 10)    = %0d", c_alu_model(1, 5, 10));

    c_minmax(42, 7, lo, hi);
    $display("3. lo = %0d, hi = %0d", lo, hi);

    c_greet("ALU testbench");
  end

endmodule
