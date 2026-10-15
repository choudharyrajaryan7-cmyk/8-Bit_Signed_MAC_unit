`timescale 1ns / 1ps

module multtop_tb();
    reg        CLK, RESET;
    reg  [7:0] A, B;
    wire [7:0] O;

    mactop dut (O, A, B, CLK, CLK, RESET);

    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, multtop_tb);
        $monitor("t=%0t  A=%h B=%h  O=%h", $time, A, B, O);
    end

    task check(input [7:0] expected);
        begin
            if (O === expected) $display("PASS: O = %h", O);
            else                $display("FAIL: O = %h, expected %h", O, expected);
        end
    endtask

    initial begin
        
        RESET = 1;
        A = 8'hC0; B = 8'hC0;     

        #8  RESET = 0;           
        #2  A = 8'hA0; B = 8'hA0;
        #6  check(8'h20);         
        #4  A = 8'hC0; B = 8'h20; 
        #6  check(8'h68);        
        #10 check(8'h58);         
        #4  $finish;
    end
endmodule