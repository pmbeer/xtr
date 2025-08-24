<article class="fullstory">
    <!-- Hero Section with Movie Poster -->
    <section class="movie-hero">
        <div class="movie-hero-background" style="background-image: url({image-1})">
            <div class="movie-hero-overlay">
                <div class="movie-hero-content">
                    <div class="movie-poster-large">
                        {image-1}
                        {if !image-1}
                            <i class="fas fa-film"></i>
                        {/if}
                    </div>
                    <div class="movie-hero-info">
                        <h1 class="movie-title-large">{title}</h1>
                        <div class="movie-meta-large">
                            {if date}
                                <span class="meta-item-large">
                                    <i class="fas fa-calendar"></i> {date}
                                </span>
                            {/if}
                            {if views}
                                <span class="meta-item-large">
                                    <i class="fas fa-eye"></i> {views} просмотров
                                </span>
                            {/if}
                            {if rating}
                                <span class="meta-item-large">
                                    <i class="fas fa-star"></i> {rating}
                                </span>
                            {/if}
                            {if category}
                                <span class="meta-item-large">
                                    <i class="fas fa-tag"></i> {link-category}
                                </span>
                            {/if}
                        </div>
                        <div class="movie-actions-large">
                            <button class="btn btn-primary btn-large" onclick="playMovie()">
                                <i class="fas fa-play"></i> Смотреть сейчас
                            </button>
                            <button class="btn btn-secondary btn-large" onclick="addToFavorites('{id}')">
                                <i class="fas fa-heart"></i> В избранное
                            </button>
                            <button class="btn btn-secondary btn-large" onclick="shareMovie()">
                                <i class="fas fa-share"></i> Поделиться
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Movie Details -->
    <section class="movie-details">
        <div class="container">
            <div class="details-grid">
                <div class="details-main">
                    <div class="details-section">
                        <h2>Описание</h2>
                        <div class="movie-description-full">
                            {full_story}
                        </div>
                    </div>

                    {if xfields}
                    <div class="details-section">
                        <h2>Информация о фильме</h2>
                        <div class="movie-info-grid">
                            {xfields}
                        </div>
                    </div>
                    {/if}

                    {if related}
                    <div class="details-section">
                        <h2>Похожие фильмы</h2>
                        <div class="related-movies">
                            {related limit="4"}
                        </div>
                    </div>
                    {/if}

                    {if comments}
                    <div class="details-section">
                        <h2>Комментарии ({comments-num})</h2>
                        <div class="comments-section">
                            {comments}
                        </div>
                    </div>
                    {/if}
                </div>

                <aside class="details-sidebar">
                    <div class="sidebar-widget">
                        <h3>Рейтинг</h3>
                        <div class="rating-widget">
                            {if rating}
                            <div class="rating-score">
                                <span class="rating-number">{rating}</span>
                                <div class="rating-stars">
                                    {rating display="stars"}
                                </div>
                            </div>
                            {/if}
                            <button class="btn btn-primary btn-full" onclick="rateMovie()">
                                Оценить фильм
                            </button>
                        </div>
                    </div>

                    <div class="sidebar-widget">
                        <h3>Статистика</h3>
                        <div class="stats-widget">
                            {if views}
                            <div class="stat-item">
                                <i class="fas fa-eye"></i>
                                <span>Просмотров: {views}</span>
                            </div>
                            {/if}
                            {if comments-num}
                            <div class="stat-item">
                                <i class="fas fa-comments"></i>
                                <span>Комментариев: {comments-num}</span>
                            </div>
                            {/if}
                            {if date}
                            <div class="stat-item">
                                <i class="fas fa-calendar"></i>
                                <span>Дата: {date}</span>
                            </div>
                            {/if}
                        </div>
                    </div>

                    <div class="sidebar-widget">
                        <h3>Поделиться</h3>
                        <div class="share-widget">
                            <button class="btn btn-secondary btn-full" onclick="shareToVK()">
                                <i class="fab fa-vk"></i> VK
                            </button>
                            <button class="btn btn-secondary btn-full" onclick="shareToTelegram()">
                                <i class="fab fa-telegram"></i> Telegram
                            </button>
                            <button class="btn btn-secondary btn-full" onclick="copyLink()">
                                <i class="fas fa-link"></i> Копировать ссылку
                            </button>
                        </div>
                    </div>
                </aside>
            </div>
        </div>
    </section>
</article>

<style>
.fullstory {
    background: #0a0a0a;
}

.movie-hero {
    position: relative;
    height: 70vh;
    min-height: 500px;
    overflow: hidden;
}

.movie-hero-background {
    width: 100%;
    height: 100%;
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    position: relative;
}

