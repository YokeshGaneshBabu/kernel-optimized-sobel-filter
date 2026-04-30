// =============================================================================
// tb_sobel_learned.v  —  testbench for sobel_filter_learned
// =============================================================================
`timescale 1ns/1ps

module tb_sobel_learned;

// ── parameters ────────────────────────────────────────────────────────────
parameter DATA_WIDTH = 8;
parameter IMG_WIDTH  = 8;   // small image for sim speed

// ── DUT signals ───────────────────────────────────────────────────────────
reg                   clk, rst_n;
reg  [DATA_WIDTH-1:0] pixel_in;
reg                   pixel_valid;
wire [DATA_WIDTH+3:0] edge_out;
wire                  edge_valid;

// ── DUT instantiation ─────────────────────────────────────────────────────
// Paste learned weights here after running train_sobel.py.
// Example below uses standard Sobel defaults.
sobel_filter_learned #(
    .DATA_WIDTH (DATA_WIDTH),
    .IMG_WIDTH  (IMG_WIDTH),
    // --- replace these 18 lines with output from train_sobel.py ---
    .K_GX_0(-1), .K_GX_1(0), .K_GX_2(1),
    .K_GX_3(-2), .K_GX_4(0), .K_GX_5(2),
    .K_GX_6(-1), .K_GX_7(0), .K_GX_8(1),
    .K_GY_0(-1), .K_GY_1(-2), .K_GY_2(-1),
    .K_GY_3( 0), .K_GY_4( 0), .K_GY_5( 0),
    .K_GY_6( 1), .K_GY_7( 2), .K_GY_8( 1)
    // ---------------------------------------------------------------
) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .pixel_in   (pixel_in),
    .pixel_valid(pixel_valid),
    .edge_out   (edge_out),
    .edge_valid (edge_valid)
);

// ── clock ─────────────────────────────────────────────────────────────────
always #5 clk = ~clk;

// ── 8×8 test image (ramp + edge at column 4) ──────────────────────────────
reg [DATA_WIDTH-1:0] img [0:63];
integer r, c, idx;

initial begin
    for (r = 0; r < 8; r = r + 1)
        for (c = 0; c < 8; c = c + 1)
            img[r*8 + c] = (c < 4) ? 8'd50 : 8'd200;  // sharp vertical edge
end

// ── stimulus ──────────────────────────────────────────────────────────────
initial begin
    $dumpfile("tb_sobel_learned.vcd");
    $dumpvars(0, tb_sobel_learned);

    clk = 0; rst_n = 0; pixel_valid = 0; pixel_in = 0;
    #20 rst_n = 1;

    // feed all 64 pixels one per clock
    for (idx = 0; idx < 64; idx = idx + 1) begin
        @(posedge clk);
        pixel_in    = img[idx];
        pixel_valid = 1;
    end
    @(posedge clk); pixel_valid = 0;

    // wait for pipeline drain (3 stages + margin)
    repeat(10) @(posedge clk);
    $display("Simulation complete.");
    $finish;
end

// ── monitor ───────────────────────────────────────────────────────────────
always @(posedge clk)
    if (edge_valid)
        $display("t=%0t  edge_out=%0d", $time, edge_out);

endmodule
