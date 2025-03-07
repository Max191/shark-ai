### Machine Setup ###
If your machine is not setup for mode switching between SPX, QPX, and CPX, then the instructions on how to set it up are located here: https://github.com/nod-ai/playbook/blob/main/HOWTO/Setup/mi3xx.md

The commands in steps `7.` and `8.` show how to set the memory and compute partitions once the machine is set up. **\*\*Note:** The memory partition should be set to `NPS4` before setting compute partition to `CPX` or `QPX` (and `NPS1` for `SPX`).

### Compiling Punet and collecting dispatches to tune ###

1. [Build IREE](https://iree.dev/building-from-source/getting-started/) with tracy (`-DIREE_BUILD_TRACY=ON -DIREE_ENABLE_RUNTIME_TRACING=ON`) and the ROCm target (`-DIREE_TARGET_BACKEND_ROCM=ON -DIREE_HAL_DRIVER_HIP=ON`). To tune horizontal fusion, the horizontal fusion branch is currently needed: https://github.com/iree-org/iree/tree/shared/noconcatHorizontalFusionE2E_feb14

2. Clone the sdxl_on_main branch of sdxl-scripts: https://github.com/nod-ai/sdxl-scripts/tree/shared/sdxl_on_main

3. Compile punet:
```shell
cd sdxl-scripts/int8-model
# Add iree-build/tools to PATH
export PATH=$PATH:/path/to/iree-build/tools
# `14` can be replaced by any supported batch size.
# `none` is used because we don't want to apply any initial tuning spec.
./compile-punet.sh gfx942 none 14
```

4. Capture a trace of the punet benchmark by running `benchmark-punet` while tracy is listening:
```shell
# `0` is the device id (0-63 for CPX, 0-31 for QPX, 0-7 for SPX). `14` is batch size.
./benchmark-unet.sh 0 14 /path/to/sdxl-weights-dir
```
Additional details about tracy: https://iree.dev/developers/performance/profiling-with-tracy/

Punet weights can be obtained through these instructions: https://github.com/nod-ai/playbook/blob/main/HOWTO/Benchmarking/sdxl.md#getting-the-irpa-file-for-punet. The `benchmark-unet.sh` script expects the weights to be saved as `sdxl_unet_int8_dataset.irpa`.

5. Look at the trace and note the top dispatch numbers for matmul and convolution to tune in the next step. The corresponding benchmark files for these dispatches will be located in `sdxl-scripts/int8-model/benchmarks/punet`.

### Running Tuning Setup ###

1. Download tuning setup:

2. Clone the experimental tuning branch of the tuner: https://github.com/Max191/shark-ai/tree/punet-tuning-experimental-branch

3. Follow instructions in `shark-ai/tuner/README.md` to setup tuner environment. There may be issues with numpy version incompatibility, so numpy should be downgraded:
```shell
pip install numpy==1.26.4
```

4. Build IREE with python bindings and source env: https://iree.dev/building-from-source/getting-started/#python-bindings. Use the same python executable that is used in the tuner setup venv for this.\
**\*\*Note:** Some machines require disabling runtime tracing for python bindings to work. (`-DIREE_ENABLE_RUNTIME_TRACING=OFF`).

5. `mkdir shark-ai/tuner/examples/simple/tmp`

6. Unzip the tuning setup (downloaded in step 1) in the `shark-ai/tuner/examples/simple/tmp` directory.

7. Collect all dispatch benchmarks (replace `/path/to/sdxl-scripts/int8-model/benchmarks/punet` with the path to the benchmark files collected during compilation):
```shell
cd shark-ai/tuner/examples/simple/tmp
mkdir top_dispatch_benchmarks
# `dispatch_num_1,dispatch_num_2,dispatch_num_3` are just the numbers for each dispatch you want to tune.
python tuning_setup/collect_benchmarks.py /path/to/sdxl-scripts/int8-model/benchmarks/punet top_dispatch_benchmarks dispatch_num_1,dispatch_num_2,dispatch_num_3,...
```

8. Verify that the collected benchmarks in `top_dispatch_benchmarks` are what you want to tune before proceeding.

9. Run tuner for each benchmark:
```shell
`./tuning_setup/tune_top_dispatches.sh <codegen-pipeline> <chip-configuration-mode> <tunable-dispatches-dir> <model-input-ir>`
```
  - `<codegen-pipeline>` can be either `llvmgpu_tile_and_fuse` or `llvmgpu_vector_distribute`. The tile_and_fuse pipeline is generally preferred, but vector_distribute must be used for horizontal contraction fusion.
  - `<chip-configuration-mode>` is `qpx`, `cpx`, or `spx`.
  - `<tunable-dispatches-dir>` is the directory with the top dispatches i.e., `top_dispatch_benchmarks`.
  - `<model-input-ir>` is the path to the punet model IR. This will be something like `/home/mdawkins/sdxl-scripts/int8-model/base_ir/stable_diffusion_xl_base_1_0_bs1_64_1024x1024_i8_punet.mlir`

10. At the end of tuning (tuning will take a long time), the final spec will be saved in `shark-ai/tuner/examples/simple/tmp/tuning_setup/current_full_spec.mlir`. There will also be temp directories for each dispatch with more detailed logs about the tuned dispatches in `shark-ai/tuner/tuning_*`.
