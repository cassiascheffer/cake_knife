import cake/adapter/mysql
import gleam/dynamic/decode
import global_value
import shork
import test_support/test_data

type GlobalConnection {
  GlobalConnection(connection: shork.Connection)
}

fn global_connection() -> shork.Connection {
  global_value.create_with_unique_name("cake_shork_test_connection", fn() {
    let conn =
      shork.default_config()
      |> shork.host("localhost")
      |> shork.port(3306)
      |> shork.user("root")
      |> shork.password("password")
      |> shork.database("cake_knife_test")
      |> shork.connect

    GlobalConnection(conn)
  }).connection
}

pub fn setup_and_run(query) {
  let conn = global_connection()

  let _ = test_data.drop_items_table_if_exists() |> mysql.execute_raw_sql(conn)
  let _ = test_data.create_items_table_mysql() |> mysql.execute_raw_sql(conn)
  let _ = test_data.insert_items_rows() |> mysql.execute_raw_sql(conn)

  query |> mysql.run_read_query(decode.dynamic, conn)
}

pub fn setup_empty_and_run(query) {
  let conn = global_connection()

  let _ = "DROP TABLE IF EXISTS empty_items" |> mysql.execute_raw_sql(conn)
  let _ =
    "CREATE TABLE empty_items (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TIMESTAMP NOT NULL,
      position INT NOT NULL
    )"
    |> mysql.execute_raw_sql(conn)

  // No inserts - table is empty

  query |> mysql.run_read_query(decode.dynamic, conn)
}

pub fn setup_single_item_and_run(query) {
  let conn = global_connection()

  let _ = test_data.drop_items_table_if_exists() |> mysql.execute_raw_sql(conn)
  let _ = test_data.create_items_table_mysql() |> mysql.execute_raw_sql(conn)
  let _ = test_data.insert_single_item() |> mysql.execute_raw_sql(conn)

  query |> mysql.run_read_query(decode.dynamic, conn)
}

pub fn setup_two_items_and_run(query) {
  let conn = global_connection()

  let _ = test_data.drop_items_table_if_exists() |> mysql.execute_raw_sql(conn)
  let _ = test_data.create_items_table_mysql() |> mysql.execute_raw_sql(conn)
  let _ = test_data.insert_two_items() |> mysql.execute_raw_sql(conn)

  query |> mysql.run_read_query(decode.dynamic, conn)
}
