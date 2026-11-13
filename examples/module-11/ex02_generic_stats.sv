class stats #(type T = int);

  static function T max_of(T q [$]);
    T m = q[0];
    foreach (q[i]) if (q[i] > m) m = q[i];
    return m;
  endfunction

  static function T min_of(T q [$]);
    T m = q[0];
    foreach (q[i]) if (q[i] < m) m = q[i];
    return m;
  endfunction

endclass

module ex02_generic_stats;

  int  iq [$] = '{3, 9, -2, 7};
  real rq [$] = '{1.5, 0.25, 7.75};

  initial begin
    $display("int : max=%0d min=%0d", stats #(int)::max_of(iq), stats #(int)::min_of(iq));
    $display("real: max=%0.2f min=%0.2f",
             stats #(real)::max_of(rq), stats #(real)::min_of(rq));
  end

endmodule
