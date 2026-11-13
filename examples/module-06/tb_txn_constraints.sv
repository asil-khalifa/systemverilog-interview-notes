module tb_txn_constraints;
  import alu_pkg::*;

  class alu_txn;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand alu_op_e  op;
    logic [8:0]    result;
    int unsigned   id;

    constraint op_dist_c {
      op dist { ALU_ADD := 2, ALU_SUB := 2, ALU_AND := 1, ALU_OR  := 1,
                ALU_XOR := 1, ALU_NOT := 1, ALU_SHL := 1, ALU_SHR := 1 };
    }

    constraint corner_c {
      a dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
      b dist { 8'h00 := 1, 8'hFF := 1, [8'h01:8'hFE] :/ 8 };
    }

    function void post_randomize();
      result = 'x;
    endfunction
  endclass

  alu_txn      t;
  int unsigned n_add, n_zero, n_max, n_ok;

  initial begin
    t = new();

    // 1. Default constraints: count how often the biased values appear
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.op == ALU_ADD) n_add++;
      if (t.a  == 8'h00)   n_zero++;
      if (t.a  == 8'hFF)   n_max++;
    end
    $display("1. bias on  : ADD=%0d  a==00: %0d  a==FF: %0d  (of 1000)",
             n_add, n_zero, n_max);

    // 2. Switch the corner bias off: a becomes uniform again
    t.corner_c.constraint_mode(0);
    n_zero = 0;
    n_max  = 0;
    repeat (1000) begin
      if (!t.randomize()) $fatal(1, "randomize() failed");
      if (t.a == 8'h00) n_zero++;
      if (t.a == 8'hFF) n_max++;
    end
    $display("2. bias off : a==00: %0d  a==FF: %0d  (of 1000)", n_zero, n_max);
    t.corner_c.constraint_mode(1);

    // 3. Inline constraint: only subtractions that borrow
    repeat (100) begin
      if (!t.randomize() with { op == ALU_SUB; a < b; }) $fatal(1, "randomize() failed");
      if (t.op == ALU_SUB && t.a < t.b) n_ok++;
    end
    $display("3. inline constraint satisfied in %0d of 100", n_ok);

    // 4. Contradictory constraints: no solution exists
    if (!t.randomize() with { a == 8'h00; a > b; })
      $display("4. randomize() returned 0: no value of b is less than 0");
  end

endmodule
