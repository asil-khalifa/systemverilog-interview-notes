package cfg_pkg;
  parameter int MAX_LEN = 16;
  typedef enum {LOW, HIGH} level_e;
endpackage

module tb_scope_resolution;

  class packet;
    typedef enum {READ, WRITE} dir_e;        // a type declared inside the class
    localparam int HEADER_BYTES = 2;         // a constant declared inside the class
    static int count = 0;                    // a static property
    dir_e dir;

    static function int get_count();         // a static method
      return count;
    endfunction
  endclass

  packet::dir_e    d;                        // type from the class scope
  cfg_pkg::level_e lvl;                      // type from the package scope

  initial begin
    d   = packet::WRITE;                     // enum label from the class scope
    lvl = cfg_pkg::HIGH;                     // enum label from the package scope
    packet::count = 3;                       // static property: no object exists

    $display("%s %s %0d %0d %0d",
             d.name(), lvl.name(), packet::HEADER_BYTES, cfg_pkg::MAX_LEN,
             packet::get_count());
  end

endmodule
