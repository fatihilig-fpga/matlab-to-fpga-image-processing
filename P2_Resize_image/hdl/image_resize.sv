//------------------------------------------------------------
// Project      : Image Processing - Resize Image
// File Name    : image_resize.sv
// Author       : Fatih ILIG
// Created Date : 30 October 2025
// Description  :
//   This module performs image downscaling by a configurable
//   resize factor. The design receives an image stream through
//   an image interface, and outputs a resized image by reducing
//   both horizontal and vertical resolutions according to the
//   'resize_option' parameter. For example, with resize_option = 2,
//   an input image of 400x400 pixels is reduced to 200x200 pixels.
//
//   The module uses horizontal and vertical counters to control
//   pixel and line selection, registers input signals for one
//   clock delay, and outputs only the selected pixels that meet
//   the resize condition.
//
//------------------------------------------------------------
module image_resize #(
	parameter resize_option                = 2   ,
	parameter input_image_resolution_width = 4800
) (
	input logic rst_i     ,
	image_if    image_if_i,
	image_if    image_if_o
);
	// ----------------------------------------
	timeunit 1ns;
	timeprecision 1ns;
	// ----------------------------------------
	localparam int H_CNT_WIDTH = $clog2(resize_option);
	localparam int V_CNT_WIDTH = $clog2(resize_option);
	//--
	logic [H_CNT_WIDTH-1:0] cnt_horizontal;
	logic [V_CNT_WIDTH-1:0] cnt_vertical  ;
	// ----------------------------------------
	integer cnt ;
	logic   sol ; // start of line
	// ----------------------------------------
	image_if #(.DATA_WIDTH(8)) image_if_r_0 (image_if_i.clk); // image_if register 0
	image_if #(.DATA_WIDTH(8)) image_if_r_1 (image_if_i.clk); // image_if register 1
	// ----------------------------------------
	// Search for the start of lines
	// Trigger process for start of line (sol)
	// counter from 0 to input_image_resolution_width
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			cnt <= '0;
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				if (cnt >= input_image_resolution_width -1) begin
					cnt <= '0;
				end else begin
					cnt <= cnt + 1;
				end
				//--
			end else begin
				cnt <= cnt; // valid signal might be dropped. cnt value should be the same.
			end
			//--
		end
	end
	//----------------------------------------
	// if valid is 1 and cnt is 0 then trigger start of line (sol)
	always_ff @(posedge image_if_i.clk) begin
		if (rst_i)
			sol <= 1'b0;
		else
			if ((cnt == '0) && (image_if_i.data_valid == 1'b1))  begin
				sol <= 1'b1 ;
			end else begin
			sol <= 1'b0;
		end
	end
	//----------------------------------------
	//  PIPELINE REGISTER STAGE
	//----------------------------------------
	// Register block for the input, we need to delay for one clock cycle
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			image_if_r_0.payload    <= '0;
			image_if_r_0.data_valid <= '0;
			image_if_r_0.sof        <= '0;
			image_if_r_0.eof        <= '0;
			//--
			image_if_r_1.payload    <= '0;
			image_if_r_1.data_valid <= '0;
			image_if_r_1.sof        <= '0;
			image_if_r_1.eof        <= '0;
		end else begin
			image_if_r_0.payload    <= image_if_i.payload;
			image_if_r_0.data_valid <= image_if_i.data_valid;
			image_if_r_0.sof        <= image_if_i.sof;
			image_if_r_0.eof        <= image_if_i.eof;
			//--
			image_if_r_1.payload    <= image_if_r_0.payload;
			image_if_r_1.data_valid <= image_if_r_0.data_valid;
			image_if_r_1.sof        <= image_if_r_0.sof;
			image_if_r_1.eof        <= image_if_r_0.eof;
		end
	end
	// ----------------------------------------
	// Counter Horizontal
	// Counting for each pixel inside the each line.
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			cnt_horizontal <= '0;
		end else begin
			if(image_if_r_1.data_valid == 1'b1) begin
				if (cnt_horizontal >= resize_option - 1) begin
					cnt_horizontal <= '0;
				end else begin
					cnt_horizontal <= cnt_horizontal + 1;
				end
			end else begin
				cnt_horizontal <= cnt_horizontal;
			end
		end
	end
	// ----------------------------------------
	// Counter Vertical
	// Counting for each line by looking at start of line trigger signal
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			cnt_vertical <= '0;
		end else begin
			if(sol == 1'b1) begin // Increment every start of line
				if (cnt_vertical >= resize_option - 1) begin
					cnt_vertical <= '0;
				end else begin
					cnt_vertical <= cnt_vertical + 1;
				end
			end else begin
				cnt_vertical <= cnt_vertical;
			end
		end
	end
	// ----------------------------------------
	assign image_if_o.payload    = (cnt_vertical == 1 && cnt_horizontal == 0 && image_if_r_1.data_valid == 1'b1) ? image_if_r_1.payload : '0;
	assign image_if_o.data_valid = (cnt_vertical == 1 && cnt_horizontal == 0 && image_if_r_1.data_valid == 1'b1) ? image_if_r_1.data_valid : '0;
	assign image_if_o.sof        = (cnt_vertical == 1 && cnt_horizontal == 0 && image_if_r_1.data_valid == 1'b1) ? image_if_r_1.sof : '0;
	assign image_if_o.eof        = (cnt_vertical == 1 && cnt_horizontal == 0 && image_if_r_1.data_valid == 1'b1) ? image_if_r_1.eof : '0;
	// ----------------------------------------
endmodule