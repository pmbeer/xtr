<section class="contacts-page">
    <!-- Contacts Hero -->
    <header class="contacts-hero">
        <div class="hero-content">
            <h1 class="hero-title">Свяжитесь с нами</h1>
            <p class="hero-subtitle">
                Мы всегда готовы помочь и ответить на ваши вопросы
            </p>
        </div>
    </header>

    <!-- Contacts Content -->
    <div class="contacts-content">
        <div class="container">
            <!-- Contact Methods -->
            <section class="contact-methods">
                <div class="methods-grid">
                    <div class="method-card">
                        <div class="method-icon">
                            <i class="fas fa-envelope"></i>
                        </div>
                        <h3>Email</h3>
                        <p>support@wink.ru</p>
                        <p>info@wink.ru</p>
                        <a href="mailto:support@wink.ru" class="btn btn-secondary">
                            <i class="fas fa-paper-plane"></i>
                            Написать
                        </a>
                    </div>

                    <div class="method-card">
                        <div class="method-icon">
                            <i class="fas fa-phone"></i>
                        </div>
                        <h3>Телефон</h3>
                        <p>+7 (800) 555-0123</p>
                        <p>Круглосуточно</p>
                        <a href="tel:+78005550123" class="btn btn-secondary">
                            <i class="fas fa-phone"></i>
                            Позвонить
                        </a>
                    </div>

                    <div class="method-card">
                        <div class="method-icon">
                            <i class="fab fa-telegram"></i>
                        </div>
                        <h3>Telegram</h3>
                        <p>@wink_support</p>
                        <p>Быстрые ответы</p>
                        <a href="https://t.me/wink_support" class="btn btn-secondary" target="_blank">
                            <i class="fab fa-telegram"></i>
                            Написать
                        </a>
                    </div>

                    <div class="method-card">
                        <div class="method-icon">
                            <i class="fab fa-vk"></i>
                        </div>
                        <h3>VKontakte</h3>
                        <p>vk.com/wink_ru</p>
                        <p>Официальная группа</p>
                        <a href="https://vk.com/wink_ru" class="btn btn-secondary" target="_blank">
                            <i class="fab fa-vk"></i>
                            Перейти
                        </a>
                    </div>
                </div>
            </section>

            <!-- Contact Form -->
            <section class="contact-form-section">
                <div class="form-container">
                    <div class="form-header">
                        <h2>Отправить сообщение</h2>
                        <p>Заполните форму ниже, и мы свяжемся с вами в ближайшее время</p>
                    </div>

                    <form class="contact-form" id="contactForm" onsubmit="sendContactMessage(event)">
                        <div class="form-row">
                            <div class="form-group">
                                <label for="contactName">Имя *</label>
                                <input type="text" id="contactName" name="name" required>
                            </div>
                            <div class="form-group">
                                <label for="contactEmail">Email *</label>
                                <input type="email" id="contactEmail" name="email" required>
                            </div>
                        </div>

                        <div class="form-row">
                            <div class="form-group">
                                <label for="contactPhone">Телефон</label>
                                <input type="tel" id="contactPhone" name="phone">
                            </div>
                            <div class="form-group">
                                <label for="contactSubject">Тема *</label>
                                <select id="contactSubject" name="subject" required>
                                    <option value="">Выберите тему</option>
                                    <option value="technical">Техническая поддержка</option>
                                    <option value="content">Вопросы по контенту</option>
                                    <option value="account">Проблемы с аккаунтом</option>
                                    <option value="billing">Вопросы по оплате</option>
                                    <option value="partnership">Партнерство</option>
                                    <option value="other">Другое</option>
                                </select>
                            </div>
                        </div>

                        <div class="form-group">
                            <label for="contactMessage">Сообщение *</label>
                            <textarea id="contactMessage" name="message" rows="6" required placeholder="Расскажите подробнее о вашем вопросе или проблеме..."></textarea>
                        </div>

                        <div class="form-group">
                            <label class="checkbox-wrapper">
                                <input type="checkbox" name="agreement" required>
                                <span class="checkmark"></span>
                                Я согласен с <a href="/privacy/" target="_blank">политикой конфиденциальности</a>
                            </label>
                        </div>

                        <div class="form-actions">
                            <button type="submit" class="btn btn-primary">
                                <i class="fas fa-paper-plane"></i>
                                Отправить сообщение
                            </button>
                            <button type="reset" class="btn btn-secondary" onclick="resetForm()">
                                <i class="fas fa-undo"></i>
                                Очистить форму
                            </button>
                        </div>
                    </form>
                </div>

                <!-- Contact Info -->
                <div class="contact-info">
                    <div class="info-card">
                        <h3>Офис</h3>
                        <div class="info-item">
                            <i class="fas fa-map-marker-alt"></i>
                            <div>
                                <strong>Адрес:</strong><br>
                                г. Москва, ул. Тверская, д. 1<br>
                                БЦ "Центральный", офис 1001
                            </div>
                        </div>
                        <div class="info-item">
                            <i class="fas fa-clock"></i>
                            <div>
                                <strong>Время работы:</strong><br>
                                Пн-Пт: 9:00 - 18:00<br>
                                Сб-Вс: 10:00 - 16:00
                            </div>
                        </div>
                    </div>

                    <div class="info-card">
                        <h3>Поддержка</h3>
                        <div class="info-item">
                            <i class="fas fa-headset"></i>
                            <div>
                                <strong>Техподдержка:</strong><br>
                                24/7 онлайн поддержка<br>
                                Среднее время ответа: 15 мин
                            </div>
                        </div>
                        <div class="info-item">
                            <i class="fas fa-language"></i>
                            <div>
                                <strong>Языки:</strong><br>
                                Русский, English<br>
                                Deutsch, Français
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            <!-- FAQ Quick Links -->
            <section class="quick-help">
                <h2>Популярные вопросы</h2>
                <div class="help-grid">
                    <a href="/faq/#general" class="help-card">
                        <i class="fas fa-info-circle"></i>
                        <h4>Как начать пользоваться?</h4>
                        <p>Быстрый старт для новых пользователей</p>
                    </a>
                    <a href="/faq/#technical" class="help-card">
                        <i class="fas fa-cog"></i>
                        <h4>Проблемы с воспроизведением</h4>
                        <p>Решение технических проблем</p>
                    </a>
                    <a href="/faq/#payment" class="help-card">
                        <i class="fas fa-credit-card"></i>
                        <h4>Вопросы по оплате</h4>
                        <p>Информация о подписке и платежах</p>
                    </a>
                    <a href="/faq/#account" class="help-card">
                        <i class="fas fa-user"></i>
                        <h4>Управление аккаунтом</h4>
                        <p>Настройки профиля и безопасность</p>
                    </a>
                </div>
            </section>

            <!-- Social Media -->
            <section class="social-section">
                <h2>Следите за нами</h2>
                <p>Будьте в курсе последних новостей и обновлений</p>
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
                    <a href="https://instagram.com/wink_ru" class="social-link instagram" target="_blank">
                        <i class="fab fa-instagram"></i>
                        <span>Instagram</span>
                    </a>
                </div>
            </section>
        </div>
    </div>
