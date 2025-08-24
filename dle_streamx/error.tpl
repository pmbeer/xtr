<section class="error-page">
    <div class="error-container">
        <!-- Error Icon -->
        <div class="error-icon">
            {if error-code="404"}
                <i class="fas fa-search"></i>
            {elseif error-code="500"}
                <i class="fas fa-exclamation-triangle"></i>
            {elseif error-code="403"}
                <i class="fas fa-ban"></i>
            {else}
                <i class="fas fa-exclamation-circle"></i>
            {/if}
        </div>

        <!-- Error Content -->
        <div class="error-content">
            <h1 class="error-title">
                {if error-code="404"}
                    Страница не найдена
                {elseif error-code="500"}
                    Ошибка сервера
                {elseif error-code="403"}
                    Доступ запрещен
                {else}
                    Произошла ошибка
                {/if}
            </h1>
            
            <div class="error-code">
                {error-code}
            </div>
            
            <p class="error-description">
                {if error-code="404"}
                    К сожалению, запрашиваемая страница не существует или была перемещена.
                {elseif error-code="500"}
                    Произошла внутренняя ошибка сервера. Попробуйте обновить страницу позже.
                {elseif error-code="403"}
                    У вас нет прав для доступа к этой странице.
                {else}
                    Произошла непредвиденная ошибка. Попробуйте обновить страницу.
                {/if}
            </p>

            <!-- Error Details -->
            {if error-details}
            <div class="error-details">
                <details>
                    <summary>Детали ошибки</summary>
                    <div class="error-details-content">
                        <pre>{error-details}</pre>
                    </div>
                </details>
            </div>
            {/if}

            <!-- Action Buttons -->
            <div class="error-actions">
                <button class="btn btn-primary" onclick="goBack()">
                    <i class="fas fa-arrow-left"></i>
                    Назад
                </button>
                <a href="/" class="btn btn-secondary">
                    <i class="fas fa-home"></i>
                    На главную
                </a>
                <button class="btn btn-secondary" onclick="refreshPage()">
                    <i class="fas fa-sync-alt"></i>
                    Обновить
                </button>
            </div>

            <!-- Search Section for 404 -->
            {if error-code="404"}
            <div class="error-search">
                <h3>Попробуйте найти то, что искали:</h3>
                <form class="search-form" onsubmit="searchFromError(event)">
                    <div class="search-input-wrapper">
                        <i class="fas fa-search search-icon"></i>
                        <input type="text" id="errorSearchInput" class="search-input" placeholder="Поиск фильмов, сериалов..." required>
                        <button type="submit" class="search-submit-btn">
                            <i class="fas fa-search"></i>
                            Найти
                        </button>
                    </div>
                </form>
            </div>
            {/if}

            <!-- Popular Links -->
            <div class="popular-links">
                <h3>Популярные разделы:</h3>
                <div class="links-grid">
                    <a href="/films/" class="link-card">
                        <i class="fas fa-film"></i>
                        <span>Фильмы</span>
                    </a>
                    <a href="/series/" class="link-card">
                        <i class="fas fa-tv"></i>
                        <span>Сериалы</span>
                    </a>
                    <a href="/new/" class="link-card">
                        <i class="fas fa-star"></i>
                        <span>Новинки</span>
                    </a>
                    <a href="/popular/" class="link-card">
                        <i class="fas fa-fire"></i>
                        <span>Популярное</span>
                    </a>
                    <a href="/categories/" class="link-card">
                        <i class="fas fa-th-large"></i>
                        <span>Категории</span>
                    </a>
                    <a href="/search/" class="link-card">
                        <i class="fas fa-search"></i>
                        <span>Поиск</span>
                    </a>
                </div>
            </div>

            <!-- Help Section -->
            <div class="help-section">
                <h3>Нужна помощь?</h3>
                <div class="help-options">
                    <a href="/help/" class="help-link">
                        <i class="fas fa-question-circle"></i>
                        Центр помощи
                    </a>
                    <a href="/contacts/" class="help-link">
                        <i class="fas fa-envelope"></i>
                        Связаться с поддержкой
                    </a>
                    <a href="/faq/" class="help-link">
                        <i class="fas fa-info-circle"></i>
                        Часто задаваемые вопросы
                    </a>
                </div>
            </div>
        </div>
    </div>
