<section class="help-center">
    <!-- Help Header -->
    <header class="help-header">
        <div class="container">
            <div class="header-content">
                <h1 class="page-title">Центр помощи</h1>
                <p class="page-subtitle">
                    Найдите ответы на ваши вопросы или свяжитесь с нашей службой поддержки
                </p>
                
                <!-- Help Search -->
                <div class="help-search">
                    <div class="search-wrapper">
                        <i class="fas fa-search search-icon"></i>
                        <input type="text" id="helpSearchInput" placeholder="Что вас интересует?" onkeyup="searchHelp(this.value)">
                        <button class="search-btn" onclick="performHelpSearch()">
                            <i class="fas fa-search"></i>
                        </button>
                    </div>
                    <div class="search-suggestions" id="searchSuggestions"></div>
                </div>
            </div>
        </div>
    </header>

    <!-- Help Content -->
    <div class="help-content">
        <div class="container">
            <!-- Quick Help Categories -->
            <section class="quick-categories">
                <h2>Популярные разделы</h2>
                <div class="categories-grid">
                    <a href="#getting-started" class="category-card" onclick="showCategory('getting-started')">
                        <div class="category-icon">
                            <i class="fas fa-play-circle"></i>
                        </div>
                        <h3>Начало работы</h3>
                        <p>Узнайте, как начать пользоваться платформой</p>
                        <span class="article-count">12 статей</span>
                    </a>

                    <a href="#account-settings" class="category-card" onclick="showCategory('account-settings')">
                        <div class="category-icon">
                            <i class="fas fa-user-cog"></i>
                        </div>
                        <h3>Настройки аккаунта</h3>
                        <p>Управление профилем и настройками безопасности</p>
                        <span class="article-count">8 статей</span>
                    </a>

                    <a href="#streaming" class="category-card" onclick="showCategory('streaming')">
                        <div class="category-icon">
                            <i class="fas fa-play"></i>
                        </div>
                        <h3>Просмотр контента</h3>
                        <p>Все о воспроизведении фильмов и сериалов</p>
                        <span class="article-count">15 статей</span>
                    </a>

                    <a href="#subscription" class="category-card" onclick="showCategory('subscription')">
                        <div class="category-icon">
                            <i class="fas fa-credit-card"></i>
                        </div>
                        <h3>Подписка и платежи</h3>
                        <p>Информация о тарифах и способах оплаты</p>
                        <span class="article-count">10 статей</span>
                    </a>

                    <a href="#troubleshooting" class="category-card" onclick="showCategory('troubleshooting')">
                        <div class="category-icon">
                            <i class="fas fa-tools"></i>
                        </div>
                        <h3>Решение проблем</h3>
                        <p>Исправление ошибок и технических проблем</p>
                        <span class="article-count">20 статей</span>
                    </a>

                    <a href="#mobile-apps" class="category-card" onclick="showCategory('mobile-apps')">
                        <div class="category-icon">
                            <i class="fas fa-mobile-alt"></i>
                        </div>
                        <h3>Мобильные приложения</h3>
                        <p>Скачивание и использование мобильных приложений</p>
                        <span class="article-count">6 статей</span>
                    </a>
                </div>
            </section>

            <!-- Help Articles -->
            <section class="help-articles" id="helpArticles">
                <div class="articles-header">
                    <h2 id="categoryTitle">Популярные статьи</h2>
                    <div class="view-options">
                        <button class="view-btn active" data-view="grid">
                            <i class="fas fa-th"></i>
                        </button>
                        <button class="view-btn" data-view="list">
                            <i class="fas fa-list"></i>
                        </button>
                    </div>
                </div>

                <div class="articles-grid" id="articlesGrid">
                    <!-- Getting Started Articles -->
                    <article class="help-article" data-category="getting-started">
                        <div class="article-icon">
                            <i class="fas fa-rocket"></i>
                        </div>
                        <div class="article-content">
                            <h3>Быстрый старт</h3>
                            <p>Пошаговое руководство для новых пользователей</p>
                            <div class="article-meta">
                                <span class="reading-time">5 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    92%
                                </span>
                            </div>
                        </div>
                    </article>

                    <article class="help-article" data-category="getting-started">
                        <div class="article-icon">
                            <i class="fas fa-user-plus"></i>
                        </div>
                        <div class="article-content">
                            <h3>Создание аккаунта</h3>
                            <p>Как зарегистрироваться и настроить профиль</p>
                            <div class="article-meta">
                                <span class="reading-time">3 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    98%
                                </span>
                            </div>
                        </div>
                    </article>

                    <!-- Account Settings Articles -->
                    <article class="help-article" data-category="account-settings">
                        <div class="article-icon">
                            <i class="fas fa-key"></i>
                        </div>
                        <div class="article-content">
                            <h3>Смена пароля</h3>
                            <p>Как изменить пароль и настроить двухфакторную аутентификацию</p>
                            <div class="article-meta">
                                <span class="reading-time">4 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    95%
                                </span>
                            </div>
                        </div>
                    </article>

                    <article class="help-article" data-category="account-settings">
                        <div class="article-icon">
                            <i class="fas fa-shield-alt"></i>
                        </div>
                        <div class="article-content">
                            <h3>Настройки приватности</h3>
                            <p>Управление видимостью профиля и персональными данными</p>
                            <div class="article-meta">
                                <span class="reading-time">6 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    88%
                                </span>
                            </div>
                        </div>
                    </article>

                    <!-- Streaming Articles -->
                    <article class="help-article" data-category="streaming">
                        <div class="article-icon">
                            <i class="fas fa-play-circle"></i>
                        </div>
                        <div class="article-content">
                            <h3>Качество видео</h3>
                            <p>Настройка качества воспроизведения и экономия трафика</p>
                            <div class="article-meta">
                                <span class="reading-time">4 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    91%
                                </span>
                            </div>
                        </div>
                    </article>

                    <article class="help-article" data-category="streaming">
                        <div class="article-icon">
                            <i class="fas fa-closed-captioning"></i>
                        </div>
                        <div class="article-content">
                            <h3>Субтитры и озвучка</h3>
                            <p>Как включить субтитры и выбрать языковую дорожку</p>
                            <div class="article-meta">
                                <span class="reading-time">3 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    96%
                                </span>
                            </div>
                        </div>
                    </article>

                    <!-- Troubleshooting Articles -->
                    <article class="help-article" data-category="troubleshooting">
                        <div class="article-icon">
                            <i class="fas fa-exclamation-triangle"></i>
                        </div>
                        <div class="article-content">
                            <h3>Проблемы с воспроизведением</h3>
                            <p>Решение проблем с загрузкой и воспроизведением видео</p>
                            <div class="article-meta">
                                <span class="reading-time">7 мин чтения</span>
                                <span class="helpful-votes">
                                    <i class="fas fa-thumbs-up"></i>
                                    89%
                                </span>
                            </div>
                        </div>
                    </article>
                </div>

                <!-- Load More Articles -->
                <div class="load-more-section">
                    <button class="btn btn-secondary" onclick="loadMoreArticles()">
                        <i class="fas fa-plus"></i>
                        Показать еще статьи
                    </button>
                </div>
            </section>

            <!-- Popular Guides -->
            <section class="popular-guides">
                <h2>Пошаговые руководства</h2>
                <div class="guides-grid">
                    <div class="guide-card">
                        <div class="guide-header">
                            <div class="guide-icon">
                                <i class="fas fa-graduation-cap"></i>
                            </div>
                            <div class="guide-info">
                                <h3>Полное руководство для новичков</h3>
                                <p>Изучите все возможности платформы за 15 минут</p>
                            </div>
                        </div>
                        <div class="guide-steps">
                            <div class="step">
                                <span class="step-number">1</span>
                                <span class="step-text">Регистрация и настройка профиля</span>
                            </div>
                            <div class="step">
                                <span class="step-number">2</span>
                                <span class="step-text">Поиск и добавление контента</span>
                            </div>
                            <div class="step">
                                <span class="step-number">3</span>
                                <span class="step-text">Настройка качества и субтитров</span>
                            </div>
                        </div>
                        <button class="btn btn-primary guide-btn">
                            <i class="fas fa-play"></i>
                            Начать руководство
                        </button>
                    </div>

                    <div class="guide-card">
                        <div class="guide-header">
                            <div class="guide-icon">
                                <i class="fas fa-mobile-alt"></i>
                            </div>
                            <div class="guide-info">
                                <h3>Настройка мобильного приложения</h3>
                                <p>Оптимальные настройки для просмотра на телефоне</p>
                            </div>
                        </div>
                        <div class="guide-steps">
                            <div class="step">
                                <span class="step-number">1</span>
                                <span class="step-text">Скачивание и установка</span>
                            </div>
                            <div class="step">
                                <span class="step-number">2</span>
                                <span class="step-text">Синхронизация аккаунта</span>
                            </div>
                            <div class="step">
                                <span class="step-number">3</span>
                                <span class="step-text">Настройка офлайн-просмотра</span>
                            </div>
                        </div>
                        <button class="btn btn-primary guide-btn">
                            <i class="fas fa-play"></i>
                            Начать руководство
                        </button>
                    </div>
                </div>
            </section>

            <!-- Contact Support -->
            <section class="contact-support">
                <div class="support-content">
                    <div class="support-info">
                        <h2>Нужна дополнительная помощь?</h2>
                        <p>Если вы не нашли ответ на свой вопрос, наша команда поддержки готова помочь вам 24/7</p>
                        
                        <div class="support-stats">
                            <div class="stat">
                                <div class="stat-number">< 15 мин</div>
                                <div class="stat-label">Среднее время ответа</div>
                            </div>
                            <div class="stat">
                                <div class="stat-number">24/7</div>
                                <div class="stat-label">Круглосуточная поддержка</div>
                            </div>
                            <div class="stat">
                                <div class="stat-number">98%</div>
                                <div class="stat-label">Решенных проблем</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="support-actions">
                        <a href="/contacts/" class="btn btn-primary">
                            <i class="fas fa-comments"></i>
                            Связаться с поддержкой
                        </a>
                        <a href="mailto:support@wink.ru" class="btn btn-secondary">
                            <i class="fas fa-envelope"></i>
                            Написать на email
                        </a>
                        <a href="/faq/" class="btn btn-secondary">
                            <i class="fas fa-question-circle"></i>
                            Посмотреть FAQ
                        </a>
                    </div>
                </div>
            </section>
        </div>
    </div>
