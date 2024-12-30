#!/bin/bash

# Automatically extract subdirectories/modules under the base directory
# This command grabs folder names in base_dir
# subdirs=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sed "s|^$BASE_DIR/||")
# This command grabs file names inside base_dir, does not grab file names inside child folders
subdirs=$(find "$BASE_DIR" -maxdepth 1 -type f | sed -E "s|^$BASE_DIR/([^/]+)\..*|\1|")

# Initialize overall counters
overall_total_functions=0  # To accumulate the total number of functions across all modules
overall_total_covered_functions=0  # To accumulate the total number of covered functions across all modules
overall_file_count=0  # Total number of files processed across all modules
overall_no_conditions_count=0  # Counter for files with no condition data across all modules
module_count=0  # To track the number of modules processed

# Used for testing, outputs what modules are found
# All 99 test modules are found plus queue-test and core-cpu1

# Collect all the module directories
echo "List of found modules:"
for dir in $subdirs; do
    # Get just the module name (strip the parent directory structure)
    module_name=$(basename "$dir")
    
    # Skip core-cpu1 and queue-test
    if [[ "$module_name" == "core-cpu1" || "$module_name" == "queue-test" ]]; then
        continue
    fi
    
    # Search for the module-name.dir folder inside build/native/default_cpu1 (with -testrunner)
    module_dirs=$(find "build/native/default_cpu1" -type d -name "${module_name}.dir")

    # Remove '-testrunner' from the module name
    module_name_no_testrunner=$(echo "$module_name" | sed 's/-testrunner$//')
    
    # Check if the module directories are found
    if [ -n "$module_dirs" ]; then
        echo "$module_name_no_testrunner"
    else
        echo "No directories found for $module_name inside build/native/default_cpu1."
    fi
done

# Show total coverage summary for each module
for dir in $subdirs; do
    # Get just the module name (strip the parent directory structure)
    module_name=$(basename "$dir")
    echo "\nProcessing $module_name module..."

    # Skip core-cpu1 and queue-test
    if [[ "$module_name" == "core-cpu1" || "$module_name" == "queue-test" ]]; then
        continue
    fi
    
    # Remove '-testrunner' from the module name for gcda search
    module_name_no_testrunner=$(echo "$module_name" | sed 's/-testrunner$//')
    
    # Initialize module-level counters
    total_functions=0
    total_covered_functions=0
    file_count=0
    no_conditions_count=0
    
    # Search for the module directory inside build/native/default_cpu1
    module_dirs=$(find "build/native/default_cpu1" -type d -name "${module_name}.dir")
    
    if [ -n "$module_dirs" ]; then
        # Iterate over each found directory
        for module_dir in $module_dirs; do
            echo "Found module directory: $module_dir"
            
            # Get the parent directory of the module directory
            parent_dir=$(dirname "$module_dir")
            
            # Find all '.gcda' files in any nested folder under the parent directory
            echo "Searching for .gcda files under parent directory: $parent_dir..."
            gcda_files=$(find "$parent_dir" -type d -name "*${module_name_no_testrunner}*.dir" -exec find {} -type f -name "*.gcda" \;)
            
            # If there are any .gcda files, run gcov on them
            if [ -n "$gcda_files" ]; then
                for gcda_file in $gcda_files; do
                    # Convert the .gcda file to its corresponding .c file
                    c_file=$(echo "$gcda_file" | sed 's/\.gcda$/.c/')
                    
                    # Run gcov and output the results, ignoring the .h files
                    echo "Running gcov on $c_file..."
                    gcov_output=$(gcov -abcg "$c_file" | sed "/\.h/,/^$/d")
                    
                    # Process the gcov output line by line
                    while IFS= read -r line; do
                        # If line contains 'Condition outcomes covered', process it
                        if [[ $line == *"Condition outcomes covered:"* ]]; then
                            # Extract the coverage percentage and total number of conditions
                            condition_covered=$(echo "$line" | grep -oP 'Condition outcomes covered:\K[0-9.]+')
                            total_conditions_in_file=$(echo "$line" | grep -oP 'of \K[0-9]+')
                            
                            # Calculate the number of covered functions in this file
                            covered_functions_in_file=$(awk -v pct="$condition_covered" -v total="$total_conditions_in_file" 'BEGIN {printf "%.2f", (pct / 100) * total}')
                            
                            # Update module-level counters
                            total_functions=$((total_functions + total_conditions_in_file))
                            total_covered_functions=$(awk -v covered="$total_covered_functions" -v new_covered="$covered_functions_in_file" 'BEGIN {printf "%.2f", covered + new_covered}')
                            
                            # Increment file count (this file has condition data)
                            file_count=$((file_count + 1))
                        elif [[ $line == *"No conditions"* ]]; then
                            # Increment the no_conditions_count for this module
                            no_conditions_count=$((no_conditions_count + 1))
                        fi
                    done <<< "$gcov_output"
                done
            else
                echo "No .gcda files found for $module_name under parent directory $parent_dir."
            fi
        done
    else
        echo "Directory for module $module_name (e.g., ${module_name}.dir) not found inside build/native/default_cpu1."
    fi
    
    # Calculate the average condition coverage for this module
    if [ "$total_functions" -ne 0 ]; then
        average_condition_coverage=$(awk -v covered="$total_covered_functions" -v total="$total_functions" 'BEGIN {printf "%.2f", (covered / total) * 100}')
    else
        average_condition_coverage=0
    fi
    
    # Accumulate the results for overall totals
    overall_total_functions=$((overall_total_functions + total_functions))
    overall_total_covered_functions=$(awk -v covered="$overall_total_covered_functions" -v new_covered="$total_covered_functions" 'BEGIN {printf "%.2f", covered + new_covered}')
    overall_file_count=$((overall_file_count + file_count))
    overall_no_conditions_count=$((overall_no_conditions_count + no_conditions_count))
    
    # Increment the module count
    module_count=$((module_count + 1))
    
    # Output the summary for this specific module
    echo "Summary for $module_name_no_testrunner module:"
    echo "  Total files processed: $file_count"
    echo "  Number of files with no condition data: $no_conditions_count"
    echo "  Condition outcomes covered: ${average_condition_coverage}% of $total_functions"
    echo ""
done

# Calculate the overall total coverage percentage
if [ "$overall_total_functions" -ne 0 ]; then
    overall_condition_coverage=$(awk -v covered="$overall_total_covered_functions" -v total="$overall_total_functions" 'BEGIN {printf "%.2f", (covered / total) * 100}')
else
    overall_condition_coverage=0
fi

# Output the overall summary for all modules
echo "Overall summary:"
echo "  Total files processed: $overall_file_count"
echo "  Number of files with no condition data: $overall_no_conditions_count"
echo "  Overall condition outcomes covered: ${overall_condition_coverage}% of $overall_total_functions"
