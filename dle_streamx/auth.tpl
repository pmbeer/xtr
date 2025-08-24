<section class="auth-page">
    <div class="auth-container">
        <!-- Auth Tabs -->
        <div class="auth-tabs">
            <button class="auth-tab-btn active" data-tab="login">
                <i class="fas fa-sign-in-alt"></i>
                Вход
            </button>
            <button class="auth-tab-btn" data-tab="register">
                <i class="fas fa-user-plus"></i>
                Регистрация
            </button>
        </div>

        <!-- Auth Forms -->
        <div class="auth-forms">
            <!-- Login Form -->
            <div class="auth-form active" id="login">
                <div class="form-header">
                    <h2>Вход в систему</h2>
                    <p>Войдите в свой аккаунт для доступа к личному кабинету</p>
                </div>

                <form method="post" action="{login-link}" class="login-form" id="loginForm">
                    <div class="form-group">
                        <label for="loginUsername" class="form-label">
                            <i class="fas fa-user"></i>
                            Логин или Email
                        </label>
                        <input type="text" name="login" id="loginUsername" class="form-input" required autocomplete="username">
                    </div>

                    <div class="form-group">
                        <label for="loginPassword" class="form-label">
                            <i class="fas fa-lock"></i>
                            Пароль
                        </label>
                        <div class="password-input-wrapper">
                            <input type="password" name="password" id="loginPassword" class="form-input" required autocomplete="current-password">
                            <button type="button" class="password-toggle" onclick="togglePassword('loginPassword')">
                                <i class="fas fa-eye"></i>
                            </button>
                        </div>
                    </div>

                    <div class="form-options">
                        <label class="checkbox-wrapper">
                            <input type="checkbox" name="remember" id="rememberMe">
                            <span class="checkmark"></span>
                            Запомнить меня
                        </label>
                        <a href="{forgot-password-link}" class="forgot-password">Забыли пароль?</a>
                    </div>

                    <button type="submit" class="btn btn-primary btn-full">
                        <i class="fas fa-sign-in-alt"></i>
                        Войти
                    </button>
                </form>

                <div class="social-login">
                    <p class="social-login-text">Или войдите через:</p>
                    <div class="social-buttons">
                        <button class="btn btn-social btn-vk" onclick="socialLogin('vk')">
                            <i class="fab fa-vk"></i>
                            VK
                        </button>
                        <button class="btn btn-social btn-google" onclick="socialLogin('google')">
                            <i class="fab fa-google"></i>
                            Google
                        </button>
                        <button class="btn btn-social btn-yandex" onclick="socialLogin('yandex')">
                            <i class="fas fa-y"></i>
                            Yandex
                        </button>
                    </div>
                </div>
            </div>

            <!-- Register Form -->
            <div class="auth-form" id="register">
                <div class="form-header">
                    <h2>Регистрация</h2>
                    <p>Создайте новый аккаунт для доступа ко всем возможностям сайта</p>
                </div>

                <form method="post" action="{registration-link}" class="register-form" id="registerForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="registerUsername" class="form-label">
                                <i class="fas fa-user"></i>
                                Логин
                            </label>
                            <input type="text" name="name" id="registerUsername" class="form-input" required autocomplete="username">
                        </div>

                        <div class="form-group">
                            <label for="registerEmail" class="form-label">
                                <i class="fas fa-envelope"></i>
                                Email
                            </label>
                            <input type="email" name="email" id="registerEmail" class="form-input" required autocomplete="email">
                        </div>
                    </div>

                    <div class="form-row">
                        <div class="form-group">
                            <label for="registerPassword" class="form-label">
                                <i class="fas fa-lock"></i>
                                Пароль
                            </label>
                            <div class="password-input-wrapper">
                                <input type="password" name="password" id="registerPassword" class="form-input" required autocomplete="new-password">
                                <button type="button" class="password-toggle" onclick="togglePassword('registerPassword')">
                                    <i class="fas fa-eye"></i>
                                </button>
                            </div>
                        </div>

                        <div class="form-group">
                            <label for="registerPasswordConfirm" class="form-label">
                                <i class="fas fa-lock"></i>
                                Подтвердите пароль
                            </label>
                            <div class="password-input-wrapper">
                                <input type="password" name="password2" id="registerPasswordConfirm" class="form-input" required autocomplete="new-password">
                                <button type="button" class="password-toggle" onclick="togglePassword('registerPasswordConfirm')">
                                    <i class="fas fa-eye"></i>
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="registerCaptcha" class="form-label">
                            <i class="fas fa-shield-alt"></i>
                            Код безопасности
                        </label>
                        <div class="captcha-wrapper">
                            <img src="{captcha-image}" alt="Капча" class="captcha-image" onclick="refreshCaptcha()">
                            <input type="text" name="sec_code" id="registerCaptcha" class="form-input" required>
                            <button type="button" class="captcha-refresh" onclick="refreshCaptcha()" title="Обновить капчу">
                                <i class="fas fa-sync-alt"></i>
                            </button>
                        </div>
                    </div>

                    <div class="form-options">
                        <label class="checkbox-wrapper">
                            <input type="checkbox" name="agree" id="agreeTerms" required>
                            <span class="checkmark"></span>
                            Я согласен с <a href="{terms-link}" target="_blank" class="terms-link">условиями использования</a>
                        </label>
                        <label class="checkbox-wrapper">
                            <input type="checkbox" name="newsletter" id="newsletter">
                            <span class="checkmark"></span>
                            Подписаться на новости
                        </label>
                    </div>

                    <button type="submit" class="btn btn-primary btn-full">
                        <i class="fas fa-user-plus"></i>
                        Зарегистрироваться
                    </button>
                </form>

                <div class="social-login">
                    <p class="social-login-text">Или зарегистрируйтесь через:</p>
                    <div class="social-buttons">
                        <button class="btn btn-social btn-vk" onclick="socialLogin('vk')">
                            <i class="fab fa-vk"></i>
                            VK
                        </button>
                        <button class="btn btn-social btn-google" onclick="socialLogin('google')">
                            <i class="fab fa-google"></i>
                            Google
                        </button>
                        <button class="btn btn-social btn-yandex" onclick="socialLogin('yandex')">
                            <i class="fas fa-y"></i>
                            Yandex
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Auth Benefits -->
        <div class="auth-benefits">
            <h3>Преимущества регистрации</h3>
            <div class="benefits-grid">
                <div class="benefit-item">
                    <div class="benefit-icon">
                        <i class="fas fa-heart"></i>
                    </div>
                    <h4>Избранное</h4>
                    <p>Сохраняйте любимые фильмы и сериалы</p>
                </div>
                <div class="benefit-item">
                    <div class="benefit-icon">
                        <i class="fas fa-comments"></i>
                    </div>
                    <h4>Комментарии</h4>
                    <p>Обсуждайте фильмы с другими пользователями</p>
                </div>
                <div class="benefit-item">
                    <div class="benefit-icon">
                        <i class="fas fa-star"></i>
                    </div>
                    <h4>Рейтинги</h4>
                    <p>Оценивайте просмотренные фильмы</p>
                </div>
                <div class="benefit-item">
                    <div class="benefit-icon">
                        <i class="fas fa-bell"></i>
                    </div>
                    <h4>Уведомления</h4>
                    <p>Получайте уведомления о новинках</p>
                </div>
            </div>
        </div>
    </div>
