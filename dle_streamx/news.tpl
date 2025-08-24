<section class="news-page">
    <!-- News Header -->
    <header class="news-header">
        <div class="container">
            <div class="header-content">
                <h1 class="page-title">Новости кино</h1>
                <p class="page-subtitle">
                    Свежие новости из мира кинематографа, рецензии и интересные факты
                </p>
            </div>
            
            <!-- News Categories -->
            <div class="news-categories">
                <button class="category-btn active" data-category="all">
                    <i class="fas fa-newspaper"></i>
                    Все новости
                </button>
                <button class="category-btn" data-category="movie-news">
                    <i class="fas fa-film"></i>
                    Фильмы
                </button>
                <button class="category-btn" data-category="tv-news">
                    <i class="fas fa-tv"></i>
                    Сериалы
                </button>
                <button class="category-btn" data-category="reviews">
                    <i class="fas fa-star"></i>
                    Рецензии
                </button>
                <button class="category-btn" data-category="interviews">
                    <i class="fas fa-microphone"></i>
                    Интервью
                </button>
                <button class="category-btn" data-category="industry">
                    <i class="fas fa-industry"></i>
                    Индустрия
                </button>
            </div>
        </div>
    </header>

    <!-- News Content -->
    <div class="news-content">
        <div class="container">
            <div class="news-layout">
                <!-- Main News -->
                <main class="news-main">
                    <!-- Featured Article -->
                    <article class="featured-article">
                        <div class="article-image">
                            <img src="{featured-image}" alt="{featured-title}">
                            <div class="article-category">Главная новость</div>
                        </div>
                        <div class="article-content">
                            <h2 class="article-title">
                                <a href="{featured-link}">{featured-title}</a>
                            </h2>
                            <div class="article-meta">
                                <span class="author">
                                    <i class="fas fa-user"></i>
                                    {featured-author}
                                </span>
                                <span class="date">
                                    <i class="fas fa-calendar"></i>
                                    {featured-date}
                                </span>
                                <span class="views">
                                    <i class="fas fa-eye"></i>
                                    {featured-views}
                                </span>
                            </div>
                            <p class="article-excerpt">{featured-excerpt}</p>
                            <a href="{featured-link}" class="read-more">
                                Читать далее
                                <i class="fas fa-arrow-right"></i>
                            </a>
                        </div>
                    </article>

                    <!-- News Grid -->
                    <div class="news-grid">
                        <!-- News Item -->
                        <article class="news-card">
                            <div class="card-image">
                                <img src="{image-1}" alt="{title}" loading="lazy">
                                <div class="card-category">{category}</div>
                            </div>
                            <div class="card-content">
                                <h3 class="card-title">
                                    <a href="{full-link}">{title}</a>
                                </h3>
                                <div class="card-meta">
                                    <span class="author">
                                        <i class="fas fa-user"></i>
                                        {autor}
                                    </span>
                                    <span class="date">
                                        <i class="fas fa-calendar"></i>
                                        {date}
                                    </span>
                                </div>
                                <p class="card-excerpt">{short-story}</p>
                                <div class="card-stats">
                                    <span class="views">
                                        <i class="fas fa-eye"></i>
                                        {views}
                                    </span>
                                    <span class="comments">
                                        <i class="fas fa-comments"></i>
                                        {comments-num}
                                    </span>
                                    <span class="rating">
                                        <i class="fas fa-thumbs-up"></i>
                                        {rating}
                                    </span>
                                </div>
                            </div>
                        </article>

                        <!-- More news cards will be loaded here -->
                    </div>

                    <!-- Load More Button -->
                    <div class="load-more-section">
                        <button class="btn btn-secondary load-more-btn" onclick="loadMoreNews()">
                            <i class="fas fa-plus"></i>
                            Загрузить еще
                        </button>
                    </div>

                    <!-- Pagination -->
                    <div class="pagination-wrapper">
                        {navigation}
                    </div>
                </main>

                <!-- News Sidebar -->
                <aside class="news-sidebar">
                    <!-- Popular News -->
                    <div class="sidebar-widget">
                        <h3 class="widget-title">
                            <i class="fas fa-fire"></i>
                            Популярные новости
                        </h3>
                        <div class="popular-news">
                            {custom category="popular-news" template="news-sidebar-item" limit="5" cache="yes"}
                        </div>
                    </div>

                    <!-- Recent Comments -->
                    <div class="sidebar-widget">
                        <h3 class="widget-title">
                            <i class="fas fa-comments"></i>
                            Последние комментарии
                        </h3>
                        <div class="recent-comments">
                            {custom category="recent-comments" template="comment-sidebar-item" limit="3" cache="yes"}
                        </div>
                    </div>

                    <!-- Tags Cloud -->
                    <div class="sidebar-widget">
                        <h3 class="widget-title">
                            <i class="fas fa-tags"></i>
                            Популярные теги
                        </h3>
                        <div class="tags-cloud">
                            <a href="/tag/marvel/" class="tag">Marvel</a>
                            <a href="/tag/dc/" class="tag">DC</a>
                            <a href="/tag/disney/" class="tag">Disney</a>
                            <a href="/tag/netflix/" class="tag">Netflix</a>
                            <a href="/tag/премьеры/" class="tag">Премьеры</a>
                            <a href="/tag/трейлеры/" class="tag">Трейлеры</a>
                            <a href="/tag/актеры/" class="tag">Актеры</a>
                            <a href="/tag/режиссеры/" class="tag">Режиссеры</a>
                        </div>
                    </div>

                    <!-- Newsletter Subscription -->
                    <div class="sidebar-widget newsletter-widget">
                        <h3 class="widget-title">
                            <i class="fas fa-envelope"></i>
                            Подписка на новости
                        </h3>
                        <p>Получайте свежие новости кино прямо на почту</p>
                        <form class="newsletter-form" onsubmit="subscribeNewsletter(event)">
                            <div class="form-group">
                                <input type="email" placeholder="Ваш email" required>
                                <button type="submit" class="btn btn-primary">
                                    <i class="fas fa-paper-plane"></i>
                                </button>
                            </div>
                            <small>Мы не рассылаем спам и не передаем данные третьим лицам</small>
                        </form>
                    </div>

                    <!-- Social Media -->
                    <div class="sidebar-widget">
                        <h3 class="widget-title">
                            <i class="fas fa-share-alt"></i>
                            Мы в соцсетях
                        </h3>
                        <div class="social-links">
                            <a href="https://vk.com/wink_ru" class="social-link vk" target="_blank">
                                <i class="fab fa-vk"></i>
                                <span>VKontakte</span>
                            </a>
                            <a href="https://t.me/wink_news" class="social-link telegram" target="_blank">
                                <i class="fab fa-telegram"></i>
                                <span>Telegram</span>
                            </a>
                            <a href="https://youtube.com/wink_ru" class="social-link youtube" target="_blank">
                                <i class="fab fa-youtube"></i>
                                <span>YouTube</span>
                            </a>
                        </div>
                    </div>
                </aside>
            </div>
        </div>
    </div>
