# Install

The quickest route is the [install picker](https://anon.example/get-started), which gives the command
for your platform and GPU. This page has the details.

## Requirements

| | |
|---|---|
| Python | CPython 3.10, 3.11, 3.12, 3.13 and 3.14 |
| macOS | Apple silicon (arm64). One wheel with Apple Metal GPU support and CPU support. |
| Linux | x86-64. The core wheel plus the `anonlib-nvidia` and `anonlib-amd` GPU packages, installed automatically. |

## pip

```sh
pip install anonlib
```

On Linux x86-64, pip also installs `anonlib-nvidia` and `anonlib-amd`, and anonlib selects the
backend for the GPU it finds. Both platforms also train and predict on the CPU
(see [Devices and the CPU](user_guide/devices.md)).

Optional extras add NumPy without changing any numerical implementation:

```sh
pip install "anonlib[verify]"   # NumPy for verification fixtures
pip install "anonlib[numpy]"    # NumPy-backed conveniences (ANN filtering, TSNE, sequence APIs)
```

A plain `pip install anonlib` is NumPy-free; APIs that need NumPy say so and name the install command.

## GPU architectures in this release

Device code is architecture specific. A GPU architecture the release does not carry needs a source
build; anonlib never substitutes the CPU for a GPU it cannot serve.

| Vendor | Package | Architectures | Examples |
|---|---|---|---|
| Apple | `anonlib` (macOS) | Apple silicon, built at the M1 instruction-set floor | M1 to M4 families |
| NVIDIA | `anonlib-nvidia` | {{nvidia_arches}} | {{nvidia_examples}} |
| AMD | `anonlib-amd` | {{amd_arches}} (exact match required) | {{amd_examples}} |

NVIDIA needs only the driver (`libcuda`); no CUDA toolkit is required. AMD needs the `amdgpu` driver
and the ROCm HIP runtime (`libamdhip64`, ROCm 6 or 7).

## Check your machine

```sh
anonlib doctor
python -m anonlib verify --quick
```

`anonlib doctor` reports what the installed wheel supports on this machine. `verify` checks the
installed package against the reference bits recorded for this release; see
[Verify on your hardware](user_guide/verify.md).

(from-source)=
## From source

A source build targets the GPU in the build machine unless `ANONLIB_GPU_ARCHS` says otherwise.
Building needs the Mojo toolchain, which the repository's `pixi` environment provides:

```sh
git clone https://github.com/anon/anon
cd anonlib
pixi run probe        # reports the toolchain and the device it finds
```

The repository's [CONTRIBUTING](https://github.com/anon/anon/blob/main/CONTRIBUTING.md) guide
describes the build tasks. Check a source build's results with `verify`.