</section>

<style>
.auth-page {
    background: linear-gradient(135deg, #0a0a0a 0%, #1a1a1a 100%);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
}

.auth-container {
    background: #1a1a1a;
    border-radius: 20px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
    max-width: 900px;
    width: 100%;
    overflow: hidden;
}

/* Auth Tabs */
.auth-tabs {
    display: flex;
    background: rgba(255, 255, 255, 0.05);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.auth-tab-btn {
    flex: 1;
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    padding: 1.5rem;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 1.1rem;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.8rem;
    border-bottom: 3px solid transparent;
}

.auth-tab-btn:hover {
    color: white;
    background: rgba(255, 255, 255, 0.1);
}

.auth-tab-btn.active {
    color: #ff6b35;
    border-bottom-color: #ff6b35;
    background: rgba(255, 107, 53, 0.1);
}

/* Auth Forms */
.auth-forms {
    padding: 3rem;
}

.auth-form {
    display: none;
}

.auth-form.active {
    display: block;
}

.form-header {
    text-align: center;
    margin-bottom: 2.5rem;
}

.form-header h2 {
    color: white;
    font-size: 2rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
}

.form-header p {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
}

/* Form Groups */
.form-group {
    margin-bottom: 1.5rem;
}

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
}

.form-label {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    color: rgba(255, 255, 255, 0.9);
    font-weight: 500;
    margin-bottom: 0.8rem;
    font-size: 0.95rem;
}

.form-label i {
    color: #ff6b35;
    width: 20px;
}

.form-input {
    width: 100%;
    padding: 1rem 1.2rem;
    background: rgba(255, 255, 255, 0.1);
    border: 2px solid rgba(255, 255, 255, 0.2);
    border-radius: 12px;
    color: white;
    font-size: 1rem;
    transition: all 0.3s ease;
    box-sizing: border-box;
}

.form-input:focus {
    outline: none;
    border-color: #ff6b35;
    background: rgba(255, 255, 255, 0.15);
}

.form-input::placeholder {
    color: rgba(255, 255, 255, 0.5);
}

/* Password Input */
.password-input-wrapper {
    position: relative;
}

.password-toggle {
    position: absolute;
    right: 1rem;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    padding: 0.5rem;
    border-radius: 6px;
    transition: all 0.3s ease;
}

.password-toggle:hover {
    color: white;
    background: rgba(255, 255, 255, 0.1);
}

/* Form Options */
.form-options {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    flex-wrap: wrap;
    gap: 1rem;
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

.terms-link {
    color: #ff6b35;
    text-decoration: none;
}

.terms-link:hover {
    color: #ff8c42;
    text-decoration: underline;
}

.forgot-password {
    color: #ff6b35;
    text-decoration: none;
    font-size: 0.9rem;
}

.forgot-password:hover {
    color: #ff8c42;
    text-decoration: underline;
}

/* Buttons */
.btn-full {
    width: 100%;
    padding: 1.2rem;
    font-size: 1.1rem;
    font-weight: 600;
}

/* Social Login */
.social-login {
    margin-top: 2.5rem;
    text-align: center;
}

.social-login-text {
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 1.5rem;
    font-size: 0.9rem;
}

.social-buttons {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
}

.btn-social {
    padding: 0.8rem 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.2);
    background: rgba(255, 255, 255, 0.1);
    color: white;
    font-weight: 500;
    transition: all 0.3s ease;
    min-width: 120px;
}

.btn-social:hover {
    background: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.3);
    transform: translateY(-2px);
}

