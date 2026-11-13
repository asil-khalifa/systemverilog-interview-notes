module tb_array_locator_struct;

  typedef struct {
    int       id;
    bit [7:0] addr;
    int       len;
  } pkt_t;

  pkt_t pkts [$];
  pkt_t res  [$];
  int   idx  [$];

  initial begin
    pkts = '{ '{1, 8'h40, 12}, '{2, 8'h10, 64}, '{3, 8'h40, 3}, '{4, 8'h80, 30} };

    res = pkts.find with (item.addr == 8'h40);
    foreach (res[i]) $display("1. addr 40 : id %0d", res[i].id);

    res = pkts.max with (item.len);
    $display("2. longest packet  : id %0d (len %0d)", res[0].id, res[0].len);

    res = pkts.min with (item.len);
    $display("3. shortest packet : id %0d (len %0d)", res[0].id, res[0].len);

    idx = pkts.find_first_index(p) with (p.len > 20);
    $display("4. first packet longer than 20 is at index %0d", idx[0]);

    res = pkts.unique with (item.addr);
    $display("5. %0d different addresses", res.size());

    idx = pkts.find_index with (item.len > 100);
    if (idx.size() == 0) $display("6. no packet longer than 100");
  end

endmodule
