<section class="user-profile-page">
    <!-- User Profile Header -->
    <header class="user-profile-header">
        <div class="profile-hero">
            <div class="profile-cover">
                <div class="profile-avatar-large">
                    {if avatar}
                        <img src="{avatar}" alt="{login}" class="user-avatar-img">
                    {else}
                        <i class="fas fa-user-circle"></i>
                    {/if}
                    <button class="avatar-edit-btn" onclick="editAvatar()" title="Изменить аватар">
                        <i class="fas fa-camera"></i>
                    </button>
                </div>
                <div class="profile-info-main">
                    <h1 class="profile-name">{login}</h1>
                    <div class="profile-meta">
                        <span class="meta-item">
                            <i class="fas fa-calendar"></i>
                            На сайте с {registration-date}
                        </span>
                        <span class="meta-item">
                            <i class="fas fa-star"></i>
                            Рейтинг: {user-rating}
                        </span>
                        <span class="meta-item">
                            <i class="fas fa-eye"></i>
                            Просмотров: {user-views}
                        </span>
                    </div>
                    <div class="profile-actions">
                        <button class="btn btn-primary" onclick="editProfile()">
                            <i class="fas fa-edit"></i>
                            Редактировать профиль
                        </button>
                        <button class="btn btn-secondary" onclick="changePassword()">
                            <i class="fas fa-key"></i>
                            Сменить пароль
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <!-- User Profile Content -->
    <div class="user-profile-content">
        <div class="container">
            <div class="profile-grid">
                <!-- Profile Sidebar -->
                <aside class="profile-sidebar">
                    <div class="sidebar-widget">
                        <h3>Личная информация</h3>
                        <div class="profile-details">
                            {if email}
                            <div class="detail-item">
                                <i class="fas fa-envelope"></i>
                                <span>{email}</span>
                            </div>
                            {/if}
                            {if icq}
                            <div class="detail-item">
                                <i class="fab fa-icq"></i>
                                <span>{icq}</span>
                            </div>
                            {/if}
                            {if skype}
                            <div class="detail-item">
                                <i class="fab fa-skype"></i>
                                <span>{skype}</span>
                            </div>
                            {/if}
                            {if website}
                            <div class="detail-item">
                                <i class="fas fa-globe"></i>
                                <a href="{website}" target="_blank" rel="noopener">{website}</a>
                            </div>
                            {/if}
                            {if location}
                            <div class="detail-item">
                                <i class="fas fa-map-marker-alt"></i>
                                <span>{location}</span>
                            </div>
                            {/if}
                            {if birthday}
                            <div class="detail-item">
                                <i class="fas fa-birthday-cake"></i>
                                <span>{birthday}</span>
                            </div>
                            {/if}
                        </div>
                    </div>

                    <div class="sidebar-widget">
                        <h3>Статистика</h3>
                        <div class="stats-grid">
                            <div class="stat-item">
                                <div class="stat-number">{user-posts}</div>
                                <div class="stat-label">Публикаций</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number">{user-comments}</div>
                                <div class="stat-label">Комментариев</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number">{user-favorites}</div>
                                <div class="stat-label">В избранном</div>
                            </div>
                        </div>
                    </div>

                    <div class="sidebar-widget">
                        <h3>Награды</h3>
                        <div class="awards-list">
                            {if user-awards}
                                {user-awards}
                            {else}
                                <p class="no-awards">Пока нет наград</p>
                            {/if}
                        </div>
                    </div>

                    <div class="sidebar-widget">
                        <h3>Быстрые действия</h3>
                        <div class="quick-actions">
                            <button class="btn btn-secondary btn-full" onclick="addToFavorites()">
                                <i class="fas fa-heart"></i>
                                Добавить в избранное
                            </button>
                            <button class="btn btn-secondary btn-full" onclick="shareProfile()">
                                <i class="fas fa-share"></i>
                                Поделиться профилем
                            </button>
                            <button class="btn btn-secondary btn-full" onclick="reportUser()">
                                <i class="fas fa-flag"></i>
                                Пожаловаться
                            </button>
                        </div>
                    </div>
                </aside>

                <!-- Profile Main Content -->
                <main class="profile-main">
                    <!-- Profile Tabs -->
                    <div class="profile-tabs">
                        <button class="tab-btn active" data-tab="overview">
                            <i class="fas fa-user"></i>
                            Обзор
                        </button>
                        <button class="tab-btn" data-tab="posts">
                            <i class="fas fa-file-alt"></i>
                            Публикации
                        </button>
                        <button class="tab-btn" data-tab="comments">
                            <i class="fas fa-comments"></i>
                            Комментарии
                        </button>
                        <button class="tab-btn" data-tab="favorites">
                            <i class="fas fa-heart"></i>
                            Избранное
                        </button>
                        <button class="tab-btn" data-tab="activity">
                            <i class="fas fa-chart-line"></i>
                            Активность
                        </button>
                    </div>

                    <!-- Tab Content -->
                    <div class="tab-content">
                        <!-- Overview Tab -->
                        <div class="tab-pane active" id="overview">
                            <div class="overview-section">
                                <h3>О пользователе</h3>
                                {if user-info}
                                <div class="user-info">
                                    {user-info}
                                </div>
                                {else}
                                <p class="no-info">Информация о пользователе не указана</p>
                                {/if}
                            </div>

                            <div class="overview-section">
                                <h3>Последние публикации</h3>
                                <div class="recent-posts">
                                    {custom category="user-posts" template="shortstory" limit="3" cache="no"}
                                </div>
                            </div>

                            <div class="overview-section">
                                <h3>Последние комментарии</h3>
                                <div class="recent-comments">
                                    {custom category="user-comments" template="comment-item" limit="3" cache="no"}
                                </div>
                            </div>
                        </div>

                        <!-- Posts Tab -->
                        <div class="tab-pane" id="posts">
                            <div class="posts-header">
                                <h3>Публикации пользователя</h3>
                                <div class="posts-controls">
                                    <select class="sort-select" onchange="sortPosts(this.value)">
                                        <option value="date">По дате</option>
                                        <option value="rating">По рейтингу</option>
                                        <option value="views">По просмотрам</option>
                                    </select>
                                </div>
                            </div>
                            <div class="posts-grid">
                                {custom category="user-posts" template="shortstory" limit="12" cache="no"}
                            </div>
                            {if user-posts-pagination}
                            <div class="posts-pagination">
                                {user-posts-pagination}
                            </div>
                            {/if}
                        </div>

                        <!-- Comments Tab -->
                        <div class="tab-pane" id="comments">
                            <div class="comments-header">
                                <h3>Комментарии пользователя</h3>
                                <div class="comments-controls">
                                    <select class="sort-select" onchange="sortComments(this.value)">
                                        <option value="date">По дате</option>
                                        <option value="rating">По рейтингу</option>
                                    </select>
                                </div>
                            </div>
                            <div class="comments-list">
                                {custom category="user-comments" template="comment-item" limit="20" cache="no"}
                            </div>
                            {if user-comments-pagination}
                            <div class="comments-pagination">
                                {user-comments-pagination}
                            </div>
                            {/if}
                        </div>

                        <!-- Favorites Tab -->
                        <div class="tab-pane" id="favorites">
                            <div class="favorites-header">
                                <h3>Избранное</h3>
                                <div class="favorites-controls">
                                    <button class="btn btn-secondary btn-sm" onclick="clearFavorites()">
                                        <i class="fas fa-trash"></i>
                                        Очистить избранное
                                    </button>
                                </div>
                            </div>
                            <div class="favorites-grid">
                                {custom category="user-favorites" template="shortstory" limit="12" cache="no"}
                            </div>
                            {if user-favorites-pagination}
                            <div class="favorites-pagination">
                                {user-favorites-pagination}
                            </div>
                            {/if}
                        </div>

                        <!-- Activity Tab -->
                        <div class="tab-pane" id="activity">
                            <div class="activity-header">
                                <h3>Активность пользователя</h3>
                            </div>
                            <div class="activity-timeline">
                                {custom category="user-activity" template="activity-item" limit="20" cache="no"}
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    </div>
</section>

