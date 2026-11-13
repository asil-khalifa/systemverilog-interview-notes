module tb_array_assign;

  int fixed [3] = '{1, 2, 3};
  int other [3];
  int rng   [7:5];
  int dyn   [];
  int q     [$];

  initial begin
    other    = fixed;                 // fixed to fixed
    other[0] = 100;
    $display("1. fixed = %p   other = %p", fixed, other);

    rng = fixed;                      // different index range, same size
    $display("2. rng[7] = %0d   rng[5] = %0d", rng[7], rng[5]);

    dyn = fixed;                      // fixed to dynamic: dyn is resized to 3
    q   = dyn;                        // dynamic to queue
    q.push_back(4);
    dyn = q;                          // queue to dynamic: dyn is resized to 4
    $display("3. dyn = %p   size = %0d", dyn, dyn.size());

    fixed = dyn[1:3];                 // a 3-element slice fits the 3-element array
    $display("4. fixed = %p", fixed);

    other[0:1] = fixed[1:2];          // slice to slice
    $display("5. other = %p", other);

    // fixed = dyn;                   // dyn has 4 elements: this would be a run-time error
  end

endmodule
