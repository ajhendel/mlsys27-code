#!/bin/bash
# lane/host-cpu-identity on NVIDIA: the scan check, IVF rebuilt from this branch, the fixed harness on GPU and CPU.
set -uo pipefail
cd "$(dirname "$0")/.."
O=/root/hcid-nv; rm -rf $O; mkdir -p $O
export PATH=/root/.pixi/bin:$PATH ANONLIB_NUMERIC_MODE=identical PYTHONUNBUFFERED=1; unset PYTHONPATH
rc() { echo "$(date -u +%T) $1 rc=$2" >> $O/rc.txt; }
git rev-parse HEAD > $O/head.txt; nvidia-smi --query-gpu=name --format=csv,noheader | head -1 > $O/gpu.txt
pixi install > $O/pixi.log 2>&1
ANONLIB_TARGET_COLUMN=nvidia ANONLIB_GPU_ARCHS=sm_89 timeout 3600 pixi run check-pinned-scan > $O/scancheck.log 2>&1; rc scancheck $?
base=$(pixi run python3 -c 'import sys;print(sys.executable)' | tail -1); $base -m venv $O/venv; PY=$O/venv/bin/python
$PY -m pip -q install anonlib==0.8.32 numpy==2.5.2 scipy==1.18.0 > $O/pip.log 2>&1
SITE=$($PY -c 'import sysconfig;print(sysconfig.get_paths()["purelib"])')/anonlib; T=$SITE/cuda/sm_89/identical
ANONLIB_TARGET_COLUMN=nvidia ANONLIB_GPU_ARCHS=sm_89 bash bindings/build_ivf.sh > $O/build-ivf.log 2>&1; rc build-ivf $?
so=$(ls -t python/anonlib/identical/_anonlib_ivf.so python/anonlib/_anonlib_ivf.so 2>/dev/null | head -1); cp $so $T/_anonlib_ivf.so; sha256sum $so > $O/ivf.sha256
cd /tmp
for col in gpu cpu; do for c in "sgd-reg 20000" "sgd-reg 1000000" "lars 200000" "lars 1000000" "sgd-clf 20000" "lu 1024" "ivf 40000" "ivf 400000"; do set -- $c
  if [ $col = cpu ]; then [ $1 = ivf ] && [ $2 = 400000 ] && continue; export ANONLIB_VENDOR=cpu; PYC=$O/venv-cpu/bin/python; [ -x $PYC ] || { $base -m venv $O/venv-cpu; $PYC -m pip -q install --no-deps anonlib==0.8.32 >/dev/null 2>&1; $PYC -m pip -q install numpy==2.5.2 scipy==1.18.0 >/dev/null 2>&1; }; else unset ANONLIB_VENDOR; PYC=$PY; fi
  timeout 3600 $PYC $OLDPWD/tools/classical_pass_ab.py case $1 $2 --out $O/$col-$1-$2.json > $O/$col-$1-$2.log 2>&1; rc $col-$1-$2 $?
  echo "$col $1 $2 $(python3 -c "import json;d=json.load(open('$O/$col-$1-$2.json'));print(d['digest'][:16], d.get('inputs','')[:16])" 2>&1 | tail -1)" >> $O/digests.txt; done; done
echo done > $O/done
