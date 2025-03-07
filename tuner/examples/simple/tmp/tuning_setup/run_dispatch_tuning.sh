
set -euo pipefail

if (( $# < 7 )); then
  echo "usage: $0 <model-path> <benchmark-path> <extra-spec-path> <partitions-per-device> <codegen-pipeline> <num-candidates> [extra-args]"
  exit 1
fi

readonly TUNER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )/../../../.." &> /dev/null && pwd)"
readonly TUNING_SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
readonly MODEL_PATH="${1}"
readonly BENCHMARK_PATH="${2}"
readonly EXTRA_SPEC_PATH="${3}"
readonly PARTITIONS_PER_DEVICE="$4"
readonly PIPELINE="$5"
NUM_CANDIDATES="$6"
EXTRA_FLAGS="${@:7}"

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
    "${BENCHMARK_PATH}" \
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
