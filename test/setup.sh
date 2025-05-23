#!/bin/bash

echo "Setting up Python testing environment..."

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    exit 1
fi

echo "Creating virtual environment..."
python3 -m venv .venv

echo "Activating virtual environment..."
source .venv/bin/activate

echo "Installing dependencies..."
echo "   Using pinned versions from requirements.txt for consistency..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Setup complete!"
echo ""
echo "Installed package versions:"
pip list | grep -E "(boto3|botocore|pytest|black)"
echo ""
echo "To activate the environment in the future, run:"
echo "  source activate.sh"
echo ""
echo "To run tests:"
echo "  python test_infrastructure.py"
echo ""
echo "To install with development tools:"
echo "  ./setup.sh --dev"