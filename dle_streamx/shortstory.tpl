<article class="movie-card">
    <div class="movie-poster">
        {image-1}
        {if !image-1}
            <i class="fas fa-film"></i>
        {/if}
    </div>
    <div class="movie-info">
        <h3 class="movie-title">
            <a href="{link-category}">{title}</a>
        </h3>
        <div class="movie-meta">
            {if date}
                <span class="meta-item">
                    <i class="fas fa-calendar"></i> {date}
                </span>
            {/if}
            {if views}
                <span class="meta-item">
                    <i class="fas fa-eye"></i> {views}
                </span>
            {/if}
            {if rating}
                <span class="meta-item">
                    <i class="fas fa-star"></i> {rating}
                </span>
            {/if}
        </div>
        {if short_story}
            <p class="movie-description">{short_story limit="120"}</p>
        {/if}
        <div class="movie-actions">
            <a href="{link-category}" class="btn btn-primary">
                <i class="fas fa-play"></i> Смотреть
            </a>
            {if favorites}
                <button class="btn btn-secondary" onclick="addToFavorites('{id}')" title="Добавить в избранное">
                    <i class="fas fa-heart"></i>
                </button>
            {/if}
        </div>
    </div>
</article>

<style>
.movie-card .movie-poster {
    position: relative;
    overflow: hidden;
}

.movie-card .movie-poster img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.3s ease;
}

.movie-card:hover .movie-poster img {
    transform: scale(1.05);
}

.movie-card .movie-poster .fas {
    font-size: 4rem;
    opacity: 0.3;
}

.movie-meta {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    margin-bottom: 1rem;
}

.meta-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.85rem;
    color: rgba(255, 255, 255, 0.7);
}

.movie-actions {
    display: flex;
    gap: 0.5rem;
    align-items: center;
}

.movie-actions .btn {
    flex: 1;
    padding: 8px 16px;
    font-size: 0.9rem;
}

.movie-actions .btn-secondary {
    flex: 0 0 auto;
    padding: 8px;
    min-width: 40px;
}

.movie-actions .btn i {
    margin-right: 0.5rem;
}

.movie-actions .btn-secondary i {
    margin-right: 0;
}
</style>

<script>
function addToFavorites(id) {
    // Implement favorites functionality
    const btn = event.target.closest('button');
    btn.innerHTML = '<i class="fas fa-heart" style="color: #ff6b35;"></i>';
    btn.style.color = '#ff6b35';
    btn.style.border-color = '#ff6b35';
    
    // You can add AJAX call here to save to favorites
    console.log('Added to favorites:', id);
}
</script>
