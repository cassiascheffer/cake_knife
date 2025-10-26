import cake/adapter/postgres
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import test_support/test_data

@external(erlang, "erlang", "pid_to_list")
fn pid_to_list(pid: anything) -> List(Int)

fn get_env(key: String, default: String) -> String {
  envoy.get(key)
  |> result.unwrap(default)
}

fn get_env_int(key: String, default: Int) -> Int {
  envoy.get(key)
  |> result.try(int.parse)
  |> result.unwrap(default)
}

fn get_env_option(key: String) -> option.Option(String) {
  case envoy.get(key) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn with_local_test_connection(callback callback) {
  // Use a unique process name for each test to avoid conflicts
  // when tests run in parallel. We use the current process's PID
  // to create a unique identifier.
  let pid_string =
    pid_to_list(process.self())
    |> list.map(int.to_string)
    |> string.join("")

  let process_name = process.new_name("cake_pog_test_" <> pid_string)

  // Support environment variable configuration for CI/CD flexibility
  // Defaults are configured for the Docker Compose setup
  let host = get_env("POSTGRES_HOST", "localhost")
  let port = get_env_int("POSTGRES_PORT", 5432)
  let username = get_env("POSTGRES_USER", "postgres")
  let password = case get_env_option("POSTGRES_PASSWORD") {
    Some(pwd) -> Some(pwd)
    None -> Some("postgres")
  }
  let database = get_env("POSTGRES_DB", "cake_knife_test")

  postgres.with_named_connection(
    process: process_name,
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
    test_data.drop_items_table_if_exists() |> postgres.execute_raw_sql(conn)
  let _ = test_data.create_items_table() |> postgres.execute_raw_sql(conn)
  let _ = test_data.insert_items_rows() |> postgres.execute_raw_sql(conn)

  query |> postgres.run_read_query(decode.dynamic, conn)
}
