module ex02_parity;

  bit [7:0] data = 8'hA7;
  bit       even_par, odd_par;
  bit [8:0] tx;

  initial begin
    even_par = ^data;        // makes the total number of ones even
    odd_par  = ~^data;       // makes the total number of ones odd
    $display("data=%h  even_parity=%b  odd_parity=%b", data, even_par, odd_par);

    tx = {even_par, data};
    $display("no error    : parity check = %b", ^tx);

    tx[2] = ~tx[2];          // inject a single-bit error
    $display("1-bit error : parity check = %b", ^tx);
  end

endmodule
