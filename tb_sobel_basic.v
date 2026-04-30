

// ============================================================================
// TESTBENCH - 5x5 IMAGE
// ============================================================================
module tb_sobel_basic;

    reg        clk, rst_n;
    reg  [7:0] pixel_in;
    reg        pixel_valid;
    wire [10:0] edge_out;
    wire        edge_valid;

    sobel_filter_basic #(.DATA_WIDTH(8), .IMG_WIDTH(5)) uut (
        .clk(clk), .rst_n(rst_n),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .edge_out(edge_out), .edge_valid(edge_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Test image 5x5:
    //  50  50  50  50  50
    //  50 100 100 100  50
    //  50 100 150 100  50   <- bright centre
    //  50 100 100 100  50
    //  50  50  50  50  50
    reg [7:0] test_image [0:24];

    // Expected 9 outputs (hand-verified Manhattan Sobel magnitudes)
    reg [10:0] expected [0:8];

    integer i;

    initial begin
        $dumpfile("sobel_fixed.vcd");
        $dumpvars(0, tb_sobel_basic);

        // Row-major order over the 3x3 valid output region
        expected[0]=400; expected[1]=300; expected[2]=400;
        expected[3]=300; expected[4]=  0; expected[5]=300;
        expected[6]=400; expected[7]=300; expected[8]=400;

        rst_n=0; pixel_valid=0; pixel_in=0;
        #20 rst_n=1;

        // Row 0
        test_image[0]=50;  test_image[1]=50;  test_image[2]=50;
        test_image[3]=50;  test_image[4]=50;
        // Row 1
        test_image[5]=50;  test_image[6]=100; test_image[7]=100;
        test_image[8]=100; test_image[9]=50;
        // Row 2
        test_image[10]=50; test_image[11]=100; test_image[12]=150;
        test_image[13]=100; test_image[14]=50;
        // Row 3
        test_image[15]=50; test_image[16]=100; test_image[17]=100;
        test_image[18]=100; test_image[19]=50;
        // Row 4
        test_image[20]=50; test_image[21]=50;  test_image[22]=50;
        test_image[23]=50; test_image[24]=50;

        #10; pixel_valid=1;
        for (i=0; i<25; i=i+1) begin
            pixel_in = test_image[i];
            @(posedge clk);
        end
        pixel_valid=0; pixel_in=0;

        // Wait for pipeline to flush last 2 outputs
        repeat(5) @(posedge clk);
        #20;

        $display("\n=== %0d/9 outputs correct ===", pass_count);
        $finish;
    end

    integer out_count;
    integer pass_count;
    initial begin out_count=0; pass_count=0; end

    always @(posedge clk) begin
        if (edge_valid) begin
            if (edge_out === expected[out_count]) begin
                $display("Time=%0t | Output #%0d | Mag=%4d | PASS", $time, out_count+1, edge_out);
                pass_count = pass_count + 1;
            end else begin
                $display("Time=%0t | Output #%0d | Mag=%4d | FAIL (expected %4d)",
                         $time, out_count+1, edge_out, expected[out_count]);
            end
            out_count = out_count + 1;
        end
    end

endmodule