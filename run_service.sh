#!/bin/bash

# Jekyll Local Development Server Startup Script
# This script starts the Jekyll server for local development

echo "Starting Jekyll development server..."
echo "Server will be available at: http://127.0.0.1:4000"
echo "Press Ctrl+C to stop the server"
echo ""

bundle exec jekyll serve
