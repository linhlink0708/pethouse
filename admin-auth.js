/* Phần 1/2 của trang quản trị: ĐĂNG NHẬP VÀ PHIÊN LÀM VIỆC.
   login.html và products.html cùng dùng file này, không cần sửa gì trong đây.
   Đọc địa chỉ và khóa công khai từ config.js. Phiên đăng nhập chỉ lưu trong tab đang mở. */
(function () {
  var cfg = window.LINHLINK_CONFIG || {};
  var API = (cfg.SUPABASE_URL || "").replace(/\/+$/, "");
  var KEY = cfg.SUPABASE_KEY || "";
  var LOGIN_PAGE = "login.html";
  var HOME_PAGE = "products.html";
  var STORE = "ll_session";
  var session = null;

  function load() {
    try { var s = sessionStorage.getItem(STORE); session = s ? JSON.parse(s) : null; } catch (e) { session = null; }
  }
  function save(s) {
    session = s;
    try { if (s) sessionStorage.setItem(STORE, JSON.stringify(s)); else sessionStorage.removeItem(STORE); } catch (e) {}
  }
  load();

  function configured() { return !!(API && KEY); }

  function tokenReq(body, grant) {
    return fetch(API + "/auth/v1/token?grant_type=" + grant, {
      method: "POST", headers: { apikey: KEY, "Content-Type": "application/json" }, body: JSON.stringify(body)
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) throw new Error(j.error_description || j.msg || "Đăng nhập thất bại");
        return j;
      });
    });
  }
  function toSession(j, oldEmail) {
    return {
      access_token: j.access_token,
      refresh_token: j.refresh_token,
      expires_at: Date.now() + (j.expires_in || 3600) * 1000,
      email: (j.user && j.user.email) || oldEmail || ""
    };
  }

  /* Trả về access token còn hạn, tự làm mới khi sắp hết hạn. Hết phiên thì quay về trang đăng nhập. */
  function token() {
    if (!session) { goLogin("expired"); return Promise.reject(new Error("expired")); }
    if (session.expires_at - Date.now() > 60000) return Promise.resolve(session.access_token);
    return tokenReq({ refresh_token: session.refresh_token }, "refresh_token").then(function (j) {
      save(toSession(j, session.email));
      return session.access_token;
    }).catch(function () {
      save(null); goLogin("expired"); throw new Error("expired");
    });
  }

  /* Gọi Supabase kèm quyền của tài khoản đang đăng nhập. */
  function api(path, opts) {
    opts = opts || {};
    return token().then(function (tok) {
      var h = Object.assign({ apikey: KEY, Authorization: "Bearer " + tok }, opts.headers || {});
      return fetch(API + path, Object.assign({}, opts, { headers: h }));
    });
  }

  /* Tài khoản đăng nhập có nằm trong bảng admins không. */
  function checkAdmin() {
    return api("/rest/v1/rpc/is_admin", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" })
      .then(function (r) { return r.ok ? r.json() : false; })
      .then(function (v) { return v === true; });
  }

  function login(email, password) {
    return tokenReq({ email: email, password: password }, "password").then(function (j) {
      save(toSession(j));
      return checkAdmin().then(function (ok) {
        if (!ok) { save(null); throw new Error("Đăng nhập đúng nhưng tài khoản này chưa có quyền quản trị. Hãy thêm email vào bảng admins trong Supabase."); }
        return session;
      });
    }).catch(function (e) {
      if (e.message === "Invalid login credentials") throw new Error("Email hoặc mật khẩu không đúng.");
      if (e.message === "Email not confirmed") throw new Error("Email chưa được xác nhận. Trong Supabase, mở Authentication, Users và xác nhận tài khoản này.");
      throw e;
    });
  }

  function logout() {
    var tok = session && session.access_token;
    save(null);
    if (!tok) return Promise.resolve();
    return fetch(API + "/auth/v1/logout", { method: "POST", headers: { apikey: KEY, Authorization: "Bearer " + tok } }).catch(function () {});
  }

  function goLogin(reason) { location.replace(LOGIN_PAGE + (reason ? "?" + reason + "=1" : "")); }
  function goHome() { location.replace(HOME_PAGE); }

  /* Dùng ở đầu trang cần đăng nhập: chưa có phiên thì chuyển về trang đăng nhập. */
  function requireLogin() {
    if (!session) { goLogin(""); return false; }
    return true;
  }

  function errText(r, j, fallback) {
    if (r.status === 401 || r.status === 403) return "Tài khoản này không có quyền thực hiện thao tác này. Hãy kiểm tra email trong bảng admins.";
    return (j && (j.message || j.error_description || j.error)) || fallback;
  }

  window.LLAuth = {
    configured: configured,
    hasSession: function () { return !!session; },
    email: function () { return session ? session.email : ""; },
    login: login, logout: logout, token: token, api: api,
    requireLogin: requireLogin, goLogin: goLogin, goHome: goHome, errText: errText,
    apiUrl: function () { return API; },
    apiKey: function () { return KEY; }
  };
})();
