module tb_new_in_loop;

  class packet;
    bit [7:0] addr;
  endclass

  packet p;
  packet q_bad  [$];        // queues of handles (Module 2)
  packet q_good [$];

  initial begin
    // WRONG: the object is created once, outside the loop
    p = new();
    for (int i = 0; i < 3; i++) begin
      p.addr = i;
      q_bad.push_back(p);            // the same handle is stored three times
    end

    // RIGHT: a new object is created in every iteration
    for (int i = 0; i < 3; i++) begin
      p = new();
      p.addr = i;
      q_good.push_back(p);
    end

    foreach (q_bad[i])  $display("q_bad[%0d].addr  = %0d", i, q_bad[i].addr);
    foreach (q_good[i]) $display("q_good[%0d].addr = %0d", i, q_good[i].addr);
  end

endmodule
