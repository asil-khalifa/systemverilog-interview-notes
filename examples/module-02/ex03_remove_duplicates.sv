module ex03_remove_duplicates;

  int in_q  [$] = {3, 1, 3, 2, 1, 5};
  int out_q [$];
  bit seen  [int];                     // associative array used as a set

  initial begin
    foreach (in_q[i])
      if (!seen.exists(in_q[i])) begin
        seen[in_q[i]] = 1;
        out_q.push_back(in_q[i]);
      end
    $display("%p", out_q);
  end

endmodule
