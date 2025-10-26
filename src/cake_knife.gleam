import cake/internal/read_query
import cake/select

pub type ReadQuery =
  select.ReadQuery

/// Errors that can occur during pagination validation.
pub type PaginationError {
  /// The page number must be at least 1.
  InvalidPage(page: Int)
  /// The per_page value must be at least 1.
  InvalidPerPage(per_page: Int)
  /// The per_page value exceeds the maximum allowed.
  PerPageTooLarge(per_page: Int, max: Int)
}

/// Represents a page of results with metadata for pagination.
///
/// ## Fields
///
/// - `data`: The actual items on this page
/// - `page`: Current page number (1-indexed)
/// - `per_page`: Number of items per page
/// - `total_count`: Total number of items across all pages
/// - `total_pages`: Total number of pages
/// - `has_previous`: Whether there is a previous page
/// - `has_next`: Whether there is a next page
///
/// ## Examples
///
/// ```gleam
/// Page(
///   data: [user1, user2, user3],
///   page: 2,
///   per_page: 3,
///   total_count: 10,
///   total_pages: 4,
///   has_previous: True,
///   has_next: True,
/// )
/// ```
pub type Page(a) {
  Page(
    data: List(a),
    page: Int,
    per_page: Int,
    total_count: Int,
    total_pages: Int,
    has_previous: Bool,
    has_next: Bool,
  )
}

/// An opaque cursor for cursor-based pagination.
///
/// Cursors encode position information (typically keyset values like
/// timestamps and IDs) to enable efficient pagination without OFFSET.
pub opaque type Cursor {
  Cursor(value: String)
}

/// Adds a LIMIT clause to a query, restricting the number of rows returned.
///
/// Negative values are clamped to 0 (which results in no LIMIT clause).
///
/// ## Examples
///
/// ```gleam
/// import cake/select
/// import cake_knife
///
/// select.new()
/// |> select.from_table("users")
/// |> cake_knife.limit(10)
/// ```
pub fn limit(query qry: ReadQuery, count cnt: Int) -> ReadQuery {
  case qry {
    read_query.SelectQuery(select_query) ->
      select_query
      |> select.limit(cnt)
      |> select.to_query
    read_query.CombinedQuery(_) -> qry
  }
}

/// Adds an OFFSET clause to a query, skipping the specified number of rows.
///
/// Negative values are clamped to 0 (which results in no OFFSET clause).
///
/// ## Examples
///
/// ```gleam
/// import cake/select
/// import cake_knife
///
/// select.new()
/// |> select.from_table("users")
/// |> cake_knife.limit(10)
/// |> cake_knife.offset(20)
/// ```
pub fn offset(query qry: ReadQuery, count cnt: Int) -> ReadQuery {
  case qry {
    read_query.SelectQuery(select_query) ->
      select_query
      |> select.offset(cnt)
      |> select.to_query
    read_query.CombinedQuery(_) -> qry
  }
}

/// Applies page-based pagination to a query using LIMIT and OFFSET.
///
/// Converts page numbers to LIMIT/OFFSET calculations:
/// - Page 1 starts at offset 0
/// - Page 2 starts at offset per_page
/// - Formula: offset = (page - 1) * per_page
///
/// Note: This function does not validate inputs. For validation, use `paginate()`.
///
/// ## Examples
///
/// ```gleam
/// import cake/select
/// import cake_knife
///
/// select.new()
/// |> select.from_table("users")
/// |> cake_knife.page(page: 2, per_page: 10)
/// // Equivalent to: limit(10) |> offset(10)
/// ```
pub fn page(query qry: ReadQuery, page pg: Int, per_page per_pg: Int) -> ReadQuery {
  let offset_amount = { pg - 1 } * per_pg
  qry
  |> limit(per_pg)
  |> offset(offset_amount)
}

/// Applies validated page-based pagination to a query.
///
/// Validates that:
/// - `page` is at least 1
/// - `per_page` is at least 1
/// - `per_page` does not exceed `max_per_page`
///
/// ## Examples
///
/// ```gleam
/// import cake/select
/// import cake_knife
///
/// select.new()
/// |> select.from_table("users")
/// |> cake_knife.paginate(page: 2, per_page: 10, max_per_page: 100)
/// // -> Ok(query with LIMIT 10 OFFSET 10)
///
/// select.new()
/// |> select.from_table("users")
/// |> cake_knife.paginate(page: 0, per_page: 10, max_per_page: 100)
/// // -> Error(InvalidPage(0))
/// ```
pub fn paginate(
  query qry: ReadQuery,
  page pg: Int,
  per_page per_pg: Int,
  max_per_page max_per_pg: Int,
) -> Result(ReadQuery, PaginationError) {
  case pg < 1 {
    True -> Error(InvalidPage(pg))
    False ->
      case per_pg < 1 {
        True -> Error(InvalidPerPage(per_pg))
        False ->
          case per_pg > max_per_pg {
            True -> Error(PerPageTooLarge(per_pg, max_per_pg))
            False -> Ok(page(qry, pg, per_pg))
          }
      }
  }
}

/// Calculates the total number of pages given a total count and items per page.
///
/// Uses ceiling division to ensure partial pages are counted.
///
/// ## Examples
///
/// ```gleam
/// calculate_total_pages(total_count: 10, per_page: 3)
/// // -> 4
///
/// calculate_total_pages(total_count: 9, per_page: 3)
/// // -> 3
///
/// calculate_total_pages(total_count: 0, per_page: 10)
/// // -> 0
/// ```
pub fn calculate_total_pages(total_count total: Int, per_page per_pg: Int) -> Int {
  case per_pg <= 0 {
    True -> 0
    False -> {
      case total <= 0 {
        True -> 0
        False -> { total + per_pg - 1 } / per_pg
      }
    }
  }
}

/// Creates a Page from results and metadata.
///
/// Automatically calculates total_pages, has_previous, and has_next.
///
/// ## Examples
///
/// ```gleam
/// new_page(
///   data: [user1, user2, user3],
///   page: 2,
///   per_page: 3,
///   total_count: 10,
/// )
/// // -> Page(
/// //   data: [user1, user2, user3],
/// //   page: 2,
/// //   per_page: 3,
/// //   total_count: 10,
/// //   total_pages: 4,
/// //   has_previous: True,
/// //   has_next: True,
/// // )
/// ```
pub fn new_page(
  data d: List(a),
  page pg: Int,
  per_page per_pg: Int,
  total_count total: Int,
) -> Page(a) {
  let total_pages = calculate_total_pages(total, per_pg)
  Page(
    data: d,
    page: pg,
    per_page: per_pg,
    total_count: total,
    total_pages: total_pages,
    has_previous: pg > 1,
    has_next: pg < total_pages,
  )
}

/// Creates a cursor from a string value.
///
/// The string should typically be a base64-encoded representation
/// of keyset values, but this function accepts any string.
pub fn cursor_from_string(value val: String) -> Cursor {
  Cursor(val)
}

/// Extracts the string value from a cursor.
pub fn cursor_to_string(cursor c: Cursor) -> String {
  c.value
}
