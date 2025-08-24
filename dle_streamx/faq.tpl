<section class="faq-page">
    <!-- FAQ Hero -->
    <header class="faq-hero">
        <div class="hero-content">
            <h1 class="hero-title">Часто задаваемые вопросы</h1>
            <p class="hero-subtitle">
                Найдите ответы на самые популярные вопросы о платформе
            </p>
            
            <!-- Search FAQ -->
            <div class="faq-search">
                <div class="search-input-wrapper">
                    <i class="fas fa-search search-icon"></i>
                    <input type="text" id="faqSearchInput" class="search-input" placeholder="Поиск по вопросам..." onkeyup="searchFAQ(this.value)">
                </div>
            </div>
        </div>
    </header>

    <!-- FAQ Content -->
    <div class="faq-content">
        <div class="container">
            <!-- FAQ Categories -->
            <div class="faq-categories">
                <button class="category-btn active" data-category="all">
                    <i class="fas fa-th-large"></i>
                    Все вопросы
                </button>
                <button class="category-btn" data-category="general">
                    <i class="fas fa-info-circle"></i>
                    Общие
                </button>
                <button class="category-btn" data-category="account">
                    <i class="fas fa-user"></i>
                    Аккаунт
                </button>
                <button class="category-btn" data-category="content">
                    <i class="fas fa-film"></i>
                    Контент
                </button>
                <button class="category-btn" data-category="technical">
                    <i class="fas fa-cog"></i>
                    Технические
                </button>
                <button class="category-btn" data-category="payment">
                    <i class="fas fa-credit-card"></i>
                    Оплата
                </button>
            </div>

            <!-- FAQ Items -->
            <div class="faq-items">
                <!-- General Questions -->
                <div class="faq-item" data-category="general">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Что такое Wink.ru?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Wink.ru — это современная платформа для просмотра фильмов и сериалов в высоком качестве. Мы предоставляем доступ к обширной библиотеке контента с удобным интерфейсом и множеством функций.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="general">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Платформа бесплатная?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Да, основная часть контента доступна бесплатно. У нас также есть премиум-подписка с дополнительными возможностями, эксклюзивным контентом и просмотром без рекламы.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="general">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>На каких устройствах можно смотреть?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Платформа доступна на всех устройствах: компьютеры, планшеты, смартфоны, Smart TV. Мы поддерживаем все популярные браузеры и операционные системы.</p>
                    </div>
                </div>

                <!-- Account Questions -->
                <div class="faq-item" data-category="account">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Как зарегистрироваться?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Регистрация очень простая: нажмите кнопку "Регистрация", заполните форму с вашим email и паролем, подтвердите email и начните пользоваться платформой.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="account">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Можно ли изменить пароль?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Да, вы можете изменить пароль в настройках профиля. Если забыли пароль, используйте функцию восстановления по email.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="account">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Как удалить аккаунт?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Удаление аккаунта возможно через настройки профиля. Обратите внимание, что это действие необратимо и все данные будут удалены.</p>
                    </div>
                </div>

                <!-- Content Questions -->
                <div class="faq-item" data-category="content">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Как часто обновляется контент?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Мы ежедневно добавляем новые фильмы и сериалы. Новинки появляются сразу после их официального релиза, а классические произведения доступны постоянно.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="content">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Есть ли субтитры?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Да, большинство фильмов и сериалов имеют русские субтитры. Для некоторых произведений доступны субтитры на других языках.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="content">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Можно ли скачать фильмы?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>В бесплатной версии скачивание недоступно. Премиум-подписчики могут скачивать контент для просмотра офлайн на мобильных устройствах.</p>
                    </div>
                </div>

                <!-- Technical Questions -->
                <div class="faq-item" data-category="technical">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Какое качество видео доступно?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Мы поддерживаем качество от 480p до 4K в зависимости от вашего интернет-соединения и устройства. Качество автоматически адаптируется под ваши возможности.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="technical">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Почему видео не воспроизводится?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Проблемы с воспроизведением могут быть связаны с медленным интернетом, устаревшим браузером или блокировщиками рекламы. Попробуйте обновить страницу или использовать другой браузер.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="technical">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Какие браузеры поддерживаются?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Мы поддерживаем все современные браузеры: Chrome, Firefox, Safari, Edge. Рекомендуется использовать последние версии для лучшей производительности.</p>
                    </div>
                </div>

                <!-- Payment Questions -->
                <div class="faq-item" data-category="payment">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Какие способы оплаты доступны?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Мы принимаем банковские карты (Visa, MasterCard, МИР), электронные кошельки (QIWI, Яндекс.Деньги), мобильные платежи и другие популярные способы оплаты.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="payment">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Можно ли отменить подписку?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Да, вы можете отменить подписку в любое время через настройки профиля. Подписка будет активна до конца оплаченного периода.</p>
                    </div>
                </div>

                <div class="faq-item" data-category="payment">
                    <div class="faq-question" onclick="toggleFAQ(this)">
                        <h3>Есть ли возврат средств?</h3>
                        <i class="fas fa-chevron-down"></i>
                    </div>
                    <div class="faq-answer">
                        <p>Возврат средств возможен в течение 14 дней с момента оплаты, если у вас возникли технические проблемы или вы недовольны качеством сервиса.</p>
                    </div>
                </div>
            </div>

            <!-- No Results Message -->
            <div class="no-results" id="noResults" style="display: none;">
                <div class="no-results-icon">
                    <i class="fas fa-search"></i>
                </div>
                <h3>Ничего не найдено</h3>
                <p>Попробуйте изменить поисковый запрос или обратитесь в поддержку</p>
                <button class="btn btn-primary" onclick="resetSearch()">
                    <i class="fas fa-undo"></i>
                    Сбросить поиск
                </button>
            </div>

            <!-- Contact Support -->
            <div class="contact-support">
                <div class="support-card">
                    <div class="support-icon">
                        <i class="fas fa-headset"></i>
                    </div>
                    <h3>Не нашли ответ?</h3>
                    <p>Наша команда поддержки готова помочь вам 24/7</p>
                    <div class="support-actions">
                        <a href="/contacts/" class="btn btn-primary">
                            <i class="fas fa-envelope"></i>
                            Написать в поддержку
                        </a>
                        <a href="/help/" class="btn btn-secondary">
                            <i class="fas fa-book"></i>
                            Центр помощи
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>