.movie-hero-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(
        135deg,
        rgba(0, 0, 0, 0.8) 0%,
        rgba(0, 0, 0, 0.6) 50%,
        rgba(0, 0, 0, 0.9) 100%
    );
    display: flex;
    align-items: center;
    padding: 2rem;
}

.movie-hero-content {
    display: flex;
    gap: 3rem;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
    width: 100%;
}

.movie-poster-large {
    width: 300px;
    height: 450px;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
    flex-shrink: 0;
}

.movie-poster-large img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.movie-poster-large .fas {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 6rem;
    color: rgba(255, 255, 255, 0.3);
    background: linear-gradient(45deg, #2a2a2a, #1a1a1a);
}

.movie-hero-info {
    flex: 1;
}

.movie-title-large {
    font-size: 3.5rem;
    font-weight: 900;
    margin-bottom: 1.5rem;
    color: white;
    line-height: 1.2;
}

.movie-meta-large {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
}

.meta-item-large {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.1rem;
    color: rgba(255, 255, 255, 0.9);
}

.movie-actions-large {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

.btn-large {
    padding: 16px 32px;
    font-size: 1.1rem;
}

.btn-full {
    width: 100%;
}

.movie-details {
    padding: 4rem 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.details-grid {
    display: grid;
    grid-template-columns: 1fr 350px;
    gap: 3rem;
}

.details-section {
    margin-bottom: 3rem;
}

.details-section h2 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.8rem;
}

.movie-description-full {
    color: rgba(255, 255, 255, 0.9);
    line-height: 1.8;
    font-size: 1.1rem;
}

.movie-info-grid {
    display: grid;
    gap: 1rem;
}

.sidebar-widget {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.sidebar-widget h3 {
    color: #ff6b35;
    margin-bottom: 1rem;
    font-size: 1.3rem;
}

.rating-widget {
    text-align: center;
}

.rating-score {
    margin-bottom: 1rem;
}

.rating-number {
    font-size: 3rem;
    font-weight: 900;
    color: #ff6b35;
    display: block;
}

.rating-stars {
    color: #ff6b35;
    font-size: 1.5rem;
}

.stats-widget {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.stat-item {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    color: rgba(255, 255, 255, 0.8);
}

.stat-item i {
    color: #ff6b35;
    width: 20px;
}

.share-widget {
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
}

.related-movies {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
}

.comments-section {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

@media (max-width: 1024px) {
    .details-grid {
        grid-template-columns: 1fr;
    }
    
    .movie-hero-content {
        flex-direction: column;
        text-align: center;
        gap: 2rem;
    }
    
    .movie-poster-large {
        width: 250px;
        height: 375px;
    }
    
    .movie-title-large {
        font-size: 2.5rem;
    }
}

@media (max-width: 768px) {
    .movie-hero {
        height: auto;
        min-height: auto;
    }
    
    .movie-hero-overlay {
        position: relative;
        padding: 2rem 1rem;
    }
    
    .movie-hero-content {
        padding: 0;
    }
    
    .movie-poster-large {
        width: 200px;
        height: 300px;
    }
    
    .movie-title-large {
        font-size: 2rem;
    }
    
    .movie-meta-large {
        justify-content: center;
    }
    
    .movie-actions-large {
        justify-content: center;
    }
    
    .movie-details {
        padding: 2rem 1rem;
    }
}
</style>

<script>
function playMovie() {
    // Implement video player functionality
    alert('Функция воспроизведения будет добавлена позже');
}

function addToFavorites(id) {
    const btn = event.target.closest('button');
    btn.innerHTML = '<i class="fas fa-heart" style="color: #ff6b35;"></i> В избранном';
    btn.style.background = '#ff6b35';
    btn.style.color = 'white';
    
    // You can add AJAX call here to save to favorites
    console.log('Added to favorites:', id);
}

function shareMovie() {
    if (navigator.share) {
        navigator.share({
            title: '{title}',
            text: 'Посмотрите этот фильм на Wink.ru',
            url: window.location.href
        });
    } else {
        copyLink();
    }
}

function shareToVK() {
    const url = encodeURIComponent(window.location.href);
    const title = encodeURIComponent('{title}');
    window.open(`https://vk.com/share.php?url=${url}&title=${title}`, '_blank');
}

function shareToTelegram() {
    const url = encodeURIComponent(window.location.href);
    const text = encodeURIComponent('Посмотрите этот фильм: {title}');
    window.open(`https://t.me/share/url?url=${url}&text=${text}`, '_blank');
}

function copyLink() {
    navigator.clipboard.writeText(window.location.href).then(() => {
        alert('Ссылка скопирована в буфер обмена!');
    });
}

function rateMovie() {
    // Implement rating functionality
    alert('Функция оценки будет добавлена позже');
}
</script>
