module ex04_burst_4k;

  class burst;
    rand bit [31:0] addr;
    rand bit [4:0]  beats;         // number of beats
    rand bit [1:0]  size_log2;     // bytes per beat = 1 << size_log2

    constraint beats_c { beats inside {[1:16]}; }
    constraint align_c { (addr & ((32'd1 << size_log2) - 1)) == 0; }
    constraint page_c  { int'(addr[11:0]) + int'(beats) * (1 << size_log2) <= 4096; }
  endclass

  burst b;
  int   errors, nbytes;

  initial begin
    b = new();
    repeat (500) begin
      if (!b.randomize()) $fatal(1, "randomize failed");
      nbytes = 1 << b.size_log2;
      if (b.beats < 1 || b.beats > 16)                          errors++;
      if (b.addr % nbytes != 0)                                 errors++;
      if ((b.addr / 4096) != ((b.addr + b.beats * nbytes - 1) / 4096)) errors++;
    end
    $display("ex04: sample addr=%h beats=%0d bytes/beat=%0d", b.addr, b.beats, nbytes);
    $display("ex04: errors=%0d", errors);
  end

endmodule
