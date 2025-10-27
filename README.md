# cake_knife

A Gleam library providing ergonomic pagination utilities for [Cake](https://hexdocs.pm/cake/) SQL queries.

[![Package Version](https://img.shields.io/hexpm/v/cake_knife)](https://hex.pm/packages/cake_knife)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/cake_knife/)

## Features

- **Offset-based pagination** - Simple page-based navigation using LIMIT/OFFSET
- **Page metadata** - Automatic calculation of total pages, has_next, has_previous
- **Validation** - Built-in validation for page parameters with helpful errors
- **Type-safe** - Fully typed with Gleam's type system
- **Keyset pagination** - Automatic WHERE clause generation for efficient cursor-based pagination
- **Adapter-agnostic** - Works with all Cake adapters (Postgres, SQLite, MySQL, MariaDB)

## Installation

```sh
gleam add cake_knife
```

## Quick Start

```gleam
import cake/select
import cake_knife

pub fn get_users_page(page: Int) {
  select.new()
  |> select.from_table("users")
  |> select.to_query
  |> cake_knife.page(page: page, per_page: 20)
  // Now execute with your database adapter (cake_pog, cake_sqlight, etc.)
}
```

## Offset Pagination

### Basic LIMIT and OFFSET

```gleam
import cake/select
import cake_knife

select.new()
|> select.from_table("posts")
|> select.to_query
|> cake_knife.limit(10)
|> cake_knife.offset(20)
// Generates: SELECT * FROM posts LIMIT 10 OFFSET 20
```

### Page-based Pagination

```gleam
import cake/select
import cake_knife

// Page 1: OFFSET 0
select.new()
|> select.from_table("posts")
|> select.to_query
|> cake_knife.page(page: 1, per_page: 10)

// Page 2: OFFSET 10
select.new()
|> select.from_table("posts")
|> select.to_query
|> cake_knife.page(page: 2, per_page: 10)
```

### Validated Pagination

```gleam
import cake/select
import cake_knife

let query = select.new() |> select.from_table("posts") |> select.to_query

case cake_knife.paginate(query, page: 1, per_page: 50, max_per_page: 100) {
  Ok(paginated_query) -> {
    // Use paginated_query
  }
  Error(cake_knife.InvalidPage(page)) -> {
    // Handle invalid page number
  }
  Error(cake_knife.InvalidPerPage(per_page)) -> {
    // Handle invalid per_page value
  }
  Error(cake_knife.PerPageTooLarge(per_page, max)) -> {
    // Handle per_page exceeding maximum
  }
}
```

### Working with Page Metadata

```gleam
import cake_knife

// After executing your query and getting results:
let page = cake_knife.new_page(
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

Cake Knife provides automatic WHERE clause generation for cursor-based (keyset) pagination. Cursor pagination is more efficient for large datasets as it uses keyset values instead of OFFSET, providing consistent performance regardless of page depth.

### Encoding and Decoding Cursors

```gleam
import cake_knife
import gleam/option.{Some, None}

// Encode keyset values into an opaque cursor
let cursor = cake_knife.encode_cursor(["2024-01-15T10:30:00Z", "12345"])

// Decode a cursor back to values
case cake_knife.decode_cursor(cursor) {
  Ok(values) -> {
    // values == ["2024-01-15T10:30:00Z", "12345"]
    // Use these values in your WHERE clause for keyset pagination
  }
  Error(cake_knife.InvalidBase64) -> {
    // Handle invalid base64
  }
  Error(cake_knife.InvalidJson) -> {
    // Handle invalid JSON
  }
  Error(cake_knife.NotAnArray) -> {
    // Handle wrong JSON structure
  }
}
```

### Working with CursorPage

```gleam
import cake_knife
import gleam/option.{Some}

// After executing your cursor-based query, construct a CursorPage
let first_item_cursor = cake_knife.encode_cursor(["2024-01-15", "100"])
let last_item_cursor = cake_knife.encode_cursor(["2024-01-20", "150"])

let cursor_page = cake_knife.CursorPage(
  data: items,
  start_cursor: Some(first_item_cursor),
  end_cursor: Some(last_item_cursor),
  has_next: True,
  has_previous: False,
)
```

### Implementing Keyset Pagination with Postgres/Pog

Cake Knife provides helper functions to automatically build keyset pagination WHERE clauses. Here's a complete example using Postgres with pog for posts ordered by `(created_at DESC, id DESC)`.

```gleam
import cake/adapter/postgres
import cake/select
import cake_knife
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

// Define keyset columns once (matches your ORDER BY)
const keyset_columns = [
  cake_knife.KeysetColumn("created_at", cake_knife.Desc),
  cake_knife.KeysetColumn("id", cake_knife.Desc),
]

// Paginate posts going forward (after a cursor)
pub fn get_posts_after(
  db: postgres.Connection,
  after_cursor: Option(cake_knife.Cursor),
  limit: Int,
) {
  // Start with base query ordered by (created_at DESC, id DESC)
  let base_query =
    select.new()
    |> select.from_table("posts")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("id")

  // Add WHERE clause for keyset pagination using helper
  let query = case after_cursor {
    None -> base_query
    Some(cursor) -> {
      use where_clause <- result.try(
        cake_knife.keyset_where_after(cursor, keyset_columns)
      )
      Ok(base_query |> select.where(where_clause))
    }
  }

  use query <- result.try(query)

  // Fetch one extra item to determine if there's a next page
  let query_with_limit =
    query
    |> select.to_query
    |> cake_knife.limit(limit + 1)

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
      Some(cake_knife.encode_cursor([
        post.created_at,
        int.to_string(post.id),
      ]))
    Error(_) -> None
  }
  let end_cursor = case list.last(posts) {
    Ok(post) ->
      Some(cake_knife.encode_cursor([
        post.created_at,
        int.to_string(post.id),
      ]))
    Error(_) -> None
  }

  // Build CursorPage
  Ok(cake_knife.CursorPage(
    data: posts,
    start_cursor: start_cursor,
    end_cursor: end_cursor,
    has_next: has_next,
    has_previous: option.is_some(after_cursor),
  ))
}
```

**Key Points:**

- Use `keyset_where_after()` to automatically build the WHERE clause
- Define `KeysetColumn` list matching your ORDER BY clause
- The helper works with all database adapters (Postgres, SQLite, MySQL, MariaDB)
- Fetch `limit + 1` items to determine if there's a next/previous page
- Cursor values must be strings, so convert numbers with `int.to_string()`
- For best performance, create an index: `CREATE INDEX idx_posts_pagination ON posts(created_at DESC, id DESC)`

**For backward pagination**, use `keyset_where_before()` with reversed ORDER BY:

```gleam
use where_clause <- result.try(
  cake_knife.keyset_where_before(before_cursor, keyset_columns)
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

### Key Functions

**Offset Pagination:**
- `limit(query, count)` - Add LIMIT clause
- `offset(query, count)` - Add OFFSET clause
- `page(query, page, per_page)` - Add LIMIT and OFFSET for page-based pagination
- `paginate(query, page, per_page, max_per_page)` - Validated page-based pagination
- `calculate_total_pages(total_count, per_page)` - Calculate number of pages
- `new_page(data, page, per_page, total_count)` - Create Page with metadata

**Cursor Pagination:**
- `encode_cursor(values)` - Encode keyset values into an opaque cursor
- `decode_cursor(cursor)` - Decode a cursor back to keyset values
- `cursor_from_string(value)` - Create a cursor from a string
- `cursor_to_string(cursor)` - Extract the string value from a cursor
- `keyset_where_after(cursor, columns)` - Build WHERE clause for forward pagination
- `keyset_where_before(cursor, columns)` - Build WHERE clause for backward pagination

### Types

- `Page(a)` - Offset-based pagination result with metadata
- `Cursor` - Opaque cursor for cursor-based pagination
- `CursorPage(a)` - Cursor-based pagination result
- `KeysetColumn` - Column definition for keyset pagination (name + direction)
- `OrderDirection` - Sort direction (Asc or Desc)
- `PaginationError` - Validation errors for pagination parameters
- `CursorDecodeError` - Errors that can occur when decoding cursors
- `KeysetError` - Errors that can occur during keyset pagination

## Examples

Check the `test/` directory for examples of all features.

## Development

### Running Tests

This project uses PostgreSQL for integration tests. Tests are run in a Docker container to ensure consistent behaviour across environments.

**Prerequisites:**
- Docker and Docker Compose installed and running

**Running the test suite:**

```sh
# Run tests with Docker database (recommended)
./scripts/test.sh

# Or manually manage the database:
docker compose up -d          # Start PostgreSQL
gleam test                    # Run tests
docker compose down           # Stop PostgreSQL
```

The test script automatically:
1. Starts a PostgreSQL 17.6 container
2. Waits for the database to be ready
3. Runs the test suite
4. Cleans up the container

**Environment Variables:**

You can customise the database connection using environment variables:

```sh
POSTGRES_HOST=localhost    # Default: localhost
POSTGRES_PORT=5432         # Default: 5432
POSTGRES_USER=postgres     # Default: postgres
POSTGRES_PASSWORD=postgres # Default: postgres
POSTGRES_DB=cake_knife_test # Default: cake_knife_test
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
