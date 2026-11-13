module tb_sparse_memory;

  logic [7:0] mem [bit [31:0]];           // only the written addresses use memory

  function automatic void mem_write(bit [31:0] addr, logic [7:0] data);
    mem[addr] = data;
  endfunction

  function automatic logic [7:0] mem_read(bit [31:0] addr);
    if (mem.exists(addr)) return mem[addr];
    return 'x;                            // unwritten memory reads as unknown
  endfunction

  initial begin
    mem_write(32'h0000_0010, 8'hAA);
    mem_write(32'hFFFF_FFF0, 8'hBB);
    mem_write(32'h8000_0000, 8'hCC);
    mem_write(32'h0000_0010, 8'hDD);      // overwrite

    $display("read 00000010 = %h", mem_read(32'h0000_0010));
    $display("read 00000020 = %h", mem_read(32'h0000_0020));
    $display("locations in use = %0d", mem.num());
    foreach (mem[a]) $display("  mem[%h] = %h", a, mem[a]);
  end

endmodule
