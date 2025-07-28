//============================
// pipe_MIPS32.v (Improved)
//============================
`timescale 1ns / 1ps

module pipeMIPS32 (clk1, clk2);

input clk1, clk2; // Two-phase clock

// Pipeline registers
reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type;
reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
reg EX_MEM_cond;
reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;

// Memory and registers
reg [31:0] Reg [0:31];
reg [31:0] Mem [0:1023]; // Combined instruction/data memory
parameter NOP = 32'h00000000;

// Operation codes
parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, 
          OR=6'b000011, SLT=6'b000100, MUL=6'b000101, 
          HLT=6'b111111, SW=6'b001000, LW=6'b001001, 
          BNEQZ=6'b001011, BEQZ=6'b001100,
          ADDI=6'b001010, SUBI=6'b001101, SLTI=6'b001110;

// Instruction types
parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011,
          BRANCH = 3'b100, HALT = 3'b101;

// Control signals
reg HALTED;
reg TAKEN_BRANCH;
wire STALL;

// Forwarding signals
wire [1:0] ForwardA, ForwardB;
wire [31:0] MEM_WB_Result;
wire [4:0] EX_MEM_rd, MEM_WB_rd;

// Forwarded operands
wire [31:0] operand_A, operand_B;

//=== New Forwarding Logic ===//
assign MEM_WB_Result = (MEM_WB_type == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOut;

assign EX_MEM_rd = (EX_MEM_type == RR_ALU) ? EX_MEM_IR[15:11] :
                   ((EX_MEM_type == RM_ALU || EX_MEM_type == LOAD) ? 
                   EX_MEM_IR[20:16] : 0);

assign MEM_WB_rd = (MEM_WB_type == RR_ALU) ? MEM_WB_IR[15:11] :
                   ((MEM_WB_type == RM_ALU || MEM_WB_type == LOAD) ? 
                   MEM_WB_IR[20:16] : 0);

assign ForwardA = (EX_MEM_rd != 0 && EX_MEM_rd == ID_EX_IR[25:21] && 
                  (EX_MEM_type == RR_ALU || EX_MEM_type == RM_ALU)) ? 2'b10 :
                 (MEM_WB_rd != 0 && MEM_WB_rd == ID_EX_IR[25:21] && 
                  (MEM_WB_type == RR_ALU || MEM_WB_type == RM_ALU || 
                   MEM_WB_type == LOAD)) ? 2'b01 : 2'b00;

assign ForwardB = (EX_MEM_rd != 0 && EX_MEM_rd == ID_EX_IR[20:16] && 
                  (EX_MEM_type == RR_ALU || EX_MEM_type == RM_ALU)) ? 2'b10 :
                 (MEM_WB_rd != 0 && MEM_WB_rd == ID_EX_IR[20:16] && 
                  (MEM_WB_type == RR_ALU || MEM_WB_type == RM_ALU || 
                   MEM_WB_type == LOAD)) ? 2'b01 : 2'b00;

assign operand_A = (ForwardA == 2'b10) ? EX_MEM_ALUOut :
                  (ForwardA == 2'b01) ? MEM_WB_Result : ID_EX_A;
                  
assign operand_B = (ForwardB == 2'b10) ? EX_MEM_ALUOut :
                  (ForwardB == 2'b01) ? MEM_WB_Result : ID_EX_B;

//=== Hazard Detection ===//
wire id_uses_rs, id_uses_rt;
wire [2:0] id_type_comb;

// Combinational instruction typing for ID stage
assign id_type_comb = 
    (IF_ID_IR[31:26] == ADD || IF_ID_IR[31:26] == SUB || 
     IF_ID_IR[31:26] == AND || IF_ID_IR[31:26] == OR || 
     IF_ID_IR[31:26] == SLT || IF_ID_IR[31:26] == MUL) ? RR_ALU :
    (IF_ID_IR[31:26] == ADDI || IF_ID_IR[31:26] == SUBI || 
     IF_ID_IR[31:26] == SLTI) ? RM_ALU :
    (IF_ID_IR[31:26] == LW) ? LOAD :
    (IF_ID_IR[31:26] == SW) ? STORE :
    (IF_ID_IR[31:26] == BNEQZ || IF_ID_IR[31:26] == BEQZ) ? BRANCH :
    (IF_ID_IR[31:26] == HLT) ? HALT : HALT;

assign id_uses_rs = (id_type_comb == RR_ALU) || (id_type_comb == RM_ALU) || 
                    (id_type_comb == LOAD) || (id_type_comb == STORE) || 
                    (id_type_comb == BRANCH);
                    
assign id_uses_rt = (id_type_comb == RR_ALU) || (id_type_comb == STORE);

assign STALL = (ID_EX_type == LOAD) && (ID_EX_IR[20:16] != 0) 
      && ((id_uses_rs && IF_ID_IR[25:21]==ID_EX_IR[20:16])
       || (id_uses_rt && IF_ID_IR[20:16]==ID_EX_IR[20:16]));

//=== Pipeline Stages ===//
// IF Stage
//initial begin
//  PC           = 0;
//  HALTED       = 0;
//  TAKEN_BRANCH = 0;
//  STALL        = 0;
//  // Zero out Reg file and all pipeline regs if you like:
//  // for (i=0; i<32; i=i+1) Reg[i]=0;
//  // IF_ID_IR = ID_EX_IR = EX_MEM_IR = MEM_WB_IR = NOP;
//end

always @(posedge clk1) begin
    if (!HALTED && !STALL) begin
        if (((EX_MEM_IR[31:26] == BEQZ) && EX_MEM_cond) ||
            ((EX_MEM_IR[31:26] == BNEQZ) && !EX_MEM_cond)) begin
            IF_ID_IR <= #2 Mem[EX_MEM_ALUOut];
            IF_ID_NPC <= #2 EX_MEM_ALUOut + 1;
            PC <= #2 EX_MEM_ALUOut + 1;
            TAKEN_BRANCH <= #2 1;
        end else begin
            IF_ID_IR <= #2 Mem[PC];
            IF_ID_NPC <= #2 PC + 1;
            PC <= #2 PC + 1;
            TAKEN_BRANCH <= #2 0;
        end
    end
end

// ID Stage
always @(posedge clk2) begin
    if (!HALTED) begin
        if (STALL) begin
            // Inject NOP on stall
            ID_EX_IR <= #2 NOP;
            ID_EX_type <= #2 HALT;
        end 
        else if (TAKEN_BRANCH) begin
            // Flush on taken branch
            ID_EX_IR <= #2 NOP;
            ID_EX_type <= #2 HALT;
        end 
        else begin
            ID_EX_A <= #2 (IF_ID_IR[25:21] == 0) ? 0 : Reg[IF_ID_IR[25:21]];
            ID_EX_B <= #2 (IF_ID_IR[20:16] == 0) ? 0 : Reg[IF_ID_IR[20:16]];
            ID_EX_NPC <= #2 IF_ID_NPC;
            ID_EX_IR <= #2 IF_ID_IR;
            ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
            
            case (IF_ID_IR[31:26])
                ADD, SUB, AND, OR, SLT, MUL:    ID_EX_type <= #2 RR_ALU;
                ADDI, SUBI, SLTI:               ID_EX_type <= #2 RM_ALU;
                LW:                             ID_EX_type <= #2 LOAD;
                SW:                             ID_EX_type <= #2 STORE;
                BNEQZ, BEQZ:                    ID_EX_type <= #2 BRANCH;
                HLT:                            ID_EX_type <= #2 HALT;
                default:                        ID_EX_type <= #2 HALT;
            endcase
        end
    end
end

// EX Stage (uses forwarded operands)
always @(posedge clk1) begin
    if (!HALTED) begin
        EX_MEM_type <= #2 ID_EX_type;
        EX_MEM_IR <= #2 ID_EX_IR;
        case (ID_EX_type)
            RR_ALU: begin
                case (ID_EX_IR[31:26])
                    ADD: EX_MEM_ALUOut <= #2 operand_A + operand_B;
                    SUB: EX_MEM_ALUOut <= #2 operand_A - operand_B;
                    AND: EX_MEM_ALUOut <= #2 operand_A & operand_B;
                    OR:  EX_MEM_ALUOut <= #2 operand_A | operand_B;
                    SLT: EX_MEM_ALUOut <= #2 (operand_A < operand_B);
                    MUL: EX_MEM_ALUOut <= #2 operand_A * operand_B;
                    default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end
            RM_ALU: begin
                case (ID_EX_IR[31:26])
                    ADDI: EX_MEM_ALUOut <= #2 operand_A + ID_EX_Imm;
                    SUBI: EX_MEM_ALUOut <= #2 operand_A - ID_EX_Imm;
                    SLTI: EX_MEM_ALUOut <= #2 (operand_A < ID_EX_Imm);
                    default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end
            LOAD, STORE: begin
                EX_MEM_ALUOut <= #2 operand_A + ID_EX_Imm;
                EX_MEM_B <= #2 operand_B;  // Forwarded store data
            end
            BRANCH: begin
                EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm;
                EX_MEM_cond <= #2 (operand_A == 0);  // Forwarded branch condition
            end
        endcase
    end
end

// MEM Stage
always @(posedge clk2) begin
    if (!HALTED) begin
        MEM_WB_type <= EX_MEM_type;
        MEM_WB_IR <= #2 EX_MEM_IR;
        case (EX_MEM_type)
            RR_ALU, RM_ALU:
                MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
            LOAD: 
                MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];
            STORE: 
                Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B;
        endcase
    end
end

// WB Stage
always @(posedge clk1) begin
    if (!HALTED && !TAKEN_BRANCH) begin
        case (MEM_WB_type)
            RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut;
            RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut;
            LOAD:   Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;
            HALT:   HALTED <= #2 1;
        endcase
    end
    TAKEN_BRANCH <= #2 0;
end

endmodule