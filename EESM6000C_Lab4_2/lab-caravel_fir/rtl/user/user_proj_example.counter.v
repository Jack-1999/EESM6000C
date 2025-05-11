// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10,
    parameter pADDR_WIDTH  = 12,
    parameter pDATA_WIDTH  = 32,
    parameter pDATA_LENGTH = 64,
    parameter pTAP_NUM     = 11
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;
    
	// AXI
    wire awready;
    wire wready;
    wire awvalid;
    wire [(pADDR_WIDTH-1):0] awaddr;
    wire wvalid;
    wire [(pDATA_WIDTH-1):0] wdata;
    wire arready;
    wire rready;
    wire arvalid;
    wire [(pADDR_WIDTH-1):0] araddr;
    wire rvalid;
    wire [(pDATA_WIDTH-1):0] rdata;
    wire ss_tvalid;
    wire [(pDATA_WIDTH-1):0] ss_tdata;
    wire ss_tlast;
    wire ss_tready;
    wire sm_tready;
    wire sm_tvalid;
    wire [(pDATA_WIDTH-1):0] sm_tdata;
    wire sm_tlast;
    
    wire [3:0] tap_WE;
    wire tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A ;
    wire [(pDATA_WIDTH-1):0] tap_Do;

    wire [3:0] data_WE;
    wire data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A ;
    wire [(pDATA_WIDTH-1):0] data_Do;

    wire axis_clk;
    wire axis_rst_n;
	
    wire fir_en;
	
    wire axil_en;
    wire [31:0] axil_adr;
    reg axil_awready;
    reg axil_wready ;
    reg axil_arready;
    wire axistream_x;
    wire axistream_y;
    reg  [31:0] axistream_count;
	
    wire exmem_en;
    wire [3:0] exmem_we;
    wire [31:0] exmem_adr;
    wire [31:0] exmem_dat_o;
    reg  [31:0] delay_count;
	
	
    fir #(.pADDR_WIDTH(pADDR_WIDTH), .pDATA_WIDTH(pDATA_WIDTH), .Tape_Num(pTAP_NUM)) fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)
    );	
	
    bram11 tap_RAM (
        .clk  (axis_clk),
        .we   (tap_WE[0]),
        .re   (tap_EN),
        .waddr(tap_A[(pADDR_WIDTH-1):0]),
        .raddr(tap_A[(pADDR_WIDTH-1):0]),
        .wdi  (tap_Di[(pDATA_WIDTH-1):0]),
        .rdo  (tap_Do[(pDATA_WIDTH-1):0])
    );

    bram11 data_RAM(
        .clk  (axis_clk),
        .we   (data_WE[0]),
        .re   (data_EN),
        .waddr(data_A[(pADDR_WIDTH-1):0]),
        .raddr(data_A[(pADDR_WIDTH-1):0]),
        .wdi  (data_Di[(pDATA_WIDTH-1):0]),
        .rdo  (data_Do[(pDATA_WIDTH-1):0])
    );
	

	
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            axistream_count <= 0;
        end else begin
            if (axistream_x & wbs_ack_o) begin
                axistream_count <= axistream_count + 1;
            end else begin
                axistream_count <= axistream_count;
            end
        end
    end
	


    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            delay_count <= 0;
        end else begin
            if (exmem_en) begin
                if (delay_count != DELAYS) begin
                    delay_count <= delay_count + 1;
                end else begin
                    delay_count <= 0;
                end
            end
        end
    end
	
	assign fir_en = wbs_stb_i & wbs_cyc_i;

    assign axis_clk = wb_clk_i ;
    assign axis_rst_n = ~wb_rst_i;    
	
    assign awvalid = axil_en & wbs_we_i & ~axil_awready;
    assign awaddr = axil_adr;
    assign wvalid = axil_en & wbs_we_i & ~axil_wready ;
    assign wdata = wbs_dat_i;
    assign arvalid = axil_en & ~wbs_we_i & ~axil_arready;
    assign araddr = axil_adr;
    assign rready = axil_en & ~wbs_we_i;
    
    assign axistream_x = fir_en & (wbs_adr_i[6:0] == 7'h40);
    assign axistream_y = fir_en & (wbs_adr_i[6:0] == 7'h44);
	
	assign ss_tvalid = axistream_x & wbs_we_i;
    assign ss_tdata = wbs_dat_i;
    assign ss_tlast = ss_tvalid & (axistream_count == pDATA_LENGTH - 1);
    assign sm_tready = axistream_y & ~wbs_we_i;
	
	assign exmem_en = wbs_stb_i & wbs_cyc_i & (wbs_adr_i[31:24] == 8'h38);
    assign exmem_we = {4{wbs_we_i}} & wbs_sel_i;
    assign exmem_adr = wbs_adr_i - 32'h38000000;
	
	assign wbs_ack_o = axil_awready & axil_wready | rready & rvalid | ss_tvalid & ss_tready | sm_tready & sm_tvalid | (delay_count == DELAYS) ;
    assign wbs_dat_o[ = {32{axil_en }} & rdata|{32{axistream_y}} & sm_tdata[|{32{exmem_en}} & exmem_dat_o;
	
    bram user_bram (
        .CLK(wb_clk_i),
        .WE0(exmem_we),
        .EN0(exmem_en),
        .Di0(wbs_dat_i),
        .Do0(exmem_dat_o),
        .A0 (exmem_adr)
    );


endmodule



`default_nettype wire
