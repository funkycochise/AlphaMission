//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`default_nettype none

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = status[14];
assign HDMI_FREEZE = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];
wire orientation = ~status[10];
wire [2:0] scan_lines = status[6:4];
wire        direct_video;
wire forced_scandoubler;
wire [21:0] gamma_bus;

assign VIDEO_ARX = (!ar) ? (orientation  ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (orientation  ? 8'd3 : 8'd4) : 12'd0;


// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// 
`include "build_id.v" 
localparam CONF_STR = {
	"Alpha Mission;;",
	"-;",
    "P1,Screen Settings;",
    "P1-;",
    "P1O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OA,Orientation,Horz.,Vert.;",
	"P1OB,Rotation,CW,CCW;",
	"P1O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
   "P2,Game Settings;",
   "P2-;",
	"P2O2,Service Mode,Off,On;",
	"P2-;",
	"P3,Other Settings;",
	"P3-;",
	"P3OE,VGA Scaler,Off,On;",
	"P3OF,Flip,Off,On;",
	"P3-;",
	"DIP;",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"J1,Fire,Missile,Armor,Start,Coin;",
	"jn,A,B,X,Start,R;",
	"DEFMRA,ASO.mra;",
	"V,v",`BUILD_DATE 
};

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;
wire        rom_download = ioctl_download && (ioctl_index  == 0);

//wire forced_scandoubler;

wire service_mode;
assign service_mode = ~status[2];

wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_53p6),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),
	.forced_scandoubler(),
	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.direct_video(direct_video),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),
	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	
	.ps2_key(ps2_key),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

// Video rotation 
wire rotate_ccw = status[11];
wire no_rotate = orientation | direct_video;
wire video_rotated ;
wire flip = status[15];
screen_rotate screen_rotate (.*);

arcade_video #(288,24) arcade_video
(
        .*,

        .clk_video(clk_53p6),
        .ce_pix(ce_pix),

        .RGB_in({R8B,G8B,B8B}),

        .HBlank(HBlank),
        .VBlank(VBlank),
        .HSync(HSync),
        .VSync(VSync),

        .fx(scan_lines)
);

///////////////////////   CLOCKS and POR  ///////////////////////////////

wire clk_sys;
wire clk_53p6;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_53p6)
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

// wire reset_s;
// POR por(
// 	.reset_a(~reset),
// 	.clk(clk_53p6),    
// 	.reset_s(reset_s)
// );

// //add 11 clock cycles delay
// reg [3:0]hack_reset_cnt = 4'd11;
// reg hack_reset = 1'b0;
// always @(posedge clk_53p6) begin
// 	if(!reset_s) hack_reset_cnt <= 4'd11;
// 	else hack_reset_cnt <= hack_reset_cnt - 4'd1;
	
// 	if(!hack_reset && hack_reset_cnt == 4'd0) hack_reset <= 1'b1;
// end
	
// <<< Start of Integration on Alpha Mission Core on MiSTer >>>
wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [3:0] R,G,B;
wire [15:0] snd;
logic [15:0] PLAYER1;

AlphaMissionCore_Sync amc_sync
(
	.RESETn(~reset),
	.VIDEO_RSTn(~reset),
	.i_clk(clk_53p6), //53.6MHz
	.DSW({dsw1,dsw2}),
	.PLAYER1(PLAYER1), //stub
	//hps_io rom interface
	.ioctl_addr(ioctl_addr[24:0]),
	.ioctl_wr(ioctl_wr && rom_download),
	.ioctl_data(ioctl_dout),
	//output
	.R(R),
	.G(G),
	.B(B),
	.HBLANK(HBlank),
	.VBLANK(VBlank),
	.HSYNC(HSync),
	.VSYNC(VSync),
	.CE_PIXEL(ce_pix),
	.snd(snd)
);

//color LUT for 4bit component to 8bit non-linear scale conversion (from LT Spice calculated values)
logic [7:0] R8B, G8B, B8B;
RGB4bit_LUT R_LUT( .COL_4BIT(R), .COL_8BIT(R8B));
RGB4bit_LUT G_LUT( .COL_4BIT(G), .COL_8BIT(G8B));
RGB4bit_LUT B_LUT( .COL_4BIT(B), .COL_8BIT(B8B));
// >>> End of Integration on Alpha Mission Core on MiSTer <<<

// assign CLK_VIDEO = clk_sys;
assign CLK_VIDEO = clk_53p6;

//Controlled by arcade_video
// assign VGA_DE = ~(HBlank | VBlank);
// assign VGA_HS = HSync;
// assign VGA_VS = VSync;

// assign VGA_G  = G8B; //ASO
// assign VGA_R  = R8B; //ASO
// assign VGA_B  = B8B; //ASO

//Audio
assign AUDIO_S = 1'b1; //Signed audio samples
assign AUDIO_MIX = 2'b00; //no mix


//synchronize audio
reg [15:0] snd_r;
always @(posedge CLK_AUDIO) begin
	snd_r <= snd;
	AUDIO_L <= snd_r;
	AUDIO_R <= snd_r;
end


//////// Game inputs, the same controls are used for two player alternate gameplay ////////
//Dip Switches
// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire [7:0] dsw1, dsw2;
assign dsw1 = {~sw[0][7],~sw[0][6],~sw[0][5],~sw[0][4],~sw[0][3],~sw[0][2],~sw[0][1],~sw[0][0]};
assign dsw2 = {~sw[1][7],~sw[1][6],~sw[1][5],~sw[1][4],~sw[1][3],~sw[1][2],~sw[1][1],~sw[1][0]};

//Keyboard


//Joysticks
//Player 1
reg m_up1       = 1'b1;
reg m_down1     = 1'b1;
reg m_left1     = 1'b1;
reg m_right1    = 1'b1;
reg m_shot1     = 1'b1;
reg m_missile1  = 1'b1;
reg m_armor1    = 1'b1;
reg m_service   = 1'b1;
reg m_start1    = 1'b1;
reg m_coin1     = 1'b1;

always @(posedge clk_53p6) begin
	m_up1       <= ~joystick_0[3];
	m_down1     <= ~joystick_0[2];
	m_left1     <= ~joystick_0[1];
	m_right1    <= ~joystick_0[0];
	m_shot1     <= ~joystick_0[4];
	m_missile1  <= ~joystick_0[5];
	m_armor1    <= ~joystick_0[6];
	m_service   <= service_mode;
	m_start1    <= ~joystick_0[7];
	m_coin1     <= ~joystick_0[8];
end

assign PLAYER1 = {2'b11,m_up1,m_down1,m_right1,m_left1,m_service,4'b1111,m_armor1,m_missile1,m_shot1,m_start1,m_coin1};

assign LED_USER = 1'b1;

endmodule
