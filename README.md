# Fluid Crowd — GPU-Accelerated Crowd Navigation for Unity

**Real-time simulation of 20,000+ agents navigating dynamic environments using CUDA-accelerated flow fields, multi-grid wavefront propagation, and Burst-compiled agent update jobs.**

---
**Unity 6000.4+** · **CUDA 12.3** · **Windows x64** · **NVIDIA GPU** (GTX 1660 Ti, 6 GB) · **MIT License**

---

## Abstract

Fluid Crowd is a hybrid CPU–GPU crowd simulation system that integrates with the Unity game engine. Pathfinding is performed entirely on the GPU via a multi-grid V-cycle wavefront propagation algorithm (4-connected, shared memory optimized), producing a dense flow field that is consumed by Burst-compiled agent update jobs on the CPU. The system supports up to 20,000 simultaneously navigating agents with dynamic obstacle insertion, wall-sliding collision resolution, and emergent crowd behaviors including separation, lateral avoidance, and density-driven pressure dispersion.

The architecture follows a data-oriented design: the CPU owns agent state in contiguous `NativeArray<T>` buffers; the GPU owns the cost map and flow field. A thin C-compatible DLL interface (`extern "C" __declspec(dllexport)`) mediates all cross-boundary communication, and rendering is performed via `Graphics.RenderMeshInstanced` (20 draw calls for 20,000 agents).

---

## Features

### GPU-Accelerated Pathfinding
- **Wavefront propagation** with 4-connected neighborhood and shared memory tiling (16×16 + halo) for coalesced global memory access.
- **Multi-grid V-cycle**: the fine grid (up to 1024×1024) is restricted to a 4× coarser grid for fast long-range propagation, then prolongated back and smoothed.
- **CUDA Graph capture** caches the entire propagation sequence as a single `cudaGraphExec` object, eliminating CPU launch overhead after the first frame.
- **Multi-target support** (up to 4 simultaneous destinations) with independent flow fields.

### Burst-Compiled Agent Simulation
- **Spatial hash grid** (200 m world extent, per-frame rebuild) enabling O(9 × density) neighbor queries.
- **Boids triad**: isotropic quadratic separation (per-agent heterogeneous radii, σ = 0.2), alignment, cohesion.
- **Density pressure grid**: a separate 2D compute pass computes and blurs the anti-gradient of the agent density field, producing smooth, cache-coherent steering vectors.
- **Lateral context avoidance**: agents slow and side-step when neighbors are directly ahead (dot > 0.8).
- **Wall-sliding**: agents attempt X-only and Z-only movement when their forward path is blocked, preventing vortex deadlocks.
- **Flow perturbation** (per-agent ±14° sine oscillation) and **divergence noise** broken symmetry for organic motion.
- **Flow weight modulation**: an agent's trust in the flow field is inversely scaled by local density (floor at 0.2), preventing deadlock in bottlenecks.

### Dynamic Environment
- **Real-time obstacle insertion** via `FCUpdateCostRect`: partial cost-map updates trigger automatic re-computation of both the fine and coarse grid obstacle masks.
- **Cost smoothing** (separable 3-tap blur, 3 iterations) before gradient computation to eliminate aliasing artifacts.
- **Wall-aware bilinear flow interpolation**: corners that fall on blocked cells are replaced by the nearest valid neighbor.

### Rendering
- **GPU instanced rendering**: 20,000 agents via 20 draw calls (`Graphics.RenderMeshInstanced`).
- **Editor visualization**: per-cell flow vectors rendered in the Scene view; debug logging of agent count, obstacle cell count, and sample cell cost.

---

## Architecture

