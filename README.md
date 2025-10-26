# cake_knife

A Gleam library providing ergonomic pagination utilities for [Cake](https://hexdocs.pm/cake/) SQL queries.

[![Package Version](https://img.shields.io/hexpm/v/cake_knife)](https://hex.pm/packages/cake_knife)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/cake_knife/)

## Features

- **Offset-based pagination** - Simple page-based navigation using LIMIT/OFFSET
- **Page metadata** - Automatic calculation of total pages, has_next, has_previous
- **Validation** - Built-in validation for page parameters with helpful errors
- **Type-safe** - Fully typed with Gleam's type system
- **Cursor support** - Types for implementing efficient cursor-based pagination

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

Cake Knife provides types for cursor-based pagination. Cursor pagination is more efficient for large datasets as it uses keyset values instead of OFFSET.

```gleam
import cake_knife
import gleam/option.{Some}

// Types are provided for cursor pagination
pub type MyCursor {
  MyCursor(timestamp: String, id: Int)
}

// Create a cursor from your keyset values
let cursor = cake_knife.cursor_from_string("base64_encoded_cursor")

// Use CursorPage type for results
let cursor_page = cake_knife.CursorPage(
  data: items,
  start_cursor: Some(first_cursor),
  end_cursor: Some(last_cursor),
  has_next: True,
  has_previous: False,
)
```

## Offset vs Cursor Pagination

### When to use Offset Pagination

- **Pros:**
  - Simple to implement
  - Supports jumping to arbitrary pages
  - Easy for users to understand (page numbers)
  - Works with any dataset

- **Cons:**
  - Performance degrades with large offsets
  - Can show duplicate/missing items if data changes between requests
  - Database must scan skipped rows

- **Use when:**
  - Dataset is small to medium sized (< 10,000 rows)
  - Users need to jump to specific pages
  - Consistency during pagination isn't critical
  - Simplicity is more important than performance

### When to use Cursor Pagination

- **Pros:**
  - Consistent performance regardless of position in dataset
  - No duplicate/missing items even with concurrent changes
  - Efficient for infinite scroll interfaces

- **Cons:**
  - Cannot jump to arbitrary pages
  - Requires indexed keyset columns
  - More complex to implement correctly

- **Use when:**
  - Dataset is large (> 10,000 rows)
  - Implementing infinite scroll or "load more"
  - Data changes frequently
  - Performance at scale is critical

## API Reference

See the [Hex documentation](https://hexdocs.pm/cake_knife/) for complete API reference.

### Key Functions

- `limit(query, count)` - Add LIMIT clause
- `offset(query, count)` - Add OFFSET clause
- `page(query, page, per_page)` - Add LIMIT and OFFSET for page-based pagination
- `paginate(query, page, per_page, max_per_page)` - Validated page-based pagination
- `calculate_total_pages(total_count, per_page)` - Calculate number of pages
- `new_page(data, page, per_page, total_count)` - Create Page with metadata

### Types

- `Page(a)` - Offset-based pagination result with metadata
- `Cursor` - Opaque cursor for cursor-based pagination
- `CursorPage(a)` - Cursor-based pagination result
- `PaginationError` - Validation errors for pagination parameters

## Examples

Check the `test/` directory for comprehensive examples of all features.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam build # Build the project
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Licence

This project is licensed under the Apache License 2.0.
