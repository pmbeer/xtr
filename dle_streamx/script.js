/**
 * Wink.ru Style Template - Main JavaScript
 * DLE 16.0 Template
 */

class WinkTemplate {
    constructor() {
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.initializeComponents();
        this.setupAnimations();
    }

    setupEventListeners() {
        // Header scroll effect
        window.addEventListener('scroll', this.handleScroll.bind(this));
        
        // Search functionality
        const searchBtn = document.querySelector('.search-btn');
        if (searchBtn) {
            searchBtn.addEventListener('click', this.showSearchModal.bind(this));
        }

        // Profile functionality
        const profileBtn = document.querySelector('.profile-btn');
        if (profileBtn) {
            profileBtn.addEventListener('click', this.showProfileModal.bind(this));
        }

        // Mobile menu toggle
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        if (mobileMenuBtn) {
            mobileMenuBtn.addEventListener('click', this.toggleMobileMenu.bind(this));
        }

        // Lazy loading for images
        this.setupLazyLoading();

        // Infinite scroll for categories
        this.setupInfiniteScroll();
    }

    initializeComponents() {
        // Initialize tooltips
        this.initTooltips();
        
        // Initialize modals
        this.initModals();
        
        // Initialize notifications
        this.initNotifications();
        
        // Initialize video player placeholders
        this.initVideoPlayers();
    }

