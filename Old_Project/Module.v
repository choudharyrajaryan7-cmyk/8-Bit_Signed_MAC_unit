module mactop (O, A, B, CLK1, CLK2, RESET);
    input  [7:0] A;
    input  [7:0] B;
    output [7:0] O;
    input  CLK1, CLK2, RESET;

    wire [7:0] P, Q, R, S;

    reg8         reg1   (A, CLK1, P);      
    reg8         reg2   (B, CLK1, Q);
    mult         mult1  (P, Q, R);       
    signedadder  adder1 (R, O, S);          
    reg8bit      reg3   (S, CLK2, RESET, O);
endmodule

module reg8 (
    input  [7:0] D,
    input        clk,
    output reg [7:0] Q
);
    always @(posedge clk)
        Q <= D;
endmodule

module mult (a, b, out);
    input  signed [7:0] a, b;
    output signed [7:0] out;
    wire          [15:0] tempout;

    assign tempout = a * b;         
    assign out     = tempout[14:7];
endmodule

module signedadder (a, b, sum);
    input  signed [7:0] a, b;
    output        [7:0] sum;

    assign sum = a + b;
endmodule

module reg8bit (
    input      [7:0] D,
    input            clk,
    input            reset,
    output reg [7:0] Q
);
    always @(posedge clk or posedge reset)
        if (reset) Q <= 8'd0;
        else       Q <= D;
endmodule