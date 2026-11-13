module tb_packed_unpacked;

  logic [3:0][7:0] word;       // packed: 4 bytes forming one 32-bit vector
  bit   [7:0]      mem [4];    // unpacked array of 4 packed bytes, indices 0 to 3
  bit   [7:0]      copy [4];

  initial begin
    word = 32'hDEAD_BEEF;
    $display("1. word        = %h", word);
    $display("2. word[3]     = %h   word[0] = %h", word[3], word[0]);
    $display("3. word[1:0]   = %h", word[1:0]);
    $display("4. word[2][7]  = %b", word[2][7]);
    $display("5. word + 1    = %h", word + 1);
    $display("6. $bits(word) = %0d", $bits(word));

    mem = '{8'h11, 8'h22, 8'h33, 8'h44};
    $display("7. mem[0] = %h   mem[3] = %h", mem[0], mem[3]);
    $display("8. mem[1][3:0] = %h", mem[1][3:0]);
    $display("9. $bits(mem) = %0d   $size(mem) = %0d", $bits(mem), $size(mem));

    copy = mem;                               // whole-array copy
    copy[2] = 8'h00;
    if (copy == mem) $display("10. copy == mem");
    else             $display("10. copy != mem (mem[2]=%h copy[2]=%h)", mem[2], copy[2]);

    mem = '{default: 8'hFF};
    foreach (mem[i]) $display("11. mem[%0d] = %h", i, mem[i]);
  end

endmodule
