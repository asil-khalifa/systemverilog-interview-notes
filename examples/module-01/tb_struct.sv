module tb_struct;

  typedef struct packed {
    logic [3:0] kind;
    logic [3:0] len;
    logic [7:0] addr;
  } hdr_t;

  typedef struct {
    int       id;
    bit [7:0] data;
    string    name;
    real      delay_ns;
  } item_t;

  hdr_t  hdr;
  item_t item, item_copy;

  initial begin
    // ---------------- packed struct ----------------
    hdr = 16'hA5C3;
    $display("1. kind=%h len=%h addr=%h", hdr.kind, hdr.len, hdr.addr);

    hdr.len = 4'hF;
    $display("2. hdr=%h  hdr[7:0]=%h  $bits(hdr)=%0d", hdr, hdr[7:0], $bits(hdr));

    hdr = '{kind: 4'h1, len: 4'h2, addr: 8'h34};
    $display("3. hdr=%h", hdr);

    hdr = '{default: '0};
    $display("4. hdr=%h", hdr);

    // ---------------- unpacked struct ----------------
    item = '{id: 7, data: 8'hAB, name: "pkt", delay_ns: 1.5};
    item_copy    = item;        // copies every member
    item_copy.id = 8;
    $display("5. item.id=%0d  item_copy.id=%0d", item.id, item_copy.id);

    if (item == item_copy) $display("6. structs are equal");
    else                   $display("6. structs differ");

    $display("7. item = %p", item);
  end

endmodule
