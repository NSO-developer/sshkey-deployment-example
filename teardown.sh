#!/bin/bash
docker compose --profile nso down -v
docker compose --profile example down -v
docker compose --profile dev down -v
rm .env
