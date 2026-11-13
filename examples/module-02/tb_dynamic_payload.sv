module tb_dynamic_payload;

  bit [7:0]    payload [];
  int unsigned len;
  bit [7:0]    checksum;

  initial begin
    len     = 6;                              // in a real test this would be random
    payload = new[len];
    foreach (payload[i]) payload[i] = 8'hA0 + i;

    checksum = 8'h00;
    foreach (payload[i]) checksum ^= payload[i];

    // append the checksum: grow by one element, keeping the data
    payload = new[payload.size() + 1](payload);
    payload[payload.size() - 1] = checksum;

    $write("frame (%0d bytes):", payload.size());
    foreach (payload[i]) $write(" %h", payload[i]);
    $display("");
  end

endmodule
