module ex03_pack_unpack;
  import alu_pkg::*;
  import alu_tb_pkg::*;

  typedef bit [18:0] alu_bits_t;

  function automatic alu_bits_t pack_txn(alu_txn t);
    return {t.op, t.a, t.b};
  endfunction

  function automatic alu_txn unpack_txn(alu_bits_t bits);
    alu_txn t = new();
    if (!$cast(t.op, bits[18:16])) $error("illegal opcode %b", bits[18:16]);
    t.a = bits[15:8];
    t.b = bits[7:0];
    return t;
  endfunction

  alu_txn    t, u;
  alu_bits_t w;

  initial begin
    t    = new();
    t.op = ALU_XOR;
    t.a  = 8'hAA;
    t.b  = 8'h0F;

    w = pack_txn(t);
    $display("packed           : %h", w);

    u = unpack_txn(w);
    $display("unpacked         : %s", u.convert2string());
    $display("round trip equal : %0d", t.compare(u));
  end

endmodule
