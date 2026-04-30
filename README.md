# Kernel-Optimized Sobel Filter

Low-power VLSI architecture for real-time Sobel-based edge detection in satellite imagery, with an ML-to-RTL kernel learning pipeline.

**Course:** BEVD311L — VLSI DSP Systems, VIT Chennai  
**Team:** GeoSobel (Adithya, Hariharan, Bharghav, Yokesh, Dravidan)

---

## What's Here

| File | Description |
|------|-------------|
| `sobel_filter_basic.v` | Streaming Sobel filter with fixed classic kernels, 1-cycle registered output |
| `sobel_filter_pipelined.v` | Fully registered 3-stage pipeline (Gx/Gy → abs → output) |
| `sobel_filter_learned.v` | Parameterized Sobel filter with ML-learned quantized kernel weights |
| `train_sobel.py` | PyTorch training script — learns and quantizes Gx/Gy kernels from synthetic image data |
| `kernel_weights.json` | Trained floating-point and quantized integer kernel values |
| `learned_kernel_params.vh` | Auto-generated Verilog `parameter` file — drop directly into `sobel_filter_learned` |
| `tb_sobel_basic.v` | Testbench for the basic architecture |
| `tb_sobel_filter.v` | Testbench for the pipelined architecture |
| `tb_sobel_learned.v` | Testbench for the learned-kernel architecture |

---

## Architecture Overview

### Three Progressive Designs

```
sobel_filter_basic       sobel_filter_pipelined       sobel_filter_learned
─────────────────        ──────────────────────       ────────────────────
Single-stage             3-stage pipeline              3-stage pipeline
combinational Gx/Gy      Stage 1: Gx, Gy compute      Parameterized kernels
+ registered output      Stage 2: |Gx| + |Gy|         Weights from ML training
                         Stage 3: output register      Same streaming interface
```

All three share the same streaming pixel interface:

```verilog
input  wire [DATA_WIDTH-1:0]  pixel_in;    // 8-bit grayscale pixel
input  wire                   pixel_valid; // handshake
output reg  [DATA_WIDTH+3:0]  edge_out;    // edge magnitude
output reg                    edge_valid;  // output handshake
```

### 3×3 Window Extraction

Pixels stream in row by row. Two line buffers reconstruct the previous two rows. A 3×3 shift register window is updated every clock:

```
  p00  p01  p02   ← row N-2 (line_buffer2)
  p10  p11  p12   ← row N-1 (line_buffer1)
  p20  p21  p22   ← row N   (current input)
```

`edge_valid` asserts only after `row >= 2 && col >= 2` — the first 2 rows and 2 columns are warm-up latency.

### Classic Sobel Kernels

```
Gx = [-1  0 +1]      Gy = [-1 -2 -1]
     [-2  0 +2]           [ 0  0  0]
     [-1  0 +1]           [+1 +2 +1]

magnitude = |Gx| + |Gy|   (L1 approximation, synthesizes efficiently)
```

### ML-Learned Kernels

`train_sobel.py` trains a single-layer convolution model on synthetic grayscale images (rectangles, ellipses, lines). It minimizes MSE against a fixed Sobel reference, then quantizes the learned weights to small signed integers:

```
Learned result:
Gx = [-3  0  3]      Gy = [-3 -8 -3]
     [-8  0  8]           [ 0  0  0]
     [-3  0  3]           [ 3  8  3]
```

These are written to `learned_kernel_params.vh` as Verilog parameters and loaded into `sobel_filter_learned.v` at synthesis time. No floating point in hardware — the quantization scale factor is absorbed into the output shift.

**This closes the ML-to-RTL loop:** PyTorch → quantization → `.vh` → synthesizable Verilog.

---

## Application

Hardware-accelerated edge detection for satellite and remote sensing imagery:

- **Disaster assessment** — structural damage detection by comparing pre/post-event imagery (floods, earthquakes, wildfires)
- **Land cover classification** — boundary extraction from Landsat-8, Sentinel-2, WorldView multispectral data
- **Infrastructure extraction** — road, railway, and building footprint detection
- **Agricultural monitoring** — field boundary delineation for precision agriculture
- **Coastline detection** — water body boundary extraction for environmental monitoring

The streaming pixel-valid interface is suitable for FPGA deployment in ground stations, UAV onboard processors, or satellite edge computing units.

---

## Simulation

With Icarus Verilog:

```bash
# Basic architecture
iverilog -o sim_basic tb_sobel_basic.v sobel_filter_basic.v
vvp sim_basic

# Pipelined architecture
iverilog -o sim_pipe tb_sobel_filter.v sobel_filter_pipelined.v
vvp sim_pipe

# Learned-kernel architecture
iverilog -o sim_learned tb_sobel_learned.v sobel_filter_learned.v
vvp sim_learned
```

The testbenches feed synthetic 8×8 images with sharp horizontal and vertical edges and print `edge_out` / `edge_valid` per clock.

---

## ML Training

```bash
pip install torch numpy pillow scipy
python train_sobel.py
```

Outputs `kernel_weights.json` and `learned_kernel_params.vh`. The `.vh` file can be directly included in `sobel_filter_learned.v` with `` `include ``.

---

## Key Design Notes

- **`initial` block zero-init on line buffers** — prevents `X` propagation on the first output cycles (ModelSim-safe)
- **Non-blocking assignments on line buffers** — ensures `line_buffer2[col] <= line_buffer1[col]` reads the pre-clock value, no read-before-write hazard
- **Signed arithmetic via `$signed` cast** — avoids Verilog unsigned subtraction wrapping in Gx/Gy computation
- **L1 magnitude (`|Gx| + |Gy|`)** — avoids the square root of L2, hardware-friendly and sufficient for binary edge maps
- **1-cycle output latency** (basic) / **3-cycle latency** (pipelined) — documented in testbenches

---

## Waveform Screenshots

See `pipeline 1.jpg`, `pipeline 2.jpg`, `pipeline 3.jpg` — ModelSim simulation waveforms showing window valid timing, Gx/Gy computation, and edge_valid alignment across pipeline stages.

---

## Tools

- **Simulation:** ModelSim / Icarus Verilog
- **Synthesis target:** Xilinx Vivado (FPGA)
- **ML training:** PyTorch, NumPy, SciPy
- **HDL:** Verilog-2001
