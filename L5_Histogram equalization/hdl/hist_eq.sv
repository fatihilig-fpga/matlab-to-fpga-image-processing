//------------------------------------------------------------
// Project      : Image Processing - Histogram Equalization
// Author       : Fatih ILIG
// Created Date : 08 November 2025
//------------------------------------------------------------
import hist_eq_pkg::*;

module hist_eq (
	input logic rst_i     ,
	image_if    image_if_i,
	image_if    image_if_o
);
	// ----------------------------------------
	timeunit 1ns;
	timeprecision 1ns;
	// ----------------------------------------
	image_if #(.DATA_WIDTH(8)) image_if_r (image_if_i.clk); // image_if register 0
	logic eof_r1;
	logic eof_r2;
	logic eof_r3;
	logic eof_r4;
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Sort and Find the Gray Levels
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Calculate nj
	// --
	// nj  , number of pixels with intensity rj
	// rj is index number of rj_index_numbers array.
	// So if received data (pixel value) is 0 then rj_index_numbers[0] counter must increment by 1
	//                                   is 255 then rj_index_numbers[255] counter must increment by 1
	// Note: If Grayscale 8 bits then max value is 255
	// Let's say that all of the pixels are the same intensity rj, then counter can count up to number_of_pixels,
	// which width value is RJ_WIDTH
	logic [RJ_WIDTH-1:0] rj_index_numbers[pixel_min_value:pixel_max_value];
	//
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			rj_index_numbers <= '{default:'0};
		end else begin
			if(image_if_i.data_valid == 1'b1) begin
				rj_index_numbers[image_if_i.payload] <= rj_index_numbers[image_if_i.payload] + 1;
			end else begin
				rj_index_numbers[image_if_i.payload] <= rj_index_numbers[image_if_i.payload];
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			eof_r1 <= '0;
			eof_r2 <= '0;
			eof_r3 <= '0;
			eof_r4 <= '0;
		end else begin
			eof_r1 <= image_if_i.eof;
			eof_r2 <= eof_r1;
			eof_r3 <= eof_r2;
			eof_r4 <= eof_r3;
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Calculate p(rj) = nj/N
	// We will use Ck (cumulative) values (p_rj)
	// N = input_image_resolution_width * input_image_resolution_height;
	//
	logic [RJ_WIDTH-1:0] p_rj[pixel_min_value:pixel_max_value];

	always_comb begin
		p_rj[pixel_min_value] = rj_index_numbers[pixel_min_value];
		for (integer i = pixel_min_value + 1; i <= pixel_max_value; i++) begin
			p_rj[i] = p_rj[i-1] + rj_index_numbers[i];
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	logic [RJ_WIDTH-1:0] p_rj_clean[pixel_min_value:pixel_max_value];

	always_comb begin
		if (eof_r2 == 1) begin
			p_rj_clean[pixel_min_value] = p_rj[pixel_min_value];

			for (integer i = pixel_min_value + 1; i <= pixel_max_value; i++) begin
				if (p_rj[i] > p_rj[i - 1]) begin
					p_rj_clean[i] = p_rj[i];
				end else begin
					p_rj_clean[i] = 0;
				end
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// s_k = floor((255 × C_k) / N)
	integer s_k[pixel_min_value:pixel_max_value];

	always_comb begin
		if (eof_r3 == 1) begin
			for (integer i = pixel_min_value; i <= pixel_max_value; i++) begin
				s_k[i] = (pixel_max_value * p_rj_clean[i]) / N;
			end
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	// Replacing  original values with calculated ones.
	// We can use a ram instead of queue
	logic [DATA_WIDTH-1:0] ram_queue_payload   [$];
	logic                  ram_queue_data_valid[$];
	logic                  ram_queue_sof       [$];
	logic                  ram_queue_eof       [$];
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	//    Buffer: Store the image data in a buffer for this stage, a queue structure can be used (for verification purposes);
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
	//--
	enum {IDLE, READ, DONE} STATE;
	logic [DATA_WIDTH-1:0] payload;

	always_ff@(posedge(image_if_i.clk)) begin
		if(rst_i) begin
			STATE                   <= IDLE;
			image_if_r.payload    <= '0;
			image_if_r.data_valid <= '0;
			image_if_r.sof        <= '0;
			image_if_r.eof        <= '0;
		end else begin
			case (STATE)
				IDLE : begin
					if(eof_r3 == 1) begin
						STATE <= READ;
					end 	else begin
						STATE <= IDLE;
					end
				end

				READ : begin
					// payload = s_k[ram_queue_payload.pop_front];
					image_if_r.payload    <= s_k[ram_queue_payload.pop_front];
					image_if_r.data_valid <= ram_queue_data_valid.pop_front;
					image_if_r.sof        <= ram_queue_sof.pop_front;
					image_if_r.eof        <= ram_queue_eof.pop_front;
					// --
					if(ram_queue_payload.size() <= 0 ) begin
						STATE <= DONE;
					end 	else begin
						STATE <= READ;
					end
				end

				DONE : begin
					image_if_r.payload    <= '0;
					image_if_r.data_valid <= '0;
					image_if_r.sof        <= '0;
					image_if_r.eof        <= '0;
					STATE <= IDLE;
				end
			endcase
		end
	end
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	assign image_if_o.payload    = image_if_r.payload    ;
	assign image_if_o.data_valid = image_if_r.data_valid ;
	assign image_if_o.sof        = image_if_r.sof        ;
	assign image_if_o.eof        = image_if_r.eof        ;
	// % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
endmodule