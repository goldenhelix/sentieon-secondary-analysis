#!/bin/bash
set -x
cd "$(dirname "$0")"

echo "Working directory: $(pwd)"
echo "Git version: $(git --version 2>&1)"
echo "Git repo root: $(git rev-parse --show-toplevel 2>&1)"

mkdir -p "${WORKSPACE_DIR}/AppData/VarSeq/User Data/ProjectTemplates"

cp -f ./.project_templates/*.vsproject-template "${WORKSPACE_DIR}/AppData/VarSeq/User Data/ProjectTemplates"

git submodule update --init --recursive
echo "Submodule update exit code: $?"

echo "Submodule status:"
git submodule status

echo "Installed VarSeq project templates"