<style>
.faq-page {
    background: #0a0a0a;
    min-height: 100vh;
}

/* FAQ Hero */
.faq-hero {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    padding: 4rem 2rem 3rem;
    text-align: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.hero-content {
    max-width: 800px;
    margin: 0 auto;
}

.hero-title {
    font-size: 3.5rem;
    font-weight: 900;
    color: white;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #ffffff, #ff6b35);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.hero-subtitle {
    font-size: 1.2rem;
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    line-height: 1.6;
}

/* FAQ Search */
.faq-search {
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
    width: 100%;
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

/* FAQ Content */
.faq-content {
    padding: 3rem 2rem;
}

.container {
    max-width: 1000px;
    margin: 0 auto;
}

/* FAQ Categories */
.faq-categories {
    display: flex;
    gap: 1rem;
    margin-bottom: 3rem;
    flex-wrap: wrap;
    justify-content: center;
}

.category-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.7);
    padding: 0.8rem 1.5rem;
    border-radius: 25px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.category-btn:hover {
    background: rgba(255, 107, 53, 0.1);
    border-color: rgba(255, 107, 53, 0.3);
    color: white;
}

.category-btn.active {
    background: #ff6b35;
    border-color: #ff6b35;
    color: white;
}

/* FAQ Items */
.faq-items {
    margin-bottom: 3rem;
}

.faq-item {
    background: #1a1a1a;
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin-bottom: 1rem;
    overflow: hidden;
    transition: all 0.3s ease;
}

.faq-item:hover {
    border-color: rgba(255, 107, 53, 0.2);
}

.faq-question {
    padding: 1.5rem;
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    transition: all 0.3s ease;
}

.faq-question:hover {
    background: rgba(255, 255, 255, 0.05);
}

.faq-question h3 {
    color: white;
    margin: 0;
    font-size: 1.1rem;
    font-weight: 600;
    flex: 1;
}

.faq-question i {
    color: #ff6b35;
    font-size: 1.1rem;
    transition: transform 0.3s ease;
    margin-left: 1rem;
}

.faq-item.active .faq-question i {
    transform: rotate(180deg);
}

.faq-answer {
    max-height: 0;
    overflow: hidden;
    transition: max-height 0.3s ease;
    background: rgba(255, 255, 255, 0.02);
}

.faq-item.active .faq-answer {
    max-height: 200px;
}

.faq-answer p {
    padding: 0 1.5rem 1.5rem;
    margin: 0;
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.6;
}

/* No Results */
.no-results {
    text-align: center;
    padding: 3rem 2rem;
    background: #1a1a1a;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    margin: 2rem 0;
}

.no-results-icon {
    font-size: 3rem;
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

/* Contact Support */
.contact-support {
    margin-top: 4rem;
}

.support-card {
    background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
    border-radius: 20px;
    padding: 3rem 2rem;
    text-align: center;
    border: 1px solid rgba(255, 107, 53, 0.2);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}

.support-icon {
    width: 80px;
    height: 80px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1.5rem;
}

.support-icon i {
    font-size: 2rem;
    color: #ff6b35;
}

.support-card h3 {
    color: white;
    font-size: 1.8rem;
    margin-bottom: 1rem;
}

.support-card p {
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
    font-size: 1.1rem;
}

.support-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
}

.support-actions .btn {
    min-width: 200px;
    padding: 1rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
}

/* Responsive Design */
@media (max-width: 768px) {
    .faq-hero {
        padding: 3rem 1rem 2rem;
    }
    
    .hero-title {
        font-size: 2.5rem;
    }
    
    .hero-subtitle {
        font-size: 1.1rem;
    }
    
    .faq-content {
        padding: 2rem 1rem;
    }
    
    .faq-categories {
        gap: 0.8rem;
    }
    
    .category-btn {
        padding: 0.7rem 1.2rem;
        font-size: 0.85rem;
    }
    
    .faq-question {
        padding: 1.2rem;
    }
    
    .faq-question h3 {
        font-size: 1rem;
    }
    
    .support-card {
        padding: 2rem 1.5rem;
    }
    
    .support-actions {
        flex-direction: column;
        align-items: center;
    }
    
    .support-actions .btn {
        width: 100%;
        max-width: 300px;
    }
}

@media (max-width: 480px) {
    .hero-title {
        font-size: 2rem;
    }
    
    .faq-categories {
        flex-direction: column;
        align-items: center;
    }
    
    .category-btn {
        width: 100%;
        max-width: 250px;
        justify-content: center;
    }
    
    .faq-question {
        padding: 1rem;
    }
    
    .faq-answer p {
        padding: 0 1rem 1rem;
    }
}
</style>

<script>
// FAQ functionality
function toggleFAQ(element) {
    const faqItem = element.closest('.faq-item');
    const isActive = faqItem.classList.contains('active');
    
    // Close all FAQ items
    document.querySelectorAll('.faq-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Open clicked item if it wasn't active
    if (!isActive) {
        faqItem.classList.add('active');
    }
}

// Search FAQ functionality
function searchFAQ(query) {
    const faqItems = document.querySelectorAll('.faq-item');
    const noResults = document.getElementById('noResults');
    let hasResults = false;
    
    faqItems.forEach(item => {
        const question = item.querySelector('h3').textContent.toLowerCase();
        const answer = item.querySelector('p').textContent.toLowerCase();
        const searchQuery = query.toLowerCase();
        
        if (question.includes(searchQuery) || answer.includes(searchQuery)) {
            item.style.display = 'block';
            hasResults = true;
        } else {
            item.style.display = 'none';
        }
    });
    
    // Show/hide no results message
    if (hasResults || query === '') {
        noResults.style.display = 'none';
    } else {
        noResults.style.display = 'block';
    }
}

// Reset search functionality
function resetSearch() {
    document.getElementById('faqSearchInput').value = '';
    searchFAQ('');
}

// Category filtering
document.addEventListener('DOMContentLoaded', function() {
    const categoryBtns = document.querySelectorAll('.category-btn');
    const faqItems = document.querySelectorAll('.faq-item');
    
    categoryBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from all buttons
            categoryBtns.forEach(b => b.classList.remove('active'));
            // Add active class to clicked button
            this.classList.add('active');
            
            const category = this.dataset.category;
            
            // Filter FAQ items
            faqItems.forEach(item => {
                if (category === 'all' || item.dataset.category === category) {
                    item.style.display = 'block';
                } else {
                    item.style.display = 'none';
                }
            });
            
            // Reset search
            document.getElementById('faqSearchInput').value = '';
        });
    });
    
    // Add animation for FAQ items
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
    
    // Observe FAQ items
    faqItems.forEach(item => {
        observer.observe(item);
    });
    
    // Keyboard navigation
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' && document.activeElement.id === 'faqSearchInput') {
            e.preventDefault();
            const query = document.getElementById('faqSearchInput').value;
            searchFAQ(query);
        }
        
        // Escape to clear search
        if (e.key === 'Escape') {
            resetSearch();
        }
    });
    
    // Auto-focus search input
    setTimeout(() => {
        document.getElementById('faqSearchInput').focus();
    }, 1000);
});

// Smooth scrolling for internal links
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
</script>