import cake
import cake/internal/dialect
import cake/select
import cake_knife/keyset
import cake_knife/offset
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn limit_adds_limit_clause_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.limit(10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 10"
}

pub fn offset_adds_offset_clause_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.offset(20)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users OFFSET 20"
}

pub fn limit_and_offset_together_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.limit(10)
    |> offset.offset(20)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 10 OFFSET 20"
}

pub fn negative_limit_handling_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.limit(-5)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users"
}

pub fn negative_offset_handling_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.offset(-10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users"
}

pub fn zero_limit_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.limit(0)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users"
}

pub fn zero_offset_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.offset(0)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users"
}

pub fn page_one_starts_at_zero_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.page(page: 1, per_page: 10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 10"
}

pub fn page_two_calculates_correct_offset_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.page(page: 2, per_page: 10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 10 OFFSET 10"
}

pub fn page_five_with_different_page_size_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.page(page: 5, per_page: 25)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 25 OFFSET 100"
}

pub fn paginate_rejects_zero_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = offset.paginate(query, page: 0, per_page: 10, max_per_page: 100)

  assert result == Error(offset.InvalidPage(0))
}

pub fn paginate_rejects_negative_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = offset.paginate(query, page: -1, per_page: 10, max_per_page: 100)

  assert result == Error(offset.InvalidPage(-1))
}

pub fn paginate_rejects_zero_per_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = offset.paginate(query, page: 1, per_page: 0, max_per_page: 100)

  assert result == Error(offset.InvalidPerPage(0))
}

pub fn paginate_rejects_per_page_too_large_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = offset.paginate(query, page: 1, per_page: 150, max_per_page: 100)

  assert result == Error(offset.PerPageTooLarge(150, 100))
}

pub fn paginate_accepts_valid_inputs_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = offset.paginate(query, page: 2, per_page: 10, max_per_page: 100)

  let assert Ok(q) = result
  let sql =
    q
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 10 OFFSET 10"
}

pub fn large_page_numbers_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> offset.page(page: 1000, per_page: 50)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM users LIMIT 50 OFFSET 49950"
}

pub fn total_pages_with_exact_division_test() {
  let result = offset.calculate_total_pages(total_count: 100, per_page: 20)
  assert result == 5
}

pub fn total_pages_with_remainder_test() {
  let result = offset.calculate_total_pages(total_count: 101, per_page: 20)
  assert result == 6
}

pub fn total_pages_with_small_remainder_test() {
  let result = offset.calculate_total_pages(total_count: 10, per_page: 3)
  assert result == 4
}

pub fn zero_total_count_handling_test() {
  let result = offset.calculate_total_pages(total_count: 0, per_page: 10)
  assert result == 0
}

pub fn new_page_has_next_true_when_more_pages_test() {
  let page = offset.new_page(data: [], page: 2, per_page: 10, total_count: 50)

  assert page.has_next == True
}

pub fn new_page_has_next_false_on_last_page_test() {
  let page = offset.new_page(data: [], page: 5, per_page: 10, total_count: 50)

  assert page.has_next == False
}

pub fn new_page_has_previous_false_on_first_page_test() {
  let page = offset.new_page(data: [], page: 1, per_page: 10, total_count: 50)

  assert page.has_previous == False
}

pub fn new_page_has_previous_true_on_later_pages_test() {
  let page = offset.new_page(data: [], page: 2, per_page: 10, total_count: 50)

  assert page.has_previous == True
}

pub fn single_page_result_test() {
  let page =
    offset.new_page(data: [1, 2, 3], page: 1, per_page: 10, total_count: 3)

  assert page.total_pages == 1
  assert page.has_next == False
  assert page.has_previous == False
}

pub fn cursor_roundtrip_test() {
  let values = ["2024-01-15T10:30:00Z", "12345"]
  let cursor = keyset.encode_cursor(values)
  let result = keyset.decode_cursor(cursor)

  assert result == Ok(values)
}

pub fn cursor_with_single_value_test() {
  let values = ["single"]
  let cursor = keyset.encode_cursor(values)
  let result = keyset.decode_cursor(cursor)

  assert result == Ok(values)
}

pub fn cursor_with_multiple_values_test() {
  let values = ["first", "second", "third", "fourth"]
  let cursor = keyset.encode_cursor(values)
  let result = keyset.decode_cursor(cursor)

  assert result == Ok(values)
}

pub fn cursor_with_empty_list_test() {
  let values = []
  let cursor = keyset.encode_cursor(values)
  let result = keyset.decode_cursor(cursor)

  assert result == Ok(values)
}

pub fn cursor_with_special_characters_test() {
  let values = ["hello \"world\"", "unicode: 🎉", "newline:\n", "tab:\t"]
  let cursor = keyset.encode_cursor(values)
  let result = keyset.decode_cursor(cursor)

  assert result == Ok(values)
}

pub fn decode_invalid_base64_test() {
  let bad_cursor = keyset.cursor_from_string("not!valid@base64#")
  let result = keyset.decode_cursor(bad_cursor)

  assert result == Error(keyset.InvalidBase64)
}

pub fn decode_invalid_json_test() {
  let bad_cursor = keyset.cursor_from_string("aW52YWxpZCBqc29u")
  let result = keyset.decode_cursor(bad_cursor)

  assert result == Error(keyset.InvalidJson)
}

pub fn decode_non_array_json_test() {
  let bad_cursor = keyset.cursor_from_string("eyJub3QiOiJhbiBhcnJheSJ9")
  let result = keyset.decode_cursor(bad_cursor)

  assert result == Error(keyset.NotAnArray)
}

pub fn cursor_is_opaque_test() {
  let cursor = keyset.encode_cursor(["test"])
  let cursor_string = keyset.cursor_to_string(cursor)

  assert cursor_string != "test"
}

pub fn keyset_where_after_single_column_desc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM posts WHERE created_at < '2024-01-15'::timestamp"
}

pub fn keyset_where_after_single_column_asc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Asc, keyset.TimestampType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM posts WHERE created_at > '2024-01-15'::timestamp"
}

pub fn keyset_where_after_two_columns_desc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15", "100"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
    keyset.KeysetColumn("id", keyset.Desc, keyset.IntType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql
    == "SELECT * FROM posts WHERE (created_at < '2024-01-15'::timestamp OR created_at = '2024-01-15'::timestamp AND id < $1)"
}

pub fn keyset_where_after_two_columns_asc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15", "100"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Asc, keyset.TimestampType),
    keyset.KeysetColumn("id", keyset.Asc, keyset.IntType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql
    == "SELECT * FROM posts WHERE (created_at > '2024-01-15'::timestamp OR created_at = '2024-01-15'::timestamp AND id > $1)"
}

pub fn keyset_where_after_three_columns_desc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15", "100", "42"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
    keyset.KeysetColumn("id", keyset.Desc, keyset.IntType),
    keyset.KeysetColumn("version", keyset.Desc, keyset.IntType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql
    == "SELECT * FROM posts WHERE (created_at < '2024-01-15'::timestamp OR created_at = '2024-01-15'::timestamp AND (id < $1 OR id = $2 AND version < $3))"
}

pub fn keyset_where_before_single_column_desc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_before(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql == "SELECT * FROM posts WHERE created_at > '2024-01-15'::timestamp"
}

pub fn keyset_where_before_two_columns_desc_test() {
  let cursor = keyset.encode_cursor(["2024-01-15", "100"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
    keyset.KeysetColumn("id", keyset.Desc, keyset.IntType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_before(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql
    == "SELECT * FROM posts WHERE (created_at > '2024-01-15'::timestamp OR created_at = '2024-01-15'::timestamp AND id > $1)"
}

pub fn keyset_where_after_mixed_directions_test() {
  let cursor = keyset.encode_cursor(["2024-01-15", "100"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.TimestampType),
    keyset.KeysetColumn("id", keyset.Asc, keyset.IntType),
  ]

  let assert Ok(where_clause) = keyset.keyset_where_after(cursor, keyset_cols)

  let query =
    select.new()
    |> select.from_table("posts")
    |> select.where(where_clause)
    |> select.to_query

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  assert sql
    == "SELECT * FROM posts WHERE (created_at < '2024-01-15'::timestamp OR created_at = '2024-01-15'::timestamp AND id > $1)"
}

pub fn keyset_where_after_mismatched_cursor_length_test() {
  let cursor = keyset.encode_cursor(["2024-01-15"])
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.StringType),
    keyset.KeysetColumn("id", keyset.Desc, keyset.IntType),
  ]

  let result = keyset.keyset_where_after(cursor, keyset_cols)

  assert result == Error(keyset.MismatchedCursorLength(expected: 2, got: 1))
}

pub fn keyset_where_after_invalid_cursor_test() {
  let bad_cursor = keyset.cursor_from_string("not-valid-base64!")
  let keyset_cols = [
    keyset.KeysetColumn("created_at", keyset.Desc, keyset.StringType),
  ]

  let result = keyset.keyset_where_after(bad_cursor, keyset_cols)

  assert result == Error(keyset.InvalidCursor(keyset.InvalidBase64))
}
