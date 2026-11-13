module tb_assoc_histogram;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  alu_op_e ops [10] = '{ALU_ADD, ALU_SUB, ALU_ADD, ALU_XOR, ALU_ADD,
                        ALU_SHL, ALU_SUB, ALU_ADD, ALU_XOR, ALU_ADD};
  int      hist [alu_op_e];

  initial begin
    foreach (ops[i]) hist[ops[i]]++;

    $display("%0d different operations seen", hist.num());
    foreach (hist[op]) $display("  %-8s : %0d", op.name(), hist[op]);

    if (!hist.exists(ALU_NOT)) $display("ALU_NOT was never generated");
  end

endmodule
