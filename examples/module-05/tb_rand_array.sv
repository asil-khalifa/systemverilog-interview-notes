module tb_rand_array;

  class pkt;
    rand bit [7:0] hdr[2];
    rand bit [7:0] payload[];
    rand bit [3:0] nosize[];             // size is never constrained

    constraint size_c  { payload.size() inside {[2:5]}; }
    constraint value_c { foreach (payload[i]) payload[i] inside {[8'h10:8'h1F]}; }
  endclass

  pkt p;

  initial begin
    p = new();
    $display("before : payload.size=%0d nosize.size=%0d", p.payload.size(), p.nosize.size());

    if (!p.randomize()) $fatal(1, "randomize failed");
    $display("after  : payload.size=%0d nosize.size=%0d", p.payload.size(), p.nosize.size());
    $display("hdr=%p payload=%p", p.hdr, p.payload);

    p.nosize = new[3];                   // give it a size by hand
    if (!p.randomize()) $fatal(1, "randomize failed");
    $display("again  : payload.size=%0d nosize.size=%0d nosize=%p",
             p.payload.size(), p.nosize.size(), p.nosize);
  end

endmodule
