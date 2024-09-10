#!/bin/bash
set -ex
# Input parameters
TARGET="${TARGET:-}"
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
ls -a

# Initialize CodeQL
echo "Initializing CodeQL..."
# Download CodeQL CLI
wget https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.18.4/codeql-bundle.tar.gz
tar -xzvf codeql-bundle.tar.gz
export PATH="$PATH:$(pwd)/codeql"
codeql --version

echo "Creating CodeQL database..."
cd "$COMPONENT_PATH" || exit
codeql database create codeql-db --language=cpp --source-root=.
echo "$(pwd)"
ls -a

if [ "$TARGET" = "coding-standard" ]; then
  echo "Performing Coding Standard CodeQL analysis..."
  codeql database analyze codeql-db ../.github/codeql/jpl-misra.qls --format=sarif-latest --output=Codeql-coding-standard.sarif
  echo "$(pwd)"
  ls -a
fi

if [ "$TARGET" = "security" ]; then
  echo "Performing Security CodeQL analysis..."
  codeql database analyze codeql-db ../codeql/qlpacks/codeql/cpp-queries/1.2.2/codeql-suites/cpp-security-and-quality.qls \
  ../codeql/qlpacks/codeql/cpp-queries/1.2.2/codeql-suites/cpp-security-extended.qls \
  --format=sarif-latest --output=Codeql-security.sarif 
  echo "$(pwd)"
  ls -a
fi
