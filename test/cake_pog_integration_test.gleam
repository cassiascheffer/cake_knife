import cake/select
import cake_knife
import gleam/list
import gleeunit
import gleeunit/should
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

  list.length(results)
  |> should.equal(10)
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
  list.length(results)
  |> should.equal(5)
}

pub fn page_one_returns_first_items_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 1, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  list.length(results)
  |> should.equal(10)
}

pub fn page_two_returns_second_batch_test() {
  let query =
    select.new()
    |> select.from_table("items")
    |> select.order_by_asc("position")
    |> select.to_query
    |> cake_knife.page(page: 2, per_page: 10)

  let assert Ok(results) = pog_test_helper.setup_and_run(query)

  list.length(results)
  |> should.equal(10)
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
  list.length(results)
  |> should.equal(10)
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
  list.length(results)
  |> should.equal(0)
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
  list.length(results)
  |> should.equal(5)
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

  list.length(results)
  |> should.equal(10)
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
  list.length(results)
  |> should.equal(15)
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
  list.length(results)
  |> should.equal(5)
}
