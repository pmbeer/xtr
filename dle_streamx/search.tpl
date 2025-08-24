<section class="search-page">
    <!-- Search Header -->
    <header class="search-header">
        <div class="search-hero">
            <h1 class="search-title">
                <i class="fas fa-search"></i>
                Поиск фильмов и сериалов
            </h1>
            <p class="search-subtitle">
                Найдите любимые фильмы, сериалы и актеров по названию, жанру или году
            </p>
        </div>
    </header>

    <!-- Search Form -->
    <div class="search-form-section">
        <div class="container">
            <form method="post" action="{search-url}" class="search-form" id="searchForm">
                <div class="search-input-group">
                    <div class="search-input-wrapper">
                        <i class="fas fa-search search-icon"></i>
                        <input type="text" name="story" value="{search-query}" placeholder="Введите название фильма, сериала или актера..." class="search-input-main" autocomplete="off" required>
                        <button type="submit" class="search-submit-btn">
                            <i class="fas fa-search"></i>
                            Найти
                        </button>
                    </div>
                </div>

                <!-- Advanced Search Filters -->
                <div class="search-filters">
                    <div class="filters-row">
                        <div class="filter-group">
                            <label class="filter-label">Категория:</label>
                            <select name="category" class="filter-select">
                                <option value="">Все категории</option>
                                <option value="films" {if search-category="films"}selected{/if}>Фильмы</option>
                                <option value="series" {if search-category="series"}selected{/if}>Сериалы</option>
                                <option value="cartoons" {if search-category="cartoons"}selected{/if}>Мультфильмы</option>
                                <option value="documentary" {if search-category="documentary"}selected{/if}>Документальные</option>
                            </select>
                        </div>

                        <div class="filter-group">
                            <label class="filter-label">Год:</label>
                            <select name="year" class="filter-select">
                                <option value="">Любой год</option>
                                {custom category="years" template="year-options" limit="20" cache="no"}
                            </select>
                        </div>

                        <div class="filter-group">
                            <label class="filter-label">Жанр:</label>
                            <select name="genre" class="filter-select">
                                <option value="">Любой жанр</option>
                                <option value="action" {if search-genre="action"}selected{/if}>Боевик</option>
                                <option value="comedy" {if search-genre="comedy"}selected{/if}>Комедия</option>
                                <option value="drama" {if search-genre="drama"}selected{/if}>Драма</option>
                                <option value="horror" {if search-genre="horror"}selected{/if}>Ужасы</option>
                                <option value="sci-fi" {if search-genre="sci-fi"}selected{/if}>Фантастика</option>
                                <option value="thriller" {if search-genre="thriller"}selected{/if}>Триллер</option>
                                <option value="romance" {if search-genre="romance"}selected{/if}>Мелодрама</option>
                                <option value="adventure" {if search-genre="adventure"}selected{/if}>Приключения</option>
                            </select>
                        </div>

                        <div class="filter-group">
                            <label class="filter-label">Рейтинг:</label>
                            <select name="rating" class="filter-select">
                                <option value="">Любой рейтинг</option>
                                <option value="9" {if search-rating="9"}selected{/if}>9+ (Отлично)</option>
                                <option value="8" {if search-rating="8"}selected{/if}>8+ (Очень хорошо)</option>
                                <option value="7" {if search-rating="7"}selected{/if}>7+ (Хорошо)</option>
                                <option value="6" {if search-rating="6"}selected{/if}>6+ (Нормально)</option>
                            </select>
                        </div>
                    </div>

                    <div class="filters-row">
                        <div class="filter-group">
                            <label class="filter-label">Сортировка:</label>
                            <select name="sort" class="filter-select">
                                <option value="relevance" {if search-sort="relevance"}selected{/if}>По релевантности</option>
                                <option value="date" {if search-sort="date"}selected{/if}>По дате</option>
                                <option value="rating" {if search-sort="rating"}selected{/if}>По рейтингу</option>
                                <option value="views" {if search-sort="views"}selected{/if}>По просмотрам</option>
                                <option value="title" {if search-sort="title"}selected{/if}>По названию</option>
                            </select>
                        </div>

                        <div class="filter-group">
                            <label class="filter-label">Результатов на странице:</label>
                            <select name="limit" class="filter-select">
                                <option value="20" {if search-limit="20"}selected{/if}>20</option>
                                <option value="40" {if search-limit="40"}selected{/if}>40</option>
                                <option value="60" {if search-limit="60"}selected{/if}>60</option>
                            </select>
                        </div>

                        <div class="filter-group">
                            <label class="filter-label">Только с постером:</label>
                            <div class="checkbox-wrapper">
                                <input type="checkbox" name="with_poster" id="withPoster" {if search-with-poster}checked{/if}>
                                <label for="withPoster" class="checkbox-label">Да</label>
                            </div>
                        </div>
                    </div>

                    <div class="filters-actions">
                        <button type="submit" class="btn btn-primary">
                            <i class="fas fa-search"></i>
                            Найти
                        </button>
                        <button type="button" class="btn btn-secondary" onclick="resetFilters()">
                            <i class="fas fa-undo"></i>
                            Сбросить фильтры
                        </button>
                    </div>
                </div>
            </form>
        </div>
    </div>

    <!-- Search Results -->
    <div class="search-results-section">
        <div class="container">
            {if search-query}
            <div class="search-results-header">
                <div class="results-info">
                    <h2>Результаты поиска</h2>
                    <p class="results-count">
                        Найдено <strong>{search-count}</strong> результатов по запросу "<strong>{search-query}</strong>"
                    </p>
                </div>
                
                <div class="results-controls">
                    <div class="view-toggle">
                        <button class="view-btn active" data-view="grid" title="Сетка">
                            <i class="fas fa-th"></i>
                        </button>
                        <button class="view-btn" data-view="list" title="Список">
                            <i class="fas fa-list"></i>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Results Grid -->
            <div class="search-results" id="searchResults">
                <div class="content-grid" id="resultsGrid">
                    {search-results}
                </div>
            </div>

            <!-- No Results Message -->
            {if !search-results}
            <div class="no-results">
                <div class="no-results-icon">
                    <i class="fas fa-search"></i>
                </div>
                <h3>Ничего не найдено</h3>
                <p>По вашему запросу "<strong>{search-query}</strong>" ничего не найдено.</p>
                <div class="no-results-suggestions">
                    <h4>Попробуйте:</h4>
                    <ul>
                        <li>Проверить правильность написания</li>
                        <li>Использовать более общие слова</li>
                        <li>Убрать лишние фильтры</li>
                        <li>Поискать в других категориях</li>
                    </ul>
                </div>
            </div>
            {/if}

            <!-- Search Pagination -->
            {if search-navigation}
            <div class="search-pagination">
                {search-navigation}
            </div>
            {/if}
            {/if}

            <!-- Popular Searches -->
            <div class="popular-searches">
                <h3>Популярные запросы</h3>
                <div class="search-tags">
                    <a href="?story=боевики" class="search-tag">Боевики</a>
                    <a href="?story=комедии" class="search-tag">Комедии</a>
                    <a href="?story=драмы" class="search-tag">Драмы</a>
                    <a href="?story=ужасы" class="search-tag">Ужасы</a>
                    <a href="?story=фантастика" class="search-tag">Фантастика</a>
                    <a href="?story=триллеры" class="search-tag">Триллеры</a>
                    <a href="?story=мелодрамы" class="search-tag">Мелодрамы</a>
                    <a href="?story=приключения" class="search-tag">Приключения</a>
                </div>
            </div>
        </div>
    </div>
