module ex05_enum_list;

  typedef enum logic [2:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_NOT, ALU_SHL, ALU_SHR
  } alu_op_e;

  alu_op_e op;

  initial begin
    op = op.first();
    for (int i = 0; i < op.num(); i++) begin
      $display("%-8s = %0d (%b)", op.name(), op, op);
      op = op.next();
    end
  end

endmodule