<style>
.user-profile-page {
    background: #0a0a0a;
    min-height: 100vh;
}

.user-profile-header {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 4rem 2rem 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.profile-hero {
    max-width: 1200px;
    margin: 0 auto;
}

.profile-cover {
    display: flex;
    gap: 3rem;
    align-items: center;
    flex-wrap: wrap;
}

.profile-avatar-large {
    position: relative;
    width: 150px;
    height: 150px;
    border-radius: 50%;
    overflow: hidden;
    background: rgba(255, 255, 255, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    border: 4px solid rgba(255, 107, 53, 0.3);
}

.profile-avatar-large img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.profile-avatar-large i {
    font-size: 4rem;
    color: rgba(255, 255, 255, 0.5);
}

.avatar-edit-btn {
    position: absolute;
    bottom: 0;
    right: 0;
    background: #ff6b35;
    border: none;
    color: white;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
}

.avatar-edit-btn:hover {
    background: #ff8c42;
    transform: scale(1.1);
}

.profile-info-main {
    flex: 1;
    min-width: 300px;
}

.profile-name {
    font-size: 2.5rem;
    font-weight: 900;
    color: white;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.profile-meta {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
}

.meta-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.meta-item i {
    color: #ff6b35;
}

.profile-actions {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

.user-profile-content {
    padding: 3rem 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.profile-grid {
    display: grid;
    grid-template-columns: 300px 1fr;
    gap: 3rem;
}

/* Profile Sidebar */
.profile-sidebar {
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

.sidebar-widget h3 {
    color: #ff6b35;
    margin-bottom: 1rem;
    font-size: 1.3rem;
}

.profile-details {
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
}

.detail-item {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.9rem;
}

.detail-item i {
    color: #ff6b35;
    width: 20px;
}

.detail-item a {
    color: #ff6b35;
    text-decoration: none;
}

.detail-item a:hover {
    color: #ff8c42;
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
}

.stat-item {
    text-align: center;
    padding: 1rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
}

.stat-number {
    font-size: 1.5rem;
    font-weight: 700;
    color: #ff6b35;
    margin-bottom: 0.5rem;
}

.stat-label {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.8rem;
}

.awards-list {
    color: rgba(255, 255, 255, 0.8);
}

.no-awards {
    color: rgba(255, 255, 255, 0.5);
    font-style: italic;
    text-align: center;
    margin: 0;
}

.quick-actions {
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
}

.btn-full {
    width: 100%;
}

/* Profile Main Content */
.profile-main {
    background: #1a1a1a;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    overflow: hidden;
}

.profile-tabs {
    display: flex;
    background: rgba(255, 255, 255, 0.05);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    overflow-x: auto;
}

.tab-btn {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    padding: 1rem 1.5rem;
    cursor: pointer;
    transition: all 0.3s ease;
    white-space: nowrap;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    border-bottom: 3px solid transparent;
}

.tab-btn:hover {
    color: white;
    background: rgba(255, 255, 255, 0.1);
}

.tab-btn.active {
    color: #ff6b35;
    border-bottom-color: #ff6b35;
    background: rgba(255, 107, 53, 0.1);
}

.tab-content {
    padding: 2rem;
}

.tab-pane {
    display: none;
}

.tab-pane.active {
    display: block;
}

.overview-section {
    margin-bottom: 3rem;
}

.overview-section h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.5rem;
}

.user-info {
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.6;
}

.no-info {
    color: rgba(255, 255, 255, 0.5);
    font-style: italic;
    text-align: center;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
}

.recent-posts,
.recent-comments {
    display: grid;
    gap: 1rem;
}

.posts-header,
.comments-header,
.favorites-header,
.activity-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 1rem;
}

.posts-header h3,
.comments-header h3,
.favorites-header h3,
.activity-header h3 {
    color: #ff6b35;
    margin: 0;
    font-size: 1.5rem;
}

.posts-controls,
.comments-controls,
.favorites-controls {
    display: flex;
    gap: 1rem;
    align-items: center;
}

.sort-select {
    padding: 0.5rem 1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 6px;
    color: white;
    font-size: 0.9rem;
    cursor: pointer;
}

.sort-select:focus {
    outline: none;
    border-color: #ff6b35;
}

.posts-grid,
.favorites-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 1.5rem;
    margin-bottom: 2rem;
}

.comments-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 2rem;
}

.activity-timeline {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.posts-pagination,
.comments-pagination,
.favorites-pagination {
    display: flex;
    justify-content: center;
    margin-top: 2rem;
}

.posts-pagination a,
.posts-pagination span,
.comments-pagination a,
.comments-pagination span,
.favorites-pagination a,
.favorites-pagination span {
    display: inline-block;
    padding: 10px 16px;
    background: #1a1a1a;
    color: white;
    text-decoration: none;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
    margin: 0 0.25rem;
}

.posts-pagination a:hover,
.comments-pagination a:hover,
.favorites-pagination a:hover {
    background: #ff6b35;
    border-color: #ff6b35;
}

.posts-pagination .current,
.comments-pagination .current,
.favorites-pagination .current {
    background: #ff6b35;
    border-color: #ff6b35;
}

/* Responsive Design */
@media (max-width: 1024px) {
    .profile-grid {
        grid-template-columns: 1fr;
        gap: 2rem;
    }
    
    .profile-sidebar {
        order: 2;
    }
    
    .profile-main {
        order: 1;
    }
}

@media (max-width: 768px) {
    .user-profile-header {
        padding: 2rem 1rem 1rem;
    }
    
    .profile-cover {
        flex-direction: column;
        text-align: center;
        gap: 2rem;
    }
    
    .profile-name {
        font-size: 2rem;
    }
    
    .profile-meta {
        justify-content: center;
    }
    
    .profile-actions {
        justify-content: center;
    }
    
    .user-profile-content {
        padding: 2rem 1rem;
    }
    
    .profile-tabs {
        flex-wrap: wrap;
    }
    
    .tab-btn {
        flex: 1;
        min-width: 120px;
        justify-content: center;
    }
    
    .tab-content {
        padding: 1.5rem;
    }
    
    .posts-header,
    .comments-header,
    .favorites-header,
    .activity-header {
        flex-direction: column;
        align-items: stretch;
        text-align: center;
    }
    
    .posts-grid,
    .favorites-grid {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
    
    .stats-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 480px) {
    .profile-name {
        font-size: 1.8rem;
    }
    
    .profile-avatar-large {
        width: 120px;
        height: 120px;
    }
    
    .avatar-edit-btn {
        width: 35px;
        height: 35px;
    }
    
    .profile-actions {
        flex-direction: column;
        align-items: center;
    }
    
    .profile-tabs {
        flex-direction: column;
    }
    
    .tab-btn {
        width: 100%;
    }
}
</style>

<script>
// Profile tab functionality
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        // Remove active class from all tabs and panes
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        
        // Add active class to clicked tab
        this.classList.add('active');
        
        // Show corresponding pane
        const tabId = this.dataset.tab;
        document.getElementById(tabId).classList.add('active');
    });
});

