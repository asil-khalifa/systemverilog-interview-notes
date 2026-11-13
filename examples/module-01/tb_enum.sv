module tb_enum;

  typedef enum logic [1:0] {IDLE, FETCH, EXEC, DONE} state_e;
  typedef enum {RED = 1, GREEN = 2, BLUE = 4}        color_e;

  state_e state;
  color_e color;
  int     raw;

  initial begin
    $display("1. default state = %b, name = '%s'", state, state.name());
    $display("2. default color = %0d, name = '%s'", color, color.name());

    $display("3. state_e has %0d members:", state.num());
    state = state.first();
    do begin
      $display("     %-5s = %0d", state.name(), state);
      state = state.next();
    end while (state != state.first());

    state = DONE;
    state = state.next();
    $display("4. next of DONE    = %s", state.name());
    state = state.prev(2);
    $display("5. prev(2) of IDLE = %s", state.name());

    raw = 2;
    if ($cast(color, raw))  $display("6. $cast of 2 succeeded: %s", color.name());
    raw = 3;
    if (!$cast(color, raw)) $display("7. $cast of 3 failed, color is still %s", color.name());

    color = color_e'(raw);
    $display("8. static cast of 3: value = %0d, name = '%s'", color, color.name());

    color = BLUE;
    raw   = color + 1;
    $display("9. BLUE + 1 = %0d", raw);
  end

endmodule