</section>

<style>
.error-page {
    background: linear-gradient(135deg, #0a0a0a 0%, #1a1a1a 100%);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
}

.error-container {
    background: #1a1a1a;
    border-radius: 20px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
    max-width: 800px;
    width: 100%;
    padding: 3rem;
    text-align: center;
}

/* Error Icon */
.error-icon {
    margin-bottom: 2rem;
}

.error-icon i {
    font-size: 6rem;
    color: #ff6b35;
    animation: errorPulse 2s ease-in-out infinite;
}

@keyframes errorPulse {
    0%, 100% { 
        transform: scale(1);
        opacity: 1;
    }
    50% { 
        transform: scale(1.1);
        opacity: 0.8;
    }
}

/* Error Content */
.error-content {
    max-width: 600px;
    margin: 0 auto;
}

.error-title {
    color: white;
    font-size: 2.5rem;
    font-weight: 700;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.error-code {
    background: rgba(255, 107, 53, 0.2);
    color: #ff6b35;
    font-size: 3rem;
    font-weight: 900;
    padding: 1rem 2rem;
    border-radius: 12px;
    border: 2px solid rgba(255, 107, 53, 0.3);
    margin-bottom: 2rem;
    display: inline-block;
    font-family: 'Courier New', monospace;
}

.error-description {
    color: rgba(255, 255, 255, 0.8);
    font-size: 1.1rem;
    line-height: 1.6;
    margin-bottom: 2rem;
    max-width: 500px;
    margin-left: auto;
    margin-right: auto;
}

/* Error Details */
.error-details {
    margin-bottom: 2rem;
    text-align: left;
}

.error-details summary {
    color: #ff6b35;
    cursor: pointer;
    font-weight: 600;
    margin-bottom: 1rem;
    padding: 0.5rem;
    border-radius: 6px;
    transition: all 0.3s ease;
}

.error-details summary:hover {
    background: rgba(255, 107, 53, 0.1);
}

.error-details-content {
    background: rgba(0, 0, 0, 0.3);
    border-radius: 8px;
    padding: 1rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.error-details-content pre {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.85rem;
    line-height: 1.4;
    margin: 0;
    white-space: pre-wrap;
    word-break: break-word;
}

/* Action Buttons */
.error-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    margin-bottom: 3rem;
    flex-wrap: wrap;
}

.error-actions .btn {
    min-width: 120px;
    padding: 1rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
}

/* Search Section */
.error-search {
    margin-bottom: 3rem;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.error-search h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.3rem;
}

.search-form {
    max-width: 500px;
    margin: 0 auto;
}

.search-input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
}

.search-icon {
    position: absolute;
    left: 1rem;
    color: rgba(255, 255, 255, 0.5);
    font-size: 1.1rem;
    z-index: 2;
}

.search-input {
    flex: 1;
    padding: 1rem 1rem 1rem 3rem;
    font-size: 1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 2px solid rgba(255, 255, 255, 0.2);
    border-radius: 12px;
    color: white;
    transition: all 0.3s ease;
}

.search-input:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.search-input::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.search-submit-btn {
    margin-left: 1rem;
    padding: 1rem 1.5rem;
    background: #ff6b35;
    border: none;
    color: white;
    border-radius: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    white-space: nowrap;
}

.search-submit-btn:hover {
    background: #ff8c42;
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(255, 107, 53, 0.3);
}

/* Popular Links */
.popular-links {
    margin-bottom: 3rem;
}

.popular-links h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.3rem;
}

.links-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 1rem;
    max-width: 600px;
    margin: 0 auto;
}

.link-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 1.5rem 1rem;
    text-decoration: none;
    color: white;
    transition: all 0.3s ease;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.8rem;
}

