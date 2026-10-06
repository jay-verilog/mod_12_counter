module mod_12_counter
#(
parameter MOD = 12
)
(
input                                clk,
input                                rst_n,
input                                load_en,
input                                up_down,
input      [$clog2(MOD)-1:0] data_in,
output reg [$clog2(MOD)-1:0] count_out
);

always @(posedge clk or negedge rst_n)
begin
   if(rst_n == 1'b0)
   begin
      count_out <= 4'b0000;
   end
   
   else
   begin
      if(load_en == 1'b1 && data_in < MOD)
      begin 
         count_out <= data_in;
      end
      
      else if(up_down == 1'b1)
      begin
         if(count_out == (MOD -1)) 
         begin
            count_out <= 4'b0000;
         end
  
         else 
         begin
            count_out <= count_out + 1'b1;
         end
      end 

      else 
      begin
         if(count_out == 4'b0000) 
         begin
            count_out <= MOD - 1;
         end
  
         else 
         begin
            count_out <= count_out - 1'b1;
         end
      end 

   
   end
end
endmodule
