/* Màu (tone) và hình minh họa (icon) dùng chung cho trang bán hàng (index.html) và trang quản lý sản phẩm (products.html).
   Dữ liệu thật nằm trong 2 bảng "tones" và "icons" của Supabase (sửa trong Table Editor).
   File này chỉ vẽ icon từ mã SVG và áp màu. Không cần sửa gì trong đây.
   Mã SVG lấy từ database được lọc kỹ: chỉ giữ các thẻ hình vẽ cơ bản, bỏ mọi script, sự kiện và link ngoài (thẻ lạ bị bỏ qua, phần còn lại vẫn vẽ). */
(function () {
  var NS = "http://www.w3.org/2000/svg";

  /* Bộ icon và màu mặc định: dùng khi chưa kết nối Supabase hoặc khi tải bảng bị lỗi */
  var DEFAULT_ICONS = {
    "paw": "<svg viewBox=\"0 0 48 48\" fill=\"currentColor\"><path d=\"M24 40c-7 0-12-3-12-8 0-4 5-9 12-9s12 5 12 9c0 5-5 8-12 8z\"/><circle cx=\"10\" cy=\"22\" r=\"4.5\"/><circle cx=\"19\" cy=\"13\" r=\"4.5\"/><circle cx=\"29\" cy=\"13\" r=\"4.5\"/><circle cx=\"38\" cy=\"22\" r=\"4.5\"/></svg>",
    "fountain": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10 42h28v-8H10z\"/><path d=\"M14 34V23a10 10 0 0 1 20 0v11\"/><path d=\"M24 13V7M19 7h10\"/><path d=\"M20 28c0 2 2 3 4 3s4-1 4-3\"/></svg>",
    "bed": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M5 31c0-7 8-12 19-12s19 5 19 12v6H5z\"/><path d=\"M11 29c3-3 8-4 13-4s10 1 13 4\"/></svg>",
    "scratch": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M8 43h32\"/><path d=\"M20 43V8h8v35\"/><path d=\"M20 15l8 3M20 24l8 3M20 33l8 3\"/><path d=\"M28 12h10v6H28z\"/></svg>",
    "collar": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 22c0-8 7-13 17-13s17 5 17 13-7 13-17 13S7 30 7 22z\"/><path d=\"M24 35v3\"/><circle cx=\"24\" cy=\"42\" r=\"3\"/></svg>",
    "blender": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M16 9h16l-3 24H19z\"/><path d=\"M14 33h20v9H14z\"/><path d=\"M18 9V6h12v3\"/><path d=\"M20 20h8\"/></svg>",
    "lamp": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M24 6a11 11 0 0 0-6 20c1 1 1 3 1 4h10c0-1 0-3 1-4a11 11 0 0 0-6-20z\"/><path d=\"M20 35h8M21 40h6\"/></svg>",
    "purifier": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"12\" y=\"6\" width=\"24\" height=\"36\" rx=\"4\"/><path d=\"M17 14h14M17 19h14M17 24h14\"/><circle cx=\"24\" cy=\"34\" r=\"2.5\"/></svg>",
    "bottle": "<svg viewBox=\"0 0 48 48\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M19 5h10v6l3 4v26a2 2 0 0 1-2 2H18a2 2 0 0 1-2-2V15l3-4z\"/><path d=\"M16 24h16\"/></svg>"
  };
  var DEFAULT_TONES = [
    { slug: "yellow", color: "#ffd23f", color_dark: "#f7c92f" },
    { slug: "pink",   color: "#ff9db1", color_dark: "#f58aa0" },
    { slug: "sky",    color: "#8fd0ff", color_dark: "#7cc4f5" },
    { slug: "mint",   color: "#9fe8c4", color_dark: "#8fdcb8" }
  ];

  var icons = {};
  Object.keys(DEFAULT_ICONS).forEach(function (k) { icons[k] = DEFAULT_ICONS[k]; });
  var cache = {};

  var EL_OK = { svg: 1, g: 1, path: 1, circle: 1, ellipse: 1, rect: 1, line: 1, polyline: 1, polygon: 1 };
  var ATTR_OK = {
    d: 1, cx: 1, cy: 1, r: 1, rx: 1, ry: 1, x: 1, y: 1, width: 1, height: 1, x1: 1, y1: 1, x2: 1, y2: 1, points: 1,
    fill: 1, stroke: 1, "stroke-width": 1, "stroke-linecap": 1, "stroke-linejoin": 1, "fill-rule": 1, "clip-rule": 1,
    opacity: 1, "fill-opacity": 1, "stroke-opacity": 1, transform: 1
  };
  var VAL_OK = /^[\w\s.,#%()+\-]*$/;
  var HEX = /^#[0-9a-fA-F]{6}$/;
  var SLUG = /^[a-z0-9-]{1,30}$/;

  function valueOk(v) { return v.length <= 2000 && VAL_OK.test(v) && !/url\s*\(/i.test(v); }

  /* Lọc mã SVG: chỉ giữ thẻ và thuộc tính trong danh sách cho phép. Trả về phần tử svg mới, hoặc null nếu không hợp lệ. */
  function sanitizeSvg(code) {
    if (typeof code !== "string" || code.length < 10 || code.length > 4000) return null;
    var doc;
    try { doc = new DOMParser().parseFromString(code, "image/svg+xml"); } catch (e) { return null; }
    var root = doc.documentElement;
    if (!root || root.localName !== "svg" || doc.getElementsByTagName("parsererror").length) return null;
    var count = 0, bad = false;
    function copy(src, isRoot) {
      var name = src.localName;
      if (!EL_OK[name]) return null;
      if (++count > 200) { bad = true; return null; }
      var out = document.createElementNS(NS, name);
      for (var i = 0; i < src.attributes.length; i++) {
        var a = src.attributes[i], n = a.name, v = a.value;
        if (isRoot && n === "viewBox") {
          if (/^[\d\s.,-]+$/.test(v)) out.setAttribute("viewBox", v.trim());
        } else if (ATTR_OK[n] && valueOk(v)) {
          out.setAttribute(n, v);
        }
      }
      for (var c = src.firstElementChild; c; c = c.nextElementSibling) {
        var k = copy(c, false);
        if (bad) return null;
        if (k) out.appendChild(k);
      }
      return out;
    }
    var svg = copy(root, true);
    if (bad || !svg) return null;
    if (!svg.getAttribute("viewBox")) svg.setAttribute("viewBox", "0 0 48 48");
    if (!svg.hasAttribute("fill") && !svg.hasAttribute("stroke")) svg.setAttribute("fill", "currentColor");
    svg.setAttribute("aria-hidden", "true");
    return svg;
  }

  function setIcons(rows) {
    icons = {}; cache = {};
    Object.keys(DEFAULT_ICONS).forEach(function (k) { icons[k] = DEFAULT_ICONS[k]; });
    (rows || []).forEach(function (r) { if (r && SLUG.test(r.slug || "") && typeof r.svg === "string") icons[r.slug] = r.svg; });
  }

  /* Trả về một phần tử svg mới cho icon có tên slug. Không tìm thấy hoặc mã SVG lỗi thì dùng icon dấu chân. */
  function icon(slug, cls) {
    var el = sanitizeSvg(icons[slug]) || sanitizeSvg(DEFAULT_ICONS.paw);
    if (cls) el.setAttribute("class", cls);
    return el;
  }

  /* Tạo các lớp .c-<tên màu> từ bảng tones, có màu riêng cho giao diện tối */
  function applyTones(rows) {
    var css = "";
    (rows || []).forEach(function (t) {
      if (!t || !SLUG.test(t.slug || "") || !HEX.test(t.color || "")) return;
      var dark = HEX.test(t.color_dark || "") ? t.color_dark : t.color, sel = ".c-" + t.slug;
      css += sel + "{background:" + t.color + "}" +
        "@media (prefers-color-scheme: dark){:root:not([data-theme=\"light\"]) " + sel + "{background:" + dark + "}}" +
        ":root[data-theme=\"dark\"] " + sel + "{background:" + dark + "}\n";
    });
    var st = document.getElementById("ll-tones");
    if (!st) { st = document.createElement("style"); st.id = "ll-tones"; document.head.appendChild(st); }
    st.textContent = css;
  }

  function safeSlug(s) { return SLUG.test(s || "") ? s : ""; }

  /* Điền icon mặc định vào các phần tử có thuộc tính data-icon="tên" (phần trang trí cố định) */
  function fillStatic(root) {
    (root || document).querySelectorAll("[data-icon]").forEach(function (box) {
      var old = box.querySelector(":scope > svg");
      if (old) old.remove();
      box.insertBefore(icon(box.getAttribute("data-icon")), box.firstChild);
    });
  }

  window.LLApp = {
    DEFAULT_ICONS: DEFAULT_ICONS, DEFAULT_TONES: DEFAULT_TONES,
    sanitizeSvg: sanitizeSvg, setIcons: setIcons, icon: icon, applyTones: applyTones, safeSlug: safeSlug, fillStatic: fillStatic
  };
})();
