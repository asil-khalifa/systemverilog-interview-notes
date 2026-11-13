module tb_typedef;

  typedef logic [7:0] byte_t;
  typedef byte_t      buf_t [4];                  // array type: 4 bytes
  typedef enum bit {READ, WRITE} dir_e;
  typedef struct {
    dir_e  dir;
    byte_t addr;
    buf_t  payload;
  } xfer_t;

  // A function can return an array only through a typedef name
  function automatic buf_t make_ramp(byte_t start);
    buf_t result;
    foreach (result[i]) result[i] = start + i;
    return result;
  endfunction

  xfer_t x;

  initial begin
    x.dir     = WRITE;
    x.addr    = 8'h40;
    x.payload = make_ramp(8'h10);
    $display("dir=%s addr=%h", x.dir.name(), x.addr);
    foreach (x.payload[i]) $display("payload[%0d] = %h", i, x.payload[i]);
    $display("$bits(byte_t) = %0d, $bits(buf_t) = %0d", $bits(byte_t), $bits(buf_t));
  end

endmodule
