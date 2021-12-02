module regfile(
    input logic clk,
    input logic reset,
    input logic reg_dst,
    input logic valid,
    input logic[31:0] Instruction,
    input logic[31:0] WriteData,
    input logic W_en,
    output logic end_instr,
    output logic[31:0] ReadData1,
    output logic[31:0] ReadData2
);

logic[31:0] regs[4:0];
logic[4:0] read_addr_1;
logic[4:0] read_addr_2;
logic[4:0] write_addr;

assign read_addr_1 = Instruction[25:21];
assign read_addr_2 = Instruction[20:16];
assign write_addr = reg_dst == 1 ? Instruction[15:11]:Instruction[20:16];

always_ff @(posedge clk) begin
    if valid==1:
        ReadData1 <= regs[read_addr_1];
        ReadData2 <= regs[read_addr_2];
        if (reset == 1) begin
            for (integer idx = 0; idx<32; idx=idx+1) begin
                regs[idx]<=0;
            end
        end
        else if (W_en == 1) begin
            regs[write_addr]<= writeData;
            end_instr<=1; //added end_instr signal output to go into PC asking to fetch next instruction.
        end
    end
end
endmodule
