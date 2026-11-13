module tb_p12_kind_len;

  typedef enum {SHORT, MEDIUM, LONG} kind_e;

  class pkt;
    rand kind_e     kind;
    rand bit [10:0] len;
    rand bit [7:0]  payload[];

    constraint len_c {
      (kind == SHORT)  -> len inside {[1:15]};
      (kind == MEDIUM) -> len inside {[16:255]};
      (kind == LONG)   -> len inside {[256:1500]};
    }
    constraint order_c { solve kind before len; }
    constraint size_c  { payload.size() == len; }
  endclass

  pkt p;
  int errors;
  int count[kind_e];

  initial begin
    p = new();
    repeat (300) begin
      if (!p.randomize()) $fatal(1, "randomize failed");
      count[p.kind]++;
      case (p.kind)
        SHORT  : if (!(p.len inside {[1:15]}))     errors++;
        MEDIUM : if (!(p.len inside {[16:255]}))   errors++;
        LONG   : if (!(p.len inside {[256:1500]})) errors++;
      endcase
      if (p.payload.size() != p.len) errors++;
    end
    $display("p12: SHORT=%0d MEDIUM=%0d LONG=%0d", count[SHORT], count[MEDIUM], count[LONG]);
    $display("p12: errors=%0d", errors);
  end

endmodule
