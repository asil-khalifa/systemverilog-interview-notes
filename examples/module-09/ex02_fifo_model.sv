module ex02_fifo_model;

  typedef enum bit {FIFO_WRITE, FIFO_READ} fifo_kind_e;

  bit [7:0]    model_q [$];
  int unsigned num_checked;
  int unsigned num_fail;

  function automatic void observe(fifo_kind_e kind, logic [7:0] value);
    bit [7:0] expected_data;
    if (kind == FIFO_WRITE) begin
      model_q.push_back(value);
      $display("WRITE %h  model holds %0d", value, model_q.size());
    end
    else begin
      num_checked++;
      if (model_q.size() == 0) begin
        num_fail++;
        $display("READ  %h  FAIL: model is empty", value);
      end
      else begin
        expected_data = model_q.pop_front();
        if (value !== expected_data) begin
          num_fail++;
          $display("READ  %h  FAIL: expected %h", value, expected_data);
        end
        else
          $display("READ  %h  PASS", value);
      end
    end
  endfunction

  initial begin
    observe(FIFO_WRITE, 8'hA1);
    observe(FIFO_WRITE, 8'hB2);
    observe(FIFO_READ,  8'hA1);
    observe(FIFO_WRITE, 8'hC3);
    observe(FIFO_READ,  8'hB2);
    observe(FIFO_READ,  8'hFF);     // the "DUT" returned FF instead of C3
    observe(FIFO_READ,  8'h00);     // the "DUT" produced data from an empty FIFO
    $display("checked=%0d fail=%0d left in model=%0d",
             num_checked, num_fail, model_q.size());
  end

endmodule