    setupAnimations() {
        // Intersection Observer for fade-in animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-in');
                }
            });
        }, observerOptions);

        // Observe all movie cards and sections
        document.querySelectorAll('.movie-card, .details-section, .sidebar-widget').forEach(el => {
            observer.observe(el);
        });
    }

    handleScroll() {
        const header = document.querySelector('.header');
        if (!header) return;

        if (window.scrollY > 100) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }

        // Parallax effect for hero sections
        this.handleParallax();
    }

    handleParallax() {
        const heroSections = document.querySelectorAll('.hero-section, .movie-hero');
        heroSections.forEach(hero => {
            const scrolled = window.pageYOffset;
            const rate = scrolled * -0.5;
            hero.style.transform = `translateY(${rate}px)`;
        });
    }

    showSearchModal() {
        const modal = this.createModal('search', {
            title: 'Поиск фильмов и сериалов',
            content: `
                <div class="search-modal">
                    <div class="search-input-wrapper">
                        <input type="text" class="search-input-large" placeholder="Введите название фильма, сериала или актера..." autofocus>
                        <button class="search-submit-btn">
                            <i class="fas fa-search"></i>
                        </button>
                    </div>
                    <div class="search-suggestions">
                        <h4>Популярные запросы:</h4>
                        <div class="suggestion-tags">
                            <span class="tag">Боевики</span>
                            <span class="tag">Комедии</span>
                            <span class="tag">Драмы</span>
                            <span class="tag">Ужасы</span>
                            <span class="tag">Фантастика</span>
                        </div>
                    </div>
                </div>
            `
        });

        // Focus on search input
        setTimeout(() => {
            const searchInput = modal.querySelector('.search-input-large');
            if (searchInput) searchInput.focus();
        }, 100);

        // Handle search input
        const searchInput = modal.querySelector('.search-input-large');
        if (searchInput) {
            searchInput.addEventListener('input', this.handleSearchInput.bind(this));
        }
    }

    showProfileModal() {
        this.createModal('profile', {
            title: 'Профиль пользователя',
            content: `
                <div class="profile-modal">
                    <div class="profile-avatar">
                        <i class="fas fa-user-circle"></i>
                    </div>
                    <div class="profile-info">
                        <h3>Гость</h3>
                        <p>Войдите в систему для доступа к личному кабинету</p>
                    </div>
                    <div class="profile-actions">
                        <button class="btn btn-primary" onclick="this.login()">Войти</button>
                        <button class="btn btn-secondary" onclick="this.register()">Регистрация</button>
                    </div>
                </div>
            `
        });
    }

    createModal(type, options) {
        // Remove existing modal
        const existingModal = document.querySelector('.modal-overlay');
        if (existingModal) {
            existingModal.remove();
        }

        const modal = document.createElement('div');
        modal.className = 'modal-overlay';
        modal.innerHTML = `
            <div class="modal">
                <div class="modal-header">
                    <h3>${options.title}</h3>
                    <button class="modal-close" onclick="this.closeModal()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    ${options.content}
                </div>
            </div>
        `;

        document.body.appendChild(modal);
        
        // Add close functionality
        modal.querySelector('.modal-close').addEventListener('click', () => {
            this.closeModal();
        });

        // Close on overlay click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                this.closeModal();
            }
        });

        // Show modal with animation
        setTimeout(() => {
            modal.classList.add('show');
        }, 10);

        return modal;
    }

    closeModal() {
        const modal = document.querySelector('.modal-overlay');
        if (modal) {
            modal.classList.remove('show');
            setTimeout(() => {
                modal.remove();
            }, 300);
        }
    }

    handleSearchInput(event) {
        const query = event.target.value.trim();
        if (query.length < 2) return;

        // Simulate search suggestions
        this.showSearchSuggestions(query);
    }

    showSearchSuggestions(query) {
        // This would typically make an AJAX call to your search API
        console.log('Searching for:', query);
        
        // Show loading state
        const suggestions = document.querySelector('.search-suggestions');
        if (suggestions) {
            suggestions.innerHTML = '<div class="loading">Поиск...</div>';
        }
    }

    setupLazyLoading() {
        const imageObserver = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const img = entry.target;
                    img.src = img.dataset.src;
                    img.classList.remove('lazy');
                    observer.unobserve(img);
                }
            });
        });

        document.querySelectorAll('img[data-src]').forEach(img => {
            imageObserver.observe(img);
        });
    }

    setupInfiniteScroll() {
        let isLoading = false;
        let page = 1;

        const loadMoreObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting && !isLoading) {
                    this.loadMoreContent();
                }
            });
        });

        // Observe the last movie card for infinite scroll
        const movieCards = document.querySelectorAll('.movie-card');
        if (movieCards.length > 0) {
            loadMoreObserver.observe(movieCards[movieCards.length - 1]);
        }
    }

    loadMoreContent() {
        // This would typically make an AJAX call to load more content
        console.log('Loading more content...');
        
        // Show loading indicator
        this.showNotification('Загрузка дополнительного контента...', 'info');
    }

    initTooltips() {
        // Initialize tooltips for interactive elements
        document.querySelectorAll('[title]').forEach(element => {
            this.createTooltip(element);
        });
    }

    createTooltip(element) {
        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip';
        tooltip.textContent = element.title;
        
        element.addEventListener('mouseenter', (e) => {
            document.body.appendChild(tooltip);
            const rect = element.getBoundingClientRect();
            tooltip.style.left = rect.left + (rect.width / 2) - (tooltip.offsetWidth / 2) + 'px';
            tooltip.style.top = rect.top - tooltip.offsetHeight - 10 + 'px';
        });

        element.addEventListener('mouseleave', () => {
            if (tooltip.parentNode) {
                tooltip.parentNode.removeChild(tooltip);
            }
        });
    }

    initModals() {
        // Initialize any existing modals on the page
        document.querySelectorAll('[data-modal]').forEach(trigger => {
            trigger.addEventListener('click', (e) => {
                e.preventDefault();
                const modalId = trigger.dataset.modal;
                this.showModal(modalId);
            });
        });
    }

    initNotifications() {
        // Create notification container
        if (!document.querySelector('.notification-container')) {
            const container = document.createElement('div');
            container.className = 'notification-container';
            document.body.appendChild(container);
        }
    }

    showNotification(message, type = 'info', duration = 3000) {
        const container = document.querySelector('.notification-container');
        if (!container) return;

        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <i class="fas fa-${this.getNotificationIcon(type)}"></i>
                <span>${message}</span>
            </div>
            <button class="notification-close" onclick="this.remove()">
                <i class="fas fa-times"></i>
            </button>
        `;

        container.appendChild(notification);

        // Show notification
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);

        // Auto remove
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, duration);
    }

    getNotificationIcon(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    }

    initVideoPlayers() {
        // Initialize video player placeholders
        document.querySelectorAll('.video-player-placeholder').forEach(placeholder => {
            placeholder.addEventListener('click', () => {
                this.initVideoPlayer(placeholder);
            });
        });
    }

    initVideoPlayer(placeholder) {
        // This would typically initialize a video player
        placeholder.innerHTML = `
            <div class="video-player">
                <video controls>
                    <source src="sample-video.mp4" type="video/mp4">
                    Ваш браузер не поддерживает видео.
                </video>
            </div>
        `;
    }

    toggleMobileMenu() {
        const nav = document.querySelector('.nav-main');
        if (nav) {
            nav.classList.toggle('mobile-open');
        }
    }

    // Utility methods
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    throttle(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
}

// Initialize template when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.winkTemplate = new WinkTemplate();
});

// Export for global access
window.WinkTemplate = WinkTemplate;