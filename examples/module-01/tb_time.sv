`timescale 1ns/1ps

module tb_time;

  time     t_int;
  realtime t_real;
  realtime t_start, latency;

  initial begin
    $timeformat(-9, 3, " ns", 0);    // unit = ns, 3 decimals, suffix, no minimum width

    #1.75;
    t_int  = $time;
    t_real = $realtime;
    $display("$time     = %0d", t_int);
    $display("$realtime = %0.3f", t_real);
    $display("with %%t   = %t", $realtime);

    t_start = $realtime;
    #12.5;
    latency = $realtime - t_start;
    $display("latency   = %0.2f ns", latency);
  end

endmodule