</section>

<style>
.news-page {
    background: #0a0a0a;
    min-height: 100vh;
    color: white;
}

/* News Header */
.news-header {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 3rem 2rem 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.header-content {
    text-align: center;
    margin-bottom: 2rem;
}

.page-title {
    font-size: 3rem;
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
    line-height: 1.6;
    max-width: 600px;
    margin: 0 auto;
}

/* News Categories */
.news-categories {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
}

.category-btn {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: rgba(255, 255, 255, 0.8);
    padding: 0.8rem 1.5rem;
    border-radius: 25px;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
}

.category-btn:hover {
    background: rgba(255, 107, 53, 0.2);
    border-color: rgba(255, 107, 53, 0.4);
    color: white;
}

.category-btn.active {
    background: #ff6b35;
    border-color: #ff6b35;
    color: white;
}

/* News Content */
.news-content {
    padding: 3rem 2rem;
}

.news-layout {
    display: grid;
    grid-template-columns: 1fr 350px;
    gap: 3rem;
}

/* Featured Article */
.featured-article {
    background: #1a1a1a;
    border-radius: 16px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin-bottom: 3rem;
    transition: all 0.3s ease;
}

.featured-article:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.article-image {
    position: relative;
    aspect-ratio: 16/9;
    overflow: hidden;
}

.article-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.3s ease;
}

.featured-article:hover .article-image img {
    transform: scale(1.05);
}

