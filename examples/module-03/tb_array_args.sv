module tb_array_args;

  typedef struct {
    int       id;
    bit [7:0] payload [4];
  } pkt_t;

  // const ref: no copy, read-only
  function automatic int sum(const ref int arr[]);
    int s;
    s = 0;
    foreach (arr[i]) s += arr[i];
    return s;
  endfunction

  // ref: modifies the caller's array in place
  function automatic void scale(ref int arr[], input int factor);
    foreach (arr[i]) arr[i] *= factor;
  endfunction

  // input queue: a private copy that the function may consume freely
  function automatic int last_two_sum(int q[$]);
    int s;
    s  = q.pop_back();
    s += q.pop_back();
    return s;
  endfunction

  // struct by ref, string by value
  function automatic void stamp(ref pkt_t p, input string who);
    p.id++;
    foreach (p.payload[i]) p.payload[i] = p.payload[i] + 8'h10;
    $display("%s stamped packet %0d", who, p.id);
  endfunction

  int   values[];
  int   numbers[$] = {10, 20, 30, 40};
  pkt_t pkt;

  initial begin
    values = new[4];
    values = '{1, 2, 3, 4};

    $display("1. sum            = %0d", sum(values));
    scale(values, 10);
    $display("2. after scale    = %0d %0d %0d %0d",
             values[0], values[1], values[2], values[3]);
    $display("3. sum            = %0d", sum(values));

    $display("4. last_two_sum   = %0d", last_two_sum(numbers));
    $display("5. queue size is still %0d", numbers.size());

    pkt.id      = 6;
    pkt.payload = '{8'h01, 8'h02, 8'h03, 8'h04};
    stamp(pkt, "driver");
    $display("6. payload[0] = %h, payload[3] = %h", pkt.payload[0], pkt.payload[3]);
  end

endmodule
