package image_point_transformation_pkg;
	parameter  int num_of_image_processing_options = 8                                      ;
	localparam int option_width                    = $clog2(num_of_image_processing_options);
	localparam int pixel_max_value                 = 255                                    ;
	localparam int pixel_min_value                 = 0                                      ;
	localparam int DATA_WIDTH                      = 8                                      ;
	// 0 : Thresholding
	localparam int thresholding_value = 120;
	// 1 : Increase the intensity of the pixel
	localparam int incr_intensity_by_value = 100;
	// 2 : Decrease the intensity of the pixel
	localparam int decr_intensity_by_value = 100;
	// 3 : Multiply image pixels
	localparam int multiply_by_value = 2; // 2 ^ n
   localparam int mul_shift_times = $clog2(multiply_by_value);
	// 4 : Divide image pixels
	localparam int divide_by_value = 2; // 2 ^ n
   localparam int div_shift_times = $clog2(divide_by_value);
endpackage