module mips_cpu_bus(
    /* Standard signals */
    input logic clk,
    input logic reset, //sync to clk, must be active for 1 cycle
    output logic active, //when CPU poggywoggy, active = 1
    output logic[31:0] register_v0, //final value of $v0 (ie: reg2). (Only for testing purposes)

    /* Avalon memory mapped bus controller (master) */
    output logic[31:0] address,
    output logic write, // <-- write request
    output logic read, // <-- read request
    input logic waitrequest, //indicates stall cycle (ie:  read or write request cannot complete in the current cycle)
    output logic[31:0] writedata,
    output logic[3:0] byteenable,
    input logic[31:0] readdata //not avaliable until cycle following read request
);

	/*---Comb Decode---*/
	logic[31:0] instruction;
    logic[5:0] instructionOpcode = instruction[31:26]; //R,I,J
    logic[4:0] instructionSource1 = instruction[25:21]; //R,I
    logic[4:0] instructionSource2 = instruction[20:16]; //R,I (note for I, source2 also refered as dest sometimes maybe)
    logic[4:0] instructionDest = instruction[15:11]; //R
    logic[4:0] instructionShift = instruction[10:6]; //R
    logic[5:0] instructionFnCode = instruction[5:0]; //R
    logic[15:0] instructionImmediateI = instruction[15:0]; //I
    logic[25:0] instructionAddressJ = instruction[25:0]; //J
    /*---*/

    /*----Memory combinational things-------------------*/
    assign write = (state == S_MEMORY && instructionOpcode == OP_SW); //add SH and SB later
    assign writedata = (instructionOpcode == OP_SW) ? registerReadB : 32'h00000000; //placeholder logic for SH and SB later
    
    assign read = (state == S_FETCH || (state == S_MEMORY && instructionOpcode == OP_LW));

    logic[31:0] address_temp;
    assign address_temp = (state == S_FETCH) ? progCount : AluOut;
    assign address = {address_temp[31:2] << 2}; //uses ALU to compute instrSource1 + instrImmI
    // ^ setting address to read from to be what's dictated by the instruction
    /*---*/

    /*---ALU things---*/
    logic [3:0] AluControl;
    logic[31:0] AluA;
    logic[31:0] AluB;
    logic[31:0] AluOut;
    logic AluZero;
    logic[4:0] shiftAmount;

    mips_cpu_ALU ALU0(.reset(reset),.clk(clk),.control(AluControl),.a(AluA),.b(AluB),.sa(shiftAmount),.r(AluOut),.zero(AluZero));
    /*---*/

    /*---Register0-31+HI+LO+progCountS---*/
    logic registerWriteEnable;
    logic[31:0] registerDataIn;
    logic[4:0] registerWriteAddress;
    logic[4:0] registerAddressA;
    logic[31:0] registerReadA;
    logic[4:0] registerAddressB;
    logic[31:0] registerReadB;  

    mips_cpu_registers Regs0(.reset(reset),.clk(clk),.writeEnable(registerWriteEnable),.dataIn(registerDataIn),.writeAddress(registerWriteAddress),.readAddressA(registerAddressA),.readDataA(registerReadA),.readAddressB(registerAddressB),.readDataB(registerReadB),.register_v0(register_v0));
    
    logic[31:0] registerHi;
    logic[31:0] registerLo;
    /*---*/

    /*---Program Counter---*/
    logic[31:0] progCount;
    logic[31:0] progTemp;
    logic[31:0] progNext;
    assign progNext = progCount + 4; //this is for J-type jumps as we need to get the value correct
    /*---*/

    /*---State------------*/
    logic[2:0] state;
    /*---*/


    /*---Jump controls---*/
    logic[1:0] branch; //0 = normal, 1 = jump instr, 2 = previous jump
    /*---*/

    typedef enum logic[5:0] {
        OP_R_TYPE = 6'b000000,
        OP_ADDIU  = 6'b001001,
        OP_LW     = 6'b100011,
        OP_SW     = 6'b101011,
        OP_J      = 6'b000010,
        OP_JAL    = 6'b000011
    } typeOpCode; 

    typedef enum logic[5:0] {
        FN_JR = 6'b001000,
        FN_JALR = 6'b001001,
        FN_ADDU = 6'b100001
    } typeFnCode;

    typedef enum logic[3:0] {
    	ALU_ADD = 4'b0100,
    	ALU_DEFAULT = 4'b1111
    } typeALUOp;

    typedef enum logic[2:0] {
       	S_FETCH = 3'b000,
        S_DECODE = 3'b001,
        S_EXECUTE = 3'b010,
        S_MEMORY = 3'b011,
        S_WRITEBACK = 3'b100,
        S_HALTED = 3'b111
    } typeState; //type declaration for the CPU states

         //normally progTemp = progCount + 4;
         //but when JR=1 progTemp = value of register A;

         //progCount <-- progTemp
        //5 cycle CPU: Fetch, Decode, Execute,Memory,W.B
        //CPU has 6 states, 5 cycles + HALT

    always @(posedge clk) begin
        if (reset == 1) begin
            progCount <=32'hBFC00000;
            progTemp <= 32'd0;
            registerHi <= 0;
            registerHi <= 0;
            branch <= 0;
            registerDataIn <= 0; //don't know if this is necessary but might as well right
            //other things as well
        end
        else if(state == S_FETCH) begin
        	$display("---FETCH---");
        	if(address == 32'h00000000) begin
        		active <= 0;
        		state <= S_HALTED;
        	end
        	else if(waitrequest) begin
        	end//if waitrequest = 1, keep waiting
        	else begin
        		state <= S_DECODE;
        	end
        	registerWriteEnable <= 0; //make sure register isn't writing (W.B sets it to 1)
        end
        else if(state == S_DECODE) begin
            $display("---DECODE---");
        	instruction <=readdata; //avalon output = our instruction
        	registerAddressA <= instructionSource1;
        	registerAddressB <= instructionSource2;

            AluControl <= (instructionOpcode == OP_ADDIU  || instructionOpcode == OP_LW)    ? ALU_ADD :
            		      (instructionOpcode == OP_R_TYPE || instructionOpcode == FN_ADDU) ? ALU_ADD : ALU_DEFAULT;

            /*-------------------------------*/
            //JALR
             //change
            //data --> comb logic --> decoded stuff
            //honestly, if it's comb logic, we can just put the decoder on this sheet
            //ALU control gets set in this cycle
            //sets to 1111 (default) when ALU is not used
            state <= S_EXECUTE;
        end
        else if(state == S_EXECUTE) begin

        	if(instructionOpcode == OP_R_TYPE) begin
        		AluA <= registerReadA;
        		AluB <=registerReadB;
        		shiftAmount <= instructionShift;
        	end
        	else begin
        		AluA <= registerReadA;
        		AluB <= {{16{instructionImmediateI[15]}} , instructionImmediateI};
        		shiftAmount <= 0;
        	end


            /*---Jump instruction control signals--- */
            if(instructionOpcode == OP_R_TYPE) begin
                if(instructionFnCode == FN_JR || instructionFnCode == FN_JALR) begin
                    branch = 1;
                    progTemp <=registerReadA;
                end
            end

            if(instructionOpcode == OP_J || instructionOpcode == OP_JAL) begin
                branch <= 1;
                progTemp <= {progNext[31:28],instructionAddressJ << 2};
            end
            /*-----------------------------------*/

            //JALR

            //ALU
            //Jumps will occur here (J,JAL,JR,JAlR)
            //moves --> Memory
        end
        else if(state == S_MEMORY) begin
        	//some logic to check if execute is done for multicycle executes (don't know what tho)
        	if (waitrequest == 1) begin
        	end
        	

        	//make sure avalon is avaliable before starting
        	//write is already taken care of in the comb logic written above I think?
            //(maybe additonal criteria for pauses but not sure yet)
            //branches will occur here I think?(BNE,BGTZ,BLEZ)
            //moves --> WriteBack
        end
        else if(state == S_WRITEBACK) begin

        	registerWriteEnable <= (instructionOpcode == OP_R_TYPE && (instructionFnCode == FN_ADDU || instructionFnCode == FN_JALR
        																						    || (0))//placeholder
        						    || instructionOpcode == OP_JAL
        						    || instructionOpcode == OP_ADDIU
        						    || instructionOpcode == OP_LW
        							|| (0)); //placeholder

        	registerWriteAddress <= (instructionOpcode == OP_JAL)    ? 5'd31 :
        							(instructionOpcode == OP_R_TYPE) ? instructionDest: instructionSource2;

        	
            registerDataIn <= (instructionOpcode == OP_JAL)                                      ? progCount + 8:
                              (instructionOpcode == OP_R_TYPE && instructionFnCode == FN_JALR) ? progCount + 8: AluOut;
    		
            //write to registers
            //mthi and mtlo also happens here
            //PC updates here depending on normal,jump or branch
            state <= S_FETCH;

        	/*---ProgramCounter stuff---*/
        	if(branch == 1) begin
        		branch <= 2;
            	progCount <= progNext;
        	end
        	else if(branch == 2) begin
        		branch <= 0;
        		progCount <= progTemp;
        	end
        	else begin
        		branch <= 0; //just to be sure lol
            	progCount <= progNext;
        	end
        	/*---*/
    	end

    	else if(state == S_HALTED) begin
        	$display("Halted kekw");
        end
    end
endmodule : mips_cpu_bus


        //32'hBFC00000 is progCount on reset
        //32'h00000000 should cause a halt


//IR register on CPU sheet
//PC register on CPU sheet
//Get avalon working

//depending on R,I,J, split up instr:
/*
R:opcode[31:26]|source1[25:21]|source2[20:16]|Dest.[15:11]|Shift amt[10:6]|Fn code[5:0] => 0
I:opcode[31:26]|source1[25:21]|source2/Dest.[20:16]|Address/Data[15:0] => else:
J:opcode[31:26]|Address[25:0] => 2,3
*/



/*
32 registers within CPU
2 (hi,lo) registers within ALU 
1 PC register?
Do JR, ADDU, ADDIU, LW, SW first
max CPI of 36

/rtl/mips_cpu_bus.v
*/
// /rtl/mips_cpu/*.v
/*
/test/test_mips_cpu_bus.sh
/docs/mips_data_sheet.pdf:
        Overall architecture,
        >=1 diagram,
        Design decisions,
        Approach in testing,
        >=1 diagram/flowchart descibing testing,
        MU0 area+timing summary
*/