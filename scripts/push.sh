#!/usr/bin/env bash
# Push using the betroyer GitHub account (bypasses global diobrandedd credentials).
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push "$@"
