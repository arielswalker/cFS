#!/bin/bash
set -e

# Reject non-compatible deployment settings
if [[ "$DEPLOY" == "true" && "$CACHE_KEY" != "" ]]; then
  echo "Deployment when using cache not supported due to password fail issue"
  exit 1
fi

# Get cache if supplied
if [[ "$CACHE_KEY" != "" ]]; then
  actions/cache@v4
fi

# Checkout Bundle Main
if [[ "$APP_NAME" != "" ]]; then
  actions/checkout@v4
fi

# Copy Files
cp ./cfe/cmake/Makefile.sample Makefile
cp -r ./cfe/cmake/sample_defs sample_defs

# Add Repo To Build
if [[ "$APP_NAME" != "" ]]; then
  echo 'set(MISSION_GLOBAL_APPLIST '"$APP_NAME"')' >> sample_defs/targets.cmake
fi

# Make Prep
make prep

# Install Dependencies
sudo apt-get update && sudo apt-get install doxygen graphviz -y

if [[ "$BUILD_PDF" == "true" ]]; then
  sudo apt-get install texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
fi

# Generate OSAL header list
if [[ "$NEEDS_OSAL_API" == "true" ]]; then
  make -C build osal_public_api_headerlist
fi

# Build Document
make -C build "$TARGET" 2>&1 > "$TARGET"_stdout.txt | tee "$TARGET"_stderr.txt
mv build/docs/"$TARGET"/"$TARGET"-warnings.log .

# Archive Document Build Logs
actions/upload-artifact@v4

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
  make -C ./build/docs/"$TARGET"/latex
  mkdir deploy
  mv ./build/docs/"$TARGET"/latex/refman.pdf ./deploy/"$TARGET".pdf
fi

# Archive PDF
if [[ "$BUILD_PDF" == "true" ]]; then
  actions/upload-artifact@v4
fi

# Deploy to GitHub
if [[ "$DEPLOY" == "true" ]]; then
  JamesIves/github-pages-deploy-action@v4
fi
