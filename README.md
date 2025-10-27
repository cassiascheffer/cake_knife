# cake_knife

A Gleam library providing ergonomic pagination utilities for [Cake](https://hexdocs.pm/cake/) SQL queries.

[![Package Version](https://img.shields.io/hexpm/v/cake_knife)](https://hex.pm/packages/cake_knife)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/cake_knife/)

## Features

- **Offset-based pagination** - Simple page-based navigation using LIMIT/OFFSET
- **Page metadata** - Automatic calculation of total pages, has_next, has_previous
- **Validation** - Built-in validation for page parameters with helpful errors
- **Type-safe** - Fully typed with Gleam's type system
- **Cursor pagination** - Automatic WHERE clause generation for efficient cursor-based pagination
- **Adapter-agnostic** - Works with all Cake adapters (Postgres, SQLite, MySQL, MariaDB)

## Installation

```sh
gleam add cake_knife
```

## Quick Start

### Offset Pagination

```gleam
import cake/select
import cake_knife/offset

pub fn get_users_page(page: Int) {
  select.new()
  |> select.from_table("users")
  |> select.to_query
  |> offset.page(page: page, per_page: 20)
  // Now execute with your database adapter (cake_pog, cake_sqlight, etc.)
}
```

### Cursor Pagination

```gleam
import cake/select
import cake_knife/cursor

pub fn get_posts_after(cursor: Option(cursor.Cursor), limit: Int) {
  let base_query =
    select.new()
    |> select.from_table("posts")
    |> select.order_by_desc("created_at")

  case cursor {
    None -> base_query
    Some(c) -> {
      let cursor_cols = [
        cursor.KeysetColumn("created_at", cursor.Desc, cursor.TimestampType)
      ]
      case cursor.where_after(c, cursor_cols) {
        Ok(where_clause) -> base_query |> select.where(where_clause)
        Error(_) -> base_query
      }
    }
  }
}
```

## Offset Pagination

### Basic LIMIT and OFFSET

```gleam
import cake/select
import cake_knife/offset

select.new()
|> select.from_table("posts")
|> select.to_query
|> offset.limit(10)
|> offset.offset(20)
// Generates: SELECT * FROM posts LIMIT 10 OFFSET 20
```

### Page-based Pagination

```gleam
import cake/select
import cake_knife/offset

// Page 1: OFFSET 0
select.new()
|> select.from_table("posts")
|> select.to_query
|> offset.page(page: 1, per_page: 10)

// Page 2: OFFSET 10
select.new()
|> select.from_table("posts")
|> select.to_query
|> offset.page(page: 2, per_page: 10)
```

### Validated Pagination

```gleam
import cake/select
import cake_knife/offset

let query = select.new() |> select.from_table("posts") |> select.to_query

case cake_knife.paginate(query, page: 1, per_page: 50, max_per_page: 100) {
  Ok(paginated_query) -> {
    // Use paginated_query
  }
  Error(offset.InvalidPage(page)) -> {
    // Handle invalid page number
  }
  Error(offset.InvalidPerPage(per_page)) -> {
    // Handle invalid per_page value
  }
  Error(offset.PerPageTooLarge(per_page, max)) -> {
    // Handle per_page exceeding maximum
  }
}
```

### Working with Page Metadata

```gleam
import cake_knife/offset

// After executing your query and getting results:
let page = offset.new_page(
  data: users,
  page: 2,
  per_page: 10,
  total_count: 47,
)

// Page automatically calculates:
// page.total_pages -> 5
// page.has_previous -> True (page 2 > 1)
// page.has_next -> True (page 2 < 5)
```

## Cursor Pagination

Cake Knife provides automatic WHERE clause generation for cursor-based pagination. Cursor pagination is more efficient for large datasets as it uses cursor values instead of OFFSET, providing consistent performance regardless of page depth.

### Encoding and Decoding Cursors

```gleam
import cake_knife/cursor
import gleam/option.{Some, None}

// Encode cursor values into an opaque cursor
let cursor = cursor.encode(["2024-01-15T10:30:00Z", "12345"])

// Decode a cursor back to values
case cursor.decode(cursor) {
  Ok(values) -> {
    // values == ["2024-01-15T10:30:00Z", "12345"]
    // Use these values in your WHERE clause for cursor pagination
  }
  Error(cursor.InvalidBase64) -> {
    // Handle invalid base64
  }
  Error(cursor.InvalidJson) -> {
    // Handle invalid JSON
  }
  Error(cursor.NotAnArray) -> {
    // Handle wrong JSON structure
  }
}
```

### Working with CursorPage

```gleam
import cake_knife/cursor
import gleam/option.{Some}

// After executing your cursor-based query, construct a CursorPage
let first_item_cursor = cursor.encode(["2024-01-15", "100"])
let last_item_cursor = cursor.encode(["2024-01-20", "150"])

let cursor_page = cursor.CursorPage(
  data: items,
  start_cursor: Some(first_item_cursor),
  end_cursor: Some(last_item_cursor),
  has_next: True,
  has_previous: False,
)
```

### Implementing Cursor Pagination with Postgres/Pog

Cake Knife provides helper functions to automatically build cursor pagination WHERE clauses. Here's a complete example using Postgres with pog for posts ordered by `(created_at DESC, id DESC)`.

```gleam
import cake/adapter/postgres
import cake/select
import cake_knife/cursor
import cake_knife/offset
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

// Your Post type
pub type Post {
  Post(id: Int, created_at: String, title: String)
}

// Decoder for Post
fn post_decoder() {
  use id <- decode.field("id", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use title <- decode.field("title", decode.string)
  decode.success(Post(id:, created_at:, title:))
}

// Define cursor columns once (matches your ORDER BY)
const cursor_columns = [
  cursor.KeysetColumn("created_at", cursor.Desc, cursor.TimestampType),
  cursor.KeysetColumn("id", cursor.Desc, cursor.IntType),
]

// Paginate posts going forward (after a cursor)
pub fn get_posts_after(
  db: postgres.Connection,
  after_cursor: Option(cursor.Cursor),
  limit: Int,
) {
  // Start with base query ordered by (created_at DESC, id DESC)
  let base_query =
    select.new()
    |> select.from_table("posts")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("id")

  // Add WHERE clause for cursor pagination using helper
  let query = case after_cursor {
    None -> base_query
    Some(c) -> {
      use where_clause <- result.try(
        cursor.where_after(c, cursor_columns)
      )
      Ok(base_query |> select.where(where_clause))
    }
  }

  use query <- result.try(query)

  // Fetch one extra item to determine if there's a next page
  let query_with_limit =
    query
    |> select.to_query
    |> offset.limit(limit + 1)

  // Execute query
  use results <- result.try(postgres.run_read_query(
    query_with_limit,
    post_decoder(),
    db,
  ))

  // Check if there are more results
  let has_next = list.length(results) > limit
  let posts = case has_next {
    True -> list.take(results, limit)
    False -> results
  }

  // Create cursors from first and last items
  let start_cursor = case list.first(posts) {
    Ok(post) ->
      Some(cursor.encode([
        post.created_at,
        int.to_string(post.id),
      ]))
    Error(_) -> None
  }
  let end_cursor = case list.last(posts) {
    Ok(post) ->
      Some(cursor.encode([
        post.created_at,
        int.to_string(post.id),
      ]))
    Error(_) -> None
  }

  // Build CursorPage
  Ok(cursor.CursorPage(
    data: posts,
    start_cursor: start_cursor,
    end_cursor: end_cursor,
    has_next: has_next,
    has_previous: option.is_some(after_cursor),
  ))
}
```

**Key Points:**

- Use `where_after()` to automatically build the WHERE clause
- Define `KeysetColumn` list matching your ORDER BY clause
- The helper works with all database adapters (Postgres, SQLite, MySQL, MariaDB)
- Fetch `limit + 1` items to determine if there's a next/previous page
- Cursor values must be strings, so convert numbers with `int.to_string()`
- For best performance, create an index: `CREATE INDEX idx_posts_pagination ON posts(created_at DESC, id DESC)`

**For backward pagination**, use `where_before()` with reversed ORDER BY:

```gleam
use where_clause <- result.try(
  cursor.where_before(before_cursor, cursor_columns)
)

select.new()
|> select.from_table("posts")
|> select.order_by_asc("created_at")  // Reversed
|> select.order_by_asc("id")           // Reversed
|> select.where(where_clause)
// Then reverse the results after fetching
```

## API Reference

See the [Hex documentation](https://hexdocs.pm/cake_knife/) for complete API reference.

### Modules

- **`cake_knife/offset`** - Offset-based pagination (LIMIT/OFFSET)
- **`cake_knife/cursor`** - Cursor-based pagination

### Key Functions

**Offset Pagination (`cake_knife/offset`):**
- `limit(query, count)` - Add LIMIT clause
- `offset(query, count)` - Add OFFSET clause
- `page(query, page, per_page)` - Add LIMIT and OFFSET for page-based pagination
- `paginate(query, page, per_page, max_per_page)` - Validated page-based pagination
- `calculate_total_pages(total_count, per_page)` - Calculate number of pages
- `new_page(data, page, per_page, total_count)` - Create Page with metadata

**Cursor Pagination (`cake_knife/cursor`):**
- `encode(values)` - Encode cursor values into an opaque cursor
- `decode(cursor)` - Decode a cursor back to cursor values
- `from_string(value)` - Create a cursor from a string
- `to_string(cursor)` - Extract the string value from a cursor
- `where_after(cursor, columns)` - Build WHERE clause for forward pagination
- `where_before(cursor, columns)` - Build WHERE clause for backward pagination

### Types

**Offset Pagination (`cake_knife/offset`):**
- `Page(a)` - Offset-based pagination result with metadata
- `PaginationError` - Validation errors for pagination parameters
- `ReadQuery` - Type alias for Cake's ReadQuery type

**Cursor Pagination (`cake_knife/cursor`):**
- `Cursor` - Opaque cursor for cursor-based pagination
- `CursorPage(a)` - Cursor-based pagination result
- `KeysetColumn` - Column definition for cursor pagination (name, direction, and type)
- `OrderDirection` - Sort direction (Asc or Desc)
- `ColumnType` - Data type of a column (StringType, IntType, FloatType, TimestampType)
- `CursorDecodeError` - Errors that can occur when decoding cursors
- `CursorError` - Errors that can occur during cursor pagination
- `ReadQuery` - Type alias for Cake's ReadQuery type

## Examples

Check the `test/` directory for examples of all features.

## Development

### Running Tests

This project uses PostgreSQL and MySQL for integration tests. Tests are run in Docker containers to ensure consistent behaviour across environments.

**Prerequisites:**
- Docker and Docker Compose installed and running

**Running the test suite:**

```sh
# Run tests with Docker databases (recommended)
./scripts/test.sh

# Or manually manage the databases:
docker compose up -d          # Start PostgreSQL and MySQL
gleam test                    # Run tests
docker compose down           # Stop databases
```

The test script automatically:
1. Starts PostgreSQL 17.6 and MySQL 8.0 containers
2. Waits for both databases to be ready
3. Runs the test suite
4. Cleans up the containers

**Environment Variables:**

You can customise the database connections using environment variables:

**PostgreSQL:**
```sh
POSTGRES_HOST=localhost      # Default: localhost
POSTGRES_PORT=5432           # Default: 5432
POSTGRES_USER=postgres       # Default: postgres
POSTGRES_PASSWORD=postgres   # Default: postgres
POSTGRES_DB=cake_knife_test  # Default: cake_knife_test
```

**MySQL:**
```sh
MYSQL_HOST=localhost         # Default: localhost
MYSQL_PORT=3306              # Default: 3306
MYSQL_PASSWORD=password      # Default: password
MYSQL_DB=cake_knife_test     # Default: cake_knife_test
```

**Other Development Commands:**

```sh
gleam run   # Run the project
gleam build # Build the project
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Licence

This project is licensed under the Apache License 2.0.
