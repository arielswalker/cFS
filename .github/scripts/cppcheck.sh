#!/bin/bash
set -e

# Install cppcheck and other required tools
echo "Installing cppcheck and other tools..."
sudo apt-get update
sudo apt-get install cppcheck xsltproc -y
npm install @microsoft/sarif-multitool

# Fetch conversion XSLT files
echo "Fetching XSLT files..."
wget -O cppcheck-xml2text.xslt https://raw.githubusercontent.com/${INPUT_CPP_CHECK_XSLT_PATH}/cppcheck-xml2text.xslt
wget -O cppcheck-merge.xslt https://raw.githubusercontent.com/${INPUT_CPP_CHECK_XSLT_PATH}/cppcheck-merge.xslt

# Checkout the repository
echo "Checking out the repository..."
git clone --recurse-submodules https://github.com/${GITHUB_REPOSITORY}.git source
cd source

# CMake setup if required
if [ -n "${INPUT_CMAKE_PROJECT_OPTIONS}" ]; then
    echo "Setting up CMake..."
    cmake -DCMAKE_INSTALL_PREFIX=$GITHUB_WORKSPACE/staging -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=debug ${INPUT_CMAKE_PROJECT_OPTIONS} -S $GITHUB_WORKSPACE/source -B $GITHUB_WORKSPACE/build
    export CPPCHECK_OPTS=--project="$GITHUB_WORKSPACE/build/compile_commands.json"
else
    export CPPCHECK_OPTS="$GITHUB_WORKSPACE/source"
fi

# Run cppcheck
echo "Running cppcheck..."
cppcheck --force --inline-suppr --xml $CPPCHECK_OPTS 2> cppcheck_err.xml

# Run strict cppcheck if specified
if [ -n "${INPUT_STRICT_DIR_LIST}" ]; then
    echo "Running strict cppcheck..."
    cppcheck --force --inline-suppr --std=c99 --language=c --enable=warning,performance,portability,style --suppress=variableScope --inconclusive --xml ${INPUT_STRICT_DIR_LIST} 2> ../strict_cppcheck_err.xml
    mv cppcheck_err.xml general_cppcheck_err.xml
    xsltproc --stringparam merge_file strict_cppcheck_err.xml cppcheck-merge.xslt general_cppcheck_err.xml > cppcheck_err.xml
fi

# Convert cppcheck results to SARIF
echo "Converting cppcheck results to SARIF..."
npx "@microsoft/sarif-multitool" convert "cppcheck_err.xml" --tool "CppCheck" --output "cppcheck_err.sarif"

# Convert cppcheck results to Markdown
echo "Converting cppcheck results to Markdown..."
xsltproc cppcheck-xml2text.xslt cppcheck_err.xml | tee $GITHUB_STEP_SUMMARY cppcheck_err.txt

# Upload SARIF results
echo "Uploading SARIF results..."
gh codeql-action upload-sarif --sarif_file $GITHUB_WORKSPACE/cppcheck_err.sarif --checkout_path $GITHUB_WORKSPACE/source --category 'cppcheck'

# Archive static analysis artifacts
echo "Archiving static analysis artifacts..."
tar -czf cppcheck-errors.tar.gz cppcheck_err.*

# Check for reported errors
echo "Checking for reported errors..."
tail -n 1 cppcheck_err.txt | grep -q '^\*\*0 error(s) reported\*\*$'
