module tb_p17_date;

  class date_gen;
    rand bit [11:0] year;
    rand bit [3:0]  month;
    rand bit [4:0]  day;

    constraint year_c  { year inside {[2000:2099]}; }
    constraint month_c { month inside {[1:12]}; }
    constraint day_c {
      day >= 1;
      if (month inside {4, 6, 9, 11})
        day <= 30;
      else if (month == 2) {
        if (year % 4 == 0) day <= 29;
        else               day <= 28;
      }
      else
        day <= 31;
    }
  endclass

  function automatic int days_in(int y, int m);
    if (m inside {4, 6, 9, 11}) return 30;
    if (m == 2)                 return (y % 4 == 0) ? 29 : 28;
    return 31;
  endfunction

  date_gen g;
  int      errors;

  initial begin
    g = new();
    repeat (500) begin
      if (!g.randomize()) $fatal(1, "randomize failed");
      if (g.year < 2000 || g.year > 2099)                      errors++;
      if (g.month < 1 || g.month > 12)                         errors++;
      if (g.day < 1 || g.day > days_in(g.year, g.month))       errors++;
    end
    $display("p17: sample %0d-%0d-%0d", g.year, g.month, g.day);
    $display("p17: errors=%0d", errors);
  end

endmodule
