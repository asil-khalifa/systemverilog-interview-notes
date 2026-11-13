module ex05_fifo_model;

  localparam int DEPTH = 4;
  bit [7:0] fifo_q [$];

  function automatic void fifo_write(bit [7:0] data);
    if (fifo_q.size() == DEPTH) begin
      $display("write %h : FULL, data dropped", data);
      return;
    end
    fifo_q.push_back(data);
    $display("write %h : ok   (count %0d)", data, fifo_q.size());
  endfunction

  function automatic void fifo_read();
    bit [7:0] data;
    if (fifo_q.size() == 0) begin
      $display("read     : EMPTY");
      return;
    end
    data = fifo_q.pop_front();
    $display("read  %h : ok   (count %0d)", data, fifo_q.size());
  endfunction

  initial begin
    fifo_write(8'h11);
    fifo_write(8'h22);
    fifo_write(8'h33);
    fifo_write(8'h44);
    fifo_write(8'h55);
    fifo_read();
    fifo_read();
    fifo_write(8'h66);
    repeat (4) fifo_read();
  end

endmodule
