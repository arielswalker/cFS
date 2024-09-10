#!/bin/bash

TARGET="${TARGET:-}"
CACHE_KEY="${CACHE_KEY:-}"
DEPLOY="${DEPLOY:-true}"
BUILD_PDF="${BUILD_PDF:-true}"
APP_NAME="${APP_NAME:-}"
NEEDS_OSAL_API="${NEEDS_OSAL_API:-true}"

echo "Target: $TARGET"
echo "Cache Key: $CACHE_KEY"
echo "Deploy: $DEPLOY"
echo "Build PDF: $BUILD_PDF"
echo "App Name: $APP_NAME"
echo "Needs OSAL API: $NEEDS_OSAL_API"



echo "Building document for target: $TARGET"

# Handle cache if provided
if [ -n "$CACHE_KEY" ]; then
    echo "Getting cache for key: $CACHE_KEY"
    # Cache logic here (this is just a placeholder)
fi

# Prepare the environment
echo "Checking out repository and preparing build..."
cp ./cfe/cmake/Makefile.sample Makefile
cp -r ./cfe/cmake/sample_defs sample_defs

if [ -n "$APP_NAME" ]; then
    echo "Adding app to build: $APP_NAME"
    echo "set(MISSION_GLOBAL_APPLIST $APP_NAME)" >> sample_defs/targets.cmake
fi

echo "Making prep..."
make prep

echo "Installing dependencies..."
sudo apt-get update && sudo apt-get install -y doxygen graphviz
if [ "$BUILD_PDF" = true ]; then
    sudo apt-get install -y texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
fi

if [ "$NEEDS_OSAL_API" = true ]; then
    echo "Generating OSAL header list..."
    make -C build osal_public_api_headerlist
fi

echo "Building document..."
make -C build $TARGET > "${TARGET}_stdout.txt" 2> "${TARGET}_stderr.txt"

# Move the warnings log to the root
mv build/docs/${TARGET}/${TARGET}-warnings.log .

echo "Checking for errors..."
if grep -q "Error" "${TARGET}_stderr.txt"; then
    echo "Errors found in ${TARGET}_stderr.txt"
    cat "${TARGET}_stderr.txt"
    exit 1
fi

echo "Checking for warnings..."
if [ -s "${TARGET}-warnings.log" ]; then
    cat "${TARGET}-warnings.log"
    exit 1
fi

if [ "$BUILD_PDF" = true ]; then
    echo "Generating PDF..."
    make -C build/docs/${TARGET}/latex
    #  Move the pdf to the root
    mv ./build/docs/${TARGET}/latex/refman.pdf ./${TARGET}.pdf
fi
