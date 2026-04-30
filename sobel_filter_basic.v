module sobel_filter_basic #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 512
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0]  pixel_in,
    input  wire                   pixel_valid,
    output reg  [DATA_WIDTH+2:0]  edge_out,
    output reg                    edge_valid
);

// ============================================================================
// LINE BUFFERS
// ============================================================================
reg [DATA_WIDTH-1:0] line_buffer1 [0:IMG_WIDTH-1]; // Row N-1
reg [DATA_WIDTH-1:0] line_buffer2 [0:IMG_WIDTH-1]; // Row N-2

// FIX 1: Zero-initialise buffers so first output is never 'x'
integer k;
initial begin
    for (k = 0; k < IMG_WIDTH; k = k + 1) begin
        line_buffer1[k] = 0;
        line_buffer2[k] = 0;
    end
end

// ============================================================================
// 3x3 WINDOW REGISTERS
// ============================================================================
reg [DATA_WIDTH-1:0] p00, p01, p02; // Top row    (row N-2)
reg [DATA_WIDTH-1:0] p10, p11, p12; // Middle row (row N-1)
reg [DATA_WIDTH-1:0] p20, p21, p22; // Bottom row (row N, current)

integer col_count;
integer row_count;

// FIX 3: Single-stage valid pipeline
// window_ready goes high when a full 3x3 window is ready (col>=2 means
// columns 0,1,2 have all been loaded into the window shift registers).
// valid_pipe delays it by 1 cycle to align with the registered edge_out.
reg valid_pipe;
wire window_ready = (row_count >= 2) && (col_count >= 2) && pixel_valid;

// ============================================================================
// WINDOW EXTRACTION
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        col_count  <= 0;
        row_count  <= 0;
        valid_pipe <= 0;
        p00<=0; p01<=0; p02<=0;
        p10<=0; p11<=0; p12<=0;
        p20<=0; p21<=0; p22<=0;
    end else begin
        // Advance valid pipeline every clock
        valid_pipe <= window_ready;

        if (pixel_valid) begin
            // FIX 2: Non-blocking RHS reads OLD values, so writing buffers
            // first is safe and makes read-before-write intent explicit.
            line_buffer2[col_count] <= line_buffer1[col_count]; // N-1 -> N-2
            line_buffer1[col_count] <= pixel_in;                // N   -> N-1

            // Shift window (RHS captures pre-clock buffer values)
            p00 <= p01; p01 <= p02; p02 <= line_buffer2[col_count];
            p10 <= p11; p11 <= p12; p12 <= line_buffer1[col_count];
            p20 <= p21; p21 <= p22; p22 <= pixel_in;

            if (col_count == IMG_WIDTH - 1) begin
                col_count <= 0;
                row_count <= row_count + 1;
            end else
                col_count <= col_count + 1;
        end
    end
end

// ============================================================================
// SOBEL CONVOLUTION (Combinational)
//
//  Gx:  -1  0 +1      Gy:  -1 -2 -1
//       -2  0 +2            0  0  0
//       -1  0 +1           +1 +2 +1
// ============================================================================
wire signed [DATA_WIDTH+2:0] gx, gy;
wire        [DATA_WIDTH+2:0] abs_gx, abs_gy;

assign gx = ( $signed({1'b0, p02}) - $signed({1'b0, p00}) )
          + (($signed({1'b0, p12}) - $signed({1'b0, p10})) <<< 1)
          + ( $signed({1'b0, p22}) - $signed({1'b0, p20}) );

assign gy = (-$signed({1'b0, p00}) - ($signed({1'b0, p01}) <<< 1) - $signed({1'b0, p02}))
          + ( $signed({1'b0, p20}) + ($signed({1'b0, p21}) <<< 1) + $signed({1'b0, p22}));

assign abs_gx = gx[DATA_WIDTH+2] ? (~gx + 1'b1) : gx;
assign abs_gy = gy[DATA_WIDTH+2] ? (~gy + 1'b1) : gy;

wire [DATA_WIDTH+2:0] magnitude = abs_gx + abs_gy;

// ============================================================================
// OUTPUT REGISTER
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        edge_out   <= 0;
        edge_valid <= 0;
    end else begin
        edge_out   <= magnitude;   // 1-cycle registered
        edge_valid <= valid_pipe;  // aligned: valid_pipe was set 1 cycle ago
    end
end

endmodule
