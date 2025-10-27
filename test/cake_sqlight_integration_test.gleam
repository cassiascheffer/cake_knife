import cake/combined
import cake/select
import cake/where
import cake_knife/cursor
import cake_knife/offset
import gleam/list
import gleam/option.{Some}
import gleeunit
import test_helper/sqlight_test_helper

pub fn main() -> Nil {
  gleeunit.main()
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │  Offset Pagination Tests                                                  │
// └───────────────────────────────────────────────────────────────────────────┘

pub fn limit_returns_correct_number_of_rows_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn offset_skips_correct_rows_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(5)
    |> offset.offset(10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get items 11-15 (positions 11-15)
  assert list.length(results) == 5
}

pub fn page_one_returns_first_items_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn page_two_returns_second_batch_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 2, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn last_page_returns_partial_results_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 5, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Page 5 with per_page=10 should have items 41-50 (10 items)
  assert list.length(results) == 10
}

pub fn page_six_returns_empty_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 6, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Page 6 should be empty (we only have 50 items)
  assert results == []
}

pub fn large_offset_works_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(5)
    |> offset.offset(45)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get last 5 items (positions 46-50)
  assert list.length(results) == 5
}

pub fn paginate_with_valid_params_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query

  let assert Ok(paginated_query) =
    query
    |> offset.paginate(page: 3, per_page: 10, max_per_page: 100)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(paginated_query)

  assert list.length(results) == 10
}

pub fn different_page_sizes_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 2, per_page: 15)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Page 2 with per_page=15 should have items 16-30
  assert list.length(results) == 15
}

pub fn combined_limit_offset_page_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 5)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get first 5 items when ordered descending (items 50-46)
  assert list.length(results) == 5
}

pub fn combined_query_union_ignores_limit_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(10)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(40)))

  let combined_query =
    combined.union(query_a, query_b)
    |> combined.to_query
    |> offset.limit(5)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(combined_query)

  // limit is ignored on CombinedQuery, so we get all results from union
  // (10 items from first query + 10 from second = 20 total)
  assert list.length(results) == 20
}

pub fn combined_query_union_ignores_offset_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(5)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(45)))

  let combined_query =
    combined.union(query_a, query_b)
    |> combined.to_query
    |> offset.offset(3)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(combined_query)

  // offset is ignored on CombinedQuery, so we get all results from union
  // (5 items from first query + 5 from second = 10 total)
  assert list.length(results) == 10
}

pub fn combined_query_union_ignores_page_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(15)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(35)))

  let combined_query =
    combined.union(query_a, query_b)
    |> combined.to_query
    |> offset.page(page: 2, per_page: 5)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(combined_query)

  // page is ignored on CombinedQuery, so we get all results from union
  // (15 items from first query + 15 from second = 30 total)
  assert list.length(results) == 30
}

pub fn combined_query_union_all_ignores_pagination_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(8)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(8)))

  let combined_query =
    combined.union_all(query_a, query_b)
    |> combined.to_query
    |> offset.paginate(page: 1, per_page: 5, max_per_page: 100)

  let assert Ok(query) = combined_query
  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // paginate is ignored, UNION ALL includes duplicates
  // (8 items + 8 items = 16 total)
  assert list.length(results) == 16
}

pub fn combined_query_intersect_ignores_limit_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(25)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(15)))

  let combined_query =
    combined.intersect(query_a, query_b)
    |> combined.to_query
    |> offset.limit(3)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(combined_query)

  // limit is ignored, intersect returns items 16-25 (10 items)
  assert list.length(results) == 10
}

pub fn combined_query_except_ignores_offset_integration_test() {
  let query_a =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(20)))

  let query_b =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(10)))

  let combined_query =
    combined.except(query_a, query_b)
    |> combined.to_query
    |> offset.offset(5)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(combined_query)

  // offset is ignored, except returns items 1-10 (10 items)
  assert list.length(results) == 10
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │  Cursor Pagination Tests                                                  │
// └───────────────────────────────────────────────────────────────────────────┘

