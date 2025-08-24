<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{THEME} - {SITE_DESCR}</title>
    <meta name="description" content="{SITE_DESCR}">
    <meta name="keywords" content="{SITE_KEYWORDS}">
    
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&display=swap" rel="stylesheet">
    
    <!-- Icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <!-- Styles -->
    <link rel="stylesheet" href="{THEME}/style.css">
    <link rel="stylesheet" href="{THEME}/modal.css">
    
    <!-- DLE Head -->
    {THEME_HEAD}
</head>
<body>
    <!-- Header -->
    <header class="header">
        <div class="header-top">
            <div class="logo">:: WINK</div>
            <div class="header-actions">
                <button class="search-btn" title="Поиск">
                    <i class="fas fa-search"></i>
                </button>
                <button class="profile-btn" title="Профиль">
                    <i class="fas fa-user"></i>
                </button>
            </div>
        </div>
        
        <!-- Promotional Banner -->
        <div class="promo-banner">
            <div class="promo-text">
                Бесплатный просмотр топовых фильмов и сериалов для всех — не пропустите!
            </div>
            <a href="#" class="promo-btn">Смотреть</a>
        </div>
        
        <!-- Navigation -->
        <nav class="nav-main">
            <ul class="nav-list">
                <li class="nav-item"><a href="/">Главная</a></li>
                <li class="nav-item"><a href="/films/">Фильмы</a></li>
                <li class="nav-item"><a href="/series/">Сериалы</a></li>
                <li class="nav-item"><a href="/new/">Новинки</a></li>
                <li class="nav-item"><a href="/popular/">Популярное</a></li>
                <li class="nav-item"><a href="/categories/">Категории</a></li>
            </ul>
        </nav>
    </header>

    <!-- Main Content -->
    <main class="main-content">
        <!-- Hero Section -->
        <section class="hero-section">
            <h1 class="hero-title">Добро пожаловать в мир кино</h1>
            <p class="hero-subtitle">
                Откройте для себя тысячи фильмов и сериалов в отличном качестве. 
                Смотрите любимые произведения в любое время и в любом месте.
            </p>
            <a href="/new/" class="btn btn-primary">Смотреть новинки</a>
        </section>

        <!-- Latest Movies -->
        <section class="mb-4">
            <h2 class="mb-3">Последние добавления</h2>
            <div class="content-grid">
                {custom category="1" template="shortstory" limit="6" cache="no"}
            </div>
        </section>

        <!-- Popular Content -->
        <section class="mb-4">
            <h2 class="mb-3">Популярное сейчас</h2>
            <div class="content-grid">
                {custom category="2" template="shortstory" limit="6" cache="no"}
            </div>
        </section>

        <!-- Categories -->
        <section class="mb-4">
            <h2 class="mb-3">Категории</h2>
            <div class="content-grid">
                {custom category="3" template="shortstory" limit="4" cache="no"}
            </div>
        </section>

        <!-- Call to Action -->
        <section class="text-center mb-4">
            <div class="hero-section" style="background: linear-gradient(135deg, #ff6b35, #ff8c42);">
                <h2 class="hero-title" style="color: white; -webkit-text-fill-color: white;">Смотрите в подписке</h2>
                <p class="hero-subtitle" style="color: rgba(255, 255, 255, 0.9);">
                    Получите доступ к эксклюзивному контенту и смотрите без рекламы
                </p>
                <a href="/subscription/" class="btn btn-secondary">Подписаться</a>
            </div>
        </section>
    </main>

    <!-- Footer -->
    <footer class="footer">
        <div class="footer-content">
            <div class="footer-section">
                <h3>О нас</h3>
                <a href="/about/">О проекте</a>
                <a href="/team/">Команда</a>
                <a href="/contacts/">Контакты</a>
            </div>
            <div class="footer-section">
                <h3>Контент</h3>
                <a href="/films/">Фильмы</a>
                <a href="/series/">Сериалы</a>
                <a href="/cartoons/">Мультфильмы</a>
                <a href="/documentary/">Документальные</a>
            </div>
            <div class="footer-section">
                <h3>Поддержка</h3>
                <a href="/help/">Помощь</a>
                <a href="/faq/">FAQ</a>
                <a href="/feedback/">Обратная связь</a>
            </div>
            <div class="footer-section">
                <h3>Правовая информация</h3>
                <a href="/terms/">Пользовательское соглашение</a>
                <a href="/privacy/">Политика конфиденциальности</a>
                <a href="/cookies/">Использование cookies</a>
            </div>
        </div>
        <div class="footer-bottom">
            <p>&copy; {THEME} {SITE_DESCR}. Все права защищены.</p>
        </div>
    </footer>

    <!-- Cookie Consent -->
    <div class="cookie-consent" id="cookieConsent">
        <div class="cookie-text">
            Мы используем cookie и рекомендательные технологии, чтобы улучшать работу сайта. 
            <a href="/cookies/" class="cookie-link">Пользовательское соглашение.</a>
        </div>
        <div class="cookie-actions">
            <button class="btn btn-secondary" onclick="acceptCookies()">OK</button>
        </div>
    </div>

    <!-- JavaScript -->
    <script src="{THEME}/script.js"></script>
    <script>
        // Cookie consent functionality
        function acceptCookies() {
            document.getElementById('cookieConsent').style.display = 'none';
            localStorage.setItem('cookiesAccepted', 'true');
        }

        // Check if cookies were already accepted
        if (localStorage.getItem('cookiesAccepted')) {
            document.getElementById('cookieConsent').style.display = 'none';
        }

        // Initialize template functionality
        document.addEventListener('DOMContentLoaded', function() {
            // Smooth scrolling for navigation links
            document.querySelectorAll('a[href^="#"]').forEach(anchor => {
                anchor.addEventListener('click', function (e) {
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {
                        target.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                });
            });
        });
    </script>

    <!-- DLE Footer -->
    {THEME_FOOTER}
</body>
</html>
