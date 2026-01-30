#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "nats_version" nats --version
check "nsc_version" nsc --version

# Report result
reportResults