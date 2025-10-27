import cake/adapter/mysql
import envoy
import gleam/dynamic/decode
import gleam/int
import gleam/option.{Some}
import gleam/result
import test_support/test_data

fn get_env(key: String, default: String) -> String {
  envoy.get(key)
  |> result.unwrap(default)
}

fn get_env_int(key: String, default: Int) -> Int {
  envoy.get(key)
  |> result.try(int.parse)
  |> result.unwrap(default)
}

fn with_local_test_connection(callback callback) {
  // Support environment variable configuration for CI/CD flexibility
  // Defaults are configured for the Docker Compose setup
  let host = get_env("MYSQL_HOST", "localhost")
  let port = get_env_int("MYSQL_PORT", 3306)
  // MySQL Docker image uses root user by default
  let username = Some("root")
  let password = get_env("MYSQL_PASSWORD", "password")
  let database = get_env("MYSQL_DB", "cake_knife_test")

  mysql.with_connection(
    host: host,
    port: port,
    username: username,
    password: password,
    database: database,
    callback:,
  )
}

pub fn setup_and_run(query) {
  use conn <- with_local_test_connection

  let _ =
    test_data.drop_items_table_if_exists() |> mysql.execute_raw_sql(conn)
  let _ = test_data.create_items_table_mysql() |> mysql.execute_raw_sql(conn)
  let _ = test_data.insert_items_rows() |> mysql.execute_raw_sql(conn)

  query |> mysql.run_read_query(decode.dynamic, conn)
}
