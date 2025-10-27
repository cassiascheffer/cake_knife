//// Ergonomic pagination utilities for Cake SQL queries.
////
//// This module re-exports functions from both `cake_knife/offset` and
//// `cake_knife/keyset` for backwards compatibility. For better tree-shaking
//// and clearer imports, consider importing directly from those modules:
////
//// ## Offset Pagination
////
//// For traditional page-based pagination using LIMIT/OFFSET:
////
//// ```gleam
//// import cake_knife/offset
////
//// query
//// |> offset.page(page: 1, per_page: 20)
//// ```
////
//// See `cake_knife/offset` module documentation for details.
////
//// ## Keyset Pagination
////
//// For efficient cursor-based pagination (recommended for large datasets):
////
//// ```gleam
//// import cake_knife/keyset
////
//// let cursor = keyset.encode_cursor(["2024-01-15", "12345"])
//// keyset.keyset_where_after(cursor, columns)
//// ```
////
//// See `cake_knife/keyset` module documentation for details.

import cake/where
import cake_knife/keyset
import cake_knife/offset

// Re-export offset pagination types
pub type ReadQuery =
  offset.ReadQuery

pub type PaginationError =
  offset.PaginationError

pub type Page(a) =
  offset.Page(a)

// Re-export offset pagination functions
pub fn limit(query qry: ReadQuery, count cnt: Int) -> ReadQuery {
  offset.limit(qry, cnt)
}

pub fn offset(query qry: ReadQuery, count cnt: Int) -> ReadQuery {
  offset.offset(qry, cnt)
}

pub fn page(
  query qry: ReadQuery,
  page pg: Int,
  per_page per_pg: Int,
) -> ReadQuery {
  offset.page(qry, pg, per_pg)
}

pub fn paginate(
  query qry: ReadQuery,
  page pg: Int,
  per_page per_pg: Int,
  max_per_page max_per_pg: Int,
) -> Result(ReadQuery, PaginationError) {
  offset.paginate(qry, pg, per_pg, max_per_pg)
}

pub fn calculate_total_pages(
  total_count total: Int,
  per_page per_pg: Int,
) -> Int {
  offset.calculate_total_pages(total, per_pg)
}

pub fn new_page(
  data d: List(a),
  page pg: Int,
  per_page per_pg: Int,
  total_count total: Int,
) -> Page(a) {
  offset.new_page(d, pg, per_pg, total)
}

// Re-export keyset pagination types
pub type CursorDecodeError =
  keyset.CursorDecodeError

pub type KeysetError =
  keyset.KeysetError

pub type OrderDirection =
  keyset.OrderDirection

pub type ColumnType =
  keyset.ColumnType

pub type KeysetColumn =
  keyset.KeysetColumn

pub type Cursor =
  keyset.Cursor

pub type CursorPage(a) =
  keyset.CursorPage(a)

// Re-export keyset pagination functions
pub fn cursor_from_string(value val: String) -> Cursor {
  keyset.cursor_from_string(val)
}

pub fn cursor_to_string(cursor c: Cursor) -> String {
  keyset.cursor_to_string(c)
}

pub fn encode_cursor(values vals: List(String)) -> Cursor {
  keyset.encode_cursor(vals)
}

pub fn decode_cursor(
  cursor c: Cursor,
) -> Result(List(String), CursorDecodeError) {
  keyset.decode_cursor(c)
}

pub fn keyset_where_after(
  cursor c: Cursor,
  columns cols: List(KeysetColumn),
) -> Result(where.Where, KeysetError) {
  keyset.keyset_where_after(c, cols)
}

pub fn keyset_where_before(
  cursor c: Cursor,
  columns cols: List(KeysetColumn),
) -> Result(where.Where, KeysetError) {
  keyset.keyset_where_before(c, cols)
}
