#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "msodbcsql_version" odbcinst -j 
check "msodbcsql_location" bash -c "odbcinst -q -d | grep 'msodbcsql18'"

# Report result
reportResults