// Cấu hình kết nối Supabase cho trang bán hàng và trang quản trị.
//
// Lấy 2 giá trị này trong Supabase: Project Settings -> API Keys (hoặc nút Connect).
//   SUPABASE_URL : địa chỉ dự án, dạng https://xxxxxxxx.supabase.co
//   SUPABASE_KEY : khóa CÔNG KHAI (publishable, bắt đầu bằng sb_publishable_, hoặc khóa anon cũ).
//
// TUYỆT ĐỐI KHÔNG dán khóa "secret" hoặc "service_role" vào file này,
// vì file này được công khai trên GitHub Pages.
// Khóa công khai là an toàn nhờ các quy tắc quyền (RLS) trong setup.sql.
window.LINHLINK_CONFIG = {
  SUPABASE_URL: "https://czxikuvkdgiggtseqcus.supabase.co",
  SUPABASE_KEY: "sb_publishable_rBKlNLqdkg9LSZoQSoIXtQ_CkSrORFg"
};
