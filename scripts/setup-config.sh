#!/bin/bash

# Simple setup script - just ensures .env exists
# Actual config substitution is done by containers using envsubst

set -e

if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

echo "✅ .env file found. Containers will use envsubst to substitute variables automatically."
echo "No manual setup needed - just ensure .env is configured correctly."
