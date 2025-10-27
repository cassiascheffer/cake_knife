import cake/adapter/postgres
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/option.{Some}
import global_value
import pog
import test_support/test_data

type GlobalConnection {
  GlobalConnection(connection: pog.Connection)
}

fn global_connection() -> pog.Connection {
  global_value.create_with_unique_name("cake_pog_test_connection", fn() {
    let process_name = process.new_name("cake_pog_test_global")

    let pog_config =
      pog.default_config(process_name)
      |> pog.host("localhost")
      |> pog.port(5432)
      |> pog.user("postgres")
      |> pog.password(Some("postgres"))
      |> pog.database("cake_knife_test")

    let assert Ok(actor) = pog.start(pog_config)

    GlobalConnection(actor.data)
  }).connection
}

pub fn setup_and_run(query) {
  let conn = global_connection()

  let _ =
    test_data.drop_items_table_if_exists() |> postgres.execute_raw_sql(conn)
  let _ = test_data.create_items_table() |> postgres.execute_raw_sql(conn)
  let _ = test_data.insert_items_rows() |> postgres.execute_raw_sql(conn)

  query |> postgres.run_read_query(decode.dynamic, conn)
}

pub fn setup_empty_and_run(query) {
  let conn = global_connection()

  let _ = "DROP TABLE IF EXISTS empty_items" |> postgres.execute_raw_sql(conn)
  let _ =
    "CREATE TABLE empty_items (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TIMESTAMP NOT NULL,
      position INTEGER NOT NULL
    )"
    |> postgres.execute_raw_sql(conn)

  // No inserts - table is empty

  query |> postgres.run_read_query(decode.dynamic, conn)
}

pub fn setup_single_item_and_run(query) {
  let conn = global_connection()

  let _ =
    test_data.drop_items_table_if_exists() |> postgres.execute_raw_sql(conn)
  let _ = test_data.create_items_table() |> postgres.execute_raw_sql(conn)
  let _ = test_data.insert_single_item() |> postgres.execute_raw_sql(conn)

  query |> postgres.run_read_query(decode.dynamic, conn)
}

pub fn setup_two_items_and_run(query) {
  let conn = global_connection()

  let _ =
    test_data.drop_items_table_if_exists() |> postgres.execute_raw_sql(conn)
  let _ = test_data.create_items_table() |> postgres.execute_raw_sql(conn)
  let _ = test_data.insert_two_items() |> postgres.execute_raw_sql(conn)

  query |> postgres.run_read_query(decode.dynamic, conn)
}
