module ex08_sign_extend;

  logic        [11:0] imm = 12'hF85;
  logic signed [11:0] imm_s;
  logic        [31:0] e1, e2, e3;
  int                 value;

  initial begin
    e1 = {{20{imm[11]}}, imm};     // 1. replicate the sign bit manually
    e2 = signed'(imm);             // 2. cast: a signed right-hand side is sign-extended
    imm_s = imm;
    e3 = imm_s;                    // 3. copy into a signed variable first
    value = signed'(imm);
    $display("%h %h %h %0d", e1, e2, e3, value);
  end

endmodule
