module tb_randsequence;

  int n_ops;

  initial begin
    randsequence (main)
      main     : do_reset traffic do_done ;
      traffic  : repeat (4) one_op ;
      one_op   : do_write := 3 | do_read := 2 | do_idle := 1 ;
      do_reset : { $display("RESET"); } ;
      do_write : { $display("  WRITE"); n_ops++; } ;
      do_read  : { $display("  READ");  n_ops++; } ;
      do_idle  : { $display("  IDLE");  n_ops++; } ;
      do_done  : { $display("DONE after %0d operations", n_ops); } ;
    endsequence
  end

endmodule