</section>

<style>
.search-page {
    background: #0a0a0a;
    min-height: 100vh;
}

.search-header {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 4rem 2rem 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.search-hero {
    max-width: 1200px;
    margin: 0 auto;
    text-align: center;
}

.search-title {
    font-size: 3.5rem;
    font-weight: 900;
    color: white;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
}

.search-subtitle {
    font-size: 1.2rem;
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    max-width: 800px;
    margin-left: auto;
    margin-right: auto;
    line-height: 1.6;
}

.search-form-section {
    padding: 3rem 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.search-form {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}

.search-input-group {
    margin-bottom: 2rem;
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
    font-size: 1.2rem;
    z-index: 2;
}

.search-input-main {
    flex: 1;
    padding: 1.2rem 1rem 1.2rem 3rem;
    font-size: 1.1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 2px solid rgba(255, 255, 255, 0.2);
    border-radius: 12px;
    color: white;
    transition: all 0.3s ease;
}

.search-input-main:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.search-input-main::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.search-submit-btn {
    margin-left: 1rem;
    padding: 1.2rem 2rem;
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

/* Search Filters */
.search-filters {
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    padding-top: 2rem;
}

.filters-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1.5rem;
    margin-bottom: 1.5rem;
}

.filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.filter-label {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.9rem;
    font-weight: 500;
}

.filter-select {
    padding: 0.8rem 1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    color: white;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all 0.3s ease;
}

.filter-select:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.filter-select option {
    background: #1a1a1a;
    color: white;
}

.checkbox-wrapper {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.checkbox-wrapper input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: #ff6b35;
}

.checkbox-label {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.9rem;
    cursor: pointer;
}

.filters-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
}

/* Search Results */
.search-results-section {
    padding: 3rem 2rem;
}

.search-results-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 1rem;
}

