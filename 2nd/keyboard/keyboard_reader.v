// read keyboard input when instruction received

module keyboard_reader(input clk,
                       input [31:0]      inst,

                       // for extension
                       // 0: is_break
                       // 1: this is new break input
                       input [7:0]       key_status,
                       input [7:0]       keycode,

                       output reg        enable,
                       output            float, // always false
                       output reg [4:0]  addr,
                       output reg [31:0] data);

   `include "../opcode.h"

   wire [5:0] op;

   assign op = inst[31:26];
   assign float = 1'b0;

   always @ (posedge(clk)) begin
      if (op == READKEY && key_status[1] == 1'b1) begin
         enable <= 1'b1;
         addr <= inst[20:16];
         data <= {16'b0, key_status, keycode};
      end else
        enable <= 1'b0;
   end

endmodule