</section>

<style>
.help-center {
    background: #0a0a0a;
    min-height: 100vh;
    color: white;
}

/* Help Header */
.help-header {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 4rem 2rem 3rem;
    text-align: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.header-content {
    max-width: 800px;
    margin: 0 auto;
}

.page-title {
    font-size: 3.5rem;
    font-weight: 900;
    color: white;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.page-subtitle {
    font-size: 1.2rem;
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    line-height: 1.6;
}

/* Help Search */
.help-search {
    max-width: 600px;
    margin: 0 auto;
    position: relative;
}

.search-wrapper {
    position: relative;
    display: flex;
    align-items: center;
    background: rgba(255, 255, 255, 0.1);
    border: 2px solid rgba(255, 255, 255, 0.2);
    border-radius: 50px;
    padding: 0.5rem;
    transition: all 0.3s ease;
}

.search-wrapper:focus-within {
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.search-icon {
    color: rgba(255, 255, 255, 0.5);
    margin-left: 1rem;
    font-size: 1.1rem;
}

#helpSearchInput {
    flex: 1;
    background: none;
    border: none;
    padding: 1rem;
    color: white;
    font-size: 1rem;
    outline: none;
}

#helpSearchInput::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.search-btn {
    background: #ff6b35;
    border: none;
    color: white;
    padding: 1rem 1.5rem;
    border-radius: 50px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 1rem;
}

.search-btn:hover {
    background: #ff8c42;
    transform: scale(1.05);
}

.search-suggestions {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: #1a1a1a;
    border-radius: 12px;
    margin-top: 0.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    display: none;
    z-index: 1000;
}

/* Help Content */
.help-content {
    padding: 4rem 2rem;
}

.help-content section {
    margin-bottom: 5rem;
}

.help-content h2 {
    color: #ff6b35;
    font-size: 2rem;
    margin-bottom: 2rem;
    text-align: center;
}

/* Quick Categories */
.categories-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
}

