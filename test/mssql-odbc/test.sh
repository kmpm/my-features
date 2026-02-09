#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
# check "step1" dpkg -p msodbcsql18
# check "opt_microsoft" test -d "/opt/microsoft"
check "msodbcsql_version" odbcinst -j 
# check "msodbcsql_location" bash -c "odbcinst -q -d | grep 'msodbcsql18'"

# Report result
reportResults