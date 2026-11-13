class cnt_user;

  virtual cnt_if vif;

  function void set_vif(virtual cnt_if vif);
    this.vif = vif;
  endfunction

  function bit is_connected();
    return (vif != null);
  endfunction

  task enable();
    if (vif == null) begin
      $display("[%0t] ERROR: vif is null, cannot drive", $time);
      return;
    end
    vif.en = 1;
    $display("[%0t] en driven to 1", $time);
  endtask

endclass

module tb_vif_null;

  logic clk = 0;
  always #5 clk = ~clk;

  cnt_if  cif (clk);
  counter dut (cif);

  cnt_user u;

  initial begin
    u = new();
    $display("connected = %b", u.is_connected());
    u.enable();

    u.set_vif(cif);
    $display("connected = %b", u.is_connected());
    u.enable();
    $finish;
  end

endmodule
