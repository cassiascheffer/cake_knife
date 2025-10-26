#!/usr/bin/env bash
set -euo pipefail

# Test runner script for cake_knife
# This script manages the Docker PostgreSQL container and runs tests

COMPOSE_FILE="docker-compose.yml"

# Colours for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

echo_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo_error "Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if Docker Compose is available
if ! command -v docker compose &>/dev/null; then
  echo_error "Docker Compose is not installed. Please install Docker Compose and try again."
  exit 1
fi

# Start the database container
echo_info "Starting PostgreSQL test database..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for the database to be healthy
echo_info "Waiting for database to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
    echo_info "Database is ready!"
    break
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_error "Database failed to become ready in time"
    docker compose -f "$COMPOSE_FILE" logs
    docker compose -f "$COMPOSE_FILE" down
    exit 1
  fi

  echo_warn "Waiting for database... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 1
done

# Run the tests
echo_info "Running tests..."
if gleam test; then
  echo_info "Tests passed!"
  TEST_EXIT_CODE=0
else
  echo_error "Tests failed!"
  TEST_EXIT_CODE=1
fi

# Clean up - stop the container
echo_info "Stopping PostgreSQL test database..."
docker compose -f "$COMPOSE_FILE" down

exit $TEST_EXIT_CODE
