package bus_pkg;

  parameter int ADDR_W = 8;
  parameter int DATA_W = 16;

  typedef enum bit {BUS_READ, BUS_WRITE} bus_dir_e;

  typedef struct packed {
    bus_dir_e          dir;
    logic [ADDR_W-1:0] addr;
    logic [DATA_W-1:0] data;
  } bus_req_t;

  function automatic bus_req_t make_req(bus_dir_e          dir,
                                        logic [ADDR_W-1:0] addr,
                                        logic [DATA_W-1:0] data = '0);
    bus_req_t r;
    r.dir  = dir;
    r.addr = addr;
    r.data = data;
    return r;
  endfunction

  function automatic bit parity(bus_req_t r);
    return ^r;
  endfunction

endpackage : bus_pkg

module ex01_bus_pkg;
  import bus_pkg::*;

  bus_req_t req;

  initial begin
    req = make_req(BUS_WRITE, 8'h3C, 16'hBEEF);
    $display("dir=%s addr=%h data=%h bits=%0d",
             req.dir.name(), req.addr, req.data, $bits(req));
    $display("raw=%h parity=%b", req, parity(req));

    req = make_req(BUS_READ, 8'h10);
    $display("dir=%s addr=%h data=%h", req.dir.name(), req.addr, req.data);
  end
endmodule