.results-info h2 {
    color: white;
    font-size: 1.8rem;
    margin-bottom: 0.5rem;
}

.results-count {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
}

.results-count strong {
    color: #ff6b35;
}

.results-controls {
    display: flex;
    gap: 1rem;
    align-items: center;
}

.view-toggle {
    display: flex;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 4px;
}

.view-btn {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    padding: 8px 12px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.3s ease;
}

.view-btn.active {
    background: #ff6b35;
    color: white;
}

.view-btn:hover:not(.active) {
    background: rgba(255, 255, 255, 0.1);
    color: white;
}

.content-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.content-grid.list-view {
    grid-template-columns: 1fr;
}

.content-grid.list-view .movie-card {
    display: flex;
    max-width: none;
}

.content-grid.list-view .movie-poster {
    width: 200px;
    height: 150px;
    flex-shrink: 0;
}

.content-grid.list-view .movie-info {
    flex: 1;
}

/* No Results */
.no-results {
    text-align: center;
    padding: 4rem 2rem;
    background: #1a1a1a;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin: 2rem 0;
}

.no-results-icon {
    font-size: 4rem;
    color: rgba(255, 255, 255, 0.3);
    margin-bottom: 1rem;
}

.no-results h3 {
    color: white;
    margin-bottom: 1rem;
    font-size: 1.5rem;
}

.no-results p {
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 2rem;
}

.no-results-suggestions h4 {
    color: #ff6b35;
    margin-bottom: 1rem;
    font-size: 1.1rem;
}

.no-results-suggestions ul {
    color: rgba(255, 255, 255, 0.6);
    text-align: left;
    max-width: 400px;
    margin: 0 auto;
    line-height: 1.6;
}

.no-results-suggestions li {
    margin-bottom: 0.5rem;
}

/* Search Pagination */
.search-pagination {
    display: flex;
    justify-content: center;
    margin: 3rem 0;
}

.search-pagination a,
.search-pagination span {
    display: inline-block;
    padding: 12px 16px;
    background: #1a1a1a;
    color: white;
    text-decoration: none;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
    margin: 0 0.25rem;
}

.search-pagination a:hover {
    background: #ff6b35;
    border-color: #ff6b35;
}

.search-pagination .current {
    background: #ff6b35;
    border-color: #ff6b35;
}

/* Popular Searches */
.popular-searches {
    margin-top: 4rem;
    padding-top: 3rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.popular-searches h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.5rem;
    text-align: center;
}

.search-tags {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    justify-content: center;
}

.search-tag {
    background: rgba(255, 107, 53, 0.2);
    color: #ff6b35;
    padding: 0.8rem 1.5rem;
    border-radius: 25px;
    text-decoration: none;
    font-weight: 500;
    transition: all 0.3s ease;
    border: 1px solid rgba(255, 107, 53, 0.3);
}

.search-tag:hover {
    background: #ff6b35;
    color: white;
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(255, 107, 53, 0.3);
}

