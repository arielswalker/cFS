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

# Directory setup
if [ "$COMPONENT_PATH" == "cFS" ]; then
    BUILD_DIRECTORY="$(pwd)"
    echo "Using current directory as build directory: $BUILD_DIRECTORY"
else
    # Clone the cFS repository if not using the default component-path
    echo "Cloning cFS repository..."
    cd ..
    git clone https://github.com/nasa/cFS.git --recurse-submodules
    cd cFS
    BUILD_DIRECTORY="$(pwd)"
    echo "Using cloned cFS repository as build directory: $BUILD_DIRECTORY"
    git log -1 --pretty=oneline
    git submodule
    rm -r .git
    rm -rf "$COMPONENT_PATH"
    ln -s "$(pwd)" "$COMPONENT_PATH"
fi

# Checkout code
echo "Checking out the repository..."
git clone --recursive "https://github.com/${REPO}.git" "$BUILD_DIRECTORY"

# Setup build system
echo "Setting up build system..."
cd "$BUILD_DIRECTORY"
eval "$SETUP_COMMAND"
eval "$PREP_COMMAND"

# Initialize CodeQL
echo "Initializing CodeQL..."
# Note: The CodeQL initialization would typically be done in a GitHub Actions context
# You may need to manually install and run CodeQL commands or use CodeQL CLI
wget https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.18.4/codeql-bundle.tar.gz
tar -xzvf codeql-bundle.tar.gz
ls
cp codeql-bundle /usr/local/bin/
codeql --version


# Build the project
echo "Building the project..."
eval "$MAKE_COMMAND"

# Perform CodeQL Analysis
echo "Performing CodeQL analysis..."
# CodeQL CLI commands for analysis would be added here

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
