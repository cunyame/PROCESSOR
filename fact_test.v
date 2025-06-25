`timescale 1ns / 1ps

module test_mips32;

    reg clk1, clk2;
    integer k;

    // Instantiate the processor
    pipe_MIPS32 mips(clk1, clk2);

    // Clock generation
    initial begin
        clk1 = 0; clk2 = 0;
        repeat (50) begin
            #5 clk1 = 1; #5 clk2 = 1;
            #5 clk1 = 0; #5 clk2 = 0;
        end
    end

    // Initialize memory and registers
    initial begin
        for (k = 0; k < 31; k = k + 1)
            mips.Reg[k] = k;

        mips.Mem[0]  = 32'h280a00c8;  // ADDI  R10,R0,200
        mips.Mem[1]  = 32'h28020001;  // ADDI  R2,R0,1
        mips.Mem[2]  = 32'h0e94a000;  // OR    R20,R20,R20 -- dummy
        mips.Mem[3]  = 32'h21430000;  // LW    R3,0(R10)
        mips.Mem[4]  = 32'h0e94a000;  // OR    R20,R20,R20 -- dummy
        mips.Mem[5]  = 32'h14431000;  // Loop: MUL  R2,R2,R3
        mips.Mem[6]  = 32'h2c630001;  // SUBI  R3,R3,1
        mips.Mem[7]  = 32'h0e94a000;  // OR    R20,R20,R20 -- dummy
        mips.Mem[8]  = 32'h3460fffc;  // BNEQZ R3,Loop
        mips.Mem[9]  = 32'h2542fffe;  // SW    R2,-2(R10)
        mips.Mem[10] = 32'hfc000000;  // HLT
        mips.Mem[200] = 7;

        mips.PC = 0;
        mips.HALTED = 0;
        mips.TAKEN_BRANCH = 0;

        #3000;
        $display("==============================================");
        $display("Input  : %d", mips.Mem[200]);
        $display("Output : %d", mips.Mem[198]); // Should print 5040
        $display("==============================================");
    end

    // Dump waveform and monitor values
    initial begin
        $dumpfile("mips.vcd");
        $dumpvars(0, test_mips32);
        $dumpvars(1, mips); // Dump internal state
        $monitor("Time=%0t | R2=%d | R3=%d | R10=%d | Mem[200]=%d | Mem[198]=%d | HALTED=%b", 
            $time, mips.Reg[2], mips.Reg[3], mips.Reg[10], mips.Mem[200], mips.Mem[198], mips.HALTED);
        #10000 $finish;
    end

endmodule
