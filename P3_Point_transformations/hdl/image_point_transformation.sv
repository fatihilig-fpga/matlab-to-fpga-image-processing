//------------------------------------------------------------
// Project      : Image Processing - Point Transformation
// Author       : Fatih ILIG
// Created Date : 03 November 2025
//------------------------------------------------------------
import image_point_transformation_pkg::*;
import logarithm_lut_pkg::*;

module image_point_transformation (
	input logic                    rst_i,
	// image_pro_option Register values
	// 0 : Thresholding
	// 1 : Increase the intensity of the pixel
	// 2 : Decrease the intensity of the pixel
	// 3 : Multiply image pixels
	// 4 : Divide image pixels
	// 5 : Complement
	// 6 : Logarithm Operator : Reducing contrast of brighter regions
	// 7 : Power Function : Enhancing contrast of brighter regions
	input logic [option_width-1:0] image_pro_option,
	//--
	image_if                       image_if_i,
	image_if                       image_if_o
);
	// ----------------------------------------
	timeunit 1ns;
	timeprecision 1ns;
	// ----------------------------------------
	image_if #(.DATA_WIDTH(8)) image_if_r_0 (image_if_i.clk); // image_if register 0
	// ----------------------------------------
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			image_if_r_0.payload    <= '0;
			image_if_r_0.data_valid <= '0;
			image_if_r_0.sof        <= '0;
			image_if_r_0.eof        <= '0;
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				image_if_r_0.data_valid <= image_if_i.data_valid;
				image_if_r_0.sof        <= image_if_i.sof;
				image_if_r_0.eof        <= image_if_i.eof;
				//
				case (image_pro_option)
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Thresholding
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					0 : begin
						if (image_if_i.payload > thresholding_value) begin
							image_if_r_0.payload <= pixel_max_value;
						end else begin
							image_if_r_0.payload <= pixel_min_value;
						end
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Increase the intensity of the pixel
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					1 : begin
						image_if_r_0.payload <= image_if_i.payload + incr_intensity_by_value;
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Decrease the intensity of the pixel
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					2 : begin
						image_if_r_0.payload <= image_if_i.payload - decr_intensity_by_value;
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Multiply image pixels
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					3 : begin
						image_if_r_0.payload <= image_if_i.payload << mul_shift_times;
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Divide image pixels
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					4 : begin
						image_if_r_0.payload <= image_if_i.payload >> div_shift_times;
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Complement image pixels
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					5 : begin
						image_if_r_0.payload <= (image_if_i.payload > pixel_max_value) ? (image_if_i.payload - pixel_max_value) : (pixel_max_value - image_if_i.payload);
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Logarithm of image pixels
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					6 : begin
						// Equation
						// S = C * log(1 + r) where C is constant and r is pixel value of the image and S is the output image.
						// We need a precomputed LUT for log(1 + r)
						// Let's say Y = log(1 + r)
						// S = C * Y
						// log(1 + r) ->  {0 <= r <= 255} ->  {log(1+0) <= Y <= log(1+255)}
						// Lets say C is equal to 1.
						// We calculated  {log(1+0) <= Y <= log(1+255)} with LUT log_1_plus_r_lut
						image_if_r_0.payload <= log_1_plus_r_lut[image_if_i.payload]; //  As 0 <= image_if_i.payload <= 255
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					// %% Power Function : Enhancing contrast of brighter regions
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					7 : begin
						// Equation
						// S = C * ( r ^ Y ) where C is constant and r is pixel value of the image and S is the output image.
						// Y = 2 in this example.
						// C = 1
						image_if_r_0.payload <= image_if_i.payload * image_if_i.payload;
					end
					// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					default : begin
						image_if_r_0.payload <= 0; // Error
					end
				endcase
			end else begin
				image_if_r_0.payload    <= image_if_r_0.payload    ;
				image_if_r_0.data_valid <= image_if_r_0.data_valid ;
				image_if_r_0.sof        <= image_if_r_0.sof        ;
				image_if_r_0.eof        <= image_if_r_0.eof        ;
			end
		end
	end
	// ----------------------------------------
	assign image_if_o.payload    = image_if_r_0.payload    ;
	assign image_if_o.data_valid = image_if_r_0.data_valid ;
	assign image_if_o.sof        = image_if_r_0.sof        ;
	assign image_if_o.eof        = image_if_r_0.eof        ;
	// ----------------------------------------
endmodule