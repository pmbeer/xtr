<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{title}</title>
    <meta name="description" content="{description}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="{THEME}/css/variables.css">
    <link rel="stylesheet" href="{THEME}/css/style.css">
</head>
<body class="theme-wink">
    {include file="header.tpl"}

    <main id="main" class="container">
        {content}
    </main>

    {include file="footer.tpl"}

    <script src="{THEME}/js/app.js"></script>
</body>
</html>

