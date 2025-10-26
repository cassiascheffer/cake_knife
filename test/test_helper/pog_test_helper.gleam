import cake/adapter/postgres
import gleam/dynamic/decode
import gleam/option.{Some}
import test_support/test_data

fn with_local_test_connection(callback callback) {
  postgres.with_connection(
    host: "localhost",
    port: 5432,
    username: "postgres",
    password: Some("postgres"),
    database: "cake_knife_test",
    callback:,
  )
}

pub fn setup_and_run(query) {
  use conn <- with_local_test_connection

  let _ =
    test_data.drop_items_table_if_exists() |> postgres.execute_raw_sql(conn)
  let _ = test_data.create_items_table() |> postgres.execute_raw_sql(conn)
  let _ = test_data.insert_items_rows() |> postgres.execute_raw_sql(conn)

  query |> postgres.run_read_query(decode.dynamic, conn)
}
