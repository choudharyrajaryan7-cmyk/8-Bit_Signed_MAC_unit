`timescale 1ns / 1ps
// =============================================================================
// mac_tb.v : one self-checking testbench for the whole design
//   Part 1 - mac_core directly (directed + 200 random accumulations)
//   Part 2 - mac_board_top driven with switches/buttons like a person would
// Set  mac_tb  as the simulation top.  Prints "ALL PASS" when everything matches.
// iverilog: iverilog -g2012 -o sim mac_tb.v mac_design.v && vvp sim
// =============================================================================
module mac_tb;
    localparam IB = 8, FB = 8, N = IB + FB;
    localparam integer MAXI =  (1 << (N-1)) - 1;
    localparam integer MINI = -(1 << (N-1));

    reg clk = 0;
    always #5 clk = ~clk;                        // 100 MHz

    integer fails = 0, k;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, mac_tb);
    end

    // ------------------------------------------------------------------ DUT 1
    reg          rst = 0, clr = 0, ld_a = 0, ld_b = 0, acc_en = 0;
    reg  [N-1:0] a_in = 0, b_in = 0;
    wire [N-1:0] a_q, b_q, o;
    wire         ovf;
    reg signed [63:0] total, expv;

    mac_core #(.IB(IB), .FB(FB), .ROUND(0), .SAT(1)) dut_core (
        .clk(clk), .rst(rst), .clr(clr), .ld_a(ld_a), .ld_b(ld_b), .acc_en(acc_en),
        .a_in(a_in), .b_in(b_in), .a_q(a_q), .b_q(b_q), .o(o), .ovf(ovf));

    // ------------------------------------------------------------------ DUT 2
    reg         CPU_RESETN = 1, BTNC = 0, BTNL = 0, BTNR = 0, BTNU = 0;
    reg  [15:0] SW = 0;
    wire [15:0] LED;
    wire [7:0]  SEG, AN;

    mac_board_top #(.DB_CYCLES(4)) dut_top (      // short debounce for simulation
        .CLK100MHZ(clk), .CPU_RESETN(CPU_RESETN),
        .BTNC(BTNC), .BTNL(BTNL), .BTNR(BTNR), .BTNU(BTNU),
        .SW(SW), .LED(LED), .SEG(SEG), .AN(AN));

    // ------------------------------------------------------------ helpers
    function [N-1:0] q(input real x);            // real -> Q8.8 word
        q = $rtoi(x * (1 << FB));
    endfunction
    function real r(input [N-1:0] w);            // Q8.8 word -> real
        r = $itor($signed(w)) / (1 << FB);
    endfunction

    task do_reset;
        begin
            @(negedge clk); rst = 1;
            repeat (2) @(negedge clk);
            rst = 0;
            repeat (3) @(negedge clk);
            total = 0;
        end
    endtask

    // load -> multiply -> accumulate -> output register
    task step(input [N-1:0] a, input [N-1:0] b);
        begin
            @(negedge clk); a_in = a; b_in = b; ld_a = 1; ld_b = 1;
            @(negedge clk); ld_a = 0; ld_b = 0;
            repeat (2) @(negedge clk);           // operand regs -> product reg
            acc_en = 1;
            @(negedge clk); acc_en = 0;
            repeat (2) @(negedge clk);           // accumulator -> output reg
            total = total + $signed(a) * $signed(b);
        end
    endtask

    task mac(input real a, input real b);
        begin step(q(a), q(b)); end
    endtask

    task check(input [255:0] name, input real expected);
        begin
            if (r(o) == expected) $display("PASS  %0s : %f", name, r(o));
            else begin
                $display("FAIL  %0s : got %f expected %f", name, r(o), expected);
                fails = fails + 1;
            end
        end
    endtask

    task idle(input integer n); begin repeat (n) @(posedge clk); end endtask
    task tapL; begin BTNL = 1; idle(20); BTNL = 0; idle(20); end endtask
    task tapR; begin BTNR = 1; idle(20); BTNR = 0; idle(20); end endtask
    task tapC; begin BTNC = 1; idle(20); BTNC = 0; idle(20); end endtask
    task tapU; begin BTNU = 1; idle(20); BTNU = 0; idle(20); end endtask

    task expect_led(input [255:0] name, input [15:0] expected);
        begin
            if (LED === expected) $display("PASS  %0s : LED=%h", name, LED);
            else begin
                $display("FAIL  %0s : LED=%h expected %h", name, LED, expected);
                fails = fails + 1;
            end
        end
    endtask

    // ------------------------------------------------------------ tests
    initial begin
        $display("---- Part 1: mac_core ----");
        do_reset;
        mac(12, -5);                 check("int x int       12 * -5",   -60.0);
        do_reset; mac(5, 2.5);       check("int x decimal    5 * 2.5",   12.5);
        do_reset; mac(1.5, 2.0);     check("decimal x dec  1.5 * 2.0",    3.0);
        do_reset; mac(-0.5, -0.5);   check("fraction     -0.5 * -0.5",   0.25);
        do_reset; mac(100, 0.75);    check("scale int     100 * 0.75",   75.0);
        do_reset; mac(-3.25, 4);     check("neg decimal -3.25 * 4",     -13.0);

        do_reset; mac(2, 3); mac(1.5, 1.0); mac(-0.25, 2);
        check("accumulate 6 + 1.5 - 0.5", 7.0);

        @(negedge clk); clr = 1; @(negedge clk); clr = 0; repeat (3) @(negedge clk);
        check("clr -> 0", 0.0);

        do_reset; mac(100, 100);
        if (ovf && o == 16'h7FFF) $display("PASS  positive overflow -> saturated, OVF=1");
        else begin $display("FAIL  positive overflow"); fails = fails + 1; end

        do_reset; mac(-100, 100);
        if (ovf && o == 16'h8000) $display("PASS  negative overflow -> saturated, OVF=1");
        else begin $display("FAIL  negative overflow"); fails = fails + 1; end

        do_reset;
        for (k = 0; k < 200; k = k + 1) begin
            step($random, $random);
            expv = total >>> FB;
            if (expv > MAXI) expv = MAXI;
            if (expv < MINI) expv = MINI;
            if ($signed(o) !== expv[N-1:0]) begin
                fails = fails + 1;
                $display("FAIL random step %0d : got %0d expected %0d", k, $signed(o), expv);
            end
            if (k % 8 == 7) do_reset;
        end
        $display("random: 200 accumulations checked");

        $display("---- Part 2: mac_board_top (switches / buttons) ----");
        idle(10);
        CPU_RESETN = 0; idle(20); CPU_RESETN = 1; idle(20);
        expect_led("after reset", 16'h0000);

        SW = 16'h0300; tapL;                     // A = 3.0
        SW = 16'h0180; tapR;                     // B = 1.5
        tapC; expect_led("3.0*1.5 = 4.5",          16'h0480);
        tapC; expect_led("accumulate again = 9.0", 16'h0900);
        tapU; expect_led("BTNU clears",            16'h0000);

        SW = 16'hFE00; tapL;                     // A = -2.0
        SW = 16'h0180; tapR;                     // B = 1.5
        tapC; expect_led("-2.0*1.5 = -3.0",        16'hFD00);

        tapU;
        SW = 16'h6400; tapL; tapR;               // 100.0 * 100.0 -> saturate
        tapC; expect_led("saturate",               16'h7FFF);

        CPU_RESETN = 0; idle(20); CPU_RESETN = 1; idle(20);
        expect_led("global reset", 16'h0000);

        $display("=========================================");
        if (fails == 0) $display("ALL PASS"); else $display("%0d FAIL(S)", fails);
        $display("=========================================");
        $finish;
    end
endmodule