.btn-vk:hover {
    background: #4a76a8;
    border-color: #4a76a8;
}

.btn-google:hover {
    background: #db4437;
    border-color: #db4437;
}

.btn-yandex:hover {
    background: #ff0000;
    border-color: #ff0000;
}

/* Captcha */
.captcha-wrapper {
    display: flex;
    gap: 1rem;
    align-items: center;
}

.captcha-image {
    height: 50px;
    border-radius: 8px;
    cursor: pointer;
    border: 1px solid rgba(255, 255, 255, 0.2);
}

.captcha-refresh {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    padding: 0.8rem;
    border-radius: 8px;
    transition: all 0.3s ease;
}

.captcha-refresh:hover {
    color: white;
    background: rgba(255, 255, 255, 0.1);
}

/* Auth Benefits */
.auth-benefits {
    background: rgba(255, 255, 255, 0.05);
    padding: 2.5rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.auth-benefits h3 {
    color: #ff6b35;
    text-align: center;
    margin-bottom: 2rem;
    font-size: 1.5rem;
}

.benefits-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 2rem;
}

.benefit-item {
    text-align: center;
    padding: 1.5rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: all 0.3s ease;
}

.benefit-item:hover {
    background: rgba(255, 255, 255, 0.08);
    border-color: rgba(255, 107, 53, 0.3);
    transform: translateY(-5px);
}

.benefit-icon {
    width: 60px;
    height: 60px;
    background: rgba(255, 107, 53, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1rem;
}

.benefit-icon i {
    font-size: 1.5rem;
    color: #ff6b35;
}

.benefit-item h4 {
    color: white;
    margin-bottom: 0.8rem;
    font-size: 1.1rem;
}

.benefit-item p {
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
    font-size: 0.9rem;
    line-height: 1.5;
}

/* Responsive Design */
@media (max-width: 768px) {
    .auth-page {
        padding: 1rem;
    }
    
    .auth-forms {
        padding: 2rem;
    }
    
    .form-row {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
    
    .form-options {
        flex-direction: column;
        align-items: stretch;
        text-align: center;
    }
    
    .social-buttons {
        flex-direction: column;
        align-items: center;
    }
    
    .btn-social {
        width: 100%;
        max-width: 250px;
    }
    
    .benefits-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .auth-tabs {
        flex-direction: column;
    }
    
    .auth-tab-btn {
        padding: 1rem;
    }
}

@media (max-width: 480px) {
    .auth-container {
        border-radius: 16px;
    }
    
    .auth-forms {
        padding: 1.5rem;
    }
    
    .form-header h2 {
        font-size: 1.5rem;
    }
    
    .form-input {
        padding: 0.8rem 1rem;
        font-size: 0.9rem;
    }
    
    .btn-full {
        padding: 1rem;
        font-size: 1rem;
    }
    
    .auth-benefits {
        padding: 1.5rem;
    }
    
    .benefit-item {
        padding: 1rem;
    }
    
    .benefit-icon {
        width: 50px;
        height: 50px;
    }
    
    .benefit-icon i {
        font-size: 1.2rem;
    }
}
</style>

<script>
// Auth tab functionality
document.querySelectorAll('.auth-tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        // Remove active class from all tabs and forms
        document.querySelectorAll('.auth-tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.auth-form').forEach(f => f.classList.remove('active'));
        
        // Add active class to clicked tab
        this.classList.add('active');
        
        // Show corresponding form
        const tabId = this.dataset.tab;
        document.getElementById(tabId).classList.add('active');
    });
});

