#!/usr/bin/env bash
# Deploys now happen in GitHub Actions (.github/workflows/backend.yml): tests -> image
# ghcr.io/dettinjo/oratge-backend -> signed Komodo webhook. Push to main, or run it by hand:
exec gh workflow run backend.yml -R dettinjo/oratge --ref main