// Profile functionality
function editAvatar() {
    // Implement avatar editing functionality
    alert('Функция изменения аватара будет добавлена позже');
}

function editProfile() {
    // Implement profile editing functionality
    alert('Функция редактирования профиля будет добавлена позже');
}

function changePassword() {
    // Implement password change functionality
    alert('Функция смены пароля будет добавлена позже');
}

function addToFavorites() {
    // Implement add to favorites functionality
    alert('Функция добавления в избранное будет добавлена позже');
}

function shareProfile() {
    if (navigator.share) {
        navigator.share({
            title: 'Профиль пользователя {login}',
            text: 'Посмотрите профиль пользователя на Wink.ru',
            url: window.location.href
        });
    } else {
        // Fallback for browsers that don't support Web Share API
        navigator.clipboard.writeText(window.location.href).then(() => {
            alert('Ссылка на профиль скопирована в буфер обмена!');
        });
    }
}

function reportUser() {
    // Implement user reporting functionality
    alert('Функция жалобы на пользователя будет добавлена позже');
}

function clearFavorites() {
    if (confirm('Вы уверены, что хотите очистить избранное? Это действие нельзя отменить.')) {
        // Implement clear favorites functionality
        alert('Избранное очищено');
    }
}

// Sort functionality
function sortPosts(sortBy) {
    // Implement posts sorting
    console.log('Sorting posts by:', sortBy);
}

function sortComments(sortBy) {
    // Implement comments sorting
    console.log('Sorting comments by:', sortBy);
}

// Initialize profile page
document.addEventListener('DOMContentLoaded', function() {
    // Add animation for profile elements
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
    
    // Observe profile elements
    document.querySelectorAll('.sidebar-widget, .overview-section, .posts-grid, .comments-list, .favorites-grid').forEach(el => {
        observer.observe(el);
    });
    
    // Initialize first tab as active
    const firstTab = document.querySelector('.tab-btn');
    const firstPane = document.querySelector('.tab-pane');
    if (firstTab && firstPane) {
        firstTab.classList.add('active');
        firstPane.classList.add('active');
    }
});
</script>