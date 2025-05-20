#!/bin/bash
docker stop nso ex2 ex1 ex0
docker volume rm nsoshare
docker network rm ExampleNet
