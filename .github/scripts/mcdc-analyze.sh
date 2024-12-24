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

for dir in $subdirs; do
    # Get just the module name (strip the parent directory structure)
    module_name=$(basename "$dir")
    
    # Output the current module name
    echo "Processing $module_name module..."
    
    # Find all '.gcda' files in the module directory, convert to '.c' and run gcov
    find "build/native/default_cpu1/$module_name" -name '*.gcda' | sed 's/\.gcda$/.c/' | xargs -I {} sh -c 'gcov -abcg {} | sed "/\.h/,/^$/d"'
done

# Loop over each subdir/module
for dir in $subdirs; do
    # Get just the module name (strip the parent directory structure)
    module_name=$(basename "$dir")
    echo "Processing $module_name module..."
    
    # Initialize module-level counters for each module
    total_functions=0  # To accumulate total functions in the module
    total_covered_functions=0  # To accumulate total covered functions in the module
    file_count=0  # Counter for files with condition data in this module
    no_conditions_count=0  # Counter for files with no condition data in this module
    
    # Process each gcda file in the current subdir (module)
    while IFS= read -r line; do
        # If line contains 'Condition outcomes covered', process it
        if [[ $line == *"Condition outcomes covered:"* ]]; then
            # Extract the coverage percentage and total number of conditions
            condition_covered=$(echo "$line" | grep -oP 'Condition outcomes covered:\K[0-9.]+')  # Extract coverage percentage
            total_conditions_in_file=$(echo "$line" | grep -oP 'of \K[0-9]+')  # Extract total number of conditions
            
            # Calculate the number of covered functions in this file
            covered_functions_in_file=$(awk -v pct="$condition_covered" -v total="$total_conditions_in_file" 'BEGIN {printf "%.2f", (pct / 100) * total}')
            
            # Increment total functions and total covered functions for the module
            total_functions=$((total_functions + total_conditions_in_file))
            total_covered_functions=$(awk -v covered="$total_covered_functions" -v new_covered="$covered_functions_in_file" 'BEGIN {printf "%.2f", covered + new_covered}')
            
            # Increment the file count (this file has condition data)
            file_count=$((file_count + 1))
        elif [[ $line == *"No conditions"* ]]; then
            # If line contains "No conditions", increment the no_conditions_count for this module
            no_conditions_count=$((no_conditions_count + 1))
        fi
    done < <(find "$BASE_DIR/$dir" -name '*.gcda' | sed 's/\.gcda$/.c/' | xargs -I {} sh -c 'gcov -abcg {} | sed "/\.h/,/^$/d"')
    
    # Calculate the average condition coverage percentage for the module
    if [ "$total_functions" -ne 0 ]; then
        # If there are total functions, calculate the condition coverage percentage for this module
        average_condition_coverage=$(awk -v covered="$total_covered_functions" -v total="$total_functions" 'BEGIN {printf "%.2f", (covered / total) * 100}')
    else
        # If there are no functions, set the average coverage to 0
        average_condition_coverage=0
    fi
    
    # Accumulate the results for the overall totals across all modules
    overall_total_functions=$((overall_total_functions + total_functions))
    overall_total_covered_functions=$(awk -v covered="$overall_total_covered_functions" -v new_covered="$total_covered_functions" 'BEGIN {printf "%.2f", covered + new_covered}')
    overall_file_count=$((overall_file_count + file_count))
    overall_no_conditions_count=$((overall_no_conditions_count + no_conditions_count))
    
    # Increment the module count (this module has been processed)
    module_count=$((module_count + 1))
    
    # Output the summary for this specific module
    echo "Summary for $dir module:"
    echo "  Total files processed: $file_count"  # Number of files processed in this module
    echo "  Number of files with no condition data: $no_conditions_count"  # Files with no condition data in this module
    echo "  Condition outcomes covered: ${average_condition_coverage}% of $total_functions"  # Coverage percentage for the module
    echo ""
done

# Calculate the overall total coverage percentage for all modules combined
if [ "$overall_total_functions" -ne 0 ]; then
    # If there are total functions across all modules, calculate the overall condition coverage percentage
    overall_condition_coverage=$(awk -v covered="$overall_total_covered_functions" -v total="$overall_total_functions" 'BEGIN {printf "%.2f", (covered / total) * 100}')
else
    # If no functions, set the overall coverage to 0
    overall_condition_coverage=0
fi

# Output the overall summary for all modules
echo "Overall summary:"
echo "  Total files processed: $overall_file_count"  # Total files processed across all modules
echo "  Number of files with no condition data: $overall_no_conditions_count"  # Total files with no condition data across all modules
echo "  Overall condition outcomes covered: ${overall_condition_coverage}% of $overall_total_functions"  # Overall condition coverage percentage
