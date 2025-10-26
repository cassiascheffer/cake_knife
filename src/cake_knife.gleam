import cake/internal/read_query
import cake/select

pub type ReadQuery =
  select.ReadQuery

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
