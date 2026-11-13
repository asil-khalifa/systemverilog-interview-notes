module tb_randcase;

  int n_write, n_read, n_idle, n_never;

  initial begin
    repeat (1000) begin
      randcase
        6 : n_write++;
        3 : n_read++;
        1 : n_idle++;
        0 : n_never++;        // weight 0: never selected
      endcase
    end

    $display("write=%0d read=%0d idle=%0d never=%0d", n_write, n_read, n_idle, n_never);
    $display("total=%0d", n_write + n_read + n_idle + n_never);
  end

endmodule
