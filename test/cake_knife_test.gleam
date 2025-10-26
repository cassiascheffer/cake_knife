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
