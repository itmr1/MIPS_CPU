module top_level_CPU(
    /* Standard signals */
    input logic clk,
    input logic reset,
    output logic active,
    //output logic[31:0] register_v0,

    /* Avalon memory mapped bus controller (master) */
    output logic[31:0] address,
    output logic write,
    output logic read,
    input logic waitrequest,
    output logic[31:0] writedata,
    //output logic[3:0] byteenable,
    input logic[31:0] readdata
    //output logic[31:0] reg_out[4:0]
);

logic[31:0] instr;
logic[31:0] inst_addr;
logic[31:0] addr;
logic[31:0] data_reg_a;
logic[31:0] data_reg_b;
logic valid_read;
logic valid_write;
logic end_of_inst_reg;
logic end_of_inst_store;
logic MemRead;
logic MemWrite;
logic ALUSrc;
logic RegDest;
logic RegWrite;
logic PCSrc;
logic MemtoReg;
logic fetch;
logic jump;
logic JRcontrol;
logic[31:0] reg_data_in;
logic[31:0] alu_data;


assign addr = (fetch==1)?inst_addr:alu_data;
assign address = addr;
assign writedata = data_reg_b;

always@* begin
	if (addr == 0) begin
		active = 0;
	end
end


PC pc_dut(
    .clk(clk),
    .reset(reset),
    .jumpaddr(data_reg_a),
    .JRcontrol(JRcontrol),
    .pcout(inst_addr)
);

instr_reg instreg_dut(
    .mem_in(readdata),
    .delay(waitrequest),
    .instruction(instr),
    .valid(valid_read),    
    .fetch(fetch),
	.reset(reset)
);

regfile reg_dut(
    .clk(clk),
    .reset(reset),
    .reg_dst(RegDest),
    .valid_read(valid_read),
    .valid_write(valid_write),
    .Instruction(instr),
    .WriteData(reg_data_in),
    .W_en(RegWrite),
    .end_instr(end_of_inst_reg),
    .ReadData1(data_reg_a),
    .ReadData2(data_reg_b),
	.active(active)
    //.reg_out[4:0](reg_out[4:0])
);

ALU alu_dut(
    .instruction(instr),
    .ReadData1(data_reg_a),
    .ReadData2(data_reg_b),
    .reset(reset),
    .ALUResult(alu_data)
);

data_mem data_dut(
    .mem_in(readdata),
    .alu_in(alu_data),
    .instr(instr),
    .mem_sel(MemtoReg),
    .delay(waitrequest),
    .data_to_reg(reg_data_in), 
    .valid(valid_write) 
);

control_signals control_dut(
    .inst(instr),
    .end_of_inst_reg(end_of_inst_reg),
    .end_of_inst_store(end_of_inst_store),
    .MemRead(read),
    .MemWrite(write),
    .ALUSrc(ALUSrc),
    .RegDest(RegDest),
    .RegWrite(RegWrite),
    .PCSrc(PCSrc),
    .MemtoReg(MemtoReg),
    .fetch(fetch),
    .JRcontrol(JRcontrol),
	.clk(clk),
	.reset(reset)
);

endmodule



