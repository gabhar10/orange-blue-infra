#!/bin/bash

# Check if script is being sourced (not executed)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced, not executed!"
    echo "Run: source activate.sh"
    echo "Or:  . activate.sh"
    exit 1
fi

# Activate the virtual environment
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    echo "Virtual environment activated"
    echo "Python: $(which python)"
    echo "Pip: $(which pip)"
    
    # Verify boto3 is available
    if python -c "import boto3" 2>/dev/null; then
        echo "boto3 is available"
    else
        echo "boto3 not found - run setup.sh first"
    fi
else
    echo "Virtual environment not found. Run ./setup.sh first"
    return 1  # Use return instead of exit when sourced
fi
