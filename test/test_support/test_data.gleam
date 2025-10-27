pub fn drop_items_table_if_exists() -> String {
  "DROP TABLE IF EXISTS items"
}

pub fn create_items_table() -> String {
  "CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    position INTEGER NOT NULL
  )"
}

pub fn create_items_table_sqlite() -> String {
  "CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at TEXT NOT NULL,
    position INTEGER NOT NULL
  )"
}

pub fn create_items_table_mysql() -> String {
  "CREATE TABLE items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    position INT NOT NULL
  )"
}

pub fn insert_items_rows() -> String {
  "INSERT INTO items (name, created_at, position) VALUES
    ('Item 1', '2024-01-01 10:00:00', 1),
    ('Item 2', '2024-01-01 11:00:00', 2),
    ('Item 3', '2024-01-01 12:00:00', 3),
    ('Item 4', '2024-01-01 13:00:00', 4),
    ('Item 5', '2024-01-01 14:00:00', 5),
    ('Item 6', '2024-01-01 15:00:00', 6),
    ('Item 7', '2024-01-01 16:00:00', 7),
    ('Item 8', '2024-01-01 17:00:00', 8),
    ('Item 9', '2024-01-01 18:00:00', 9),
    ('Item 10', '2024-01-01 19:00:00', 10),
    ('Item 11', '2024-01-02 10:00:00', 11),
    ('Item 12', '2024-01-02 11:00:00', 12),
    ('Item 13', '2024-01-02 12:00:00', 13),
    ('Item 14', '2024-01-02 13:00:00', 14),
    ('Item 15', '2024-01-02 14:00:00', 15),
    ('Item 16', '2024-01-02 15:00:00', 16),
    ('Item 17', '2024-01-02 16:00:00', 17),
    ('Item 18', '2024-01-02 17:00:00', 18),
    ('Item 19', '2024-01-02 18:00:00', 19),
    ('Item 20', '2024-01-02 19:00:00', 20),
    ('Item 21', '2024-01-03 10:00:00', 21),
    ('Item 22', '2024-01-03 11:00:00', 22),
    ('Item 23', '2024-01-03 12:00:00', 23),
    ('Item 24', '2024-01-03 13:00:00', 24),
    ('Item 25', '2024-01-03 14:00:00', 25),
    ('Item 26', '2024-01-03 15:00:00', 26),
    ('Item 27', '2024-01-03 16:00:00', 27),
    ('Item 28', '2024-01-03 17:00:00', 28),
    ('Item 29', '2024-01-03 18:00:00', 29),
    ('Item 30', '2024-01-03 19:00:00', 30),
    ('Item 31', '2024-01-04 10:00:00', 31),
    ('Item 32', '2024-01-04 11:00:00', 32),
    ('Item 33', '2024-01-04 12:00:00', 33),
    ('Item 34', '2024-01-04 13:00:00', 34),
    ('Item 35', '2024-01-04 14:00:00', 35),
    ('Item 36', '2024-01-04 15:00:00', 36),
    ('Item 37', '2024-01-04 16:00:00', 37),
    ('Item 38', '2024-01-04 17:00:00', 38),
    ('Item 39', '2024-01-04 18:00:00', 39),
    ('Item 40', '2024-01-04 19:00:00', 40),
    ('Item 41', '2024-01-05 10:00:00', 41),
    ('Item 42', '2024-01-05 11:00:00', 42),
    ('Item 43', '2024-01-05 12:00:00', 43),
    ('Item 44', '2024-01-05 13:00:00', 44),
    ('Item 45', '2024-01-05 14:00:00', 45),
    ('Item 46', '2024-01-05 15:00:00', 46),
    ('Item 47', '2024-01-05 16:00:00', 47),
    ('Item 48', '2024-01-05 17:00:00', 48),
    ('Item 49', '2024-01-05 18:00:00', 49),
    ('Item 50', '2024-01-05 19:00:00', 50)"
}
