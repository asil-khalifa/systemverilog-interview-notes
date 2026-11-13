module tb_plusargs;

  int    num_txn = 10;            // defaults, used when the plusarg is absent
  string test_name = "default_test";
  bit    verbose;

  initial begin
    if (!$value$plusargs("NUM_TXN=%d", num_txn))
      $display("NUM_TXN not given, using default %0d", num_txn);

    void'($value$plusargs("TEST=%s", test_name));

    verbose = $test$plusargs("VERBOSE") ? 1'b1 : 1'b0;

    $display("test=%s num_txn=%0d verbose=%b", test_name, num_txn, verbose);
  end

endmodule
