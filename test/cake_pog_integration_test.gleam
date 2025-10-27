import cake/combined
import cake/select
import cake/where
import cake_knife
import gleam/list
import gleeunit
import test_helper/pog_test_helper

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn limit_returns_correct_number_of_rows_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.to_query
    |> cake_knife.limit(10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn offset_skips_correct_rows_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.limit(5)
    |> cake_knife.offset(10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  // Should get items 11-15 (positions 11-15)
  assert list.length(results) == 5
}

pub fn page_one_returns_first_items_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 1, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn page_two_returns_second_batch_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 2, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  assert list.length(results) == 10
}

pub fn last_page_returns_partial_results_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 5, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  // Page 5 with per_page=10 should have items 41-50 (10 items)
  assert list.length(results) == 10
}

pub fn page_six_returns_empty_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 6, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  // Page 6 should be empty (we only have 50 items)
  assert results == []
}

pub fn large_offset_works_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.limit(5)
    |> cake_knife.offset(45)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

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
    |> cake_knife.paginate(page: 3, per_page: 10, max_per_page: 100)

  let assert Ok(results) = pog_test_helper.setup_and_run(paginated_query)

  assert list.length(results) == 10
}

pub fn different_page_sizes_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 2, per_page: 15)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  // Page 2 with per_page=15 should have items 16-30
  assert list.length(results) == 15
}

pub fn combined_limit_offset_page_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_desc("position")
    |> select.to_query
    |> cake_knife.page(page: 1, per_page: 5)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

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
    |> cake_knife.limit(5)

  let assert Ok(results) = pog_test_helper.setup_and_run(combined_query)

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
    |> cake_knife.offset(3)

  let assert Ok(results) = pog_test_helper.setup_and_run(combined_query)

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
    |> cake_knife.page(page: 2, per_page: 5)

  let assert Ok(results) = pog_test_helper.setup_and_run(combined_query)

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
    |> cake_knife.paginate(page: 1, per_page: 5, max_per_page: 100)

  let assert Ok(query) = combined_query
  let assert Ok(results) = pog_test_helper.setup_and_run(query)

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
    |> cake_knife.limit(3)

  let assert Ok(results) = pog_test_helper.setup_and_run(combined_query)

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
    |> cake_knife.offset(5)

  let assert Ok(results) = pog_test_helper.setup_and_run(combined_query)

  // offset is ignored, except returns items 1-10 (10 items)
  assert list.length(results) == 10
}
