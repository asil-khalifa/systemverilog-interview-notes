module tb_file_io;

  int fd;
  int idx, a, b;

  initial begin
    // ---- write ----
    fd = $fopen("alu_vectors.txt", "w");
    if (fd == 0) $fatal(1, "cannot open alu_vectors.txt for writing");
    for (int i = 0; i < 3; i++)
      $fdisplay(fd, "%0d %0d %0d", i, i * 10, i * i);
    $fclose(fd);

    // ---- read back ----
    fd = $fopen("alu_vectors.txt", "r");
    if (fd == 0) $fatal(1, "cannot open alu_vectors.txt for reading");
    while ($fscanf(fd, "%d %d %d", idx, a, b) == 3)
      $display("vector %0d: a=%0d b=%0d", idx, a, b);
    $fclose(fd);
  end

endmodule
