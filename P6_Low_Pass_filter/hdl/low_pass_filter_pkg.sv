package low_pass_filter_pkg;
	localparam int DATA_WIDTH = 8;
	localparam logic[DATA_WIDTH-1:0] pixel_max_value = 255;
	localparam logic[DATA_WIDTH-1:0] pixel_min_value = 0;
	//
	localparam int input_image_resolution_width  = 240;
	localparam int input_image_resolution_height = 291;
	// 1 channel for grayscale
	localparam int channel          = 1 ;
	// Total pixel number
	localparam int number_of_pixels = channel * input_image_resolution_width * input_image_resolution_height;
	// max width calculation for rj
	localparam int RJ_WIDTH = $clog2(number_of_pixels);
	// N
	localparam int N = input_image_resolution_width * input_image_resolution_height;
endpackage