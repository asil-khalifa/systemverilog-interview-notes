module tb_bitstream;

  typedef struct {            // unpacked struct, 32 bits in total
    bit [7:0]  addr;
    bit [7:0]  data;
    bit [15:0] crc;
  } pkt_t;
  typedef bit [31:0] u32_t;

  pkt_t     p, q;
  u32_t     v;
  bit [7:0] b8;

  initial begin
    p = '{addr: 8'hA1, data: 8'hB2, crc: 16'hC3D4};

    v = u32_t'(p);                 $display("1. bit-stream cast       : %h", v);
    v = {>>{p}};                   $display("2. streaming {>>{p}}     : %h", v);

    q = pkt_t'(32'h1122_3344);     $display("3. unpack                : addr=%h data=%h crc=%h",
                                            q.addr, q.data, q.crc);

    v  = {<<8{32'hA1B2_C3D4}};     $display("4. byte reverse {<<8{..}} : %h", v);
    b8 = {<<{8'b1100_0001}};       $display("5. bit reverse  {<<{..}}  : %b", b8);
  end

endmodule
