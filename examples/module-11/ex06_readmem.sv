module ex06_readmem;

  logic [7:0] mem [0:7];
  int         fd;

  initial begin
    fd = $fopen("mem_init.hex", "w");
    if (fd == 0) $fatal(1, "cannot create mem_init.hex");
    $fdisplay(fd, "// test image");
    $fdisplay(fd, "@0");
    $fdisplay(fd, "de ad be ef");
    $fdisplay(fd, "@6");
    $fdisplay(fd, "55 aa");
    $fclose(fd);

    $readmemh("mem_init.hex", mem);
    foreach (mem[i]) $display("mem[%0d] = %h", i, mem[i]);
  end

endmodule
