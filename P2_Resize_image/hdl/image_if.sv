//------------------------------------------------------------
// Project      : Image Processing
// File Name    : image_if.sv
// Author       : Fatih ILIG
// Created Date : 30 October 2025
// Description  :
//   This interface defines the image stream signal bundle used
//   for transferring pixel data between modules. It includes
//   synchronization and validity signals along with the pixel
//   payload itself.
//
//   Signals:
//     - clk        : Clock signal driving the interface
//     - payload    : Pixel data bus (width defined by DATA_WIDTH)
//     - data_valid : Indicates when the payload contains valid data
//     - sof        : Start of frame indicator
//     - eof        : End of frame indicator
//
//   The interface provides a structured and reusable connection
//   between image-processing modules such as image capture,
//   resize, and display blocks.
//------------------------------------------------------------

interface image_if #(parameter int DATA_WIDTH = 8 )  // Width of the pixel payload
	(input logic clk);
	logic [DATA_WIDTH-1:0] payload   ;
	logic                  data_valid;
	logic                  sof       ;
	logic                  eof       ;
endinterface