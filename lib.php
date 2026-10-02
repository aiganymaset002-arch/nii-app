<?php
// Shared helpers for NII App pages.

function e($value)
{
    return htmlspecialchars((string)$value, ENT_QUOTES, "UTF-8");
}

function redirect($url)
{
    header("Location: " . $url);
    exit();
}

// Runs a prepared statement: q("SELECT ... WHERE id = ?", [$id])
function q($sql, array $params = [])
{
    global $conn;

    $stmt = $conn->prepare($sql);

    if ($params) {
        $types = "";
        foreach ($params as $p) {
            $types .= is_int($p) ? "i" : (is_float($p) ? "d" : "s");
        }
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();

    return $stmt;
}

function rows($sql, array $params = [])
{
    $result = q($sql, $params)->get_result();

    return $result ? $result->fetch_all(MYSQLI_ASSOC) : [];
}

function row($sql, array $params = [])
{
    $result = q($sql, $params)->get_result();

    return $result ? $result->fetch_assoc() : null;
}

function insert_id()
{
    global $conn;

    return $conn->insert_id;
}

// ---------- Users & roles ----------

function current_user()
{
    static $user = false;

    if ($user === false) {
        $user = isset($_SESSION["uid"]) ? row("SELECT * FROM users WHERE id = ?", [(int)$_SESSION["uid"]]) : null;
    }

    return $user;
}

function require_login()
{
    $user = current_user();

    if (!$user) {
        redirect("login.php");
    }

    return $user;
}

function require_role(...$roles)
{
    $user = require_login();

    if (!in_array($user["role"], $roles, true)) {
        http_response_code(403);
        die("Доступ запрещён.");
    }

    return $user;
}

function is_staff($user)
{
    return $user && in_array($user["role"], ["admin", "team"], true);
}

// Pro = paid subscription, family access or staff
function has_pro($user)
{
    if (!$user) {
        return false;
    }

    return is_staff($user)
        || $user["is_family"]
        || ($user["pro_until"] && $user["pro_until"] >= date("Y-m-d"));
}

function is_free_access_code($code)
{
    global $settings;

    return $code !== "" && password_verify($code, $settings["free_access_hash"]);
}

// ---------- Forms ----------

function csrf_token()
{
    if (empty($_SESSION["csrf"])) {
        $_SESSION["csrf"] = bin2hex(random_bytes(16));
    }

    return $_SESSION["csrf"];
}

function csrf_field()
{
    return '<input type="hidden" name="csrf" value="' . csrf_token() . '">';
}

// true for a POST with a valid token; stops on a bad token
function is_post()
{
    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        return false;
    }

    if (!hash_equals(csrf_token(), $_POST["csrf"] ?? "")) {
        http_response_code(400);
        die("Форма устарела. Обновите страницу и попробуйте снова.");
    }

    return true;
}

function flash($message = null, $type = "ok")
{
    if ($message !== null) {
        $_SESSION["flash"] = [$message, $type];
        return null;
    }

    $f = $_SESSION["flash"] ?? null;
    unset($_SESSION["flash"]);

    return $f;
}

function post($key, $default = "")
{
    return trim((string)($_POST[$key] ?? $default));
}

// ---------- Files ----------

function save_upload($field, array $allowed_ext, $max_mb = 20)
{
    if (!isset($_FILES[$field]) || $_FILES[$field]["error"] !== UPLOAD_ERR_OK) {
        return null;
    }

    $file = $_FILES[$field];
    $ext = strtolower(pathinfo($file["name"], PATHINFO_EXTENSION));

    if (!in_array($ext, $allowed_ext, true) || $file["size"] > $max_mb * 1024 * 1024) {
        return null;
    }

    $dir = __DIR__ . "/uploads/";

    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }

    if (!file_exists($dir . ".htaccess")) {
        file_put_contents($dir . ".htaccess", "<FilesMatch \"\\.(php|phtml|phar)$\">\n    Require all denied\n</FilesMatch>\nOptions -Indexes\n");
    }

    $name = date("YmdHis") . "_" . bin2hex(random_bytes(6)) . "." . $ext;

    return move_uploaded_file($file["tmp_name"], $dir . $name) ? $name : null;
}

function upload_url($name)
{
    return "uploads/" . rawurlencode((string)$name);
}

// ---------- Formatting ----------

function money($amount, $currency = null)
{
    global $settings;

    return number_format((float)$amount, ((float)$amount == floor((float)$amount)) ? 0 : 2, ".", " ")
        . " " . ($currency ?? $settings["currency"]);
}

function fmt_date($value)
{
    return $value ? date("d.m.Y", strtotime($value)) : "—";
}

function fmt_dt($value)
{
    return $value ? date("d.m.Y H:i", strtotime($value)) : "—";
}

// YouTube watch / youtu.be links → embeddable URL; other links unchanged
function video_embed_url($url)
{
    if (preg_match('~(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)([\w-]{6,})~', (string)$url, $m)) {
        return "https://www.youtube.com/embed/" . $m[1];
    }

    return $url;
}

function safe_url($url)
{
    return preg_match('~^https?://~i', (string)$url) ? $url : "";
}

// ---------- Payments ----------

$payment_types = [
    "pro"     => "Подписка NII Pro",
    "course"  => "Курс",
    "event"   => "Участие в мероприятии",
    "product" => "Мерч НИИ",
];

// Price and title of something that can be paid for, or null
function payable_item($type, $id)
{
    global $settings;

    switch ($type) {
        case "pro":
            return ["title" => "NII Pro — " . $settings["pro_days"] . " дней", "price" => (float)$settings["pro_price"]];
        case "course":
            $c = row("SELECT title, price FROM courses WHERE id = ? AND published = 1", [$id]);
            return $c && $c["price"] > 0 ? ["title" => $c["title"], "price" => (float)$c["price"]] : null;
        case "event":
            $ev = row("SELECT title, price FROM events WHERE id = ? AND published = 1", [$id]);
            return $ev && $ev["price"] > 0 ? ["title" => $ev["title"], "price" => (float)$ev["price"]] : null;
        case "product":
            $p = row("SELECT title, price FROM products WHERE id = ? AND active = 1", [$id]);
            return $p ? ["title" => $p["title"], "price" => (float)$p["price"]] : null;
    }

    return null;
}

// Gives the user what they paid for (called when a payment is confirmed or waived)
function fulfil_payment($payment)
{
    global $settings;

    $uid = (int)$payment["user_id"];
    $id = (int)$payment["item_id"];

    switch ($payment["item_type"]) {
        case "pro":
            q("UPDATE users SET pro_until = DATE_ADD(GREATEST(COALESCE(pro_until, CURDATE()), CURDATE()), INTERVAL ? DAY) WHERE id = ?",
              [(int)$settings["pro_days"], $uid]);
            break;
        case "course":
            q("INSERT IGNORE INTO enrollments (user_id, course_id) VALUES (?, ?)", [$uid, $id]);
            break;
        case "event":
            q("INSERT INTO event_regs (event_id, user_id, status) VALUES (?, ?, 'registered')
               ON DUPLICATE KEY UPDATE status = 'registered'", [$id, $uid]);
            break;
    }
}

// Image source: http(s) link or a file uploaded to uploads/
function img_url($url)
{
    $url = (string)$url;

    return (safe_url($url) || preg_match('~^uploads/[\w.%-]+$~', $url)) ? $url : "";
}
