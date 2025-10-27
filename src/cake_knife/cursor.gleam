//// Cursor-based pagination for Cake SQL queries.
////
//// This module provides efficient cursor-based pagination using cursor values
//// instead of OFFSET. This is recommended for large datasets where OFFSET
//// performance becomes an issue.
////
//// Use `encode()`, `decode()`, `where_after()`, and
//// `where_before()` for cursor-based pagination, along with the
//// `CursorPage(a)` type for working with paginated results.

import cake/fragment
import cake/select
import cake/where
import gleam/bit_array
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result

/// A type alias for Cake's ReadQuery type.
///
/// This represents a SQL SELECT query that can be paginated.
/// All pagination functions in this module operate on ReadQuery values.
///
/// ## Examples
///
/// ```gleam
/// import cake/select
/// import cake_knife/cursor
///
/// let query: cursor.ReadQuery =
///   select.new()
///   |> select.from_table("users")
///   |> select.to_query
/// ```
pub type ReadQuery =
  select.ReadQuery

/// Errors that can occur during cursor decoding.
pub type CursorDecodeError {
  /// The cursor contains invalid base64.
  InvalidBase64
  /// The cursor contains invalid JSON.
  InvalidJson
  /// The cursor JSON is not an array.
  NotAnArray
  /// The cursor array contains non-string values.
  InvalidArrayElement
}

/// Errors that can occur during cursor pagination.
pub type CursorError {
  /// The cursor could not be decoded.
  InvalidCursor(CursorDecodeError)
  /// The cursor has a different number of values than expected columns.
  MismatchedCursorLength(expected: Int, got: Int)
  /// A cursor value could not be parsed as the expected type.
  InvalidCursorValue(value: String, expected_type: String)
}

/// Defines the sort direction for a cursor column.
pub type OrderDirection {
  /// Ascending order (smallest to largest).
  Asc
  /// Descending order (largest to smallest).
  Desc
}

/// Defines the data type of a column for cursor pagination.
///
/// This is used to ensure cursor values are properly typed when
/// generating WHERE clauses, which is required for databases
/// like PostgreSQL that enforce strict type checking.
pub type ColumnType {
  /// String/text column type.
  StringType
  /// Integer column type.
  IntType
  /// Float/decimal column type.
  FloatType
  /// Timestamp column type. Uses SQL CAST for PostgreSQL compatibility.
  TimestampType
}

/// Describes a column used in cursor pagination.
///
/// The column name, direction, and type must match your ORDER BY clause
/// and database schema.
///
/// ## Examples
///
/// ```gleam
/// KeysetColumn("created_at", Desc, TimestampType)  // For TIMESTAMP columns
/// KeysetColumn("name", Asc, StringType)             // For TEXT columns
/// KeysetColumn("id", Asc, IntType)                  // For INTEGER columns
/// KeysetColumn("score", Desc, FloatType)            // For FLOAT columns
/// ```
pub type KeysetColumn {
  KeysetColumn(name: String, direction: OrderDirection, column_type: ColumnType)
}

/// An opaque cursor for cursor-based pagination.
///
/// Cursors encode position information (typically values like
/// timestamps and IDs) to enable efficient pagination without OFFSET.
pub opaque type Cursor {
  Cursor(value: String)
}

/// Represents a page of results using cursor-based pagination.
///
/// Cursor-based pagination is more efficient than offset-based pagination
/// for large datasets, as it uses cursor values instead of OFFSET.
///
/// ## Fields
///
/// - `data`: The actual items on this page
/// - `start_cursor`: Cursor of the first item (None if no results)
/// - `end_cursor`: Cursor of the last item (None if no results)
/// - `has_next`: Whether there are more results after end_cursor
/// - `has_previous`: Whether there are results before start_cursor
///
/// ## Examples
///
/// ```gleam
/// CursorPage(
///   data: [item1, item2, item3],
///   start_cursor: Some(cursor1),
///   end_cursor: Some(cursor3),
///   has_next: True,
///   has_previous: False,
/// )
/// ```
pub type CursorPage(a) {
  CursorPage(
    data: List(a),
    start_cursor: Option(Cursor),
    end_cursor: Option(Cursor),
    has_next: Bool,
    has_previous: Bool,
  )
}

/// Creates a cursor from a string value.
///
/// The string should typically be a base64-encoded representation
/// of cursor values, but this function accepts any string.
///
/// This is useful when receiving cursor tokens from API requests
/// or other external sources.
///
/// ## Examples
///
/// ```gleam
/// let cursor = from_string("WyIyMDI0LTAxLTE1IiwiMTIzNDUiXQ==")
/// // Can now decode this cursor to get the original values
/// ```
pub fn from_string(value val: String) -> Cursor {
  Cursor(val)
}

