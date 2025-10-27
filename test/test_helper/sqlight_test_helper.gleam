import cake
import cake/internal/dialect
import cake/param
import gleam/dynamic/decode
import gleam/list
import sqlight.{type Connection}
import test_support/test_data

fn with_test_connection(callback: fn(Connection) -> a) -> a {
  // Create an in-memory SQLite database for each test
  let assert Ok(conn) = sqlight.open(":memory:")
  let result = callback(conn)
  let _ = sqlight.close(conn)
  result
}

pub fn setup_and_run(query) {
  use conn <- with_test_connection

  let _ = test_data.drop_items_table_if_exists() |> sqlight.exec(conn)
  let _ = test_data.create_items_table_sqlite() |> sqlight.exec(conn)
  let _ = test_data.insert_items_rows() |> sqlight.exec(conn)

  // Convert Cake query to SQL and execute with sqlight
  let prepared = cake.read_query_to_prepared_statement(query, dialect.Sqlite)
  let sql = cake.get_sql(prepared)
  let params =
    cake.get_params(prepared)
    |> list.map(fn(p) {
      case p {
        param.StringParam(s) -> sqlight.text(s)
        param.IntParam(i) -> sqlight.int(i)
        param.FloatParam(f) -> sqlight.float(f)
        param.BoolParam(True) -> sqlight.int(1)
        param.BoolParam(False) -> sqlight.int(0)
        param.NullParam -> sqlight.null()
      }
    })

  sqlight.query(sql, conn, params, decode.dynamic)
}

pub fn setup_empty_and_run(query) {
  use conn <- with_test_connection

  let _ = "DROP TABLE IF EXISTS empty_items" |> sqlight.exec(conn)
  let _ =
    "CREATE TABLE empty_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      position INTEGER NOT NULL
    )"
    |> sqlight.exec(conn)

  // No inserts - table is empty

  let prepared = cake.read_query_to_prepared_statement(query, dialect.Sqlite)
  let sql = cake.get_sql(prepared)
  let params =
    cake.get_params(prepared)
    |> list.map(fn(p) {
      case p {
        param.StringParam(s) -> sqlight.text(s)
        param.IntParam(i) -> sqlight.int(i)
        param.FloatParam(f) -> sqlight.float(f)
        param.BoolParam(True) -> sqlight.int(1)
        param.BoolParam(False) -> sqlight.int(0)
        param.NullParam -> sqlight.null()
      }
    })

  sqlight.query(sql, conn, params, decode.dynamic)
}

pub fn setup_single_item_and_run(query) {
  use conn <- with_test_connection

  let _ = test_data.drop_items_table_if_exists() |> sqlight.exec(conn)
  let _ = test_data.create_items_table_sqlite() |> sqlight.exec(conn)
  let _ = test_data.insert_single_item() |> sqlight.exec(conn)

  let prepared = cake.read_query_to_prepared_statement(query, dialect.Sqlite)
  let sql = cake.get_sql(prepared)
  let params =
    cake.get_params(prepared)
    |> list.map(fn(p) {
      case p {
        param.StringParam(s) -> sqlight.text(s)
        param.IntParam(i) -> sqlight.int(i)
        param.FloatParam(f) -> sqlight.float(f)
        param.BoolParam(True) -> sqlight.int(1)
        param.BoolParam(False) -> sqlight.int(0)
        param.NullParam -> sqlight.null()
      }
    })

  sqlight.query(sql, conn, params, decode.dynamic)
}

pub fn setup_two_items_and_run(query) {
  use conn <- with_test_connection

  let _ = test_data.drop_items_table_if_exists() |> sqlight.exec(conn)
  let _ = test_data.create_items_table_sqlite() |> sqlight.exec(conn)
  let _ = test_data.insert_two_items() |> sqlight.exec(conn)

  let prepared = cake.read_query_to_prepared_statement(query, dialect.Sqlite)
  let sql = cake.get_sql(prepared)
  let params =
    cake.get_params(prepared)
    |> list.map(fn(p) {
      case p {
        param.StringParam(s) -> sqlight.text(s)
        param.IntParam(i) -> sqlight.int(i)
        param.FloatParam(f) -> sqlight.float(f)
        param.BoolParam(True) -> sqlight.int(1)
        param.BoolParam(False) -> sqlight.int(0)
        param.NullParam -> sqlight.null()
      }
    })

  sqlight.query(sql, conn, params, decode.dynamic)
}