.article-category {
    position: absolute;
    top: 1rem;
    left: 1rem;
    background: #ff6b35;
    color: white;
    padding: 0.5rem 1rem;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: 600;
}

.article-content {
    padding: 2rem;
}

.article-title {
    margin-bottom: 1rem;
}

.article-title a {
    color: white;
    text-decoration: none;
    font-size: 1.8rem;
    font-weight: 700;
    line-height: 1.3;
    transition: color 0.3s ease;
}

.article-title a:hover {
    color: #ff6b35;
}

.article-meta {
    display: flex;
    gap: 1.5rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
}

.article-meta span {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.article-meta i {
    color: #ff6b35;
}

.article-excerpt {
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.6;
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
}

.read-more {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    color: #ff6b35;
    text-decoration: none;
    font-weight: 600;
    transition: all 0.3s ease;
}

.read-more:hover {
    gap: 0.8rem;
}

/* News Grid */
.news-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.news-card {
    background: #1a1a1a;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.news-card:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-3px);
}

.card-image {
    position: relative;
    aspect-ratio: 16/10;
    overflow: hidden;
}

.card-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.3s ease;
}

.news-card:hover .card-image img {
    transform: scale(1.05);
}

.card-category {
    position: absolute;
    top: 0.8rem;
    left: 0.8rem;
    background: rgba(255, 107, 53, 0.9);
    color: white;
    padding: 0.3rem 0.8rem;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 600;
}

.card-content {
    padding: 1.5rem;
}

.card-title {
    margin-bottom: 1rem;
}

