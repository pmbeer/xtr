<section class="comments-section">
    <div class="comments-header">
        <h3 class="comments-title">
            <i class="fas fa-comments"></i>
            Комментарии ({comments-num})
        </h3>
        <div class="comments-controls">
            <button class="btn btn-secondary btn-sm" onclick="sortComments('date')">
                <i class="fas fa-clock"></i> По дате
            </button>
            <button class="btn btn-secondary btn-sm" onclick="sortComments('rating')">
                <i class="fas fa-star"></i> По рейтингу
            </button>
        </div>
    </div>

    <!-- Add Comment Form -->
    <div class="add-comment">
        <div class="comment-form-wrapper">
            <div class="comment-avatar">
                {if logged}
                    <img src="{avatar}" alt="{login}" class="user-avatar">
                {else}
                    <i class="fas fa-user-circle"></i>
                {/if}
            </div>
            <div class="comment-form">
                {if logged}
                    <form method="post" action="{add-comment}" class="comment-form-inner">
                        <textarea name="comment" placeholder="Напишите ваш комментарий..." class="comment-textarea" required></textarea>
                        <div class="comment-form-actions">
                            <div class="comment-rating">
                                <span class="rating-label">Оценка:</span>
                                <div class="star-rating">
                                    <input type="radio" name="rating" value="5" id="star5">
                                    <label for="star5"><i class="fas fa-star"></i></label>
                                    <input type="radio" name="rating" value="4" id="star4">
                                    <label for="star4"><i class="fas fa-star"></i></label>
                                    <input type="radio" name="rating" value="3" id="star3">
                                    <label for="star3"><i class="fas fa-star"></i></label>
                                    <input type="radio" name="rating" value="2" id="star2">
                                    <label for="star2"><i class="fas fa-star"></i></label>
                                    <input type="radio" name="rating" value="1" id="star1">
                                    <label for="star1"><i class="fas fa-star"></i></label>
                                </div>
                            </div>
                            <button type="submit" class="btn btn-primary">
                                <i class="fas fa-paper-plane"></i> Отправить
                            </button>
                        </div>
                    </form>
                {else}
                    <div class="login-prompt">
                        <p>Для добавления комментария необходимо <a href="{login-link}" class="login-link">войти в систему</a></p>
                    </div>
                {/if}
            </div>
        </div>
    </div>

    <!-- Comments List -->
    <div class="comments-list" id="commentsList">
        {comments}
    </div>

    <!-- Comments Pagination -->
    {if comments-navigation}
    <div class="comments-pagination">
        {comments-navigation}
    </div>
    {/if}
</section>

<style>
.comments-section {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin: 2rem 0;
}

.comments-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 1rem;
}

.comments-title {
    color: #ff6b35;
    font-size: 1.5rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.8rem;
    margin: 0;
}

.comments-controls {
    display: flex;
    gap: 0.8rem;
}

.btn-sm {
    padding: 8px 16px;
    font-size: 0.9rem;
}