.category-card {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
    text-decoration: none;
    color: white;
    display: block;
}

.category-card:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.category-icon {
    width: 60px;
    height: 60px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.5rem;
}

.category-icon i {
    font-size: 1.8rem;
    color: #ff6b35;
}

.category-card h3 {
    color: white;
    margin-bottom: 1rem;
    font-size: 1.3rem;
}

.category-card p {
    color: rgba(255, 255, 255, 0.7);
    line-height: 1.5;
    margin-bottom: 1rem;
}

.article-count {
    color: #ff6b35;
    font-size: 0.9rem;
    font-weight: 600;
}

/* Help Articles */
.articles-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
}

.articles-header h2 {
    margin-bottom: 0;
    text-align: left;
}

.view-options {
    display: flex;
    gap: 0.5rem;
}

.view-btn {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    padding: 0.8rem;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
}

.view-btn:hover,
.view-btn.active {
    background: #ff6b35;
    border-color: #ff6b35;
}

.articles-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
}

.help-article {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
    cursor: pointer;
    display: flex;
    gap: 1rem;
}

.help-article:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-3px);
}

.article-icon {
    width: 50px;
    height: 50px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
}

.article-icon i {
    color: #ff6b35;
    font-size: 1.2rem;
}

.article-content {
    flex: 1;
}