.card-title a {
    color: white;
    text-decoration: none;
    font-size: 1.2rem;
    font-weight: 600;
    line-height: 1.4;
    transition: color 0.3s ease;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.card-title a:hover {
    color: #ff6b35;
}

.card-meta {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
}

.card-meta span {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    color: rgba(255, 255, 255, 0.6);
    font-size: 0.8rem;
}

.card-meta i {
    color: #ff6b35;
    font-size: 0.7rem;
}

.card-excerpt {
    color: rgba(255, 255, 255, 0.7);
    line-height: 1.5;
    margin-bottom: 1rem;
    font-size: 0.9rem;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.card-stats {
    display: flex;
    gap: 1rem;
    padding-top: 1rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.card-stats span {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    color: rgba(255, 255, 255, 0.6);
    font-size: 0.8rem;
}

.card-stats i {
    color: #ff6b35;
    font-size: 0.7rem;
}

/* Load More */
.load-more-section {
    text-align: center;
    margin-bottom: 3rem;
}

.load-more-btn {
    padding: 1rem 2rem;
    font-size: 1rem;
    font-weight: 600;
}

/* Pagination */
.pagination-wrapper {
    display: flex;
    justify-content: center;
}

/* News Sidebar */
.news-sidebar {
    display: flex;
    flex-direction: column;
    gap: 2rem;
}

.sidebar-widget {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.widget-title {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.2rem;
    display: flex;
    align-items: center;
    gap: 0.8rem;
}

/* Popular News */
.popular-news {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

/* Tags Cloud */
.tags-cloud {
    display: flex;
    flex-wrap: wrap;
    gap: 0.8rem;
}

.tag {
    background: rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.8);
    padding: 0.5rem 1rem;
    border-radius: 20px;
    text-decoration: none;
    font-size: 0.8rem;
    transition: all 0.3s ease;
}

.tag:hover {
    background: rgba(255, 107, 53, 0.2);
    color: #ff6b35;
}

/* Newsletter Widget */
.newsletter-widget {
    background: linear-gradient(135deg, #ff6b35, #ff8c42);
    color: white;
}

.newsletter-widget .widget-title {
    color: white;
}

.newsletter-widget p {
    margin-bottom: 1rem;
    opacity: 0.9;
}

.newsletter-form .form-group {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 0.8rem;
}

.newsletter-form input {
    flex: 1;
    padding: 0.8rem;
    border: none;
    border-radius: 8px;
    background: rgba(255, 255, 255, 0.2);
    color: white;
    font-size: 0.9rem;
}

.newsletter-form input::placeholder {
    color: rgba(255, 255, 255, 0.7);
}

.newsletter-form input:focus {
    outline: none;
    background: rgba(255, 255, 255, 0.3);
}

.newsletter-form .btn {
    padding: 0.8rem;
    background: rgba(255, 255, 255, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.3);
}

.newsletter-form .btn:hover {
    background: rgba(255, 255, 255, 0.3);
}

.newsletter-form small {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.75rem;
}

/* Social Links */
.social-links {
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
}

.social-link {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    padding: 0.8rem;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    color: white;
    text-decoration: none;
    transition: all 0.3s ease;
}

.social-link:hover {
    transform: translateX(5px);
}

.social-link.vk:hover {
    background: #4a76a8;
    border-color: #4a76a8;
}

.social-link.telegram:hover {
    background: #0088cc;
    border-color: #0088cc;
}

.social-link.youtube:hover {
    background: #ff0000;
    border-color: #ff0000;
}

.social-link i {
    font-size: 1.2rem;
    width: 20px;
}

/* Responsive Design */
@media (max-width: 768px) {
    .news-header {
        padding: 2rem 1rem;
    }
    
    .page-title {
        font-size: 2.5rem;
    }
    
    .page-subtitle {
        font-size: 1.1rem;
    }
    
    .news-categories {
        gap: 0.8rem;
    }
    
    .category-btn {
        padding: 0.6rem 1.2rem;
        font-size: 0.85rem;
    }
    
    .news-content {
        padding: 2rem 1rem;
    }
    
    .news-layout {
        grid-template-columns: 1fr;
        gap: 2rem;
    }
    
    .news-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .article-content {
        padding: 1.5rem;
    }
    
    .article-title a {
        font-size: 1.5rem;
    }
    
    .article-meta {
        gap: 1rem;
    }
}

@media (max-width: 480px) {
    .page-title {
        font-size: 2rem;
    }
    
    .news-categories {
        flex-direction: column;
        align-items: center;
    }
    
    .category-btn {
        width: 100%;
        max-width: 250px;
        justify-content: center;
    }
    
    .featured-article {
        margin-bottom: 2rem;
    }
    
    .article-content {
        padding: 1.2rem;
    }
    
    .article-title a {
        font-size: 1.3rem;
    }
    
    .card-content {
        padding: 1.2rem;
    }
    
    .sidebar-widget {
        padding: 1.2rem;
    }
}
</style>

<script>
// News page functionality
function loadMoreNews() {
    const btn = document.querySelector('.load-more-btn');
    const originalText = btn.innerHTML;
    
    // Show loading state
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Загрузка...';
    btn.disabled = true;
    
    // Simulate loading more news
    setTimeout(() => {
        // Here you would normally load more news via AJAX
        // For now, just restore the button
        btn.innerHTML = originalText;
        btn.disabled = false;
        
        // Hide button if no more news
        // btn.style.display = 'none';
    }, 1500);
}

function subscribeNewsletter(event) {
    event.preventDefault();
    
    const form = event.target;
    const input = form.querySelector('input[type="email"]');
    const btn = form.querySelector('button');
    const originalText = btn.innerHTML;
    
    // Show loading state
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
    btn.disabled = true;
    
    // Simulate subscription
    setTimeout(() => {
        alert('Спасибо за подписку! Проверьте почту для подтверждения.');
        input.value = '';
        btn.innerHTML = originalText;
        btn.disabled = false;
    }, 1000);
}

// Category filtering
document.addEventListener('DOMContentLoaded', function() {
    const categoryBtns = document.querySelectorAll('.category-btn');
    
    categoryBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from all buttons
            categoryBtns.forEach(b => b.classList.remove('active'));
            // Add active class to clicked button
            this.classList.add('active');
            
            const category = this.dataset.category;
            
            // Here you would filter news by category
            // For now, just show console log
            console.log('Filtering by category:', category);
            
            // You could implement AJAX loading here
            // loadNewsByCategory(category);
        });
    });
    
    // Add animation for news cards
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
    
    // Observe news cards
    document.querySelectorAll('.news-card, .featured-article').forEach(card => {
        observer.observe(card);
    });
});

// Search functionality (if search input is added)
function searchNews(query) {
    // Implement news search functionality
    console.log('Searching for:', query);
}

// Share article functionality
function shareArticle(url, title) {
    if (navigator.share) {
        navigator.share({
            title: title,
            url: url
        });
    } else {
        navigator.clipboard.writeText(url);
        alert('Ссылка скопирована в буфер обмена!');
    }
}
</script>