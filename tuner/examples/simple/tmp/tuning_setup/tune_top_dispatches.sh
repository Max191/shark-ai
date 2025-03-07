
set -uo pipefail

if (( $# != 5 )); then
  echo "usage: $0 <codegen-pipeline> <chip-configuration-mode> <num-tunable-dispatches> <tunable-dispatches-dir> <model-input-ir>"
  exit 1
fi

readonly TUNING_SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
readonly CODEGEN_PIPELINE="${1}"
readonly CHIP_CONFIGURATION="${2}"
readonly NUM_DISPATCHES="${3}"
readonly BENCHMARKS_PATH="$(realpath $4)"
readonly MODEL_IR="$(realpath $5)"

if ! [[ "${CHIP_CONFIGURATION}" =~ ^(cpx|qpx|spx)$ ]]; then
  echo "Allowed chip-configuration-modes: cpx, qpx, spx"
  exit 1
fi

PARTITIONS_PER_DEVICE=4
if [[ "$CHIP_CONFIGURATION" == "cpx" ]]; then
  PARTITIONS_PER_DEVICE=8
fi
if [[ "$CHIP_CONFIGURATION" == "spx" ]]; then
  PARTITIONS_PER_DEVICE=1
fi

if ! [[ "${CODEGEN_PIPELINE}" =~ ^(llvmgpu_tile_and_fuse|llvmgpu_vector_distribute)$ ]]; then
  echo "Allowed codegen-pipelines: llvmgpu_tile_and_fuse, llvmgpu_vector_distribute"
  exit 1
fi

rm "${TUNING_SETUP_DIR}/current_full_spec.mlir"
touch "${TUNING_SETUP_DIR}/current_full_spec.mlir"

# Placeholders for now. Running model in the loop tuning has not been helpful,
# but the tuner setup could be used with model in the loop later.
touch "${TUNING_SETUP_DIR}/punet_compile_flags.txt"
touch "${TUNING_SETUP_DIR}/punet_benchmark_flags.txt"

set -x

for ((i=1; i <= NUM_DISPATCHES; i++)) ; do
  ${TUNING_SETUP_DIR}/run_dispatch_tuning.sh \
      "$MODEL_IR" \
      "$BENCHMARKS_PATH" \
      "${TUNING_SETUP_DIR}/current_full_spec.mlir" \
      $i \
      $PARTITIONS_PER_DEVICE \
      $CODEGEN_PIPELINE \
      6000 \
      --stop-after=benchmark-dispatches
done