</section>

<style>
.contacts-page {
    background: #0a0a0a;
    min-height: 100vh;
}

/* Contacts Hero */
.contacts-hero {
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
    line-height: 1.6;
}

/* Contacts Content */
.contacts-content {
    padding: 4rem 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

/* Contact Methods */
.contact-methods {
    margin-bottom: 5rem;
}

.methods-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
}

.method-card {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2rem;
    text-align: center;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.method-card:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.method-icon {
    width: 80px;
    height: 80px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1.5rem;
}

.method-icon i {
    font-size: 2rem;
    color: #ff6b35;
}

.method-card h3 {
    color: white;
    font-size: 1.3rem;
    margin-bottom: 1rem;
}

.method-card p {
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 0.5rem;
}

.method-card .btn {
    margin-top: 1rem;
    min-width: 120px;
}

/* Contact Form Section */
.contact-form-section {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 3rem;
    margin-bottom: 5rem;
}

.form-container {
    background: #1a1a1a;
    border-radius: 16px;
    padding: 2.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.form-header {
    margin-bottom: 2rem;
}

.form-header h2 {
    color: #ff6b35;
    font-size: 1.8rem;
    margin-bottom: 0.5rem;
}

.form-header p {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
}

.contact-form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.form-group label {
    color: rgba(255, 255, 255, 0.9);
    font-weight: 500;
    font-size: 0.9rem;
}

.form-group input,
.form-group select,
.form-group textarea {
    padding: 1rem;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    color: white;
    font-size: 1rem;
    transition: all 0.3s ease;
}

.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.form-group input::placeholder,
.form-group textarea::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

.form-group select option {
    background: #1a1a1a;
    color: white;
}

.checkbox-wrapper {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    color: rgba(255, 255, 255, 0.8);
    cursor: pointer;
    font-size: 0.9rem;
}

.checkbox-wrapper input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: #ff6b35;
}

.checkbox-wrapper a {
    color: #ff6b35;
    text-decoration: none;
}

.checkbox-wrapper a:hover {
    text-decoration: underline;
}

.form-actions {
    display: flex;
    gap: 1rem;
    margin-top: 1rem;
}

.form-actions .btn {
    flex: 1;
    padding: 1rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
}

/* Contact Info */
.contact-info {
    display: flex;
    flex-direction: column;
    gap: 2rem;
}

.info-card {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.info-card h3 {
    color: #ff6b35;
    margin-bottom: 1.5rem;
    font-size: 1.3rem;
}

.info-item {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    align-items: flex-start;
}

.info-item:last-child {
    margin-bottom: 0;
}

.info-item i {
    color: #ff6b35;
    font-size: 1.2rem;
    margin-top: 0.2rem;
    width: 20px;
}

.info-item div {
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.5;
}

.info-item strong {
    color: white;
}

/* Quick Help */
.quick-help {
    margin-bottom: 5rem;
}

.quick-help h2 {
    color: #ff6b35;
    text-align: center;
    margin-bottom: 2rem;
    font-size: 2rem;
}

.help-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
}

.help-card {
    background: #1a1a1a;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    text-decoration: none;
    transition: all 0.3s ease;
    display: block;
}

.help-card:hover {
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-3px);
}

