module tb_pre_post;

  class pkt;
    rand bit [3:0] len;
    rand bit [7:0] payload[];
    bit [7:0]      checksum;          // derived: not random
    int            max_len = 4;       // knob
    int            n_calls;

    constraint len_c { len inside {[1:max_len]}; payload.size() == len; }

    function void pre_randomize();
      n_calls++;
      $display("pre  : call %0d, max_len=%0d", n_calls, max_len);
    endfunction

    function void post_randomize();
      checksum = 0;
      foreach (payload[i]) checksum ^= payload[i];
      $display("post : len=%0d payload=%p checksum=%h", len, payload, checksum);
    endfunction
  endclass

  pkt p;
  int status;

  initial begin
    p = new();
    status = p.randomize();
    $display("status=%0d", status);

    p.max_len = 0;                    // makes len_c impossible: [1:0] is an empty range
    status = p.randomize();
    $display("status=%0d", status);
  end

endmodule
