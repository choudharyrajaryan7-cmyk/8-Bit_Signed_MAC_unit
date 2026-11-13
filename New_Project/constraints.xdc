## =============================================================================
## Nexys A7-100T  (XC7A100T-1CSG324C)  --  constraints for mac_board_top
## Vivado 2020.x - 2024.x
## =============================================================================

## ----------------------------------------------------------------------------
## Configuration / DRC properties (removes CFGBVS-1, "unspecified config" warnings)
## ----------------------------------------------------------------------------
set_property CFGBVS VCCO                      [current_design]
set_property CONFIG_VOLTAGE 3.3               [current_design]
set_property CONFIG_MODE SPIx4                [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE  [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33   [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4  [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]

## ----------------------------------------------------------------------------
## 100 MHz system clock  (dedicated GCLK pin E3 -> no CLOCK_DEDICATED_ROUTE hack)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports CLK100MHZ]

## ----------------------------------------------------------------------------
## Slide switches  SW[0]..SW[15]
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports {SW[0]}]
set_property -dict { PACKAGE_PIN L16  IOSTANDARD LVCMOS33 } [get_ports {SW[1]}]
set_property -dict { PACKAGE_PIN M13  IOSTANDARD LVCMOS33 } [get_ports {SW[2]}]
set_property -dict { PACKAGE_PIN R15  IOSTANDARD LVCMOS33 } [get_ports {SW[3]}]
set_property -dict { PACKAGE_PIN R17  IOSTANDARD LVCMOS33 } [get_ports {SW[4]}]
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports {SW[5]}]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports {SW[6]}]
set_property -dict { PACKAGE_PIN R13  IOSTANDARD LVCMOS33 } [get_ports {SW[7]}]
## NOTE: SW[8] and SW[9] sit in bank 34 which is powered at 1.8 V on the Nexys A7
##       (per Digilent master XDC) -> LVCMOS18, not LVCMOS33.
set_property -dict { PACKAGE_PIN T8   IOSTANDARD LVCMOS18 } [get_ports {SW[8]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS18 } [get_ports {SW[9]}]
set_property -dict { PACKAGE_PIN R16  IOSTANDARD LVCMOS33 } [get_ports {SW[10]}]
set_property -dict { PACKAGE_PIN T13  IOSTANDARD LVCMOS33 } [get_ports {SW[11]}]
set_property -dict { PACKAGE_PIN H6   IOSTANDARD LVCMOS33 } [get_ports {SW[12]}]
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports {SW[13]}]
set_property -dict { PACKAGE_PIN U11  IOSTANDARD LVCMOS33 } [get_ports {SW[14]}]
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 } [get_ports {SW[15]}]

## ----------------------------------------------------------------------------
## Push buttons  (BTNL = load A, BTNR = load B, BTNC = accumulate, BTNU = clear)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C12  IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]
set_property -dict { PACKAGE_PIN N17  IOSTANDARD LVCMOS33 } [get_ports BTNC]
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports BTNU]
set_property -dict { PACKAGE_PIN P17  IOSTANDARD LVCMOS33 } [get_ports BTNL]
set_property -dict { PACKAGE_PIN M17  IOSTANDARD LVCMOS33 } [get_ports BTNR]

## ----------------------------------------------------------------------------
## LEDs  LED[0]..LED[15]   (low drive + slow slew = lower I/O power and SSN)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports {LED[0]}]
set_property -dict { PACKAGE_PIN K15  IOSTANDARD LVCMOS33 } [get_ports {LED[1]}]
set_property -dict { PACKAGE_PIN J13  IOSTANDARD LVCMOS33 } [get_ports {LED[2]}]
set_property -dict { PACKAGE_PIN N14  IOSTANDARD LVCMOS33 } [get_ports {LED[3]}]
set_property -dict { PACKAGE_PIN R18  IOSTANDARD LVCMOS33 } [get_ports {LED[4]}]
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {LED[5]}]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports {LED[6]}]
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {LED[7]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {LED[8]}]
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS33 } [get_ports {LED[9]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {LED[10]}]
set_property -dict { PACKAGE_PIN T16  IOSTANDARD LVCMOS33 } [get_ports {LED[11]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {LED[12]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {LED[13]}]
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 } [get_ports {LED[14]}]
set_property -dict { PACKAGE_PIN V11  IOSTANDARD LVCMOS33 } [get_ports {LED[15]}]

## ----------------------------------------------------------------------------
## Seven-segment display   SEG[0]=CA ... SEG[6]=CG, SEG[7]=DP ; AN[0] rightmost
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports {SEG[0]}]
set_property -dict { PACKAGE_PIN R10  IOSTANDARD LVCMOS33 } [get_ports {SEG[1]}]
set_property -dict { PACKAGE_PIN K16  IOSTANDARD LVCMOS33 } [get_ports {SEG[2]}]
set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS33 } [get_ports {SEG[3]}]
set_property -dict { PACKAGE_PIN P15  IOSTANDARD LVCMOS33 } [get_ports {SEG[4]}]
set_property -dict { PACKAGE_PIN T11  IOSTANDARD LVCMOS33 } [get_ports {SEG[5]}]
set_property -dict { PACKAGE_PIN L18  IOSTANDARD LVCMOS33 } [get_ports {SEG[6]}]
set_property -dict { PACKAGE_PIN H15  IOSTANDARD LVCMOS33 } [get_ports {SEG[7]}]

set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports {AN[0]}]
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports {AN[1]}]
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports {AN[2]}]
set_property -dict { PACKAGE_PIN J14  IOSTANDARD LVCMOS33 } [get_ports {AN[3]}]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports {AN[4]}]
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS33 } [get_ports {AN[5]}]
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports {AN[6]}]
set_property -dict { PACKAGE_PIN U13  IOSTANDARD LVCMOS33 } [get_ports {AN[7]}]

## ----------------------------------------------------------------------------
## Output drive strength / slew (power + signal integrity)
## ----------------------------------------------------------------------------
set_property DRIVE 4     [get_ports {LED[*] SEG[*] AN[*]}]
set_property SLEW  SLOW  [get_ports {LED[*] SEG[*] AN[*]}]

## ----------------------------------------------------------------------------
## Timing exceptions for human-speed I/O
##   Switches / buttons are asynchronous and already 2-FF synchronised in RTL.
##   LEDs / 7-seg are visual only.  The set_*_delay lines make the ports
##   "constrained" for check_timing; the false paths then remove them from
##   timing analysis.
## ----------------------------------------------------------------------------
set_input_delay  -clock [get_clocks sys_clk] 0.000 [get_ports {SW[*] BTNC BTNL BTNR BTNU CPU_RESETN}]
set_output_delay -clock [get_clocks sys_clk] 0.000 [get_ports {LED[*] SEG[*] AN[*]}]
set_false_path -from [get_ports {SW[*] BTNC BTNL BTNR BTNU CPU_RESETN}]
set_false_path -to   [get_ports {LED[*] SEG[*] AN[*]}]
