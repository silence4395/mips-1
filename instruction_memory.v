// instruction memory
// instruction is sync with clock, because block ram is far away
// TODO: use BlockRAM backend, and set data with COE
module instruction_memory (input clk,
                           input write_enable,            
                           input [15:0]      address,
                           input [31:0]      write_data,
                           output reg [31:0] read_data);
   parameter MEM_SIZE=16000; // resize if instruction exceeds this.

   reg [31:0] RAM[MEM_SIZE-1:0];

   always @ (posedge clk) begin
      if (write_enable == 1) begin
         RAM[address] <= write_data;
         $display("WRITE: %h", write_data);
      end
      else begin
         read_data <= RAM[address]; // word align
      end
   end

endmodule
