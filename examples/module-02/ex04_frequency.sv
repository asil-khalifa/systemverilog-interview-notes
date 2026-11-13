module ex04_frequency;

  string ops [6] = '{"ADD", "SUB", "ADD", "XOR", "ADD", "SUB"};
  int    freq [string];
  string best;

  initial begin
    foreach (ops[i]) freq[ops[i]]++;

    foreach (freq[k]) $display("%s = %0d", k, freq[k]);

    best = "";
    foreach (freq[k])
      if (best == "" || freq[k] > freq[best]) best = k;
    $display("most frequent: %s (%0d times)", best, freq[best]);
  end

endmodule
