module tb_array_query;

  logic [7:0]      mem  [0:3];        // dim 1 = [0:3] (unpacked), dim 2 = [7:0] (packed)
  logic [3:0][7:0] word;              // dim 1 = [3:0], dim 2 = [7:0] (both packed)
  bit [15:0]       grid [2][6:4];     // dim 1 = [0:1], dim 2 = [6:4], dim 3 = [15:0]
  int              dyn  [];

  initial begin
    $display("--- mem : logic [7:0] mem [0:3] ---");
    $display("dimensions=%0d unpacked=%0d bits=%0d",
             $dimensions(mem), $unpacked_dimensions(mem), $bits(mem));
    $display("dim 1: size=%0d left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $size(mem), $left(mem), $right(mem), $low(mem), $high(mem), $increment(mem));
    $display("dim 2: size=%0d left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $size(mem, 2), $left(mem, 2), $right(mem, 2), $low(mem, 2), $high(mem, 2),
             $increment(mem, 2));

    $display("--- word : logic [3:0][7:0] word ---");
    $display("dimensions=%0d unpacked=%0d size1=%0d size2=%0d left1=%0d",
             $dimensions(word), $unpacked_dimensions(word), $size(word, 1), $size(word, 2),
             $left(word, 1));

    $display("--- grid : bit [15:0] grid [2][6:4] ---");
    $display("dimensions=%0d size1=%0d size2=%0d size3=%0d",
             $dimensions(grid), $size(grid, 1), $size(grid, 2), $size(grid, 3));
    $display("dim 2: left=%0d right=%0d low=%0d high=%0d increment=%0d",
             $left(grid, 2), $right(grid, 2), $low(grid, 2), $high(grid, 2),
             $increment(grid, 2));

    $display("--- dyn : int dyn [] ---");
    dyn = new[5];
    $display("size=%0d $size=%0d left=%0d right=%0d high=%0d",
             dyn.size(), $size(dyn), $left(dyn), $right(dyn), $high(dyn));
  end

endmodule
