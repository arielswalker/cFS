#!/bin/bash
set -euo pipefail

# Parse arguments
TARGET=$1
APP_NAME=$2
CACHE_KEY=$3
BUILD_PDF=$4
DEPLOY=$5
NEEDS_OSAL_API=$6

# Check if DEPLOY and CACHE_KEY are compatible
if [[ "$DEPLOY" == "true" && -n "$CACHE_KEY" ]]; then
  echo "Deployment when using cache not supported due to password fail issue"
  exit 1
fi

# Get cache if supplied
if [[ -n "$CACHE_KEY" ]]; then
  echo "Restoring cache with key: $CACHE_KEY"
  # Replace with the actual command to restore cache
fi

# Checkout Bundle Main
if [[ -n "$APP_NAME" ]]; then
  echo "Checking out repository nasa/cFS"
  # Replace with the actual checkout command
fi

# Checkout Repo
if [[ -n "$APP_NAME" ]]; then
  echo "Checking out repository with path apps/$APP_NAME"
  # Replace with the actual checkout command
fi

# Copy Files
echo "Copying files"
cp ./cfe/cmake/Makefile.sample Makefile
cp -r ./cfe/cmake/sample_defs sample_defs

# Add Repo To Build
if [[ -n "$APP_NAME" ]]; then
  echo "Adding repo to build"
  echo "set(MISSION_GLOBAL_APPLIST $APP_NAME)" >> sample_defs/targets.cmake
fi

# Make Prep
echo "Running make prep"
make prep

# Install Doxygen Dependencies
echo "Installing Doxygen dependencies"
sudo apt-get update && sudo apt-get install doxygen graphviz -y

# Install PDF Generation Dependencies
if [[ "$BUILD_PDF" == "true" ]]; then
  echo "Installing PDF generation dependencies"
  sudo apt-get install texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
fi

# Generate OSAL header list
if [[ "$NEEDS_OSAL_API" == "true" ]]; then
  echo "Generating OSAL header list"
  make -C build osal_public_api_headerlist
fi

# Build Document
echo "Building document for target: $TARGET"
make -C build "$TARGET" 2>&1 > "$TARGET"_stdout.txt | tee "$TARGET"_stderr.txt
mv build/docs/"$TARGET"/"$TARGET"-warnings.log .

# Archive Document Build Logs
echo "Archiving document build logs"
# Replace with the actual command to upload artifacts

# Check For Document Build Errors
if [[ -s "$TARGET"_stderr.txt ]]; then
  cat "$TARGET"_stderr.txt
  exit 1
fi

# Check For Document Warnings
if [[ -s "$TARGET"-warnings.log ]]; then
  cat "$TARGET"-warnings.log
  exit 1
fi

# Generate PDF
if [[ "$BUILD_PDF" == "true" ]]; then
  echo "Generating PDF"
  make -C ./build/docs/"$TARGET"/latex
  mkdir deploy
  mv ./build/docs/"$TARGET"/latex/refman.pdf ./deploy/"$TARGET".pdf
  # Optionally convert PDF to GitHub markdown
  # pandoc "$TARGET".pdf -t gfm
fi

# Archive PDF
if [[ "$BUILD_PDF" == "true" ]]; then
  echo "Archiving PDF"
  # Replace with the actual command to upload PDF
fi

# Deploy to GitHub
if [[ "$DEPLOY" == "true" ]]; then
  echo "Deploying to GitHub"
  # Replace with the actual deployment command
fi
