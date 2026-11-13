module ex06_next_id;

  function automatic int unsigned next_id();
    static int unsigned id = 0;     // one copy, initialised once
    id++;
    return id - 1;
  endfunction

  initial begin
    $display("%0d", next_id());
    $display("%0d", next_id());
    $display("%0d", next_id());
  end

endmodule
