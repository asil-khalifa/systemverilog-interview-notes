module tb_arg_directions;

  task automatic demo(input int in_v, output int out_v, inout int io_v);
    $display("inside : in_v=%0d out_v=%0d io_v=%0d", in_v, out_v, io_v);
    in_v  = in_v + 100;      // modifies the local copy only
    out_v = 77;
    io_v  = io_v * 2;
  endtask

  int x, y, z;

  initial begin
    x = 1;  y = 50;  z = 10;
    $display("before : x=%0d y=%0d z=%0d", x, y, z);
    demo(x, y, z);
    $display("after  : x=%0d y=%0d z=%0d", x, y, z);
  end

endmodule
