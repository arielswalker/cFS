#!/bin/bash

# Input parameters
COMPONENT_PATH="${1:-cFS}"
CATEGORY="${2:-}"
MAKE_COMMAND="${3:-}"
PREP_COMMAND="${4:-make prep}"
SETUP_COMMAND="${5:-cp ./cfe/cmake/Makefile.sample Makefile && cp -r ./cfe/cmake/sample_defs sample_defs}"
TEST_FLAG="${6:-false}"

# Environment Variables
export SIMULATION="native"
export ENABLE_UNIT_TESTS="$TEST_FLAG"
export OMIT_DEPRECATED=true
export BUILDTYPE="release"
export REPO="$(basename "$(pwd)")"


BUILD_DIRECTORY="$(pwd)"
ls

# Setup build system
echo "Setting up build system..."
cd "$BUILD_DIRECTORY"
eval "$SETUP_COMMAND"
eval "$PREP_COMMAND"

# Build the project
echo "Building the project..."
eval "$MAKE_COMMAND"

# Initialize CodeQL
echo "Initializing CodeQL..."
# Download CodeQL CLI
wget https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.18.4/codeql-bundle.tar.gz
tar -xzvf codeql-bundle.tar.gz
cp codeql /usr/local/bin/
codeql --version

# Perform CodeQL Analysis
echo "Performing CodeQL analysis..."
ls
codeql database create codeql-db --language=cpp --source-root=.
codeql analyze codeql-db --config-file=nasa/cFS/.github/codeql/codeql-security.yml --output=results.sarif


# Rename SARIF files
echo "Renaming SARIF files..."
# Assuming SARIF files are located in a directory named 'CodeQL-Sarif'
for scan_type in "security" "coding-standard"; do
    mv "CodeQL-Sarif-${scan_type}/cpp.sarif" "CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif"
    sed -i "s/\"name\" : \"CodeQL\"/\"name\" : \"CodeQL-${scan_type}\"/g" "CodeQL-Sarif-${scan_type}/Codeql-${scan_type}.sarif"
done

# Filter SARIF files
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
