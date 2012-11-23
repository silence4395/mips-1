// instruction_loader
// Change CPU mode between loading mode and executing mode
// FFFFFFFF is the signal to toggle mode
module instruction_loader (input clk,
                           input             reset,
                           input             input_enable,
                           input [7:0]       received_data,
                           output reg        in_execution,
                           output reg        write_enable,
                           output reg [15:0] write_address,
                           output reg [31:0] write_data);

   reg [31:0] buffer;
   reg [1:0] ptr;
   reg i_write_enable;
   reg inc_address_in_next_clock;

   task initialize;
      begin
         buffer <= 32'h00000000;
         ptr <= 2'b00;
         in_execution <= 0;
         write_address <= 0;
      end
   endtask

   initial
      initialize();

   always @ (*) begin
      write_data <= buffer;
   end

   // make sure that write_enable is 0 while execution
   always @ (i_write_enable or in_execution) begin
      if (i_write_enable == 1 && in_execution == 0)
        write_enable <= 1;
      else
        write_enable <= 0;
   end

   always @ (posedge clk) begin
      if (reset == 1) begin
         initialize();
      end
      else if (input_enable == 1 && in_execution == 0) begin
         ptr <= ptr + 1;
         case (ptr)
           2'b00 : buffer[31:24] <= received_data;
           2'b01 : buffer[23:16] <= received_data;
           2'b10 : buffer[15:8] <= received_data;
           2'b11 : buffer[7:0] <= received_data;
         endcase

         if (inc_address_in_next_clock == 1) begin
            inc_address_in_next_clock <= 0;
            write_address <= write_address + 1;
         end

         if (ptr == 3) begin
            if (buffer[31:8] == 24'hffffff && received_data == 8'hff)
              in_execution <= 1;
            else begin
               i_write_enable <= 1;
               inc_address_in_next_clock <= 1;
            end
         end else
           i_write_enable <= 0;
      end
   end

endmodule