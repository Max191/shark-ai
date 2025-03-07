from pathlib import Path
import shutil
import os
import re
import argparse

def get_all_benchmarks(
    benchmarks_path: Path,
    output_path: Path,
    dispatch_numbers: list[int],
):
    if not os.path.exists(benchmarks_path):
        print("Benchmarks directory not found.")
        return
    benchmark_files = {}
    for file in os.listdir(benchmarks_path):
        if "benchmark" not in file:
            continue
        if "initializer" in file:
            continue
        for num in dispatch_numbers:
            if f"dispatch_{num}_" in file:
                benchmark_files[num] = benchmarks_path / file
                break
    if len(benchmark_files) == 0:
        print("No benchmark files found.")
        return
    
    dispatch_types = set()
    i = 0
    for arg in dispatch_numbers:
        if arg not in benchmark_files:
            print(f"Dispatch {arg} not found.")
            continue
        file = benchmark_files[arg]
        with open(file) as f:
            lines = f.readlines()
        already_found = False
        for line in lines:
            matches = re.findall("func\.func @[\w$]+", line)
            if len(matches) == 0:
                continue
            func_name_split = str(matches[0]).split("_")
            if f"dispatch" not in func_name_split:
                continue
            op_name_start = func_name_split.index(f"dispatch") + 2
            dispatch_type = "_".join(func_name_split[op_name_start:])
            if dispatch_type in dispatch_types:
                already_found = True
                break
            dispatch_types.add(dispatch_type)
            break
        
        if already_found:
            print(f"Benchmark {arg} is similar to a benchmark that was already added. Skipping...")
            continue
        out_path = output_path / f"top_{i + 1}_benchmark.mlir"
        shutil.copy(file, out_path)
        i += 1


# Custom arguments for the example tuner file.
parser = argparse.ArgumentParser()
parser.add_argument(
    "benchmarks_dir", type=Path, help="Path to the directory with benchmark files."
)
parser.add_argument(
    "output_dir", type=Path, help="Path to the directory to save extracted benchmarks."
)
parser.add_argument(
    "dispatch_numbers",
    type=lambda t: [int(s) for s in t.split(",")],
    default=[],
    help="Comma-separated list of dispatch numbers to extract.",
)
args = parser.parse_args()

get_all_benchmarks(
    args.benchmarks_dir,
    args.output_dir,
    args.dispatch_numbers,
)
