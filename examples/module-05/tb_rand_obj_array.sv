module tb_rand_obj_array;

  class beat;
    rand bit [7:0] data;
    constraint c { data inside {[1:9]}; }
  endclass

  class burst;
    rand beat beats[];                       // array of handles

    function new(int n);
      beats = new[n];
      foreach (beats[i]) beats[i] = new();   // the objects must be constructed by hand
    endfunction
  endclass

  burst b;

  initial begin
    b = new(3);
    if (!b.randomize()) $fatal(1, "randomize failed");
    foreach (b.beats[i]) $display("beat %0d: data=%0d", i, b.beats[i].data);
  end

endmodule
