module ALU(
	input logic[31:0] instruction,
	input logic[31:0] ReadData1,
	input logic reset,
	input logic[31:0] ReadData2,
	output logic[31:0] ALUResult	
);

	logic[5:0] opcode;
	assign opcode = instruction[31:26];
	logic[5:0] func;
	assign func = instruction[5:0];
	logic[31:0] immediateSE;
	assign immediateSE = {{16{instruction[15]}}, instruction[15:0]};
	logic[31:0] immediateZE;
	assign immediateZE = {16'b0, instruction[15:0]};
	logic[4:0] shamt;
	assign shamt = instruction[10:6];

always_comb begin

	if(opcode==0) begin
		case(func)
			6'b100000: ALUResult = ReadData1 + ReadData2; //ADDU
			6'b100010: ALUResult = ReadData1 - ReadData2; //SUBU
			//6'b011000: ALUResult = ReadData1 * ReadData2;
			//6'b011010: ALUResult = ReadData1 / ReadData2;
			6'b101010: ALUResult = ($signed(ReadData1) < $signed(ReadData2)) ? 1 : 0; //SLT
			6'b101011: ALUResult = (ReadData1 < ReadData2) ? 1 : 0; //SLTU
			6'b100100: ALUResult = ReadData1 & ReadData2; //AND
			6'b100101: ALUResult = ReadData1 | ReadData2; //OR
			6'b101000: ALUResult = ReadData1 ^ ReadData2; //XOR
			6'b000000: ALUResult = ReadData2 << shamt; //SLL
			6'b000100: ALUResult = ReadData2 << ReadData1; //SLLV
			6'b000011: ALUResult = ReadData2 >>> shamt; //SRA
			6'b000111: ALUResult = ReadData2 >>> ReadData1; //SRAV
			6'b000010: ALUResult = ReadData2 >> shamt; //SRL
			6'b000110: ALUResult = ReadData2 >> ReadData1; //SRLV
		endcase
			
	end

	else if(opcode == 6'b001000)begin
		ALUResult = ReadData1 + immediateSE; //ADDIU
	end	
	
	else if(opcode == 6'b100011 || opcode == 6'b101011)begin
		ALUResult = $floor(ReadData1 + immediateSE); //LW and SW	
	end

	else if(opcode == 6'b001010)begin
		ALUResult = ($signed(ReadData1) < $signed(immediateSE)) ? 1 : 0; //SLTI
	end
	
	else if(opcode == 6'b001011)begin
		ALUResult = (ReadData1 < immediateSE) ? 1 : 0; //SLTIU
	end

	else if(opcode == 6'b001100)begin
		ALUResult = ReadData1 & immediateZE; //ANDI
	end

	else if(opcode == 6'b001101)begin
		ALUResult = ReadData1 | immediateZE; //ORI
	end

	else if(opcode == 6'b001110)begin
		ALUResult = ReadData1 ^ immediateZE; //XORI
	end

	else if(opcode == 6'b100100)begin
		ALUResult = ReadData1 + immediateSE; //LBU
	end

	else if(opcode == 6'b100000)begin
		ALUResult = ReadData1 + immediateSE; //LB
	end

	else if(opcode == 6'b101000)begin
		ALUResult = ReadData1 + immediateSE; //SB
	end
end


endmodule
