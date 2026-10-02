<?php
require_once "config.php";
require_once "layout.php";

$error = "";

if (is_post()) {
    $user = row("SELECT * FROM users WHERE email = ?", [post("email")]);

    if ($user && password_verify($_POST["password"] ?? "", $user["password"])) {
        session_regenerate_id(true);
        $_SESSION["uid"] = $user["id"];
        redirect($user["role"] === "admin" ? "admin.php" : "home.php");
    }

    sleep(1);
    $error = "Неверный email или пароль.";
}

page_header("Вход");
?>
<div class="max-w-md mx-auto card p-6 md:p-8 mt-4">
    <h1 class="text-2xl font-bold mb-6">Вход</h1>

    <?php if ($error): ?><p class="mb-4 p-3 rounded-lg bg-red-100 text-red-800 font-semibold"><?= e($error) ?></p><?php endif; ?>

    <form method="POST" class="space-y-4">
        <?= csrf_field() ?>
        <div>
            <label class="label">Email</label>
            <input class="field" type="email" name="email" value="<?= e(post("email")) ?>" required autocomplete="email">
        </div>
        <div>
            <label class="label">Пароль</label>
            <input class="field" type="password" name="password" required autocomplete="current-password">
        </div>
        <button class="btn btn-primary w-full">Войти</button>
    </form>

    <p class="mt-6 text-center text-slate-600">Нет аккаунта? <a href="register.php" class="text-blue-800 font-semibold">Регистрация</a></p>
</div>
<?php page_footer();