.link-card:hover {
    background: rgba(255, 107, 53, 0.1);
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.link-card i {
    font-size: 2rem;
    color: #ff6b35;
}

.link-card span {
    font-weight: 600;
    font-size: 0.9rem;
}

/* Help Section */
.help-section {
    padding-top: 2rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.help-section h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.3rem;
}

.help-options {
    display: flex;
    gap: 1.5rem;
    justify-content: center;
    flex-wrap: wrap;
}

.help-link {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    color: rgba(255, 255, 255, 0.8);
    text-decoration: none;
    padding: 0.8rem 1.2rem;
    border-radius: 8px;
    transition: all 0.3s ease;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.help-link:hover {
    color: #ff6b35;
    background: rgba(255, 107, 53, 0.1);
    border-color: rgba(255, 107, 53, 0.3);
}

.help-link i {
    color: #ff6b35;
    font-size: 1.1rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    .error-container {
        padding: 2rem;
        margin: 1rem;
    }
    
    .error-title {
        font-size: 2rem;
    }
    
    .error-code {
        font-size: 2.5rem;
        padding: 0.8rem 1.5rem;
    }
    
    .error-actions {
        flex-direction: column;
        align-items: center;
    }
    
    .error-actions .btn {
        width: 100%;
        max-width: 250px;
    }
    
    .links-grid {
        grid-template-columns: repeat(2, 1fr);
        gap: 0.8rem;
    }
    
    .help-options {
        flex-direction: column;
        align-items: center;
    }
    
    .help-link {
        width: 100%;
        max-width: 250px;
        justify-content: center;
    }
}

@media (max-width: 480px) {
    .error-page {
        padding: 1rem;
    }
    
    .error-container {
        padding: 1.5rem;
    }
    
    .error-title {
        font-size: 1.8rem;
    }
    
    .error-code {
        font-size: 2rem;
        padding: 0.6rem 1.2rem;
    }
    
    .error-description {
        font-size: 1rem;
    }
    
    .links-grid {
        grid-template-columns: 1fr;
    }
    
    .search-input-wrapper {
        flex-direction: column;
        gap: 1rem;
    }
    
    .search-submit-btn {
        margin-left: 0;
        width: 100%;
        justify-content: center;
    }
}
</style>

<script>
// Error page functionality
function goBack() {
    if (document.referrer) {
        window.history.back();
    } else {
        window.location.href = '/';
    }
}

function refreshPage() {
    window.location.reload();
}

function searchFromError(event) {
    event.preventDefault();
    const searchInput = document.getElementById('errorSearchInput');
    const query = searchInput.value.trim();
    
    if (query) {
        window.location.href = `/search/?story=${encodeURIComponent(query)}`;
    }
}

// Initialize error page
document.addEventListener('DOMContentLoaded', function() {
    // Add animation for error page elements
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '0';
                entry.target.style.transform = 'translateY(20px)';
                
                setTimeout(() => {
                    entry.target.style.transition = 'all 0.5s ease';
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }, 100);
            }
        });
    });
    
    // Observe error page elements
    document.querySelectorAll('.error-content > *').forEach(el => {
        observer.observe(el);
    });
    
    // Auto-focus search input for 404 pages
    const searchInput = document.getElementById('errorSearchInput');
    if (searchInput) {
        setTimeout(() => {
            searchInput.focus();
        }, 1000);
    }
    
    // Add error tracking (optional)
    if (typeof gtag !== 'undefined') {
        gtag('event', 'error_page', {
            'error_code': '{error-code}',
            'error_url': window.location.href
        });
    }
});

// Keyboard shortcuts
document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + R to refresh
    if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
        e.preventDefault();
        refreshPage();
    }
    
    // Escape to go back
    if (e.key === 'Escape') {
        goBack();
    }
    
    // Enter in search input
    if (e.key === 'Enter' && document.activeElement.id === 'errorSearchInput') {
        const searchForm = document.querySelector('.search-form');
        if (searchForm) {
            searchForm.dispatchEvent(new Event('submit'));
        }
    }
});
</script>