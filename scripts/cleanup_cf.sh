#!/usr/bin/env bash
set -euo pipefail

rm -rf testing/cf || true
rm -f testing/locust/locustfile_cf_bustpath.py || true
rm -f testing/locust/locustfile_cf_root_fast.py || true
rm -f testing/locust/locustfile_cf_api.py || true
rm -f testing/locust/locustfile_cf_api_probe.py || true
rm -f testing/locust/run-locust-bustpath.sh || true
rm -f testing/locust/run-locust-cf-api.sh || true
rm -f testing/locust/run-locust-cf-probe.sh || true
rm -f testing/locust/run-cf-fast-master.sh || true
rm -f testing/locust/run-cf-fast-worker.sh || true
echo "[OK] CloudFront-related local scripts removed"
