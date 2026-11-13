module ex03_instruction;

  typedef struct packed {
    logic [5:0]  opcode;    // bits [31:26]
    logic [4:0]  rd;        // bits [25:21]
    logic [4:0]  rs1;       // bits [20:16]
    logic [4:0]  rs2;       // bits [15:11]
    logic [10:0] imm;       // bits [10:0]
  } instr_t;

  instr_t      instr;
  logic [31:0] raw = 32'hA871_4155;

  initial begin
    instr = raw;            // vector to packed struct: no cast needed
    $display("opcode=%h rd=%0d rs1=%0d rs2=%0d imm=%h",
             instr.opcode, instr.rd, instr.rs1, instr.rs2, instr.imm);
    instr.rd = 5'd31;
    $display("after changing rd: %h   ($bits = %0d)", instr, $bits(instr_t));
  end

endmodule