/// Extracts the string value from a cursor.
///
/// This is useful when sending cursor tokens in API responses
/// or storing them for later use.
///
/// ## Examples
///
/// ```gleam
/// let cursor = encode(["2024-01-15", "12345"])
/// let cursor_string = to_string(cursor)
/// // cursor_string can now be sent to clients as an opaque token
/// ```
pub fn to_string(cursor c: Cursor) -> String {
  c.value
}

/// Encodes a list of values into an opaque cursor token.
///
/// The values are JSON-encoded and base64-encoded to create an opaque cursor.
/// This is useful for cursor-based pagination where you want to encode
/// values (like timestamp and ID) into a single cursor token.
///
/// ## Examples
///
/// ```gleam
/// encode(["2024-01-15T10:30:00Z", "12345"])
/// // -> Cursor with base64-encoded JSON array
///
/// encode([])
/// // -> Cursor with base64-encoded empty array
/// ```
pub fn encode(values vals: List(String)) -> Cursor {
  vals
  |> list.map(json.string)
  |> json.array(of: fn(x) { x })
  |> json.to_string
  |> bit_array.from_string
  |> bit_array.base64_encode(True)
  |> Cursor
}

/// Decodes a cursor token back into a list of values.
///
/// This reverses the encoding done by `encode()`, returning the
/// original list of string values or an error if the cursor is invalid.
///
/// ## Examples
///
/// ```gleam
/// let cursor = encode(["2024-01-15T10:30:00Z", "12345"])
/// decode(cursor)
/// // -> Ok(["2024-01-15T10:30:00Z", "12345"])
///
/// let bad_cursor = from_string("not-valid-base64!")
/// decode(bad_cursor)
/// // -> Error(InvalidBase64)
/// ```
pub fn decode(
  cursor c: Cursor,
) -> Result(List(String), CursorDecodeError) {
  use decoded_bits <- result.try(
    c.value
    |> bit_array.base64_decode
    |> result.replace_error(InvalidBase64),
  )

  use parsed <- result.try(
    decoded_bits
    |> json.parse_bits(decode.dynamic)
    |> result.map_error(fn(_) { InvalidJson }),
  )

  decode.run(parsed, decode.list(decode.string))
  |> result.map_error(fn(_) { NotAnArray })
}

/// Builds a WHERE clause for cursor pagination going forward (after a cursor).
///
/// This function automatically generates the appropriate WHERE clause for
/// cursor pagination based on your cursor and column definitions. It works
/// with all database adapters by using expanded OR/AND conditions.
///
/// ## Parameters
///
/// - `cursor`: The cursor from the last item of the previous page
/// - `columns`: List of columns in your ORDER BY clause with their directions
///
/// ## Examples
///
/// ```gleam
/// // For ORDER BY created_at DESC, id DESC
/// let cursor_cols = [
///   KeysetColumn("created_at", Desc, TimestampType),
///   KeysetColumn("id", Desc, IntType),
/// ]
///
/// case after_cursor {
///   Some(cursor) -> {
///     use where_clause <- result.try(
///       where_after(cursor, cursor_cols)
///     )
///     base_query |> select.where(where_clause)
///   }
///   None -> base_query
/// }
/// ```
///
/// ## How it works
///
/// For descending columns `(created_at DESC, id DESC)` with cursor values `[t, i]`,
/// generates: `WHERE created_at < t OR (created_at = t AND id < i)`
///
/// For ascending columns `(created_at ASC, id ASC)` with cursor values `[t, i]`,
/// generates: `WHERE created_at > t OR (created_at = t AND id > i)`
pub fn where_after(
  cursor c: Cursor,
  columns cols: List(KeysetColumn),
) -> Result(where.Where, CursorError) {
  use values <- result.try(
    decode(c)
    |> result.map_error(InvalidCursor),
  )

  let expected_len = list.length(cols)
  let got_len = list.length(values)

  use <- result_guard(
    expected_len != got_len,
    Error(MismatchedCursorLength(expected: expected_len, got: got_len)),
  )

  // Build the WHERE clause by iterating through columns
  build_cursor_where_clause(cols, values, Forward)
}

