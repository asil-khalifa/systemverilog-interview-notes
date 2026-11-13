module ex04_randcase_mix;

  int n_add, n_sub, n_shift;

  initial begin
    repeat (2000) begin
      randcase
        8 : n_add++;
        1 : n_sub++;
        1 : n_shift++;
      endcase
    end

    $display("add=%0d sub=%0d shift=%0d", n_add, n_sub, n_shift);

    if (n_add + n_sub + n_shift != 2000)        $display("FAIL: total is wrong");
    else if (n_add < n_sub || n_add < n_shift)  $display("FAIL: weights not respected");
    else                                        $display("PASS");
  end

endmodule
