#!/bin/bash

# Input parameters
COMPONENT_PATH="${COMPONENT_PATH:-cFS}"
CATEGORY="${CATEGORY:-}"
MAKE_COMMAND="${MAKE_COMMAND:-}"
PREP_COMMAND="${PREP_COMMAND:-make prep}"
SETUP_COMMAND="${SETUP_COMMAND:-cp cfe/cmake/Makefile.sample Makefile && cp -r cfe/cmake/sample_defs sample_defs}"
TEST_FLAG="${TEST_FLAG:-false}"

# Environment Variables
export SIMULATION="native"
export ENABLE_UNIT_TESTS="$TEST_FLAG"
export OMIT_DEPRECATED=true
export BUILDTYPE="release"
export REPO="$(basename "$(pwd)")"

echo "Setting up build system..."
eval "$SETUP_COMMAND"
eval "$PREP_COMMAND"

echo "Building..."
eval "$MAKE_COMMAND"

# Initialize CodeQL
echo "Initializing CodeQL..."
# Download CodeQL CLI
wget https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.18.4/codeql-bundle.tar.gz
tar -xzvf codeql-bundle.tar.gz
export PATH="$PATH:$(pwd)/codeql"
codeql --version

echo "Performing CodeQL analysis..."
cd "$COMPONENT_PATH" || exit
ls -a
codeql database create codeql-db --language=cpp --source-root=.
codeql database analyze codeql-db --format=sarif-latest --output=results.sarif --config-file=../.github/codeql/codeql-security.yml 

echo "Renaming SARIF files..."
# Assuming SARIF files are located in a directory named 'CodeQL-Sarif'
for scan_type in "security" "coding-standard"; do
    mv "CodeQL-Sarif-${scan_type}/cpp.sarif" "CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif"
    sed -i "s/\"name\" : \"CodeQL\"/\"name\" : \"CodeQL-${scan_type}\"/g" "CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif"
done

echo "Filtering SARIF files..."
# Use the `filter-sarif` utility to filter SARIF files
# Replace with actual filter command
# filter-sarif --input CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif --output CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif

# Archive SARIF files
echo "Archiving SARIF files..."
# Replace with actual archiving command
# tar -czf "CodeQL-Sarif-${scan_type}.tar.gz" "CodeQL-Sarif-${scan_type}"

# Upload SARIF files
echo "Uploading SARIF files..."
# Replace with actual upload command
# upload-sarif --file CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif
