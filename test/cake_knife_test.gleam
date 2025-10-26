import cake
import cake/internal/dialect
import cake/select
import cake_knife
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn limit_adds_limit_clause_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.limit(10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 10")
}

pub fn offset_adds_offset_clause_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.offset(20)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users OFFSET 20")
}

pub fn limit_and_offset_together_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.limit(10)
    |> cake_knife.offset(20)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 10 OFFSET 20")
}

pub fn negative_limit_handling_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.limit(-5)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users")
}

pub fn negative_offset_handling_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.offset(-10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users")
}

pub fn zero_limit_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.limit(0)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users")
}

pub fn zero_offset_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.offset(0)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users")
}

pub fn page_one_starts_at_zero_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.page(page: 1, per_page: 10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 10")
}

pub fn page_two_calculates_correct_offset_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.page(page: 2, per_page: 10)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 10 OFFSET 10")
}

pub fn page_five_with_different_page_size_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.page(page: 5, per_page: 25)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 25 OFFSET 100")
}

pub fn paginate_rejects_zero_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = cake_knife.paginate(query, page: 0, per_page: 10, max_per_page: 100)

  result
  |> should.equal(Error(cake_knife.InvalidPage(0)))
}

pub fn paginate_rejects_negative_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = cake_knife.paginate(query, page: -1, per_page: 10, max_per_page: 100)

  result
  |> should.equal(Error(cake_knife.InvalidPage(-1)))
}

pub fn paginate_rejects_zero_per_page_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = cake_knife.paginate(query, page: 1, per_page: 0, max_per_page: 100)

  result
  |> should.equal(Error(cake_knife.InvalidPerPage(0)))
}

pub fn paginate_rejects_per_page_too_large_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = cake_knife.paginate(query, page: 1, per_page: 150, max_per_page: 100)

  result
  |> should.equal(Error(cake_knife.PerPageTooLarge(150, 100)))
}

pub fn paginate_accepts_valid_inputs_test() {
  let query = select.new() |> select.from_table("users") |> select.to_query

  let result = cake_knife.paginate(query, page: 2, per_page: 10, max_per_page: 100)

  case result {
    Ok(q) -> {
      let sql =
        q
        |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
        |> cake.get_sql

      sql
      |> should.equal("SELECT * FROM users LIMIT 10 OFFSET 10")
    }
    Error(_) -> should.fail()
  }
}

pub fn large_page_numbers_test() {
  let query =
    select.new()
    |> select.from_table("users")
    |> select.to_query
    |> cake_knife.page(page: 1000, per_page: 50)

  let sql =
    query
    |> cake.read_query_to_prepared_statement(dialect: dialect.Postgres)
    |> cake.get_sql

  sql
  |> should.equal("SELECT * FROM users LIMIT 50 OFFSET 49950")
}