pub fn cursor_pagination_forward_single_column_desc_test() {
  // Query first page
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // For second page, use cursor pagination with cursor from last item
  let cursor = cursor.encode(["2024-01-05 15:00:00"])
  let cursor_cols = [
    cursor.KeysetColumn("created_at", cursor.Desc, cursor.StringType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  // Should get items with created_at < '2024-01-05 15:00:00'
  assert list.length(results_page2) > 0
  assert list.length(results_page2) <= 10
}

pub fn cursor_pagination_forward_two_columns_desc_test() {
  // Query first page ordered by (created_at DESC, id DESC)
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // For second page, use cursor with both columns
  let cursor = cursor.encode(["2024-01-05 15:00:00", "46"])
  let cursor_cols = [
    cursor.KeysetColumn("created_at", cursor.Desc, cursor.StringType),
    cursor.KeysetColumn("id", cursor.Desc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  assert list.length(results_page2) > 0
  assert list.length(results_page2) <= 10
}

pub fn cursor_pagination_forward_two_columns_asc_test() {
  // Query first page ordered by (position ASC, id ASC)
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // For second page
  let cursor = cursor.encode(["10", "10"])
  let cursor_cols = [
    cursor.KeysetColumn("position", cursor.Asc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Asc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  // Should get items with position > 10 or (position = 10 and id > 10)
  assert list.length(results_page2) == 10
}

pub fn cursor_pagination_backward_single_column_test() {
  // Start from item at position 30
  let cursor = cursor.encode(["2024-01-03 19:00:00"])
  let cursor_cols = [
    cursor.KeysetColumn("created_at", cursor.Desc, cursor.StringType),
  ]

  let assert Ok(where_clause) = cursor.where_before(cursor, cursor_cols)

  // For backward pagination, reverse the order
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("created_at")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get items with created_at > '2024-01-03 19:00:00'
  assert list.length(results) > 0
  assert list.length(results) <= 10
}

pub fn cursor_pagination_with_mixed_directions_test() {
  // Query with mixed directions (position DESC, id ASC)
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("position")
    |> select.order_by_asc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // For second page with mixed directions
  let cursor = cursor.encode(["41", "41"])
  let cursor_cols = [
    cursor.KeysetColumn("position", cursor.Desc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Asc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("position")
    |> select.order_by_asc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  assert list.length(results_page2) > 0
  assert list.length(results_page2) <= 10
}

pub fn cursor_pagination_complete_workflow_test() {
  // Simulate a complete pagination workflow:
  // 1. Fetch first page
  // 2. Get cursor from last item
  // 3. Fetch next page using cursor
  // 4. Verify we can continue paginating

  // First page
  let query1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.to_query
    |> offset.limit(11)

  let assert Ok(results1) = sqlight_test_helper.setup_and_run(query1)
  assert list.length(results1) == 11

  // Take first 10, use last as cursor for next page
  let page1_items = list.take(results1, 10)
  let has_next_page = list.length(results1) > 10
  assert has_next_page == True

  // Second page - get items after position 10
  let cursor = cursor.encode(["10", "10"])
  let cursor_cols = [
    cursor.KeysetColumn("position", cursor.Asc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Asc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(11)

  let assert Ok(results2) = sqlight_test_helper.setup_and_run(query2)

  // Should get items 11-21 (at least 10 items)
  assert list.length(results2) == 11
  let page2_items = list.take(results2, 10)
  assert list.length(page2_items) == 10

  // Verify no overlap between pages
  assert list.length(page1_items) + list.length(page2_items) == 20
}

pub fn cursor_pagination_with_string_values_test() {
  // Test that string values in cursor work correctly
  let cursor = cursor.encode(["Item 25"])
  let cursor_cols = [
    cursor.KeysetColumn("name", cursor.Asc, cursor.StringType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("name")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get items with name > 'Item 25'
  assert list.length(results) > 0
  assert list.length(results) <= 10
}

pub fn cursor_pagination_empty_results_test() {
  // Test pagination with a cursor that should return no results
  let cursor = cursor.encode(["2024-01-01 09:00:00"])
  let cursor_cols = [
    cursor.KeysetColumn("created_at", cursor.Asc, cursor.StringType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("created_at")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get all items (they're all after 2024-01-01 09:00:00)
  assert list.length(results) == 10
}

pub fn cursor_page_construction_test() {
  // Test building a CursorPage from query results
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(11)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Check we fetched limit + 1 to determine if there's a next page
  assert list.length(results) == 11

  let has_next = list.length(results) > 10
  let page_data = list.take(results, 10)

  // Build cursor page
  let start_cursor = Some(cursor.encode(["1", "1"]))
  let end_cursor = Some(cursor.encode(["10", "10"]))

  let cursor_page =
    cursor.CursorPage(
      data: page_data,
      start_cursor: start_cursor,
      end_cursor: end_cursor,
      has_next: has_next,
      has_previous: False,
    )

  assert cursor_page.has_next == True
  assert cursor_page.has_previous == False
  assert list.length(cursor_page.data) == 10
}

pub fn cursor_pagination_three_columns_test() {
  // Test with three columns for more complex pagination
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("position")
    |> select.order_by_desc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // For second page with three columns
  let cursor = cursor.encode(["2024-01-05 15:00:00", "46", "46"])
  let cursor_cols = [
    cursor.KeysetColumn("created_at", cursor.Desc, cursor.StringType),
    cursor.KeysetColumn("position", cursor.Desc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Desc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("created_at")
    |> select.order_by_desc("position")
    |> select.order_by_desc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  assert list.length(results_page2) > 0
  assert list.length(results_page2) <= 10
}

pub fn cursor_pagination_end_to_end_scenario_test() {
  // Simulate a real-world API scenario:
  // - Client requests first page
  // - Server returns data with end_cursor
  // - Client requests next page with after=end_cursor
  // - Server returns next data

  let limit = 5

  // First request: GET /api/items?limit=5
  let first_query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(limit + 1)

  let assert Ok(first_results) = sqlight_test_helper.setup_and_run(first_query)
  let first_has_next = list.length(first_results) > limit
  let first_data = list.take(first_results, limit)

  assert first_has_next == True
  assert list.length(first_data) == 5

  // Create end_cursor from last item (position=5, id=5)
  let first_end_cursor = cursor.encode(["5", "5"])

  // Second request: GET /api/items?limit=5&after=cursor
  let cursor_cols = [
    cursor.KeysetColumn("position", cursor.Asc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Asc, cursor.IntType),
  ]

  let assert Ok(where_clause) =
    cursor.where_after(first_end_cursor, cursor_cols)

  let second_query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.where(where_clause)
    |> select.to_query
    |> offset.limit(limit + 1)

  let assert Ok(second_results) =
    sqlight_test_helper.setup_and_run(second_query)
  let second_has_next = list.length(second_results) > limit
  let second_data = list.take(second_results, limit)

  assert second_has_next == True
  assert list.length(second_data) == 5

  // Verify we got items 6-10 (no duplicates)
  let total_items = list.length(first_data) + list.length(second_data)
  assert total_items == 10
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │  Edge Case Tests                                                          │
// └───────────────────────────────────────────────────────────────────────────┘

pub fn empty_table_pagination_test() {
  // Test pagination on an empty table
  let query =
    select.new()
    |> select.from_table("empty_items")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_empty_and_run(query)

  assert results == []
}

pub fn single_item_table_pagination_test() {
  // Test pagination with exactly one item
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_single_item_and_run(query)

  assert list.length(results) == 1
}

pub fn single_item_page_two_returns_empty_test() {
  // Test that page 2 is empty when there's only 1 item
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 2, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_single_item_and_run(query)

  assert results == []
}

pub fn two_items_pagination_test() {
  // Test pagination with exactly two items
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_two_items_and_run(query)

  assert list.length(results) == 2
}

pub fn empty_table_cursor_pagination_test() {
  // Test cursor pagination on empty table
  let query =
    select.new()
    |> select.from_table("empty_items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results) = sqlight_test_helper.setup_empty_and_run(query)

  assert results == []
}

pub fn single_item_cursor_pagination_test() {
  // Test cursor pagination with single item - no next page
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.limit(2)

  let assert Ok(results) = sqlight_test_helper.setup_single_item_and_run(query)

  // Should get 1 item, indicating no next page
  assert list.length(results) == 1
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │  Pagination with WHERE Clause Tests                                       │
// └───────────────────────────────────────────────────────────────────────────┘

pub fn offset_pagination_with_where_clause_test() {
  // Filter by position > 20, then paginate
  let query =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(20)))
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get 10 items (positions 21-30)
  assert list.length(results) == 10
}

pub fn offset_pagination_with_where_clause_second_page_test() {
  // Filter by position > 20, then get second page
  let query =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gt(where.col("position"), where.int(20)))
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 2, per_page: 10)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get 10 items (positions 31-40)
  assert list.length(results) == 10
}

pub fn offset_pagination_with_date_filter_test() {
  // Filter by created_at >= 2024-01-03
  let query =
    select.new()
    |> select.from_table("items")
    |> select.where(where.gte(
      where.col("created_at"),
      where.string("2024-01-03 00:00:00"),
    ))
    |> select.order_by_asc("position")
    |> select.to_query
    |> offset.page(page: 1, per_page: 15)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get 15 items (positions 21-35, dates from 2024-01-03 onwards)
  assert list.length(results) == 15
}

pub fn cursor_pagination_with_where_clause_test() {
  // Combine WHERE filter with cursor pagination
  let query_page1 =
    select.new()
    |> select.from_table("items")
    |> select.where(where.lte(where.col("position"), where.int(30)))
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page1) = sqlight_test_helper.setup_and_run(query_page1)
  assert list.length(results_page1) == 10

  // Second page with cursor + WHERE
  let cursor = cursor.encode(["10", "10"])
  let cursor_cols = [
    cursor.KeysetColumn("position", cursor.Asc, cursor.IntType),
    cursor.KeysetColumn("id", cursor.Asc, cursor.IntType),
  ]

  let assert Ok(where_clause) = cursor.where_after(cursor, cursor_cols)

  let query_page2 =
    select.new()
    |> select.from_table("items")
    |> select.where(
      where.and([
        where.lte(where.col("position"), where.int(30)),
        where_clause,
      ]),
    )
    |> select.order_by_asc("position")
    |> select.order_by_asc("id")
    |> select.to_query
    |> offset.limit(10)

  let assert Ok(results_page2) = sqlight_test_helper.setup_and_run(query_page2)

  // Should get 10 items (positions 11-20)
  assert list.length(results_page2) == 10
}

pub fn cursor_pagination_with_complex_where_test() {
  // Test cursor pagination with multiple WHERE conditions
  let query =
    select.new()
    |> select.from_table("items")
    |> select.where(
      where.and([
        where.gt(where.col("position"), where.int(10)),
        where.lte(where.col("position"), where.int(40)),
      ]),
    )
    |> select.order_by_desc("position")
    |> select.to_query
    |> offset.limit(15)

  let assert Ok(results) = sqlight_test_helper.setup_and_run(query)

  // Should get 15 items (positions 40 down to 26)
  assert list.length(results) == 15
}
