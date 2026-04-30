# Learned Sobel Filter

Small Verilog + Python project for experimenting with Sobel edge detection in hardware, with a tiny ML loop used to learn and quantize the filter kernels.

## What is here

- `sobel_filter_basic(1).v` - basic streaming Sobel filter using fixed classic kernels.
- `sobel_filter_pipelined(1).v` - pipelined version of the fixed Sobel datapath.
- `sobel_filter_learned.v` - pipelined Sobel-style filter where the `Gx` and `Gy` kernels are parameters instead of hard-coded constants.
- `train_sobel.py` - PyTorch training script that learns Sobel-like kernels from generated image samples.
- `kernel_weights.json` - learned floating-point and quantized integer kernel values.
- `learned_kernel_params.vh` - generated Verilog parameter form of the learned kernels.
- `tb_sobel_learned.v` - simple testbench for the learned filter.
- `tb_sobel_basic(1).v`, `tb_sobel_filter(1).v` - extra testbenches for the fixed Sobel versions.

## The ML Jazz

The ML part is intentionally small, but it connects directly to the hardware.

`train_sobel.py` builds a one-layer convolution model:

- input: one grayscale image channel
- output: two learned 3x3 filters, one for horizontal edges `Gx` and one for vertical edges `Gy`
- edge magnitude: `abs(Gx) + abs(Gy)`

The model starts from the classic Sobel kernels:

```text
Gx = [-1  0  1]      Gy = [-1 -2 -1]
     [-2  0  2]           [ 0  0  0]
     [-1  0  1]           [ 1  2  1]
```

During training, the script generates synthetic grayscale images containing simple rectangles, ellipses, and lines. It creates target edge maps using a fixed Sobel-style reference, then trains the convolution weights with MSE loss. This means the model is not doing heavy deep learning; it is learning a compact edge detector that can still be mapped cleanly into hardware.

After training, the learned floating-point weights are quantized into small signed integers. The current learned result is:

```text
Gx = [-3  0  3]      Gy = [-3 -8 -3]
     [-8  0  8]           [ 0  0  0]
     [-3  0  3]           [ 3  8  3]
```

That quantization step is the important bridge: PyTorch gives flexible floating-point weights, while Verilog wants simple integer constants that synthesize efficiently. The hardware then performs a normal 3x3 dot product using those learned integer weights and shifts the result down to account for the quantization scale.

## Hardware Flow

The learned hardware module streams pixels in one at a time:

1. Two line buffers hold previous rows.
2. Shift registers build the current 3x3 image window.
3. The learned `Gx` and `Gy` kernels are applied as parameterized dot products.
4. The output edge strength is computed as `abs(gx) + abs(gy)`.
5. A small pipeline keeps the datapath clocked and aligns `edge_valid`.

The port interface is simple:

```verilog
input  wire clk;
input  wire rst_n;
input  wire [DATA_WIDTH-1:0] pixel_in;
input  wire pixel_valid;
output reg  [DATA_WIDTH+3:0] edge_out;
output reg  edge_valid;
```

## Running the Training

Install the Python dependencies:

```bash
pip install torch numpy pillow scipy
```

Run:

```bash
python train_sobel.py
```

This updates:

- `kernel_weights.json`
- `learned_kernel_params.vh`

## Running a Simulation

With Icarus Verilog installed:

```bash
iverilog -o sim_learned tb_sobel_learned.v sobel_filter_learned.v
vvp sim_learned
```

The testbench feeds an 8x8 image with a sharp vertical edge and prints valid edge outputs as the pipeline produces them.

## Notes

The point of the project is not to build a big neural net. It is to show a practical ML-to-RTL path: learn tiny convolution kernels, quantize them, and drop them into a synthesizable streaming image-processing block.
