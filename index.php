<?php
require_once "config.php";
require_once "layout.php";

$user = current_user();

if ($user) {
    redirect($user["role"] === "admin" ? "admin.php" : "home.php");
}

page_header("Добро пожаловать");
?>
<div class="max-w-3xl mx-auto text-center py-8">
    <img src="assets/icon-512.png" alt="" class="w-28 h-28 mx-auto rounded-3xl shadow-lg">
    <h1 class="text-3xl md:text-4xl font-bold mt-6"><?= e($settings["org_name"]) ?></h1>
    <p class="text-slate-600 mt-3 text-lg">Science × Technology × Inclusion × Impact</p>
    <p class="text-slate-600 mt-2">Курсы, конференции, онлайн-лаборатория, программы и новости НИИ — в одном приложении.</p>

    <div class="flex flex-col sm:flex-row gap-3 justify-center mt-8">
        <a href="register.php" class="btn btn-primary text-lg">Создать аккаунт</a>
        <a href="login.php" class="btn btn-light text-lg">Войти</a>
    </div>

    <div class="grid sm:grid-cols-3 gap-4 mt-12 text-left">
        <div class="card p-5"><div class="text-2xl">🎓</div><h3 class="font-bold mt-2">Курсы</h3><p class="text-sm text-slate-600">Бесплатные и Pro-курсы от исследователей НИИ.</p></div>
        <div class="card p-5"><div class="text-2xl">📅</div><h3 class="font-bold mt-2">Конференции</h3><p class="text-sm text-slate-600">Регистрация в один клик и ссылка на Zoom.</p></div>
        <div class="card p-5"><div class="text-2xl">🧪</div><h3 class="font-bold mt-2">Онлайн-лаборатория</h3><p class="text-sm text-slate-600">Запись на консультации и лабораторные сессии.</p></div>
    </div>
</div>
<?php page_footer();
