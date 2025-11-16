//------------------------------------------------------------
// Project      : Image Processing - Low Pass Filter
// Author       : Fatih ILIG
// Created Date : 13 November 2025
// Module      	: low_pass_filter
// Purpose     	: 3×3 averaging (low-pass) filter for streaming
//              	  grayscale image data.
// Description :
//   - Uses line buffers to store previous rows
//   - Generates a 3×3 pixel window for each pixel
//   - Computes average of window = sum/9
//   - Output is aligned with streaming protocol
//------------------------------------------------------------
import low_pass_filter_pkg::*;

module low_pass_filter (
	input logic rst_i     ,
	image_if    image_if_i,
	image_if    image_if_o
);
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	timeunit 1ns;
	timeprecision 1ns;
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	localparam integer image_resolution_width  = 240;
	localparam integer image_resolution_height = 291;

	image_if #(.DATA_WIDTH(8)) image_if_r (image_if_i.clk); // Register the incoming image interface signals
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Register
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			image_if_r.payload    <= '0;
			image_if_r.data_valid <= '0;
			image_if_r.sof        <= '0;
			image_if_r.eof        <= '0;
		end else begin
			image_if_r.payload    <= image_if_i.payload    ;
			image_if_r.data_valid <= image_if_i.data_valid ;
			image_if_r.sof        <= image_if_i.sof        ;
			image_if_r.eof        <= image_if_i.eof        ;
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// but i used integer for now.
	integer px_cnt   ; // Pixel counter: counts column index (0..width-1)
	integer px_cnt_r0; // Register versions of pixel counter for alignment
	integer px_cnt_r1; // Register versions of pixel counter for alignment
	//--
	// px count: Counts pixel numbers
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			px_cnt    <= 0;
			px_cnt_r0 <= 0;
			px_cnt_r1 <= 0;
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				if (px_cnt>= image_resolution_width-1)begin
					px_cnt <= 0;
				end else begin
					px_cnt <= px_cnt + 1;
				end
			end else begin
				px_cnt <= px_cnt; // do not change
			end
		end
		//--
		px_cnt_r0 <= px_cnt;
		px_cnt_r1 <= px_cnt_r0;
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// For the whole image
	// Line counter : Counts line numbers
	// Note: We can count up to resolution number, so that we can use logic[:] as well
	integer line_cnt; // Line counter: counts image rows
	//--
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			line_cnt <= 0;
		end else begin
			if(image_if_r.data_valid == 1'b1) begin
				if (image_if_r.eof == 1) begin
					line_cnt <= 0;
				end else begin
					if (px_cnt == 0) begin
						line_cnt <= line_cnt + 1;
					end else begin
						line_cnt <= line_cnt;
					end
				end
			end else begin
				line_cnt <= line_cnt; // do not change
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// For each 4 line
	// Line counter : Counts line numbers
	// Note: We can count up to resolution number, so that we can use logic[:] as well
	integer line_cnt_up3; // line counter
	//--
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			line_cnt_up3 <= 0;
		end else begin
			if(image_if_r.data_valid == 1'b1) begin
				if (image_if_r.eof == 1) begin
					line_cnt_up3 <= 0;
				end else begin
					if (px_cnt == 0) begin
						if (line_cnt_up3 >= 3 ) begin
							line_cnt_up3 <= 0;
						end else begin
							line_cnt_up3 <= line_cnt_up3 + 1;
						end
					end else begin
						line_cnt_up3 <= line_cnt_up3;
					end
				end
			end else begin
				line_cnt_up3 <= line_cnt_up3; // do not change
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// LR: Line Buffers, Line Registers
	// Line buffers (unpacked arrays):
	// Store 4 consecutive image lines including zero-padding at boundaries.
	// LR_PX_cnt indexes the current pixel within the line.
	logic [7:0] LR0[0:image_resolution_width+1];
	logic [7:0] LR1[0:image_resolution_width+1];
	logic [7:0] LR2[0:image_resolution_width+1];
	logic [7:0] LR3[0:image_resolution_width+1];
	//--
	integer LR_PX_cnt;
	//--
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			// zeroize
			for (int i = 0; i <= image_resolution_width+1; i++) begin
				LR0[i] <= '0;
				LR1[i] <= '0;
				LR2[i] <= '0;
				LR3[i] <= '0;
			end
			LR_PX_cnt <= 1; // start with 1 as index zero must be zero for this filtering technique
		end else begin
			// Fill each line register in counter clockwise
			if(image_if_r.data_valid == 1'b1) begin
				if (LR_PX_cnt >= image_resolution_width)begin
					LR_PX_cnt <= 1;
				end else begin
					LR_PX_cnt <= LR_PX_cnt + 1;
				end
				//--
				if(line_cnt_up3 == 0) begin
					LR0[LR_PX_cnt] <= image_if_r.payload;
				end else if (line_cnt_up3 == 1) begin
					LR1[LR_PX_cnt] <= image_if_r.payload;
				end else if (line_cnt_up3 == 2) begin
					LR2[LR_PX_cnt] <= image_if_r.payload;
				end else if (line_cnt_up3 == 3) begin
					LR3[LR_PX_cnt] <= image_if_r.payload;
				end else begin
					// Assert error, this can not happen
					for (int i = 0; i <= image_resolution_width+1; i++) begin
						LR0[i] <= '1;
						LR1[i] <= '1;
						LR2[i] <= '1;
						LR3[i] <= '1;
					end
				end
			end else begin
				LR0       <= LR0;
				LR1       <= LR1;
				LR2       <= LR2;
				LR3       <= LR3;
				//--
				LR_PX_cnt <= LR_PX_cnt;
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Compute 3×3 low-pass filtered pixel:
	// For each output pixel, sum the 3×3 neighborhood from the
	// appropriate 3 line buffers based on line_cnt_up3 position.
	//--
	logic [7:0] LR_mean       [0:image_resolution_width-1];
	logic       data_valid_out                            ;
	logic       data_eof_out                              ;
	//
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			for (int i = 0; i <= image_resolution_width-1; i++) begin
				LR_mean[i] <= '0;
			end
			//--
			data_valid_out <= 0;
			data_eof_out   <= 0;
		end else begin
			if(image_if_r.data_valid == 1'b1) begin
				data_eof_out <= image_if_r.eof;
				//--
				// Mean computation storage for each column.
				// Only valid when 3 lines have been received.
				if (line_cnt >= 3) begin // for 3x3 matrix , filtering
					data_valid_out <= 1;
					//--
					// sum/9 => sum * 8'd28 >> 8 , (28/256 ≈ 1/9)
					if(line_cnt_up3 == 3) begin // LR0 LR1 LR2 Mean
						LR_mean[px_cnt_r0] <= (LR0[px_cnt_r0] + LR0[px_cnt_r0 + 1] + LR0[px_cnt_r0 + 2] +
							LR1[px_cnt_r0] + LR1[px_cnt_r0 + 1] + LR1[px_cnt_r0 + 2] +
							LR2[px_cnt_r0] + LR2[px_cnt_r0 + 1] + LR2[px_cnt_r0 + 2]) * 28 >> 8;
					end else if (line_cnt_up3 == 0) begin // LR1 LR2 LR3 Mean
						LR_mean[px_cnt_r0] <= (LR3[px_cnt_r0] + LR3[px_cnt_r0 + 1] + LR3[px_cnt_r0 + 2] +
							LR1[px_cnt_r0] + LR1[px_cnt_r0 + 1] + LR1[px_cnt_r0 + 2] +
							LR2[px_cnt_r0] + LR2[px_cnt_r0 + 1] + LR2[px_cnt_r0 + 2]) * 28 >> 8;
					end else if (line_cnt_up3 == 1) begin // LR0 LR2 LR3 Mean
						LR_mean[px_cnt_r0] <= (LR0[px_cnt_r0] + LR0[px_cnt_r0 + 1] + LR0[px_cnt_r0 + 2] +
							LR3[px_cnt_r0] + LR3[px_cnt_r0 + 1] + LR3[px_cnt_r0 + 2] +
							LR2[px_cnt_r0] + LR2[px_cnt_r0 + 1] + LR2[px_cnt_r0 + 2]) * 28 >> 8;
					end else if (line_cnt_up3 == 2) begin // LR0 LR1 LR3 Mean
						LR_mean[px_cnt_r0] <= (LR0[px_cnt_r0] + LR0[px_cnt_r0 + 1] + LR0[px_cnt_r0 + 2] +
							LR1[px_cnt_r0] + LR1[px_cnt_r0 + 1] + LR1[px_cnt_r0 + 2] +
							LR3[px_cnt_r0] + LR3[px_cnt_r0 + 1] + LR3[px_cnt_r0 + 2]) * 28 >> 8;
					end else begin
						LR_mean[px_cnt_r0] <= 'x; // assertion
					end
				end else begin
					for (int i = 0; i <= image_resolution_width-1; i++) begin
						LR_mean[i] <= '0;
					end
				end
			end else begin
				LR_mean        <= LR_mean;
				data_valid_out <= 0;
				data_eof_out   <= 0;
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Drive output interface:
	// payload = filtered pixel
	// data_valid = valid when enough data received
	// sof/eof forwarded with correct timing
	assign image_if_o.payload    = LR_mean[px_cnt_r1];
	assign image_if_o.data_valid = data_valid_out;
	assign image_if_o.sof        = image_if_r.sof;
	assign image_if_o.eof        = data_eof_out;
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
endmodule