.article-content h3 {
    color: white;
    margin-bottom: 0.8rem;
    font-size: 1.1rem;
}

.article-content p {
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 1rem;
    line-height: 1.5;
    font-size: 0.9rem;
}

.article-meta {
    display: flex;
    gap: 1rem;
    font-size: 0.8rem;
}

.reading-time {
    color: rgba(255, 255, 255, 0.6);
}

.helpful-votes {
    color: #ff6b35;
    display: flex;
    align-items: center;
    gap: 0.3rem;
}

/* Load More */
.load-more-section {
    text-align: center;
    margin-top: 3rem;
}

/* Popular Guides */
.guides-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 2rem;
}

.guide-card {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.guide-card:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.guide-header {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
}

.guide-icon {
    width: 60px;
    height: 60px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
}

.guide-icon i {
    font-size: 1.5rem;
    color: #ff6b35;
}

.guide-info h3 {
    color: white;
    margin-bottom: 0.5rem;
    font-size: 1.2rem;
}

.guide-info p {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.guide-steps {
    margin-bottom: 2rem;
}

.step {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1rem;
    padding: 0.8rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
}

.step-number {
    width: 24px;
    height: 24px;
    background: #ff6b35;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: 600;
    flex-shrink: 0;
}

.step-text {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.9rem;
}

.guide-btn {
    width: 100%;
    padding: 1rem;
    font-size: 1rem;
    font-weight: 600;
}

/* Contact Support */
.contact-support {
    background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
    border-radius: 20px;
    padding: 3rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.support-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 3rem;
    align-items: center;
}

.support-info h2 {
    color: white;
    margin-bottom: 1rem;
    text-align: left;
    font-size: 2rem;
}

.support-info p {
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    line-height: 1.6;
}

.support-stats {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
}

.stat {
    text-align: center;
}

.stat-number {
    color: #ff6b35;
    font-size: 1.8rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
}

.stat-label {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.support-actions {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.support-actions .btn {
    padding: 1rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
    justify-content: center;
    display: flex;
    align-items: center;
    gap: 0.8rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    .help-header {
        padding: 3rem 1rem 2rem;
    }
    
    .page-title {
        font-size: 2.5rem;
    }
    
    .help-content {
        padding: 2rem 1rem;
    }
    
    .categories-grid,
    .guides-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .articles-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .articles-header {
        flex-direction: column;
        gap: 1rem;
        align-items: flex-start;
    }
    
    .support-content {
        grid-template-columns: 1fr;
        gap: 2rem;
    }
    
    .support-stats {
        justify-content: space-around;
    }
    
    .help-article {
        flex-direction: column;
        text-align: center;
    }
    
    .article-icon {
        align-self: center;
    }
}

@media (max-width: 480px) {
    .page-title {
        font-size: 2rem;
    }
    
    .search-wrapper {
        flex-direction: column;
        gap: 1rem;
        padding: 1rem;
        border-radius: 16px;
    }
    
    .search-btn {
        width: 100%;
        border-radius: 12px;
    }
    
    .category-card,
    .guide-card {
        padding: 1.5rem;
    }
    
    .guide-header {
        flex-direction: column;
        text-align: center;
    }
    
    .support-stats {
        flex-direction: column;
        gap: 1rem;
    }
    
    .contact-support {
        padding: 2rem;
    }
}

/* Hidden articles for filtering */
.help-article.hidden {
    display: none;
}
</style>

<script>
// Help center functionality
let currentCategory = 'all';
let currentView = 'grid';

function searchHelp(query) {
    const articles = document.querySelectorAll('.help-article');
    const suggestions = document.getElementById('searchSuggestions');
    
    if (query.length > 2) {
        // Show search suggestions
        showSearchSuggestions(query);
        
        // Filter articles
        articles.forEach(article => {
            const title = article.querySelector('h3').textContent.toLowerCase();
            const content = article.querySelector('p').textContent.toLowerCase();
            
            if (title.includes(query.toLowerCase()) || content.includes(query.toLowerCase())) {
                article.classList.remove('hidden');
            } else {
                article.classList.add('hidden');
            }
        });
        
        updateCategoryTitle(`Результаты поиска: "${query}"`);
    } else {
        // Hide suggestions
        suggestions.style.display = 'none';
        
        // Show all articles
        showCategory(currentCategory);
    }
}

function showSearchSuggestions(query) {
    const suggestions = document.getElementById('searchSuggestions');
    const mockSuggestions = [
        'Смена пароля',
        'Проблемы с воспроизведением',
        'Настройка качества видео',
        'Отмена подписки',
        'Скачивание приложения'
    ];
    
    const filtered = mockSuggestions.filter(s => 
        s.toLowerCase().includes(query.toLowerCase())
    );
    
    if (filtered.length > 0) {
        suggestions.innerHTML = filtered.map(suggestion => 
            `<div class="suggestion-item" onclick="selectSuggestion('${suggestion}')">${suggestion}</div>`
        ).join('');
        suggestions.style.display = 'block';
    } else {
        suggestions.style.display = 'none';
    }
}

function selectSuggestion(suggestion) {
    document.getElementById('helpSearchInput').value = suggestion;
    document.getElementById('searchSuggestions').style.display = 'none';
    searchHelp(suggestion);
}

function performHelpSearch() {
    const query = document.getElementById('helpSearchInput').value;
    searchHelp(query);
}

function showCategory(category) {
    currentCategory = category;
    const articles = document.querySelectorAll('.help-article');
    
    articles.forEach(article => {
        if (category === 'all' || article.dataset.category === category) {
            article.classList.remove('hidden');
        } else {
            article.classList.add('hidden');
        }
    });
    
    // Update category title
    const categoryNames = {
        'all': 'Все статьи',
        'getting-started': 'Начало работы',
        'account-settings': 'Настройки аккаунта',
        'streaming': 'Просмотр контента',
        'subscription': 'Подписка и платежи',
        'troubleshooting': 'Решение проблем',
        'mobile-apps': 'Мобильные приложения'
    };
    
    updateCategoryTitle(categoryNames[category] || 'Статьи');
}

function updateCategoryTitle(title) {
    document.getElementById('categoryTitle').textContent = title;
}

function loadMoreArticles() {
    const btn = event.target;
    const originalText = btn.innerHTML;
    
    // Show loading state
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Загрузка...';
    btn.disabled = true;
    
    // Simulate loading more articles
    setTimeout(() => {
        // Here you would load more articles via AJAX
        // For now, just restore the button
        btn.innerHTML = originalText;
        btn.disabled = false;
        
        // Or hide the button if no more articles
        // btn.style.display = 'none';
    }, 1500);
}

// Initialize help center
document.addEventListener('DOMContentLoaded', function() {
    // View toggle functionality
    document.querySelectorAll('.view-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            const view = this.dataset.view;
            const articlesGrid = document.getElementById('articlesGrid');
            
            if (view === 'list') {
                articlesGrid.style.gridTemplateColumns = '1fr';
            } else {
                articlesGrid.style.gridTemplateColumns = 'repeat(auto-fit, minmax(350px, 1fr))';
            }
        });
    });
    
    // Add animation for help elements
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '0';
                entry.target.style.transform = 'translateY(30px)';
                
                setTimeout(() => {
                    entry.target.style.transition = 'all 0.6s ease';
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }, 100);
            }
        });
    });
    
    // Observe help elements
    document.querySelectorAll('.category-card, .help-article, .guide-card').forEach(el => {
        observer.observe(el);
    });
    
    // Hide suggestions when clicking outside
    document.addEventListener('click', function(e) {
        const searchWrapper = e.target.closest('.help-search');
        if (!searchWrapper) {
            document.getElementById('searchSuggestions').style.display = 'none';
        }
    });
    
    // Handle search input enter key
    document.getElementById('helpSearchInput').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            performHelpSearch();
        }
    });
});

// Article rating functionality
function rateArticle(articleId, isHelpful) {
    // Here you would send rating to server
    console.log(`Rating article ${articleId}: ${isHelpful ? 'helpful' : 'not helpful'}`);
    
    // Show feedback
    alert(isHelpful ? 'Спасибо за отзыв!' : 'Мы учтем ваш отзыв и постараемся улучшить статью.');
}

// Guide functionality
function startGuide(guideId) {
    // Here you would start an interactive guide
    console.log(`Starting guide: ${guideId}`);
    alert('Интерактивное руководство будет запущено...');
}
</script>