module tb_bins_transition;

  typedef enum bit [1:0] {IDLE, FETCH, EXEC, DONE} state_e;

  state_e state;

  covergroup cg_state;
    cp_state: coverpoint state {
      bins idle_to_fetch = (IDLE => FETCH);
      bins full_cycle    = (IDLE => FETCH => EXEC => DONE);
      bins stay_exec     = (EXEC [*3]);
      bins fetch_to_done = (FETCH => DONE [->1]);
      bins to_idle[]     = (FETCH, EXEC, DONE => IDLE);
    }
  endgroup

  cg_state cg = new();

  initial begin
    state = IDLE;   cg.sample();    // sample 1
    state = FETCH;  cg.sample();    // sample 2
    state = EXEC;   cg.sample();    // sample 3
    state = EXEC;   cg.sample();    // sample 4
    state = EXEC;   cg.sample();    // sample 5
    state = DONE;   cg.sample();    // sample 6
    state = IDLE;   cg.sample();    // sample 7

    $display("cp_state = %0.2f%%", cg.cp_state.get_coverage());
  end

endmodule
