module ex06_safe_cast;

  typedef enum bit [2:0] {NOP = 0, LOAD = 1, STORE = 2, JUMP = 4} cmd_e;

  cmd_e cmd;

  initial begin
    for (int raw = 0; raw < 8; raw++) begin
      if ($cast(cmd, raw)) $display("raw %0d -> %s", raw, cmd.name());
      else                 $display("raw %0d -> ILLEGAL encoding", raw);
    end
  end

endmodule
