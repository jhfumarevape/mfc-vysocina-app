#!/bin/bash
# Run MFC backend in production mode
cd "$(dirname "$0")"
exec ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 5002 --proxy-headers --forwarded-allow-ips='*'
