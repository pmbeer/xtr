<section class="category-page">
    <!-- Category Header -->
    <header class="category-header">
        <div class="category-hero">
            <div class="category-hero-content">
                <h1 class="category-title">{category-title}</h1>
                {if category-description}
                <p class="category-description">{category-description}</p>
                {/if}
                <div class="category-meta">
                    <span class="meta-item">
                        <i class="fas fa-film"></i> {category-count} фильмов
                    </span>
                    {if category-image}
                    <span class="meta-item">
                        <i class="fas fa-image"></i> Есть постеры
                    </span>
                    {/if}
                </div>
            </div>
        </div>
    </header>

    <!-- Category Content -->
    <div class="category-content">
        <div class="container">
            <!-- Filters and Sorting -->
            <div class="category-controls">
                <div class="controls-left">
                    <div class="view-toggle">
                        <button class="view-btn active" data-view="grid" title="Сетка">
                            <i class="fas fa-th"></i>
                        </button>
                        <button class="view-btn" data-view="list" title="Список">
                            <i class="fas fa-list"></i>
                        </button>
                    </div>
                    <div class="sort-controls">
                        <select class="sort-select" onchange="sortMovies(this.value)">
                            <option value="date">По дате</option>
                            <option value="rating">По рейтингу</option>
                            <option value="views">По просмотрам</option>
                            <option value="title">По названию</option>
                        </select>
                    </div>
                </div>
                <div class="controls-right">
                    <div class="search-filter">
                        <input type="text" class="search-input" placeholder="Поиск в категории..." onkeyup="filterMovies(this.value)">
                        <i class="fas fa-search search-icon"></i>
                    </div>
                </div>
            </div>

            <!-- Movies Grid -->
            <div class="movies-container" id="moviesContainer">
                <div class="content-grid" id="moviesGrid">
                    {custom category="{category-id}" template="shortstory" limit="20" cache="no"}
                </div>
            </div>

            <!-- Pagination -->
            {if navigation}
            <div class="pagination-wrapper">
                <nav class="pagination">
                    {navigation}
                </nav>
            </div>
            {/if}

            <!-- Category Description -->
            {if category-description}
            <div class="category-info">
                <div class="info-card">
                    <h3>О категории "{category-title}"</h3>
                    <div class="info-content">
                        {category-description}
                    </div>
                </div>
            </div>
            {/if}

            <!-- Related Categories -->
            {if related-categories}
            <div class="related-categories">
                <h3>Похожие категории</h3>
                <div class="categories-grid">
                    {related-categories}
                </div>
            </div>
            {/if}
        </div>
    </div>
</section>

<style>
.category-page {
    background: #0a0a0a;
    min-height: 100vh;
}

