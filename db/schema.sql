-- Lược đồ CSDL cho AZ OFFICE – Phân hệ Kinh doanh
-- Toàn bộ dữ liệu ứng dụng được lưu dạng JSONB trong một bản ghi (id = 1),
-- mỗi lần lưu đều ghi lại một bản sao vào bảng lịch sử để có thể khôi phục.

CREATE TABLE IF NOT EXISTS app_state (
  id          INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  data        JSONB       NOT NULL,
  version     INTEGER     NOT NULL DEFAULT 1,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_state_history (
  id          BIGSERIAL PRIMARY KEY,
  version     INTEGER     NOT NULL,
  data        JSONB       NOT NULL,
  saved_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_state_history_saved_at_idx
  ON app_state_history (saved_at DESC);