// Password toggle functionality
function togglePassword(inputId) {
    const input = document.getElementById(inputId);
    const button = input.nextElementSibling;
    const icon = button.querySelector('i');
    
    if (input.type === 'password') {
        input.type = 'text';
        icon.className = 'fas fa-eye-slash';
    } else {
        input.type = 'password';
        icon.className = 'fas fa-eye';
    }
}

// Captcha refresh functionality
function refreshCaptcha() {
    const captchaImg = document.querySelector('.captcha-image');
    if (captchaImg) {
        const currentSrc = captchaImg.src;
        const separator = currentSrc.includes('?') ? '&' : '?';
        captchaImg.src = currentSrc + separator + 'refresh=' + Date.now();
    }
}

// Social login functionality
function socialLogin(provider) {
    // Implement social login functionality
    console.log('Social login with:', provider);
    alert(`Вход через ${provider} будет добавлен позже`);
}

// Form validation and submission
document.addEventListener('DOMContentLoaded', function() {
    // Login form validation
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', function(e) {
            const username = document.getElementById('loginUsername').value.trim();
            const password = document.getElementById('loginPassword').value.trim();
            
            if (!username || !password) {
                e.preventDefault();
                alert('Пожалуйста, заполните все поля');
                return false;
            }
            
            // Show loading state
            const submitBtn = this.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerHTML;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Вход...';
            submitBtn.disabled = true;
        });
    }
    
    // Register form validation
    const registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', function(e) {
            const username = document.getElementById('registerUsername').value.trim();
            const email = document.getElementById('registerEmail').value.trim();
            const password = document.getElementById('registerPassword').value;
            const passwordConfirm = document.getElementById('registerPasswordConfirm').value;
            const captcha = document.getElementById('registerCaptcha').value.trim();
            const agreeTerms = document.getElementById('agreeTerms').checked;
            
            if (!username || !email || !password || !passwordConfirm || !captcha) {
                e.preventDefault();
                alert('Пожалуйста, заполните все обязательные поля');
                return false;
            }
            
            if (password !== passwordConfirm) {
                e.preventDefault();
                alert('Пароли не совпадают');
                return false;
            }
            
            if (password.length < 6) {
                e.preventDefault();
                alert('Пароль должен содержать минимум 6 символов');
                return false;
            }
            
            if (!agreeTerms) {
                e.preventDefault();
                alert('Необходимо согласиться с условиями использования');
                return false;
            }
            
            // Show loading state
            const submitBtn = this.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerHTML;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Регистрация...';
            submitBtn.disabled = true;
        });
    }
    
    // Add animation for form elements
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
    
    // Observe form elements
    document.querySelectorAll('.form-group, .benefit-item').forEach(el => {
        observer.observe(el);
    });
    
    // Initialize first tab as active
    const firstTab = document.querySelector('.auth-tab-btn');
    const firstForm = document.querySelector('.auth-form');
    if (firstTab && firstForm) {
        firstTab.classList.add('active');
        firstForm.classList.add('active');
    }
});

// Password strength indicator (optional enhancement)
function checkPasswordStrength(password) {
    let strength = 0;
    if (password.length >= 8) strength++;
    if (/[a-z]/.test(password)) strength++;
    if (/[A-Z]/.test(password)) strength++;
    if (/[0-9]/.test(password)) strength++;
    if (/[^A-Za-z0-9]/.test(password)) strength++;
    
    return strength;
}
</script>