.help-card i {
    color: #ff6b35;
    font-size: 2rem;
    margin-bottom: 1rem;
}

.help-card h4 {
    color: white;
    margin-bottom: 0.8rem;
    font-size: 1.1rem;
}

.help-card p {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
    font-size: 0.9rem;
    line-height: 1.5;
}

/* Social Section */
.social-section {
    text-align: center;
}

.social-section h2 {
    color: #ff6b35;
    margin-bottom: 1rem;
    font-size: 2rem;
}

.social-section p {
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 2rem;
}

.social-links {
    display: flex;
    gap: 1.5rem;
    justify-content: center;
    flex-wrap: wrap;
}

.social-link {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    padding: 1rem 1.5rem;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    color: white;
    text-decoration: none;
    transition: all 0.3s ease;
    min-width: 150px;
}

.social-link:hover {
    transform: translateY(-3px);
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

.social-link.instagram:hover {
    background: linear-gradient(45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888);
    border-color: #e6683c;
}

.social-link i {
    font-size: 1.5rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    .contacts-hero {
        padding: 3rem 1rem 2rem;
    }
    
    .hero-title {
        font-size: 2.5rem;
    }
    
    .contacts-content {
        padding: 2rem 1rem;
    }
    
    .methods-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .contact-form-section {
        grid-template-columns: 1fr;
        gap: 2rem;
    }
    
    .form-container {
        padding: 2rem;
    }
    
    .form-row {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
    
    .form-actions {
        flex-direction: column;
    }
    
    .help-grid {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
    
    .social-links {
        flex-direction: column;
        align-items: center;
    }
    
    .social-link {
        width: 100%;
        max-width: 250px;
        justify-content: center;
    }
}

@media (max-width: 480px) {
    .hero-title {
        font-size: 2rem;
    }
    
    .form-container {
        padding: 1.5rem;
    }
    
    .method-card {
        padding: 1.5rem;
    }
    
    .contact-methods {
        margin-bottom: 3rem;
    }
    
    .contact-form-section {
        margin-bottom: 3rem;
    }
    
    .quick-help {
        margin-bottom: 3rem;
    }
}
</style>

<script>
// Contact form functionality
function sendContactMessage(event) {
    event.preventDefault();
    
    const form = event.target;
    const formData = new FormData(form);
    
    // Show loading state
    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerHTML;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Отправка...';
    submitBtn.disabled = true;
    
    // Simulate form submission (replace with actual AJAX call)
    setTimeout(() => {
        // Show success message
        showNotification('Сообщение отправлено! Мы свяжемся с вами в ближайшее время.', 'success');
        
        // Reset form
        form.reset();
        
        // Restore button
        submitBtn.innerHTML = originalText;
        submitBtn.disabled = false;
    }, 2000);
}

function resetForm() {
    const form = document.getElementById('contactForm');
    form.reset();
}

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <i class="fas fa-${type === 'success' ? 'check-circle' : 'info-circle'}"></i>
            <span>${message}</span>
        </div>
        <button class="notification-close" onclick="this.parentElement.remove()">
            <i class="fas fa-times"></i>
        </button>
    `;
    
    // Add styles if not already present
    if (!document.querySelector('.notification-styles')) {
        const style = document.createElement('style');
        style.className = 'notification-styles';
        style.textContent = `
            .notification {
                position: fixed;
                top: 2rem;
                right: 2rem;
                background: #1a1a1a;
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 12px;
                padding: 1rem 1.5rem;
                color: white;
                box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
                z-index: 10000;
                max-width: 400px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                animation: slideIn 0.3s ease;
            }
            
            .notification-success {
                border-left: 4px solid #4caf50;
            }
            
            .notification-content {
                display: flex;
                align-items: center;
                gap: 0.8rem;
            }
            
            .notification-content i {
                color: #4caf50;
            }
            
            .notification-close {
                background: none;
                border: none;
                color: rgba(255, 255, 255, 0.6);
                cursor: pointer;
                padding: 0.2rem;
                margin-left: 1rem;
            }
            
            .notification-close:hover {
                color: white;
            }
            
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        document.head.appendChild(style);
    }
    
    // Add to page
    document.body.appendChild(notification);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentElement) {
            notification.remove();
        }
    }, 5000);
}

// Initialize contacts page
document.addEventListener('DOMContentLoaded', function() {
    // Add animation for contact elements
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
    
    // Observe contact elements
    document.querySelectorAll('.method-card, .help-card, .social-link').forEach(el => {
        observer.observe(el);
    });
    
    // Form validation
    const form = document.getElementById('contactForm');
    const inputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    
    inputs.forEach(input => {
        input.addEventListener('blur', function() {
            if (!this.value.trim()) {
                this.style.borderColor = '#ff4444';
            } else {
                this.style.borderColor = 'rgba(255, 255, 255, 0.2)';
            }
        });
        
        input.addEventListener('input', function() {
            if (this.value.trim()) {
                this.style.borderColor = '#4caf50';
            }
        });
    });
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