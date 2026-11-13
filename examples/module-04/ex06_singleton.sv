module ex06_singleton;

  class tb_config;
    local static tb_config m_inst;      // the one and only object
    int num_txns = 10;
    bit verbose;

    local function new();               // nobody outside can call new
    endfunction

    static function tb_config get();
      if (m_inst == null) m_inst = new();
      return m_inst;
    endfunction
  endclass

  tb_config c1, c2;

  initial begin
    c1 = tb_config::get();              // first call creates the object
    c1.num_txns = 25;

    c2 = tb_config::get();              // later calls return the same object
    $display("c2.num_txns=%0d  same object=%0d", c2.num_txns, c1 == c2);

    // c1 = new();                      // ILLEGAL: the constructor is local
  end

endmodule
