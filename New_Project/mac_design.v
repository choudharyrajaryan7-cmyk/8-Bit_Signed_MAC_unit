`timescale 1ns / 1ps

module mac_board_top #(
    parameter DB_CYCLES = 1_000_000      
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNL,
    input  wire        BTNR,
    input  wire        BTNU,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire [7:0]  SEG,
    output wire [7:0]  AN
);

    wire rst_lvl, ld_a_p, ld_b_p, acc_p, clr_p;
    wire unused_rst_pulse, unused_l_lvl, unused_r_lvl, unused_c_lvl, unused_u_lvl;

    btn_cond #(.DB_CYCLES(DB_CYCLES), .ACTIVE_LOW(1))
        u_rst (.clk(CLK100MHZ), .din(CPU_RESETN), .level(rst_lvl),      .pulse(unused_rst_pulse));
    btn_cond #(.DB_CYCLES(DB_CYCLES), .ACTIVE_LOW(0))
        u_bl  (.clk(CLK100MHZ), .din(BTNL),       .level(unused_l_lvl), .pulse(ld_a_p));
    btn_cond #(.DB_CYCLES(DB_CYCLES), .ACTIVE_LOW(0))
        u_br  (.clk(CLK100MHZ), .din(BTNR),       .level(unused_r_lvl), .pulse(ld_b_p));
    btn_cond #(.DB_CYCLES(DB_CYCLES), .ACTIVE_LOW(0))
        u_bc  (.clk(CLK100MHZ), .din(BTNC),       .level(unused_c_lvl), .pulse(acc_p));
    btn_cond #(.DB_CYCLES(DB_CYCLES), .ACTIVE_LOW(0))
        u_bu  (.clk(CLK100MHZ), .din(BTNU),       .level(unused_u_lvl), .pulse(clr_p));

   
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_s0 = 16'd0;
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_s1 = 16'd0;
    always @(posedge CLK100MHZ) begin
        sw_s0 <= SW;
        sw_s1 <= sw_s0;
    end

    wire [15:0] a_q, b_q, o;
    wire        ovf;

    mac_core #(.IB(8), .FB(8), .ROUND(0), .SAT(1)) u_mac (
        .clk   (CLK100MHZ),
        .rst   (rst_lvl),
        .clr   (clr_p),
        .ld_a  (ld_a_p),
        .ld_b  (ld_b_p),
        .acc_en(acc_p),
        .a_in  (sw_s1),
        .b_in  (sw_s1),
        .a_q   (a_q),
        .b_q   (b_q),
        .o     (o),
        .ovf   (ovf)
    );

    assign LED = o;


    seg7_mux u_seg (
        .clk  (CLK100MHZ),
        .value({a_q, b_q}),
        .dp   (ovf),
        .seg  (SEG),
        .an   (AN)
    );

endmodule


module mac_core #(
    parameter IB    = 8,            
    parameter FB    = 8,            
    parameter ROUND = 0,          
    parameter SAT   = 1,            
    parameter N     = IB + FB,     
    parameter W     = 2*N + 8       
)(
    input  wire                 clk,
    input  wire                 rst,      
    input  wire                 clr,      
    input  wire                 ld_a,     
    input  wire                 ld_b,     
    input  wire                 acc_en, 
    input  wire signed [N-1:0]  a_in,
    input  wire signed [N-1:0]  b_in,
    output wire signed [N-1:0]  a_q,      
    output wire signed [N-1:0]  b_q,
    output wire signed [N-1:0]  o,      
    output wire                 ovf       
);

  
    reg signed [N-1:0]   a_r    = {N{1'b0}};
    reg signed [N-1:0]   b_r    = {N{1'b0}};
    reg signed [2*N-1:0] prod_r = {(2*N){1'b0}};
    reg signed [W-1:0]   acc    = {W{1'b0}};
    reg signed [N-1:0]   o_r    = {N{1'b0}};
    reg                  ovf_r  = 1'b0;

  
    always @(posedge clk) begin
        if (rst) begin
            a_r <= {N{1'b0}};
            b_r <= {N{1'b0}};
        end else begin
            if (ld_a) a_r <= a_in;
            if (ld_b) b_r <= b_in;
        end
    end

  
    always @(posedge clk)
        prod_r <= a_r * b_r;

    
    always @(posedge clk) begin
        if (rst | clr)   acc <= {W{1'b0}};
        else if (acc_en) acc <= acc + prod_r;     
    end

  
    localparam signed [W-1:0] MAXV = ({{(W-1){1'b0}}, 1'b1} << (N-1)) - 1;
    localparam signed [W-1:0] MINV = -MAXV - 1;
    localparam signed [N-1:0] MAXN = {1'b0, {(N-1){1'b1}}};
    localparam signed [N-1:0] MINN = {1'b1, {(N-1){1'b0}}};
    localparam signed [W-1:0] HALF = (ROUND != 0) ? ({{(W-1){1'b0}}, 1'b1} << (FB-1))
                                                  : {W{1'b0}};

    wire signed [W-1:0] r  = (acc + HALF) >>> FB;
    wire                hi = (r > MAXV);
    wire                lo = (r < MINV);

    always @(posedge clk) begin
        ovf_r <= hi | lo;
        if (SAT != 0) o_r <= hi ? MAXN : (lo ? MINN : r[N-1:0]);
        else          o_r <= r[N-1:0];
    end

    assign a_q = a_r;
    assign b_q = b_r;
    assign o   = o_r;
    assign ovf = ovf_r;

endmodule

module btn_cond #(
    parameter DB_CYCLES  = 1_000_000,
    parameter ACTIVE_LOW = 0
)(
    input  wire clk,
    input  wire din,
    output wire level,
    output wire pulse
);
    localparam CW = $clog2(DB_CYCLES + 1);
    localparam [CW-1:0] LIM = DB_CYCLES - 1;

    (* ASYNC_REG = "TRUE" *) reg s0 = ACTIVE_LOW;
    (* ASYNC_REG = "TRUE" *) reg s1 = ACTIVE_LOW;
    reg [CW-1:0] cnt     = {CW{1'b0}};
    reg          state   = 1'b0;
    reg          state_d = 1'b0;

    wire raw = s1 ^ ACTIVE_LOW;

    always @(posedge clk) begin
        s0 <= din;
        s1 <= s0;
        if (raw == state)      cnt <= {CW{1'b0}};
        else if (cnt == LIM) begin
            state <= raw;
            cnt   <= {CW{1'b0}};
        end else               cnt <= cnt + 1'b1;
        state_d <= state;
    end

    assign level = state;
    assign pulse = state & ~state_d;
endmodule

module seg7_mux (
    input  wire        clk,
    input  wire [31:0] value,
    input  wire        dp,
    output reg  [7:0]  seg = 8'hFF,
    output reg  [7:0]  an  = 8'hFF
);
    reg [16:0] rc = 17'd0;
    always @(posedge clk) rc <= rc + 1'b1;

    wire [2:0] sel = rc[16:14];
    reg  [3:0] nib;
    reg  [6:0] gfedcba;

    always @* begin
        case (sel)
            3'd0:    nib = value[3:0];
            3'd1:    nib = value[7:4];
            3'd2:    nib = value[11:8];
            3'd3:    nib = value[15:12];
            3'd4:    nib = value[19:16];
            3'd5:    nib = value[23:20];
            3'd6:    nib = value[27:24];
            default: nib = value[31:28];
        endcase
    end

    always @* begin
        case (nib)
            4'h0: gfedcba = 7'b1000000;
            4'h1: gfedcba = 7'b1111001;
            4'h2: gfedcba = 7'b0100100;
            4'h3: gfedcba = 7'b0110000;
            4'h4: gfedcba = 7'b0011001;
            4'h5: gfedcba = 7'b0010010;
            4'h6: gfedcba = 7'b0000010;
            4'h7: gfedcba = 7'b1111000;
            4'h8: gfedcba = 7'b0000000;
            4'h9: gfedcba = 7'b0010000;
            4'hA: gfedcba = 7'b0001000;
            4'hB: gfedcba = 7'b0000011;
            4'hC: gfedcba = 7'b1000110;
            4'hD: gfedcba = 7'b0100001;
            4'hE: gfedcba = 7'b0000110;
            default: gfedcba = 7'b0001110;
        endcase
    end

    always @(posedge clk) begin
        seg <= {~dp, gfedcba};
        an  <= ~(8'b0000_0001 << sel);
    end
endmodule
