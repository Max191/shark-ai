
set -euo pipefail

if (( $# < 7 )); then
  echo "usage: $0 <model-path> <benchmarks-path> <extra-spec-path> <top-dispatch-num> <partitions-per-device> <codegen-pipeline> <num-candidates> [extra-args]"
  exit 1
fi

readonly TUNER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )/../../../.." &> /dev/null && pwd)"
readonly TUNING_SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
readonly MODEL_PATH="${1}"
readonly BENCHMARKS_PATH="${2}"
readonly EXTRA_SPEC_PATH="${3}"
readonly TOP_DISPATCH="$4"
readonly PARTITIONS_PER_DEVICE="$5"
readonly PIPELINE="$6"
NUM_CANDIDATES="$7"
EXTRA_FLAGS="${@:8}"

DEVICES="hip://0"
if ((PARTITIONS_PER_DEVICE != 1)); then
  SECOND_PARTITION=$(($PARTITIONS_PER_DEVICE / 2))
  DEVICES+=",hip://${SECOND_PARTITION}"
fi
for ((i=PARTITIONS_PER_DEVICE; i < 8*PARTITIONS_PER_DEVICE; i+=PARTITIONS_PER_DEVICE)) ; do
  DEVICES+=",hip://${i}"
  if ((PARTITIONS_PER_DEVICE != 1)); then
    SECOND_PARTITION=$(($i + $PARTITIONS_PER_DEVICE / 2))
    DEVICES+=",hip://${SECOND_PARTITION}"
  fi
done

cd "${TUNER_DIR}"
set -x
python -m examples.simple \
    "${MODEL_PATH}" \
    "${BENCHMARKS_PATH}/top_${TOP_DISPATCH}_benchmark.mlir" \
    "--simple-compile-flags-file=${TUNING_SETUP_DIR}/punet_compile_flags.txt" \
    "--simple-model-benchmark-flags-file=${TUNING_SETUP_DIR}/punet_benchmark_flags.txt" \
    "--extra-spec-file=${EXTRA_SPEC_PATH}" \
    "--simple-best-spec-output-path=${EXTRA_SPEC_PATH}" \
    "--devices=${DEVICES}" \
    "--num-candidates=${NUM_CANDIDATES}" \
    --simple-num-dispatch-candidates=80 \
    --simple-num-model-candidates=80 \
    "--codegen-pipeline=${PIPELINE}" \
    --no-reduce-shared-memory-bank-conflicts-options=True,False \
    $EXTRA_FLAGS