.category-header {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 4rem 2rem 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.category-hero {
    max-width: 1200px;
    margin: 0 auto;
    text-align: center;
}

.category-title {
    font-size: 3.5rem;
    font-weight: 900;
    color: white;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.category-description {
    font-size: 1.2rem;
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    max-width: 800px;
    margin-left: auto;
    margin-right: auto;
    line-height: 1.6;
}

.category-meta {
    display: flex;
    justify-content: center;
    gap: 2rem;
    flex-wrap: wrap;
}

.meta-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: rgba(255, 255, 255, 0.7);
    font-size: 1rem;
}

.meta-item i {
    color: #ff6b35;
}

.category-content {
    padding: 3rem 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.category-controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    padding: 1.5rem;
    background: #1a1a1a;
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    flex-wrap: wrap;
    gap: 1rem;
}

.controls-left, .controls-right {
    display: flex;
    align-items: center;
    gap: 1rem;
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

.sort-select {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    padding: 8px 12px;
    border-radius: 6px;
    cursor: pointer;
}

.sort-select option {
    background: #1a1a1a;
    color: white;
}

.search-filter {
    position: relative;
}

.search-input {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    padding: 8px 16px 8px 40px;
    border-radius: 6px;
    width: 250px;
    font-size: 0.9rem;
}

.search-input::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.search-icon {
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    color: rgba(255, 255, 255, 0.5);
}

.movies-container {
    margin-bottom: 3rem;
}

.content-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 2rem;
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

.pagination-wrapper {
    margin: 3rem 0;
    display: flex;
    justify-content: center;
}

.pagination {
    display: flex;
    gap: 0.5rem;
    align-items: center;
}

.pagination a, .pagination span {
    display: inline-block;
    padding: 12px 16px;
    background: #1a1a1a;
    color: white;
    text-decoration: none;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.pagination a:hover {
    background: #ff6b35;
    border-color: #ff6b35;
}

.pagination .current {
    background: #ff6b35;
    border-color: #ff6b35;
}

.category-info {
    margin: 3rem 0;
}

.info-card {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.info-card h3 {
    color: #ff6b35;
    margin-bottom: 1rem;
    font-size: 1.5rem;
}

.info-content {
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.6;
}

.related-categories {
    margin: 3rem 0;
}

.related-categories h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.5rem;
}

.categories-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
}

@media (max-width: 768px) {
    .category-header {
        padding: 2rem 1rem 1rem;
    }
    
    .category-title {
        font-size: 2.5rem;
    }
    
    .category-content {
        padding: 2rem 1rem;
    }
    
    .category-controls {
        flex-direction: column;
        align-items: stretch;
    }
    
    .controls-left, .controls-right {
        justify-content: center;
    }
    
    .search-input {
        width: 100%;
        max-width: 300px;
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
}

@media (max-width: 480px) {
    .category-title {
        font-size: 2rem;
    }
    
    .category-meta {
        flex-direction: column;
        gap: 1rem;
    }
    
    .view-toggle {
        width: 100%;
        justify-content: center;
    }
}
</style>

<script>
// View toggle functionality
document.querySelectorAll('.view-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        // Remove active class from all buttons
        document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
        // Add active class to clicked button
        this.classList.add('active');
        
        const view = this.dataset.view;
        const container = document.getElementById('moviesGrid');
        
        if (view === 'list') {
            container.classList.add('list-view');
        } else {
            container.classList.remove('list-view');
        }
    });
});

// Sort functionality
function sortMovies(sortBy) {
    const container = document.getElementById('moviesGrid');
    const movies = Array.from(container.children);
    
    movies.sort((a, b) => {
        let aValue, bValue;
        
        switch(sortBy) {
            case 'date':
                aValue = new Date(a.querySelector('.meta-item:first-child')?.textContent || '');
                bValue = new Date(b.querySelector('.meta-item:first-child')?.textContent || '');
                return bValue - aValue;
            case 'rating':
                aValue = parseFloat(a.querySelector('.meta-item:last-child')?.textContent || '0');
                bValue = parseFloat(b.querySelector('.meta-item:last-child')?.textContent || '0');
                return bValue - aValue;
            case 'views':
                aValue = parseInt(a.querySelector('.meta-item:nth-child(2)')?.textContent || '0');
                bValue = parseInt(b.querySelector('.meta-item:nth-child(2)')?.textContent || '0');
                return bValue - aValue;
            case 'title':
                aValue = a.querySelector('.movie-title a')?.textContent || '';
                bValue = b.querySelector('.movie-title a')?.textContent || '';
                return aValue.localeCompare(bValue, 'ru');
            default:
                return 0;
        }
    });
    
    // Clear and re-append sorted movies
    container.innerHTML = '';
    movies.forEach(movie => container.appendChild(movie));
}

// Filter functionality
function filterMovies(query) {
    const movies = document.querySelectorAll('.movie-card');
    const searchTerm = query.toLowerCase();
    
    movies.forEach(movie => {
        const title = movie.querySelector('.movie-title a')?.textContent.toLowerCase() || '';
        const description = movie.querySelector('.movie-description')?.textContent.toLowerCase() || '';
        
        if (title.includes(searchTerm) || description.includes(searchTerm)) {
            movie.style.display = 'block';
        } else {
            movie.style.display = 'none';
        }
    });
}

// Initialize with grid view
document.addEventListener('DOMContentLoaded', function() {
    // Set default view
    document.querySelector('[data-view="grid"]').classList.add('active');
    
    // Add loading animation
    const movies = document.querySelectorAll('.movie-card');
    movies.forEach((movie, index) => {
        movie.style.opacity = '0';
        movie.style.transform = 'translateY(20px)';
        
        setTimeout(() => {
            movie.style.transition = 'all 0.5s ease';
            movie.style.opacity = '1';
            movie.style.transform = 'translateY(0)';
        }, index * 100);
    });
});
</script>