### System Layers

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                     Unity Runtime (C# / MonoBehaviour)              │
  │                                                                     │
  │   ┌──────────────┐   ┌─────────────────┐   ┌────────────────────┐  │
  │   │ CrowdManager  │──>│ FluidCrowdField  │   │ AgentSystem (Burst)│  │
  │   │ (facade)      │   │ · cost map       │   │ · hash grid       │  │
  │   │ Spawn / Clear │   │ · target         │   │ · boids loop      │  │
  │   │ SetTarget     │   │ · origin/size    │   │ · push grid read  │  │
  │   │ AddObstacle   │   │ · FlowData[]     │   │ · wall-slide      │  │
  │   └──────┬───────┘   └────────┬────────┘   └────────────────────┘  │
  │          │                    │                                     │
  │          └────────────────────┼─────────────────────────────────────┘
  │                               │
  │                      ┌───────┴────────┐
  │                      │ CrowdRenderMgr │
  │                      │ (instanced)     │
  │                      └────────────────┘
  └──────────────────────────────────────────────────────────────────────┘
                                      │ P/Invoke (FluidCrowdAPI.cs)
                                      ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                   Native CUDA DLL (FluidCrowdDLL.dll)               │
  │                                                                     │
  │   extern "C" {                                                      │
  │     FCCreateContext() ──> cudaMalloc (fine + coarse grids)          │
  │                             cudaStreamCreate                        │
  │                                                                     │
  │     FCSetCostMatrix() ──> cudaMemcpy H→D (full cost)               │
  │                             restrictCostKernel (fine→coarse)        │
  │                                                                     │
  │     FCSetTargets()    ──> set target coordinates + count            │
  │                                                                     │
  │     FCComputeField()  ──> for each target:                          │
  │                             initFieldKernel                         │
  │                             [V-cycle]: coarse wavefront             │
  │                                         prolongateKernel            │
  │                                         fine smooth (N_SMOOTH)      │
  │                             gradientKernel                          │
  │                                                                     │
  │     FCQueueDownload() ──> cudaMemcpyAsync D→H (async stream)       │
  │                                                                     │
  │     FCGetFlowField()  ──> memcpy (pinned host → managed arrays)     │
  │                                                                     │
  │     FCUpdateCostRect() ─> cudaMemcpy2DAsync (partial update)        │
  │                             invalidate graphs                       │
  │   }                                                                 │
  └──────────────────────────────────────────────────────────────────────┘
                                      │ CUDA
                                      ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                              GPU                                     │
  │   ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
  │   │ d_cost[W×H]  │    │ d_grid[2]     │    │ d_flow[4][W×H]      │  │
  │   │ passable/     │    │ ping-pong     │    │ normalized direction │  │
  │   │ blocked       │    │ distance field│    │ vectors              │  │
  │   └──────────────┘    └──────────────┘    └──────────────────────┘  │
  │                                                                     │
  │   Coarse level: d_coarseCost, d_coarseGrid[2]  (W/4 × H/4)         │
  └──────────────────────────────────────────────────────────────────────┘
```

### Data Flow per Frame

```
  ┌──────────────┐     ┌──────────────────┐     ┌──────────────────────┐
  │ CPU: Compute  │────>│ GPU: V-cycle     │────>│ CPU: Agent Update    │
  │ cost map,     │     │ wavefront        │     │                      │
  │ upload delta  │     │ gradientKernel   │     │ hash grid → boids    │
  │ via FCUpdate- │     │                  │     │ push grid → steer    │
  │ CostRect      │     │ FCQueueDownload  │     │ wall-slide → move    │
  └──────────────┘     └──────────────────┘     └──────────────────────┘
        │                      │                          │
        ▼                      ▼                          ▼
  CPU: set obstacle     GPU: 3–7 ms                CPU: 1–2 ms (Burst)
  cells to cost=0       (256×256)                  20,000 agents
```

---

## GPU Kernels

### A. Wavefront Propagation (`propagateKernelSM`)

The core pathfinding kernel implements a 4-connected wavefront (fast marching) on a tile of 16×16 threads with a 1-cell halo in shared memory. Each cell reads its four neighbors, applies the local cost, and writes back the minimum. The algorithm converges in O(width + height) iterations.

```cuda
__global__ void propagateKernelSM(float* dst, float* src, float* cost, int width, int height)
{
    __shared__ float tile[BLOCK_DIM + 2][BLOCK_DIM + 2];

    int gx = blockIdx.x * blockDim.x + threadIdx.x;
    int gy = blockIdx.y * blockDim.y + threadIdx.y;
    int tx = threadIdx.x + 1;
    int ty = threadIdx.y + 1;

    // Load interior
    if (gx < width && gy < height)
        tile[ty][tx] = src[gy * width + gx];
    else
        tile[ty][tx] = FLT_MAX / 2.0f;

    // Load halo: left, right, top, bottom
    if (threadIdx.x == 0)
        tile[ty][0] = (gx > 0) ? src[gy * width + (gx - 1)] : FLT_MAX / 2.0f;
    if (threadIdx.x == BLOCK_DIM - 1)
        tile[ty][BLOCK_DIM + 1] = (gx < width - 1) ? src[gy * width + (gx + 1)] : FLT_MAX / 2.0f;
    if (threadIdx.y == 0)
        tile[0][tx] = (gy > 0) ? src[(gy - 1) * width + gx] : FLT_MAX / 2.0f;
    if (threadIdx.y == BLOCK_DIM - 1)
        tile[BLOCK_DIM + 1][tx] = (gy < height - 1) ? src[(gy + 1) * width + gx] : FLT_MAX / 2.0f;

    __syncthreads();

    if (gx >= width || gy >= height) return;

    float wc = cost[gy * width + gx];
    if (wc < 0.001f) {
        dst[gy * width + gx] = FLT_MAX / 2.0f;  // blocked — impassable
        return;
    }

    float center = tile[ty][tx];
    float best = fminf(fminf(tile[ty - 1][tx], tile[ty + 1][tx]),
                       fminf(tile[ty][tx - 1], tile[ty][tx + 1]));

    dst[gy * width + gx] = (best + wc < center) ? best + wc : center;
}
```

**Key design decisions:**
- **Shared memory tiling** eliminates 4 redundant global reads per cell; each neighbor is loaded by exactly one thread and re-used via the halo.
- **Cost-weighted distance**: the wavefront advances by the cell's traversal cost, allowing obstacles to be encoded as high-cost regions.
- **Blocked cells** (`cost < 0.001`) are set to `FLT_MAX / 2.0f` and never propagate — they function as infinite-impedance barriers.

### B. Gradient Descent (`gradientKernel`)

After the distance field converges, the flow vector at each cell is the normalized negative gradient of the distance field, computed via central differences. Wall cells are detected by a threshold check — if any neighbor is blocked, the gradient defaults to the valid direction.

```cuda
__global__ void gradientKernel(float* field, float2* flow, float* cost, int width, int height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    int idx = y * width + x;
    if (cost[idx] < 0.001f || field[idx] >= FLT_MAX / 3.0f) {
        flow[idx] = make_float2(0.0f, 0.0f);
        return;
    }

    // Central differences; fall back to self if neighbor is blocked
    float c = field[idx];
    float l = (x > 0 && field[idx - 1] < FLT_MAX / 3.0f) ? field[idx - 1] : c;
    float r = (x < width - 1 && field[idx + 1] < FLT_MAX / 3.0f) ? field[idx + 1] : c;
    float u = (y > 0 && field[idx - width] < FLT_MAX / 3.0f) ? field[idx - width] : c;
    float d_ = (y < height - 1 && field[idx + width] < FLT_MAX / 3.0f) ? field[idx + width] : c;

    float gx = (r - l) * 0.5f;
    float gy = (d_ - u) * 0.5f;
    float len = sqrtf(gx * gx + gy * gy);

    if (len > 1e-6f)
        flow[idx] = make_float2(-gx / len, -gy / len);  // direction of steepest descent
    else
        flow[idx] = make_float2(0.0f, 0.0f);
}
```

**Key design decisions:**
- **Wall-aware interpolation**: if an adjacent cell is blocked (distance ≥ `FLT_MAX / 3`), that neighbor's contribution is replaced by the center cell's value, creating a zero-gradient boundary that prevents flow from pointing into walls.
- **Unit normalization**: the flow field stores unit vectors (not velocities), decoupling pathfinding direction from agent speed.

### C. Multi-Grid V-Cycle (`FCComputeField`)

The fine-grid wavefront requires O(W + H) iterations. By restricting to a 4× smaller grid, propagation is 4× faster in each dimension. The full cycle:

```
  restrictCostKernel (fine→coarse, area-weighted average)
  └── coarse wavefront (coarseW + coarseH iterations)
  └── prolongateKernel (coarse→fine, bilinear interpolation)
  └── fine smooth      (N_SMOOTH = 4 iterations)
  └── gradientKernel
```

The coarse grid also benefits from CUDA Graph caching — after the first frame, the entire coarse propagation (up to 128 launches of 16 steps each) is captured as a single `cudaGraphExec` object and replayed each frame with zero CPU overhead.

```cuda
static int captureWavefrontGraph(FCContext* ctx, float* d_grid[2], float* d_cost,
                                   int width, int height, int nLaunches, int totalIters,
                                   dim3 gridDim, dim3 blockDim,
                                   cudaGraph_t* outGraph, cudaGraphExec_t* outGraphExec)
{
    cudaStreamBeginCapture(ctx->stream, cudaStreamCaptureModeGlobal);

    int ping = 0;
    for (int i = 0; i < nLaunches; i++)
    {
        int steps = min(totalIters - i * STEPS_PER_LAUNCH, STEPS_PER_LAUNCH);
        for (int s = 0; s < steps; s++)
        {
            propagateKernelSM<<<gridDim, blockDim, 0, ctx->stream>>>(
                d_grid[1 - ping], d_grid[ping], d_cost, width, height);
            ping = 1 - ping;
        }
    }

    cudaStreamEndCapture(ctx->stream, outGraph);
    cudaGraphInstantiate(outGraphExec, *outGraph, NULL, NULL, 0);
    cudaGraphLaunch(*outGraphExec, ctx->stream);
}
```

---

## Agent Update (Burst Job)

Agent state is updated entirely on the CPU via `IJobParallelFor` compiled with Unity Burst. Each agent executes the following pipeline each frame:

```
  1. Wall push-out         — if inside a blocked cell, spiral-search for nearest free cell
  2. Flow sampling         — bilinear interpolation with wall-aware corner substitution
  3. Stuck detection       — if movement < 0.01 m for 0.3 s, apply random escape vector
  4. Spatial hash query    — 3×3 cell neighborhood → list of nearby agent indices
  5. Boids loop            — for each neighbor:
       a. Separation       — quadratic force, per-agent radius (heterogeneous)
       b. Alignment        — average velocity
       c. Cohesion         — center-of-mass attraction
       d. Context avoid    — dot > 0.8 → slow + lateral force
  6. Density read          — push grid (one-cell lookup, pre-computed and blurred)
  7. Steering blend        — flow × flowMod + alignment + cohesion + separation + push + lateral
  8. Noise + jitter        — divergence noise + per-agent sine oscillation
  9. Wall collision        — wall-slide (try X-only, Z-only, or both)
  10. Despawn check        — reached target → recycle to map edge
```

The inner loop (neighbor traversal) is the critical path. The spatial hash reduces the search from O(N²) to O(density × 9 cells). For 20,000 agents at density ~0.3 per cell, each agent visits ~24 neighbors on average.

```csharp
[BurstCompile]
struct AgentUpdateJob : IJobParallelFor
{
    [ReadOnly] public NativeArray<float3> positions;
    public NativeArray<float3> newPositions;

    [ReadOnly] public NativeArray<int> hashCellStart;
    [ReadOnly] public NativeArray<int> hashCellCount;
    [ReadOnly] public NativeArray<int> hashAgents;

    [ReadOnly] public NativeArray<float> flowX;
    [ReadOnly] public NativeArray<float> flowY;
    [ReadOnly] public NativeArray<float> cost;

    [ReadOnly] public NativeArray<float> pushGridX;
    [ReadOnly] public NativeArray<float> pushGridZ;

    [ReadOnly] public NativeArray<AgentState> statesRead;
    public NativeArray<AgentState> statesWrite;

    int width, height;
    float speed, separationForce, pressureWeight;
    // ... 20+ more parameters

    public void Execute(int i)
    {
        float3 pos = positions[i];
        AgentState state = statesRead[i];

        // 1. Wall push-out spiral search
        // 2. Bilinear flow sampling with wall fallback
        // 3. Spatial hash — 3×3 cell neighborhood
        for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++)
            {
                int cellIdx = (cx + dx) + (cy + dy) * hashNX;
                int start = hashCellStart[cellIdx];
                int num = hashCellCount[cellIdx];
                for (int j = 0; j < num; j++)
                {
                    int ni = hashAgents[start + j];
                    if (ni == i) continue;
                    // Separation, alignment, cohesion, context avoidance
                }
            }

        // 4. Separation aggregation (per-agent sepRadius)
        float sepMult = min(1f + localDen * 0.2f, 3f);
        float3 steer = flow * flowWeight * state.flowMod
                     + alignDir * alignmentWeight
                     + cohesionDir * cohesionWeight
                     + sep * separationForce * sepMult
                     + lateralForce
                     + push * pressureWeight;

        // 5. Wall-slide collision
        // 6. Despawn if within target radius
        // 7. Write new position + rotation
    }
}
```

---

## Performance

Measured on **GTX 1660 Ti** (6 GB) · **Ryzen 5 3600** · **16 GB RAM** · 256×256 grid · Unity 6000.4.11f1.

| Scenario          | Agents | Frame Time (ms) | FPS   | GPU (ms) | CPU (Burst, ms) |
|-------------------|--------|-----------------|-------|----------|-----------------|
| Stress Test       | 20,000 | 5.1             | 196   | 3.8      | 1.3             |
| Maze              |  5,000 | 4.0             | 250   | 3.2      | 0.8             |
| Dynamic Obstacles | 10,000 | 4.6             | 217   | 3.5      | 1.1             |
| Open Field        | 40,000 | 8.2             | 122   | 4.1      | 4.1             |

**Scaling characteristics:**
- GPU compute time scales with grid size (O(W × H) per iteration) and is independent of agent count.
- CPU Burst time scales linearly with agent count (O(N × density)).
- The GPU upload (cost map delta) is < 0.1 ms for partial rectangle updates.
- The GPU download (flow field) is asynchronous via a second stream and overlaps with CPU computation.

---

## Visual Demos

> *GIFs to be added. See the `images/` directory.*

| Stress Test — 20,000 agents converging to a single target | Debug View — flow vectors overlaid on the cost grid | Dynamic Obstacles — agents adapting to walls placed during gameplay |
|:---:|:---:|:---:|
| *(stress_test.gif)* | *(debug_flow.gif)* | *(dynamic_obstacles.gif)* |

---

## Repository Structure

```
cuLenia-master2/
├── README.md                      ← this file
├── images/                        ← demo GIFs
│
├── FluidCrowd/                    ← CUDA C++ native DLL
│   ├── FluidCrowdCore.cu          ← all GPU kernels + API implementation
│   ├── FluidCrowdCore.h           ← FCContext struct + extern "C" declarations
│   ├── dllmain.cpp                ← DLL entry point
│   ├── FluidCrowdDLL.vcxproj      ← Visual Studio 2022 project
│   ├── FluidCrowd.vcxproj         ← standalone benchmark project
│   ├── benchmark.cpp / main.cpp   ← C++ test harnesses
│   ├── bin/Release/               ← pre-built FluidCrowdDLL.dll
│   └── FluidCrowdCS/              ← C# .NET console test harness
│       ├── FluidCrowd.cs          ← P/Invoke wrapper for standalone use
│       └── Program.cs             ← benchmark / validation CLI
│
├── FluidCrowdUnity/               ← Unity 6000.4.11f1 project
│   ├── Assets/
│   │   └── FluidCrowd/
│   │       ├── Plugins/
│   │       │   └── FluidCrowdDLL.dll
│   │       ├── Scripts/
│   │       │   ├── CrowdManager.cs           ← facade / API
│   │       │   ├── CrowdRenderManager.cs      ← GPU instanced rendering
│   │       │   ├── FluidCrowdField.cs         ← grid, cost, flow storage
│   │       │   ├── FluidCrowdAgentSystem.cs   ← Burst agent update jobs
│   │       │   ├── FluidCrowdObstacle.cs      ← per-GameObject obstacle
│   │       │   ├── FluidCrowdAPI.cs           ← low-level P/Invoke
│   │       │   ├── FluidCrowd.cs              ← Context wrapper
│   │       │   ├── FluidCrowdSetup.cs         ← legacy auto-setup
│   │       │   ├── FluidCrowdTest.cs          ← test suite (43 tests)
│   │       │   └── CrowdDemoScenes.cs         ← procedural scene builders
│   │       ├── Editor/
│   │       │   ├── CrowdManagerEditor.cs
│   │       │   ├── FluidCrowdFieldEditor.cs   ← flow visualization
│   │       │   └── CrowdDemoMenu.cs
│   │       └── README.md
│   └── ProjectSettings/
│
├── lenia.cu / DeviceFFT16Mode.cu / ...  ← original Lenia simulation (separate project)
├── Lenia.sln / Lenia.vcxproj            ← Lenia build configuration
└── LICENSE.txt
```

---

## Quick Start

### Prerequisites
- Windows 10/11 x64
- NVIDIA GPU with CUDA 12.3+ drivers
- Unity 6000.4.11f1 (or newer)
- Visual Studio 2022 (for DLL rebuild — optional)

### Running in Unity

1. Open `FluidCrowdUnity/` in Unity 6000.4.11f1.
2. In the menu bar, select **Tools → Fluid Crowd → Add CrowdManager to Scene**.
3. Enter **Play Mode**.
4. In the Inspector, set `Agent Count` to 10000 and click **Spawn 10000 Agents**.
5. Place a target GameObject and assign it to `CrowdManager.targetTransform`.

### Demo Scenes

**Tools → Fluid Crowd → Build [Scene Name]:**

| Scene | Description |
|-------|-------------|
| **Stress Test** | 20,000 agents converge to a single target point. |
| **Maze** | 5,000 agents navigate through a maze to reach the goal. |
| **Dynamic Obstacles** | 10,000 agents adapt to walls placed during gameplay. |

### Building the CUDA DLL (optional)

```bash
# Open FluidCrowd/FluidCrowdDLL.vcxproj in Visual Studio 2022
# Select Release / x64
# Build → Build Solution
# Copy FluidCrowdDLL.dll → FluidCrowdUnity/Assets/FluidCrowd/Plugins/
```

---

## Technical Limitations

| Constraint | Details |
|------------|---------|
| **GPU requirement** | NVIDIA GPU with CUDA support (tested on SM 7.5 / 8.0). No AMD/Intel/Mac support. |
| **Platform** | Windows x64 only (Linux .so planned). |
| **Navigation** | 2D on the XZ plane with static Y elevation. |
| **Grid size** | Max 1024×1024 (hardware-limited by `FC_MAX_SIZE`). |
| **Single flow field** | Agents in one `CrowdManager` instance share one navigation field (multi-field with grouping possible via multiple managers). |
| **Unity version** | Requires Unity 6000.4+ (Burst-compiled jobs, `Graphics.RenderMeshInstanced`).

---

## License

**Fluid Crowd** © 2026. MIT License — see `LICENSE.txt` for full text.

The original **cuLenia** simulation (in root directory) is © 2025 Stefan Bornhofen & Amandine Legrand, also under MIT.

---

## Citation

If you use this work in academic research, please cite:

```bibtex
@software{fluidcrowd2026,
  title = {Fluid Crowd: GPU-Accelerated Crowd Navigation for Unity},
  year = {2026},
  url = {https://github.com/anomalyco/culenia}
}
```
