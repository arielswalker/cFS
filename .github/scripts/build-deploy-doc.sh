#!/bin/bash

TARGETS=$1
CACHE_KEY=$2
DEPLOY=$3
BUILD_PDF=$4
APP_NAME=$5
NEEDS_OSAL_API=$6

# Convert TARGETS from JSON to an array
TARGETS=$(echo $TARGETS | jq -r '.[]')

# Function to handle document build
build_document() {
    local target=$1

    echo "Building document for target: $target"

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
    make -C build $target > "${target}_stdout.txt" 2> "${target}_stderr.txt"

    # Move the warnings log to the root
    mv build/docs/${target}/${target}-warnings.log .

    echo "Archiving build logs..."
    gh run upload-artifact --name "${target}_doc_build_logs" --path "${target}_stdout.txt,${target}_stderr.txt,${target}-warnings.log"

    echo "Checking for errors..."
    if grep -q "Error" "${target}_stderr.txt"; then
        echo "Errors found in ${target}_stderr.txt"
        cat "${target}_stderr.txt"
        exit 1
    fi

    echo "Checking for warnings..."
    if [ -s "${target}-warnings.log" ]; then
        cat "${target}-warnings.log"
        exit 1
    fi

    if [ "$BUILD_PDF" = true ]; then
        echo "Generating PDF..."
        make -C build/docs/${target}/latex
        mkdir -p deploy
        mv build/docs/${target}/latex/refman.pdf deploy/${target}.pdf

        echo "Archiving PDF..."
        # Archive PDF artifact
        gh run upload-artifact --name "${target}_pdf" --path "deploy/${target}.pdf"
    fi

    if [ "$DEPLOY" = true ]; then
        echo "Deploying PDF to GitHub Pages..."
        npx github-pages-deploy-action@4.1.0 \
            --token "$GITHUB_TOKEN" \
            --branch "gh-pages" \
            --folder "deploy" \
            --single-commit
    fi
}

# Loop through each target
for target in $TARGETS; do
    build_document "$target"
done
