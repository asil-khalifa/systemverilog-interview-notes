module tb_p22_fifo_ops;

  class fifo_seq;
    localparam int N     = 20;
    localparam int DEPTH = 4;

    rand bit push[N];                      // 1 = push, 0 = pop
    rand int level[N + 1];                 // helper: fill level before each operation

    constraint start_c { level[0] == 0; }
    constraint step_c  {
      foreach (push[i]) level[i + 1] == level[i] + (push[i] ? 1 : -1);
    }
    constraint bound_c { foreach (level[i]) level[i] inside {[0:DEPTH]}; }
  endclass

  fifo_seq g;
  int      errors, fill;

  initial begin
    g = new();
    repeat (100) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      fill = 0;
      foreach (g.push[i]) begin
        if (g.push[i])  begin if (fill == 4) errors++; fill++; end
        else            begin if (fill == 0) errors++; fill--; end
      end
    end
    $write("p22: sample ops =");
    foreach (g.push[i]) $write(" %s", g.push[i] ? "PU" : "po");
    $write("\n");
    $display("p22: errors=%0d", errors);
  end

endmodule
