#!/bin/bash

# Input variables
STRICT_DIR_LIST="${STRICT_DIR_LIST:-}"
CMAKE_PROJECT_OPTIONS="${CMAKE_PROJECT_OPTIONS:-}"
CPPCHECK_XSLT_PATH="${CPPCHECK_XSLT_PATH:-nasa/cFS/main/.github/scripts}"

# Install dependencies
echo "Installing cppcheck and xsltproc..."
sudo apt-get update
sudo apt-get install cppcheck xsltproc -y

echo "Installing sarif tool..."
npm install @microsoft/sarif-multitool

# Fetch XSLT files
echo "Fetching XSLT files..."
wget -O cppcheck-xml2text.xslt "https://raw.githubusercontent.com/${CPPCHECK_XSLT_PATH}/cppcheck-xml2text.xslt"
wget -O cppcheck-merge.xslt "https://raw.githubusercontent.com/${CPPCHECK_XSLT_PATH}/cppcheck-merge.xslt"

# CMake setup if needed
if [ -n "$CMAKE_PROJECT_OPTIONS" ]; then
  echo "Setting up CMake..."
  cmake -DCMAKE_INSTALL_PREFIX=$(pwd)/staging -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=debug $CMAKE_PROJECT_OPTIONS -S source -B build
  export CPPCHECK_OPTS="--project=$(pwd)/build/compile_commands.json"
else
  export CPPCHECK_OPTS="$(pwd)"
fi

# Run cppcheck
echo "Running general cppcheck..."
cppcheck --force --inline-suppr --xml $CPPCHECK_OPTS 2> cppcheck_err.xml

# Run strict cppcheck if directories are provided
if [ -n "$STRICT_DIR_LIST" ]; then
  echo "Running strict cppcheck..."
  cppcheck --force --inline-suppr --std=c99 --language=c --enable=warning,performance,portability,style --suppress=variableScope --inconclusive --xml $STRICT_DIR_LIST 2> strict_cppcheck_err.xml

  echo "Merging cppcheck results..."
  mv cppcheck_err.xml general_cppcheck_err.xml
  xsltproc --stringparam merge_file strict_cppcheck_err.xml cppcheck-merge.xslt general_cppcheck_err.xml > cppcheck_err.xml
fi

# Convert cppcheck results to SARIF
echo "Converting cppcheck results to SARIF..."
npx "@microsoft/sarif-multitool" convert "cppcheck_err.xml" --tool "CppCheck" --output "cppcheck_err.sarif"

# Convert cppcheck results to Markdown
echo "Converting cppcheck results to Markdown..."
xsltproc cppcheck-xml2text.xslt cppcheck_err.xml | tee cppcheck_err.txt

