`timescale 1ns / 1ps
// ==============================================================================
// mac_design.v : all RTL in one file  (compile order does not matter)
//   mac_board_top  - top module for Nexys A7-100T
//   mac_core       - Q8.8 pipelined signed MAC
//   btn_cond       - synchroniser + debouncer + edge pulse
//   seg7_mux       - 8-digit hex display driver
// ==============================================================================

//-----------------------------------------------------------------------------
// mac_board_top : Nexys A7-100T (XC7A100T-1CSG324C) demo of the Q8.8 MAC
//
//   SW[15:0]    operand value, Q8.8 two's complement (signed 16-bit)
//   BTNL        load operand A from SW
//   BTNR        load operand B from SW
//   BTNC        accumulate:  ACC <= ACC + A*B
//   BTNU        clear accumulator
//   CPU_RESETN  global reset (red button, active low)
//   LED[15:0]   accumulator result, Q8.8, saturated
//   7-seg       {A[15:0], B[15:0]} in hex (A = left four digits, B = right four)
//               decimal points light when the result is saturated (overflow)
//
// One 100 MHz clock only; every button is synchronised, debounced and turned
// into a one-cycle enable, so no button is ever used as a clock.
//-----------------------------------------------------------------------------
module mac_board_top #(
    parameter DB_CYCLES = 1_000_000          // 10 ms debounce @ 100 MHz
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

    // ---- buttons -----------------------------------------------------------
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

    // ---- switch synchroniser ---------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_s0 = 16'd0;
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_s1 = 16'd0;
    always @(posedge CLK100MHZ) begin
        sw_s0 <= SW;
        sw_s1 <= sw_s0;
    end

    // ---- MAC ---------------------------------------------------------------------
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

    // ---- display -------------------------------------------------------------------
    seg7_mux u_seg (
        .clk  (CLK100MHZ),
        .value({a_q, b_q}),
        .dp   (ovf),
        .seg  (SEG),
        .an   (AN)
    );

endmodule

//-----------------------------------------------------------------------------
// mac_core : parameterised signed fixed-point (Qib.fb) multiply-accumulate
//
//   stage 0 : operand registers a_r / b_r   (loaded by ld_a / ld_b strobes)
//   stage 1 : product register  prod_r      (free running, maps to DSP48E1 MREG)
//   stage 2 : accumulator       acc         (updates on acc_en strobe)
//   stage 3 : output register   o / ovf     (round + saturate, registered)
//
// Single clock domain: no manual clocks, no CDC, no CLOCK_DEDICATED_ROUTE hack.
// Synchronous reset only (maps onto FDRE / DSP48 RST pins, no async-reset
// timing exceptions).
//
// Latency (clk cycles):  ld_a/ld_b -> prod_r : 2   |  acc_en -> o : 2
// => issue acc_en at least 2 cycles after the last ld_*.
//
// Guard bits: W = 2N+8 leaves 8 guard bits, i.e. up to 256 worst-case products
// can be accumulated before the internal accumulator itself can wrap.
//-----------------------------------------------------------------------------
module mac_core #(
    parameter IB    = 8,            // integer bits (incl. sign)
    parameter FB    = 8,            // fraction bits (must be >= 1 when ROUND=1)
    parameter ROUND = 0,            // 1 = round-to-nearest, 0 = floor
    parameter SAT   = 1,            // 1 = saturate output, 0 = wrap
    parameter N     = IB + FB,      // operand / output width
    parameter W     = 2*N + 8       // accumulator width
)(
    input  wire                 clk,
    input  wire                 rst,      // sync, clears operands + accumulator
    input  wire                 clr,      // sync, clears accumulator only
    input  wire                 ld_a,     // latch a_in
    input  wire                 ld_b,     // latch b_in
    input  wire                 acc_en,   // acc <= acc + a_r*b_r
    input  wire signed [N-1:0]  a_in,
    input  wire signed [N-1:0]  b_in,
    output wire signed [N-1:0]  a_q,      // latched operands (for display)
    output wire signed [N-1:0]  b_q,
    output wire signed [N-1:0]  o,        // accumulator, Q(IB.FB), rounded/saturated
    output wire                 ovf       // 1 when o is clamped / wrapped
);

    // power-up values (FPGA INIT) so the design is deterministic without reset
    reg signed [N-1:0]   a_r    = {N{1'b0}};
    reg signed [N-1:0]   b_r    = {N{1'b0}};
    reg signed [2*N-1:0] prod_r = {(2*N){1'b0}};
    reg signed [W-1:0]   acc    = {W{1'b0}};
    reg signed [N-1:0]   o_r    = {N{1'b0}};
    reg                  ovf_r  = 1'b0;

    // ---- stage 0 : operand registers -------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            a_r <= {N{1'b0}};
            b_r <= {N{1'b0}};
        end else begin
            if (ld_a) a_r <= a_in;
            if (ld_b) b_r <= b_in;
        end
    end

    // ---- stage 1 : product register (DSP48E1 multiplier + MREG) ------------
    always @(posedge clk)
        prod_r <= a_r * b_r;

    // ---- stage 2 : accumulator --------------------------------------------
    always @(posedge clk) begin
        if (rst | clr)   acc <= {W{1'b0}};
        else if (acc_en) acc <= acc + prod_r;      // signed + signed: sign-extends
    end

    // ---- stage 3 : drop FB fraction bits, round, saturate -----------------
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

//-----------------------------------------------------------------------------
// btn_cond : 2-FF synchroniser + counter debouncer + one-clock rising-edge pulse
//   level : debounced, synchronous version of the input (1 = "pressed")
//   pulse : single clk-wide pulse when level goes 0 -> 1
// ACTIVE_LOW = 1 for inputs that idle high (e.g. CPU_RESETN).
// DB_CYCLES  : stable time required, in clk cycles (1_000_000 @100 MHz = 10 ms)
//-----------------------------------------------------------------------------
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

//-----------------------------------------------------------------------------
// seg7_mux : 8-digit multiplexed hex display driver (Nexys A7, common anode)
//   value : 32-bit word, digit 0 (AN0, rightmost) = value[3:0]
//   dp    : 1 = light the decimal point on every digit
//   seg   : {dp, g,f,e,d,c,b,a}, active low      an : active low
// Refresh ~ 763 Hz frame rate @100 MHz. Outputs are registered.
//-----------------------------------------------------------------------------
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