/* Responsive Design */
@media (max-width: 768px) {
    .search-header {
        padding: 2rem 1rem 1rem;
    }
    
    .search-title {
        font-size: 2.5rem;
        flex-direction: column;
        gap: 0.5rem;
    }
    
    .search-form-section {
        padding: 2rem 1rem;
    }
    
    .search-form {
        padding: 1.5rem;
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
    
    .filters-row {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
    
    .filters-actions {
        flex-direction: column;
        align-items: stretch;
    }
    
    .search-results-section {
        padding: 2rem 1rem;
    }
    
    .search-results-header {
        flex-direction: column;
        align-items: stretch;
        text-align: center;
    }
    
    .content-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .content-grid.list-view .movie-card {
        flex-direction: column;
    }
    
    .content-grid.list-view .movie-poster {
        width: 100%;
        height: 200px;
    }
    
    .search-tags {
        justify-content: center;
    }
}

@media (max-width: 480px) {
    .search-title {
        font-size: 2rem;
    }
    
    .search-subtitle {
        font-size: 1rem;
    }
    
    .search-input-main {
        font-size: 1rem;
        padding: 1rem 1rem 1rem 2.5rem;
    }
    
    .search-submit-btn {
        padding: 1rem 1.5rem;
        font-size: 0.9rem;
    }
    
    .filter-select {
        padding: 0.7rem 0.8rem;
        font-size: 0.85rem;
    }
    
    .search-tag {
        padding: 0.6rem 1.2rem;
        font-size: 0.9rem;
    }
}
</style>

<script>
// Search functionality
function resetFilters() {
    // Reset all form inputs
    const form = document.getElementById('searchForm');
    form.reset();
    
    // Reset custom selects
    form.querySelectorAll('.filter-select').forEach(select => {
        select.selectedIndex = 0;
    });
    
    // Reset checkboxes
    form.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
        checkbox.checked = false;
    });
}

// View toggle functionality
document.querySelectorAll('.view-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        // Remove active class from all buttons
        document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
        // Add active class to clicked button
        this.classList.add('active');
        
        const view = this.dataset.view;
        const container = document.getElementById('resultsGrid');
        
        if (view === 'list') {
            container.classList.add('list-view');
        } else {
            container.classList.remove('list-view');
        }
    });
});

// Auto-submit form when filters change
document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('searchForm');
    const autoSubmitElements = form.querySelectorAll('select, input[type="checkbox"]');
    
    autoSubmitElements.forEach(element => {
        element.addEventListener('change', function() {
            // Add small delay to prevent too many requests
            clearTimeout(window.searchTimeout);
            window.searchTimeout = setTimeout(() => {
                form.submit();
            }, 500);
        });
    });
    
    // Add loading state to search button
    form.addEventListener('submit', function() {
        const submitBtn = form.querySelector('.search-submit-btn');
        const originalText = submitBtn.innerHTML;
        
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Поиск...';
        submitBtn.disabled = true;
        
        // Re-enable button after a delay (in case of errors)
        setTimeout(() => {
            submitBtn.innerHTML = originalText;
            submitBtn.disabled = false;
        }, 10000);
    });
});

// Search suggestions (you can implement AJAX here)
function showSearchSuggestions(query) {
    // This would typically make an AJAX call to your search API
    console.log('Searching for:', query);
}

// Initialize search page
document.addEventListener('DOMContentLoaded', function() {
    // Add animation for search results
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
    
    document.querySelectorAll('.movie-card').forEach(card => {
        observer.observe(card);
    });
    
    // Highlight search query in results
    const searchQuery = new URLSearchParams(window.location.search).get('story');
    if (searchQuery) {
        highlightSearchQuery(searchQuery);
    }
});

function highlightSearchQuery(query) {
    const textElements = document.querySelectorAll('.movie-title, .movie-description');
    const regex = new RegExp(`(${query})`, 'gi');
    
    textElements.forEach(element => {
        element.innerHTML = element.innerHTML.replace(regex, '<mark class="search-highlight">$1</mark>');
    });
}

// Add search highlight styles
const style = document.createElement('style');
style.textContent = `
    .search-highlight {
        background: #ff6b35;
        color: white;
        padding: 0.1rem 0.3rem;
        border-radius: 4px;
        font-weight: 600;
    }
`;
document.head.appendChild(style);
</script>