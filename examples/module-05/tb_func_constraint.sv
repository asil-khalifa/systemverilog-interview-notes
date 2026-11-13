module tb_func_constraint;

  class with_function;
    rand bit [3:0] x;
    rand bit [4:0] y;

    function automatic bit [4:0] twice(bit [3:0] v);
      return 2 * v;
    endfunction

    constraint c { y == twice(x); y < 6; }
  endclass

  class with_expression;
    rand bit [3:0] x;
    rand bit [4:0] y;
    constraint c { y == 2 * x; y < 6; }
  endclass

  with_function   f;
  with_expression e;
  int             f_fail, e_fail;

  initial begin
    f = new();
    e = new();
    repeat (1000) begin
      if (!f.randomize()) f_fail++;
      if (!e.randomize()) e_fail++;
    end
    $display("with function   : %0d failures in 1000 calls", f_fail);
    $display("with expression : %0d failures in 1000 calls", e_fail);
  end

endmodule
