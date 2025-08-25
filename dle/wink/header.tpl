<header class="site-header">
    <div class="container header-inner">
        <a class="logo" href="/">Wink</a>
        <nav class="nav">
            <a href="/">Главная</a>
            <a href="/index.php?do=cat&category=films">Фильмы</a>
            <a href="/index.php?do=cat&category=series">Сериалы</a>
            <a href="/index.php?do=cat&category=tv">TV</a>
            <a href="/index.php?do=cat&category=kids">Детям</a>
        </nav>
        <div class="header-actions">
            <button class="icon-btn" id="search-toggle" aria-label="Поиск">
                🔍
            </button>
            [not-logged]
            <a class="btn btn-primary" href="{registration-link}">Войти</a>
            [/not-logged]
            [logged]
            <a class="avatar" href="{profile-link}">{login}</a>
            [/logged]
        </div>
    </div>
    <div class="search-bar" id="search-bar" hidden>
        <form action="{search-link}" method="post">
            <input type="text" name="story" placeholder="Поиск..." autocomplete="off">
            <button class="btn btn-secondary" type="submit">Найти</button>
        </form>
    </div>
</header>

