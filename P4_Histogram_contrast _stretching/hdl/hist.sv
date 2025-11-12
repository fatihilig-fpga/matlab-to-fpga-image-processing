//------------------------------------------------------------
// Project      : Image Processing - Histogram
// Author       : Fatih ILIG
// Created Date : 04 November 2025
// Note : This code is currently non-synthesizable. 
// It focuses solely on implementing the histogram algorithm for 
// functional verification. However, it can be adapted for 
// synthesis in future hardware implementations.
//
// Input Video Frame or Image reqs: 8 bits monochrome
//------------------------------------------------------------
import hist_pkg::*;

module hist (
	input logic rst_i     ,
	image_if    image_if_i,
	image_if    image_if_o
);
	// ----------------------------------------
	timeunit 1ns;
	timeprecision 1ns;
	// ----------------------------------------
	image_if #(.DATA_WIDTH(8)) image_if_r_0 (image_if_i.clk); // image_if register 0
	//--
	logic[DATA_WIDTH-1:0] pixel_max_intensity_value_r;
	logic[DATA_WIDTH-1:0] pixel_min_intensity_value_r;
	//--
	logic [DATA_WIDTH-1:0] ram_queue_payload   [$];
	logic                  ram_queue_data_valid[$];
	logic                  ram_queue_sof       [$];
	logic                  ram_queue_eof       [$];
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// 1. Max - min intensity:
	// Description: Determine the maximum and minimum intensity levels across the entire
	// image to identify the current dynamic range.
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			pixel_max_intensity_value_r <= pixel_min_value; // initialize with minimum value
			pixel_min_intensity_value_r <= pixel_max_value;  // initialize with maximum value
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				// Maximum value
				if (image_if_i.payload > pixel_max_intensity_value_r) begin // If current pixel value is greater than the previous one, then assign it.
					pixel_max_intensity_value_r <= image_if_i.payload;
				end else begin
					pixel_max_intensity_value_r <= pixel_max_intensity_value_r; // Else, keep the previous one.
				end
				// Minimum value
				if (image_if_i.payload < pixel_min_intensity_value_r) begin // If current pixel value is lower than the previous one, then assign it.
					pixel_min_intensity_value_r <= image_if_i.payload;
				end else begin
					pixel_min_intensity_value_r <= pixel_min_intensity_value_r; // Else, keep the previous one.
				end
			end else begin
				pixel_min_intensity_value_r <= pixel_min_intensity_value_r;
				pixel_max_intensity_value_r <= pixel_max_intensity_value_r;
			end
		end
	end
	// --
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	//--
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// 2. Buffer: Store the image data in a buffer for this stage, a queue structure can be used (for verification purposes);
	//    however, RAM-based storage may be employed later if hardware synthesis is intended.
	//    This part is not synthesizable, but can be easily converted to
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			ram_queue_payload.delete();
			ram_queue_data_valid.delete();
			ram_queue_sof.delete();
			ram_queue_eof.delete();
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				// Note: We can concatenate payload, data_valid, sof and eof and use
				// only one queue for all but we simplified it here
				ram_queue_payload.push_back(image_if_i.payload);
				ram_queue_data_valid.push_back(image_if_i.data_valid);
				ram_queue_sof.push_back(image_if_i.sof);
				ram_queue_eof.push_back(image_if_i.eof);
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	//--
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// 3. Perform contrast (histogram) stretching on the buffered image to expand
	//		its intensity range and enhance visual contrast.
	//    Note: If we have a streaming input (video) then we can use ping pong technique from fifo,
	//			   but we are simply receiving one image.
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// This part can be done with a FSM if you want it synthesizable.
   // This time we are triggering only once to apply for one frame.
	bit trigger_hist;
	initial begin
		trigger_hist = 1'b0;
		@(posedge(image_if_i.eof)); // wait until the end of the frame to process image via using calculated Max - min intensity values
		trigger_hist = 1'b1;
	end
	//--
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			image_if_r_0.payload    <= '0;
			image_if_r_0.data_valid <= '0;
			image_if_r_0.sof        <= '0;
			image_if_r_0.eof        <= '0;
		end else begin
			if(ram_queue_payload.size() > 0 && trigger_hist == 1'b1) begin
				// (L - 1) * (r - rmin) / (rmax - rmin)
				// (255) * (r - pixel_min_intensity_value_r) / (pixel_max_intensity_value_r - pixel_min_intensity_value_r)
				image_if_r_0.payload <= 255 * ( ram_queue_payload.pop_front - pixel_min_intensity_value_r) / (pixel_max_intensity_value_r - pixel_min_intensity_value_r);
				image_if_r_0.data_valid <= ram_queue_data_valid.pop_front;
				image_if_r_0.sof        <= ram_queue_sof.pop_front;
				image_if_r_0.eof        <= ram_queue_eof.pop_front;
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	assign image_if_o.payload    = image_if_r_0.payload    ;
	assign image_if_o.data_valid = image_if_r_0.data_valid ;
	assign image_if_o.sof        = image_if_r_0.sof        ;
	assign image_if_o.eof        = image_if_r_0.eof        ;
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
endmodule