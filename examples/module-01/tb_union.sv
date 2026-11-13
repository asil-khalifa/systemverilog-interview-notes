module tb_union;

  typedef union packed {
    logic [31:0]     word;
    logic [3:0][7:0] bytes;
    struct packed {
      logic [7:0]  opcode;
      logic [23:0] operand;
    } instr;
  } reg_view_u;

  reg_view_u u;

  initial begin
    u.word = 32'h12_345678;
    $display("1. word    = %h", u.word);
    $display("2. bytes   = %h %h %h %h", u.bytes[3], u.bytes[2], u.bytes[1], u.bytes[0]);
    $display("3. opcode  = %h   operand = %h", u.instr.opcode, u.instr.operand);

    u.bytes[0] = 8'hFF;                  // write through one view...
    $display("4. word    = %h", u.word); // ...and read through another

    u.instr.opcode = 8'hA0;
    $display("5. word    = %h", u.word);

    $display("6. $bits   = %0d", $bits(u));
  end

endmodule
