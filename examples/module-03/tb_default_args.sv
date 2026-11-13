module tb_default_args;

  logic clk = 0;
  always #5 clk = ~clk;

  function automatic void report(string msg, int verbosity = 1, string tag = "TB");
    $display("[%0t] [%s] (v%0d) %s", $time, tag, verbosity, msg);
  endfunction

  task automatic wait_cycles(int n = 1);
    repeat (n) @(posedge clk);
  endtask

  initial begin
    report("one");
    report("two", 3);
    report("three", 2, "DRV");
    report("four", , "MON");
    report(.tag("SCB"), .msg("five"));
    report("six", .tag("GEN"));

    wait_cycles();          // default: 1 cycle
    report("after wait_cycles()");
    wait_cycles(3);
    report("after wait_cycles(3)");
    $finish;
  end

endmodule