/* Add Comment Form */
.add-comment {
    margin-bottom: 2rem;
    padding-bottom: 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.comment-form-wrapper {
    display: flex;
    gap: 1rem;
    align-items: flex-start;
}

.comment-avatar {
    width: 50px;
    height: 50px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
    background: rgba(255, 255, 255, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
}

.comment-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.comment-avatar i {
    font-size: 2rem;
    color: rgba(255, 255, 255, 0.5);
}

.comment-form {
    flex: 1;
}

.comment-form-inner {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.comment-textarea {
    width: 100%;
    min-height: 100px;
    padding: 1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 12px;
    color: white;
    font-family: inherit;
    font-size: 1rem;
    resize: vertical;
    transition: all 0.3s ease;
}

.comment-textarea:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.comment-textarea::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.comment-form-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.comment-rating {
    display: flex;
    align-items: center;
    gap: 0.8rem;
}

.rating-label {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.star-rating {
    display: flex;
    flex-direction: row-reverse;
    gap: 2px;
}

.star-rating input {
    display: none;
}

.star-rating label {
    cursor: pointer;
    color: rgba(255, 255, 255, 0.3);
    font-size: 1.2rem;
    transition: color 0.3s ease;
}

.star-rating label:hover,
.star-rating label:hover ~ label,
.star-rating input:checked ~ label {
    color: #ff6b35;
}

.login-prompt {
    text-align: center;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.login-prompt p {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
}

.login-link {
    color: #ff6b35;
    text-decoration: underline;
    font-weight: 600;
}

.login-link:hover {
    color: #ff8c42;
}

/* Comments List */
.comments-list {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.comment-item {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.comment-item:hover {
    background: rgba(255, 255, 255, 0.08);
    border-color: rgba(255, 255, 255, 0.2);
}

.comment-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    flex-wrap: wrap;
    gap: 1rem;
}

.comment-author {
    display: flex;
    align-items: center;
    gap: 0.8rem;
}

.comment-author-avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    overflow: hidden;
    background: rgba(255, 255, 255, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
}

.comment-author-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.comment-author-avatar i {
    font-size: 1.5rem;
    color: rgba(255, 255, 255, 0.5);
}

.comment-author-info {
    display: flex;
    flex-direction: column;
}

.comment-author-name {
    color: white;
    font-weight: 600;
    font-size: 1rem;
}

.comment-date {
    color: rgba(255, 255, 255, 0.5);
    font-size: 0.85rem;
}

.comment-rating-display {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.comment-rating-stars {
    color: #ff6b35;
    font-size: 0.9rem;
}

.comment-rating-value {
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.9rem;
}

.comment-content {
    color: rgba(255, 255, 255, 0.9);
    line-height: 1.6;
    margin-bottom: 1rem;
}

.comment-actions {
    display: flex;
    gap: 1rem;
    align-items: center;
}

.comment-action-btn {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    padding: 0.5rem;
    border-radius: 6px;
    transition: all 0.3s ease;
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.comment-action-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    color: white;
}

.comment-action-btn.liked {
    color: #ff6b35;
}

.comment-action-btn.liked i {
    animation: heartBeat 0.3s ease;
}

@keyframes heartBeat {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.2); }
}

/* Comments Pagination */
.comments-pagination {
    margin-top: 2rem;
    display: flex;
    justify-content: center;
}

.comments-pagination a,
.comments-pagination span {
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

.comments-pagination a:hover {
    background: #ff6b35;
    border-color: #ff6b35;
}

.comments-pagination .current {
    background: #ff6b35;
    border-color: #ff6b35;
}

/* Responsive Design */
@media (max-width: 768px) {
    .comments-section {
        padding: 1.5rem;
    }
    
    .comments-header {
        flex-direction: column;
        align-items: stretch;
    }
    
    .comments-controls {
        justify-content: center;
    }
    
    .comment-form-wrapper {
        flex-direction: column;
        align-items: center;
        text-align: center;
    }
    
    .comment-avatar {
        width: 60px;
        height: 60px;
    }
    
    .comment-form-actions {
        flex-direction: column;
        align-items: stretch;
    }
    
    .comment-header {
        flex-direction: column;
        align-items: flex-start;
    }
    
    .comment-actions {
        flex-wrap: wrap;
        justify-content: center;
    }
}

@media (max-width: 480px) {
    .comments-section {
        padding: 1rem;
    }
    
    .comment-item {
        padding: 1rem;
    }
    
    .comment-author-avatar {
        width: 35px;
        height: 35px;
    }
    
    .star-rating label {
        font-size: 1rem;
    }
}
</style>

<script>
// Comment functionality
function sortComments(sortBy) {
    const commentsList = document.getElementById('commentsList');
    const comments = Array.from(commentsList.children);
    
    comments.sort((a, b) => {
        let aValue, bValue;
        
        switch(sortBy) {
            case 'date':
                aValue = new Date(a.querySelector('.comment-date')?.textContent || '');
                bValue = new Date(b.querySelector('.comment-date')?.textContent || '');
                return bValue - aValue;
            case 'rating':
                aValue = parseFloat(a.querySelector('.comment-rating-value')?.textContent || '0');
                bValue = parseFloat(b.querySelector('.comment-rating-value')?.textContent || '0');
                return bValue - aValue;
            default:
                return 0;
        }
    });
    
    // Clear and re-append sorted comments
    commentsList.innerHTML = '';
    comments.forEach(comment => commentsList.appendChild(comment));
}

// Like comment functionality
function likeComment(commentId) {
    const btn = event.target.closest('.comment-action-btn');
    if (btn) {
        btn.classList.toggle('liked');
        const icon = btn.querySelector('i');
        if (btn.classList.contains('liked')) {
            icon.className = 'fas fa-heart';
        } else {
            icon.className = 'far fa-heart';
        }
    }
    
    // You can add AJAX call here to save like
    console.log('Liked comment:', commentId);
}

// Reply to comment functionality
function replyToComment(commentId) {
    // Implement reply functionality
    console.log('Reply to comment:', commentId);
}

// Report comment functionality
function reportComment(commentId) {
    // Implement report functionality
    console.log('Report comment:', commentId);
}

// Initialize comment functionality
document.addEventListener('DOMContentLoaded', function() {
    // Add click handlers for comment actions
    document.querySelectorAll('.comment-action-btn').forEach(btn => {
        if (btn.dataset.action === 'like') {
            btn.addEventListener('click', () => likeComment(btn.dataset.commentId));
        }
    });
    
    // Add animation for new comments
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
    
    document.querySelectorAll('.comment-item').forEach(comment => {
        observer.observe(comment);
    });
});
</script>