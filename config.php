<?php
// ===========================================
// NII App — settings
// Real server values go into config.local.php (created by install.sh).
// ===========================================

$settings = [
    "db_host" => "localhost",
    "db_name" => "nii_app",
    "db_user" => "root",
    "db_pass" => "",

    "app_name"    => "NII App",
    "org_name"    => "НИИ Инклюзивного Инжиниринга",
    "journal_url" => "http://89.126.192.248/publish.php",
    "debug"       => true,

    // Codes for registering as admin (organizer) or team member
    "admin_code" => "CHANGE-ME-ADMIN",
    "team_code"  => "CHANGE-ME-TEAM",

    // Family / special access: everything digital is free (bcrypt hash only)
    "free_access_hash" => '$2y$12$J2VcUAsWmBzHJPknmMFAkOc1cZoC5R8ooUMjulpn/fhUu.B5yDjJi',

    // NII Pro subscription
    "currency"  => "USD",
    "pro_price" => 40,
    "pro_days"  => 30,

    "payment_instructions" => "Kaspi (Kaspi Gold / перевод по номеру): +7 771 473 18 52\nЛюбой банк Казахстана — перевод по номеру телефона: +7 771 473 18 52\nСумма в долларах оплачивается в тенге по курсу на день оплаты.\nВ комментарии укажите номер платежа, затем загрузите чек ниже.",
];

if (file_exists(__DIR__ . "/config.local.php")) {
    $settings = array_replace($settings, require __DIR__ . "/config.local.php");
}

ini_set("display_errors", $settings["debug"] ? "1" : "0");
error_reporting(E_ALL);
date_default_timezone_set("Asia/Almaty");

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    $conn = new mysqli($settings["db_host"], $settings["db_user"], $settings["db_pass"], $settings["db_name"]);
    $conn->set_charset("utf8mb4");
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    die($settings["debug"] ? "Database connection failed: " . $e->getMessage() : "Database connection failed.");
}

if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params(["httponly" => true, "samesite" => "Lax"]);
    session_start();
}

require_once __DIR__ . "/lib.php";
