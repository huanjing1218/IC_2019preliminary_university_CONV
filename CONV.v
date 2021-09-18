`timescale 1ns/10ps

module  CONV(
	input clk,
	input reset,
	output reg busy,	
	input ready,	
			
	output reg [11:0] iaddr,
	input [19:0] idata,	
	
	output reg cwr,
	output reg [11:0] caddr_wr,
	output reg [19:0] cdata_wr,
	
	output reg crd,
	output reg [11:0] caddr_rd,
	input [19:0] cdata_rd,
	
	output reg [2:0] csel
	);

reg [4:0] state, next;
reg signed [39:0] sum;
reg signed [19:0] data, kernel; 

wire signed [39:0] mul = data * kernel;

always @ (posedge clk or posedge reset) begin
	if(reset) begin
		busy <= 0;
		iaddr <= 0;
		cwr <= 0;
		caddr_wr <= 0;
		cdata_wr <= 0;
		crd <= 0;
		caddr_rd <= 0;
		csel <= 0;
		state <= 0;
		sum <= 0;
		data <= 0;
		kernel <= 0;
	end
	else begin
		if(!busy) begin
			if(ready) begin
				busy <= 1;
			end
		end
		else begin
			state <= next;
			case (state)
				5'd0: begin
					iaddr <= caddr_wr - 65;
				end
				5'd1: begin
					iaddr <= caddr_wr - 64;
					data <= idata;
					kernel <= 20'sh0A89E;
				end
				5'd2: begin
					iaddr <= caddr_wr - 63;
					data <= idata;
					kernel <= 20'sh092D5;
					if(caddr_wr[5:0] != 6'b000000 && caddr_wr[11:6] != 6'b000000) // x != 0 && y != 0
						sum <= sum + mul;
				end
				5'd3: begin
					iaddr <= caddr_wr - 1;
					data <= idata;
					kernel <= 20'sh06D43;
					if(caddr_wr[11:6] != 6'b000000) // y != 0
						sum <= sum + mul;
				end
				5'd4: begin
					iaddr <= caddr_wr;
					data <= idata;
					kernel <= 20'sh01004;
					if(caddr_wr[5:0] != 6'b111111 && caddr_wr[11:6] != 6'b000000) // x != 63 && y != 0
						sum <= sum + mul;
				end
				5'd5: begin
					iaddr <= caddr_wr + 1;
					data <= idata;
					kernel <= 20'shF8F71;
					if(caddr_wr[5:0] != 6'b000000) // x != 0
						sum <= sum + mul;	
				end
				5'd6: begin
					iaddr <= caddr_wr + 63;
					data <= idata;
					kernel <= 20'shF6E54;
					sum <= sum + mul;
				end
				5'd7: begin
					iaddr <= caddr_wr + 64;
					data <= idata;
					kernel <= 20'shFA6D7;
					if(caddr_wr[5:0] != 6'b111111) // x != 63
						sum <= sum + mul; 
				end
				5'd8: begin
					iaddr <= caddr_wr + 65;
					data <= idata;
					kernel <= 20'shFC834;
					if(caddr_wr[5:0] != 6'b000000 && caddr_wr[11:6] != 6'b111111) // x != 0 && y != 63
						sum <= sum + mul;
				end
				5'd9: begin
					data <= idata;
					kernel <= 20'shFAC19;
					if(caddr_wr[11:6] != 6'b111111) // y != 63
						sum <= sum + mul;
				end
				5'd10: begin
					if(caddr_wr[5:0] != 6'b111111 && caddr_wr[11:6] != 6'b111111) // x != 63 && y != 63
						sum <= sum + mul;
				end
				5'd11: begin // add bias
					if(sum[15] == 1)
						cdata_wr <= sum[35:16] + 20'sh01311;
					else
						cdata_wr <= sum[35:16] + 20'sh01310;
				end
				5'd12: begin
					csel <= 3'b001;
					cwr <= 1;
					caddr_wr <= caddr_wr;
					if(cdata_wr[19] == 1) // ReLU
						cdata_wr <= 0; 
					else 
						cdata_wr <= cdata_wr;
				end
				5'd13: begin
					sum <=  0;
					csel <= 3'b000;
					cwr <= 0;
					caddr_wr <= caddr_wr + 1;
				end
				5'd14: begin
					csel <= 3'b001;
					cwr <= 0;
					crd <= 1;
					cdata_wr <= 0;
					caddr_rd <= 0;
					caddr_wr <= 0;
				end
				5'd15: begin
					caddr_rd <= caddr_rd + 1;
					cdata_wr <= cdata_rd;
				end
				5'd16: begin
					caddr_rd <= caddr_rd + 63;
					if(cdata_rd > cdata_wr) 
						cdata_wr <= cdata_rd;
				end
				5'd17: begin
					caddr_rd <= caddr_rd + 1;
					if(cdata_rd > cdata_wr) 
						cdata_wr <= cdata_rd;
				end
				5'd18: begin			
					cwr <= 1;
					crd <= 0;
					csel <= 3'b011;
					if(cdata_rd > cdata_wr) 
						cdata_wr <= cdata_rd;
					
					if(caddr_rd[6:0] == 7'b1111111)
						caddr_rd <= caddr_rd + 1;
					else 
						caddr_rd <= caddr_rd - 63;
				end
				5'd19: begin
					cwr <= 0;
					if(caddr_wr == 1023) begin
						csel <= 3'b000;
						crd <= 0;
						busy <= 0;
					end
					else begin
						csel <= 3'b001;
						crd <= 1;
						cdata_wr <= 0;
						caddr_wr <= caddr_wr + 1;
					end
				end
			endcase
		end
	end
end

always @ (*) begin
	next = 0;
	if(busy) begin 
		if(state >= 0 && state <= 12) begin
			next = state + 1;
		end
		else if(state == 13) begin
			if(caddr_wr == 4095) 
				next = 5'd14;
			else 
				next = 5'd0;		
		end
		else if(state >= 14 && state <= 18) begin
			next = state + 1;
		end
		else if(state == 19) begin	
			if(caddr_wr == 1023) 
				next = 5'd19;
			else	
				next = 5'd15;
		end
		else begin
			next = 0;
		end
	end
end

endmodule
