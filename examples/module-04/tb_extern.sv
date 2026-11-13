module tb_extern;

  class packet;
    bit [7:0] addr;
    bit [7:0] data;

    extern function new(bit [7:0] addr = 8'h00, bit [7:0] data = 8'h00);
    extern function void print(string tag = "");
    extern function bit [7:0] checksum();
  endclass

  function packet::new(bit [7:0] addr, bit [7:0] data);
    this.addr = addr;
    this.data = data;
  endfunction

  function void packet::print(string tag);
    $display("[%s] addr=%h data=%h checksum=%h", tag, addr, data, checksum());
  endfunction

  function bit [7:0] packet::checksum();
    return addr ^ data;
  endfunction

  packet p;

  initial begin
    p = new(8'h0F, 8'hF1);
    p.print("p");
    p = new();
    p.print("default");
  end

endmodule