/// Builds a WHERE clause for cursor pagination going backward (before a cursor).
///
/// This function automatically generates the appropriate WHERE clause for
/// cursor pagination going in reverse. It works with all database adapters.
///
/// ## Parameters
///
/// - `cursor`: The cursor from the first item of the current page
/// - `columns`: List of columns in your ORDER BY clause with their directions
///
/// ## Examples
///
/// ```gleam
/// // For ORDER BY created_at DESC, id DESC
/// let cursor_cols = [
///   KeysetColumn("created_at", Desc, TimestampType),
///   KeysetColumn("id", Desc, IntType),
/// ]
///
/// use where_clause <- result.try(
///   where_before(cursor, cursor_cols)
/// )
///
/// // Note: Reverse the ORDER BY for backward pagination
/// query
/// |> select.order_by_asc("created_at")
/// |> select.order_by_asc("id")
/// |> select.where(where_clause)
/// ```
///
/// ## How it works
///
/// For descending columns `(created_at DESC, id DESC)` with cursor values `[t, i]`,
/// generates: `WHERE created_at > t OR (created_at = t AND id > i)`
///
/// This is the inverse of `where_after`.
pub fn where_before(
  cursor c: Cursor,
  columns cols: List(KeysetColumn),
) -> Result(where.Where, CursorError) {
  use values <- result.try(
    decode(c)
    |> result.map_error(InvalidCursor),
  )

  let expected_len = list.length(cols)
  let got_len = list.length(values)

  use <- result_guard(
    expected_len != got_len,
    Error(MismatchedCursorLength(expected: expected_len, got: got_len)),
  )

  // Build the WHERE clause by iterating through columns (inverted)
  build_cursor_where_clause(cols, values, Backward)
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │  Internal helper functions                                                │
// └───────────────────────────────────────────────────────────────────────────┘

type Direction {
  Forward
  Backward
}

fn result_guard(
  condition: Bool,
  return: Result(a, e),
  continue: fn() -> Result(a, e),
) -> Result(a, e) {
  case condition {
    True -> return
    False -> continue()
  }
}

/// Builds a cursor WHERE clause using expanded OR/AND conditions.
///
/// For columns (a DESC, b DESC) and values (x, y), generates:
/// Forward: a < x OR (a = x AND b < y)
/// Backward: a > x OR (a = x AND b > y)
///
/// For columns (a, b, c) and values (x, y, z), generates:
/// a < x OR (a = x AND (b < y OR (b = y AND c < z)))
fn build_cursor_where_clause(
  columns: List(KeysetColumn),
  values: List(String),
  direction: Direction,
) -> Result(where.Where, CursorError) {
  case columns, values {
    [], [] -> Ok(where.none())
    [KeysetColumn(col, dir, col_type)], [val] -> {
      // Single column: simple comparison
      use comparison_where <- result.try(build_single_comparison(
        col,
        val,
        dir,
        direction,
        col_type,
      ))
      Ok(comparison_where)
    }
    [KeysetColumn(col, dir, col_type), ..rest_cols], [val, ..rest_vals] -> {
      // Multiple columns: col < val OR (col = val AND <rest>)
      use comparison_where <- result.try(build_single_comparison(
        col,
        val,
        dir,
        direction,
        col_type,
      ))
      use equality_value <- result.try(parse_value_for_type(val, col_type))
      use rest_where <- result.try(build_cursor_where_clause(
        rest_cols,
        rest_vals,
        direction,
      ))

      Ok(
        where.or([
          comparison_where,
          where.and([
            where.eq(where.col(col), equality_value),
            rest_where,
          ]),
        ]),
      )
    }
    _, _ -> Ok(where.none())
  }
}

/// Parses a string value and returns the appropriate where value based on column type.
fn parse_value_for_type(
  value: String,
  column_type: ColumnType,
) -> Result(where.WhereValue, CursorError) {
  case column_type {
    StringType -> Ok(where.string(value))
    IntType ->
      int.parse(value)
      |> result.map(where.int)
      |> result.replace_error(InvalidCursorValue(value, "integer"))
    FloatType ->
      float.parse(value)
      |> result.map(where.float)
      |> result.replace_error(InvalidCursorValue(value, "float"))
    TimestampType -> {
      // Use literal timestamp with TIMESTAMP cast for PostgreSQL compatibility
      // This avoids parameter type checking issues in pog
      // Note: Value must be from trusted cursor (base64 encoded), not user input
      let timestamp_fragment = fragment.literal("'" <> value <> "'::timestamp")
      Ok(where.fragment_value(timestamp_fragment))
    }
  }
}

/// Builds a single comparison for a column.
fn build_single_comparison(
  column: String,
  value: String,
  column_direction: OrderDirection,
  pagination_direction: Direction,
  column_type: ColumnType,
) -> Result(where.Where, CursorError) {
  let comparison = case column_direction, pagination_direction {
    Desc, Forward -> where.lt
    Desc, Backward -> where.gt
    Asc, Forward -> where.gt
    Asc, Backward -> where.lt
  }

  use typed_value <- result.try(parse_value_for_type(value, column_type))
  Ok(comparison(where.col(column), typed_value))
}
