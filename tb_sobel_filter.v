module tb_sobel_filter;

parameter DATA_WIDTH = 8;
parameter IMG_WIDTH  = 8;

reg clk, rst_n;
reg [DATA_WIDTH-1:0] pixel_in;
reg pixel_valid;

wire [DATA_WIDTH+3:0] edge_out;
wire edge_valid;

// DUT
sobel_filter_pipelined #(
    .DATA_WIDTH(DATA_WIDTH),
    .IMG_WIDTH(IMG_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .pixel_in(pixel_in),
    .pixel_valid(pixel_valid),
    .edge_out(edge_out),
    .edge_valid(edge_valid)
);

// CLOCK
always #5 clk = ~clk;

// IMAGE MEMORY
reg [7:0] image [0:63];
integer i;

// INIT
initial begin
    clk = 0;
    rst_n = 0;
    pixel_valid = 0;
    pixel_in = 0;

    #20 rst_n = 1;

    // Create horizontal edge
    for (i = 0; i < 64; i = i + 1) begin
        if (i < 32)
            image[i] = 0;
        else
            image[i] = 255;
    end

    #10 pixel_valid = 1;

    for (i = 0; i < 64; i = i + 1) begin
        pixel_in = image[i];
        #10;
    end

    pixel_valid = 0;

    #100 $finish;
end

// MONITOR
integer cycle = 0;
always @(posedge clk) begin
    cycle = cycle + 1;
    if (edge_valid) begin
        $display("Cycle=%0d Edge=%0d", cycle, edge_out);
    end
end

endmodule