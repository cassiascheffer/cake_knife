# cake_knife Project Instructions

## Project Overview

cake_knife is a Gleam library providing pagination utilities for [Cake](https://hexdocs.pm/cake/) SQL queries. It supports both offset-based pagination (LIMIT/OFFSET) and cursor-based pagination (keyset pagination).

**Core modules:**
- `cake_knife/offset` - Offset-based pagination with page metadata
- `cake_knife/cursor` - Cursor-based pagination with WHERE clause generation

## Testing

### Running Tests

**Always use the test script:**
```bash
./scripts/test.sh
```

This script automatically:
1. Starts PostgreSQL 17.6 and MySQL 8.0 containers via Docker Compose
2. Waits for databases to be ready
3. Runs the full test suite
4. Cleans up containers

**Do NOT:**
- Run `gleam test` directly without starting databases
- Skip integration tests
- Bypass Docker containers for "faster" testing

### Test Types

This project has three integration test suites:
- **Pog integration tests** - PostgreSQL adapter (`test/cake_pog_integration_test.gleam`)
- **Shork integration tests** - MySQL adapter (`test/cake_shork_integration_test.gleam`)
- **Sqlight integration tests** - SQLite adapter (`test/cake_sqlight_integration_test.gleam`)

All three must pass for the test suite to pass.

### Test Parity

When adding features or fixing bugs:
1. Implement tests for ALL three database adapters
2. Maintain test parity across all adapters
3. Ensure behaviour is consistent across PostgreSQL, MySQL, and SQLite

**Example:** If you add cursor pagination for timestamps in pog, you must also add it for shork and sqlight.

## Code Quality

### Gleam Conventions

Follow standard Gleam conventions as outlined in `~/.claude/docs/gleam.md`:
- Use `use` syntax for chaining Result and Option operations
- Prefer pattern matching over if/else
- Keep functions small and focused
- Use descriptive parameter names with labels

### Documentation

This is a library project. Documentation is critical:
- Add doc comments to all public functions and types
- Include code examples in doc comments
- Keep README.md examples up to date
- Test examples in documentation to ensure they compile

### Error Handling

- Use custom error types (`PaginationError`, `CursorError`, `CursorDecodeError`)
- Provide clear, actionable error messages
- Never panic or use `assert` in library code
- Return `Result` types for operations that can fail

## Database-Specific Considerations

### Timestamp Handling

Different databases handle timestamps differently:
- **PostgreSQL (pog):** Uses ISO 8601 format with timezone
- **MySQL (shork):** May have different timestamp precision
- **SQLite (sqlight):** Timestamps are stored as strings or integers

Ensure timestamp comparisons work consistently across all adapters.

### SQL Generation

When generating WHERE clauses for cursor pagination:
- Use parameterised queries (Cake handles this)
- Test generated SQL with actual database queries
- Ensure column types match database schema expectations

## Development Workflow

### Making Changes

1. Create empty planning commits with jj for multi-step features
2. Run tests frequently: `./scripts/test.sh`
3. Update documentation if API changes
4. Maintain test parity across all database adapters

### Before Committing

1. Run full test suite: `./scripts/test.sh`
2. Ensure all three database integrations pass
3. Check that examples in README.md are accurate
4. Format code with `gleam format`

### Common Tasks

**Add new pagination feature:**
1. Implement in core module (`offset.gleam` or `cursor.gleam`)
2. Add tests for pog integration
3. Add tests for shork integration
4. Add tests for sqlight integration
5. Update README.md with examples
6. Add doc comments to new functions

**Fix database-specific bug:**
1. Write failing test for affected adapter
2. Add equivalent tests for other adapters to ensure they don't regress
3. Fix the bug
4. Verify all tests pass

## Project Structure

```
src/cake_knife/
  cursor.gleam      - Cursor pagination (keyset pagination)
  offset.gleam      - Offset pagination (LIMIT/OFFSET)

test/
  cake_pog_integration_test.gleam      - PostgreSQL tests
  cake_shork_integration_test.gleam    - MySQL tests
  cake_sqlight_integration_test.gleam  - SQLite tests
  test_helper/
    pog_test_helper.gleam              - PostgreSQL test utilities
    shork_test_helper.gleam            - MySQL test utilities
    sqlight_test_helper.gleam          - SQLite test utilities
```

## Environment Variables

Tests use environment variables for database connections:

**PostgreSQL:**
- `POSTGRES_HOST` (default: localhost)
- `POSTGRES_PORT` (default: 5432)
- `POSTGRES_USER` (default: postgres)
- `POSTGRES_PASSWORD` (default: postgres)
- `POSTGRES_DB` (default: cake_knife_test)

**MySQL:**
- `MYSQL_HOST` (default: localhost)
- `MYSQL_PORT` (default: 3306)
- `MYSQL_PASSWORD` (default: password)
- `MYSQL_DB` (default: cake_knife_test)

The test script and docker-compose.yml are configured to use these defaults.

## Important Notes

- This is a library, not an application - focus on ergonomics and clear APIs
- Adapter-agnostic design is critical - test all database backends
- Performance matters for cursor pagination - ensure efficient SQL generation
- Security: Never expose raw cursor values - always use encoded cursors