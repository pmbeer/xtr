<section class="player-page">
    <!-- Player Container -->
    <div class="player-container">
        <!-- Video Player -->
        <div class="video-player-wrapper">
            <div class="video-player" id="videoPlayer">
                <!-- Player Controls Overlay -->
                <div class="player-overlay" id="playerOverlay">
                    <div class="player-loading" id="playerLoading">
                        <div class="loading-spinner"></div>
                        <span>Загрузка...</span>
                    </div>
                    
                    <!-- Big Play Button -->
                    <button class="big-play-btn" id="bigPlayBtn" onclick="togglePlay()">
                        <i class="fas fa-play"></i>
                    </button>
                    
                    <!-- Player Controls -->
                    <div class="player-controls" id="playerControls">
                        <!-- Progress Bar -->
                        <div class="progress-container">
                            <div class="progress-bar" id="progressBar">
                                <div class="progress-filled" id="progressFilled"></div>
                                <div class="progress-handle" id="progressHandle"></div>
                            </div>
                            <div class="time-display">
                                <span id="currentTime">00:00</span>
                                <span class="time-separator">/</span>
                                <span id="totalTime">00:00</span>
                            </div>
                        </div>
                        
                        <!-- Control Buttons -->
                        <div class="controls-row">
                            <div class="controls-left">
                                <button class="control-btn play-pause-btn" id="playPauseBtn" onclick="togglePlay()">
                                    <i class="fas fa-play"></i>
                                </button>
                                <button class="control-btn" onclick="rewind()">
                                    <i class="fas fa-backward"></i>
                                </button>
                                <button class="control-btn" onclick="forward()">
                                    <i class="fas fa-forward"></i>
                                </button>
                                <div class="volume-control">
                                    <button class="control-btn volume-btn" onclick="toggleMute()">
                                        <i class="fas fa-volume-up" id="volumeIcon"></i>
                                    </button>
                                    <div class="volume-slider">
                                        <input type="range" min="0" max="100" value="50" class="volume-range" id="volumeRange">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="controls-right">
                                <div class="quality-selector">
                                    <button class="control-btn quality-btn" onclick="toggleQualityMenu()">
                                        <span id="currentQuality">720p</span>
                                        <i class="fas fa-chevron-up"></i>
                                    </button>
                                    <div class="quality-menu" id="qualityMenu">
                                        <div class="quality-option active" data-quality="1080p">1080p HD</div>
                                        <div class="quality-option" data-quality="720p">720p</div>
                                        <div class="quality-option" data-quality="480p">480p</div>
                                        <div class="quality-option" data-quality="360p">360p</div>
                                    </div>
                                </div>
                                <button class="control-btn speed-btn" onclick="toggleSpeedMenu()">
                                    <span id="currentSpeed">1x</span>
                                </button>
                                <div class="speed-menu" id="speedMenu">
                                    <div class="speed-option" data-speed="0.5">0.5x</div>
                                    <div class="speed-option" data-speed="0.75">0.75x</div>
                                    <div class="speed-option active" data-speed="1">1x</div>
                                    <div class="speed-option" data-speed="1.25">1.25x</div>
                                    <div class="speed-option" data-speed="1.5">1.5x</div>
                                    <div class="speed-option" data-speed="2">2x</div>
                                </div>
                                <button class="control-btn subtitles-btn" onclick="toggleSubtitles()">
                                    <i class="fas fa-closed-captioning"></i>
                                </button>
                                <button class="control-btn pip-btn" onclick="togglePictureInPicture()">
                                    <i class="fas fa-external-link-alt"></i>
                                </button>
                                <button class="control-btn fullscreen-btn" onclick="toggleFullscreen()">
                                    <i class="fas fa-expand"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Video Element -->
                <video id="videoElement" preload="metadata" poster="{poster-url}">
                    <source src="{video-url-1080p}" type="video/mp4" data-quality="1080p">
                    <source src="{video-url-720p}" type="video/mp4" data-quality="720p">
                    <source src="{video-url-480p}" type="video/mp4" data-quality="480p">
                    <track kind="subtitles" src="{subtitles-ru}" srclang="ru" label="Русский">
                    <track kind="subtitles" src="{subtitles-en}" srclang="en" label="English">
                </video>
            </div>
        </div>
        
        <!-- Player Info -->
        <div class="player-info">
            <div class="movie-details">
                <h1 class="movie-title">{title}</h1>
                <div class="movie-meta">
                    <span class="rating">
                        <i class="fas fa-star"></i>
                        {rating}
                    </span>
                    <span class="year">{year}</span>
                    <span class="duration">{duration}</span>
                    <span class="quality-badge">HD</span>
                </div>
                <div class="movie-description">
                    {short-story}
                </div>
            </div>
            
            <!-- Player Actions -->
            <div class="player-actions">
                <button class="action-btn favorite-btn" onclick="toggleFavorite()">
                    <i class="fas fa-heart"></i>
                    <span>В избранное</span>
                </button>
                <button class="action-btn share-btn" onclick="shareMovie()">
                    <i class="fas fa-share"></i>
                    <span>Поделиться</span>
                </button>
                <button class="action-btn report-btn" onclick="reportIssue()">
                    <i class="fas fa-exclamation-triangle"></i>
                    <span>Сообщить о проблеме</span>
                </button>
            </div>
        </div>
    </div>
    
    <!-- Series Episodes (if applicable) -->
    {if series}
    <div class="episodes-section">
        <div class="container">
            <h2>Эпизоды</h2>
            <div class="seasons-tabs">
                <button class="season-tab active" data-season="1">Сезон 1</button>
                <button class="season-tab" data-season="2">Сезон 2</button>
                <button class="season-tab" data-season="3">Сезон 3</button>
            </div>
            <div class="episodes-grid">
                <!-- Episodes will be loaded dynamically -->
            </div>
        </div>
    </div>
    {/if}
    
    <!-- Related Content -->
    <div class="related-section">
        <div class="container">
            <h2>Похожие фильмы</h2>
            <div class="related-grid">
                {custom category="related" template="shortstory" limit="6" cache="no"}
            </div>
        </div>
    </div>
</section>

<style>
.player-page {
    background: #000;
    min-height: 100vh;
    color: white;
}

/* Player Container */
.player-container {
    position: relative;
    width: 100%;
    max-width: 1200px;
    margin: 0 auto;
}

/* Video Player */
.video-player-wrapper {
    position: relative;
    width: 100%;
    aspect-ratio: 16/9;
    background: #000;
    border-radius: 0;
    overflow: hidden;
}

.video-player {
    position: relative;
    width: 100%;
    height: 100%;
    cursor: pointer;
}

#videoElement {
    width: 100%;
    height: 100%;
    object-fit: contain;
}

/* Player Overlay */
.player-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(to bottom, 
        rgba(0, 0, 0, 0.3) 0%, 
        transparent 20%, 
        transparent 80%, 
        rgba(0, 0, 0, 0.8) 100%);
    opacity: 1;
    transition: opacity 0.3s ease;
    pointer-events: none;
}

.video-player:hover .player-overlay {
    opacity: 1;
}

.player-overlay > * {
    pointer-events: auto;
}

/* Loading Spinner */
.player-loading {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    color: white;
}

.loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255, 255, 255, 0.3);
    border-radius: 50%;
    border-top-color: #ff6b35;
    animation: spin 1s ease-in-out infinite;
}

@keyframes spin {
    to { transform: rotate(360deg); }
}

/* Big Play Button */
.big-play-btn {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 80px;
    height: 80px;
    background: rgba(255, 107, 53, 0.9);
    border: none;
    border-radius: 50%;
    color: white;
    font-size: 2rem;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
}

.big-play-btn:hover {
    background: #ff6b35;
    transform: translate(-50%, -50%) scale(1.1);
}

.big-play-btn i {
    margin-left: 4px;
}

/* Player Controls */
.player-controls {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 1rem;
    background: linear-gradient(to top, rgba(0, 0, 0, 0.8), transparent);
}

/* Progress Bar */
.progress-container {
    margin-bottom: 1rem;
}

.progress-bar {
    position: relative;
    height: 6px;
    background: rgba(255, 255, 255, 0.3);
    border-radius: 3px;
    cursor: pointer;
    margin-bottom: 0.5rem;
}

.progress-filled {
    height: 100%;
    background: #ff6b35;
    border-radius: 3px;
    width: 0%;
    transition: width 0.1s ease;
}

.progress-handle {
    position: absolute;
    top: 50%;
    left: 0%;
    width: 14px;
    height: 14px;
    background: #ff6b35;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    opacity: 0;
    transition: opacity 0.3s ease;
}

.progress-bar:hover .progress-handle {
    opacity: 1;
}

.time-display {
    display: flex;
    justify-content: space-between;
    font-size: 0.9rem;
    color: rgba(255, 255, 255, 0.9);
}

/* Controls Row */
.controls-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.controls-left,
.controls-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.control-btn {
    background: none;
    border: none;
    color: white;
    padding: 0.5rem;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 1rem;
}

.control-btn:hover {
    background: rgba(255, 255, 255, 0.2);
}

/* Volume Control */
.volume-control {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.volume-slider {
    width: 80px;
    opacity: 0;
    transition: opacity 0.3s ease;
}

.volume-control:hover .volume-slider {
    opacity: 1;
}

.volume-range {
    width: 100%;
    height: 4px;
    background: rgba(255, 255, 255, 0.3);
    border-radius: 2px;
    outline: none;
    appearance: none;
}

.volume-range::-webkit-slider-thumb {
    appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #ff6b35;
    cursor: pointer;
}

/* Quality & Speed Selectors */
.quality-selector {
    position: relative;
}

.quality-btn,
.speed-btn {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.9rem;
}

.quality-menu,
.speed-menu {
    position: absolute;
    bottom: 100%;
    right: 0;
    background: rgba(0, 0, 0, 0.9);
    border-radius: 6px;
    padding: 0.5rem 0;
    min-width: 100px;
    margin-bottom: 0.5rem;
    display: none;
    z-index: 1000;
}

.quality-menu.show,
.speed-menu.show {
    display: block;
}

.quality-option,
.speed-option {
    padding: 0.5rem 1rem;
    cursor: pointer;
    transition: background 0.3s ease;
    font-size: 0.9rem;
}

.quality-option:hover,
.speed-option:hover {
    background: rgba(255, 255, 255, 0.1);
}

.quality-option.active,
.speed-option.active {
    color: #ff6b35;
    background: rgba(255, 107, 53, 0.2);
}

/* Player Info */
.player-info {
    padding: 2rem;
    background: #0a0a0a;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 2rem;
}

.movie-details {
    flex: 1;
}

.movie-title {
    font-size: 2rem;
    font-weight: 700;
    margin-bottom: 1rem;
    color: white;
}

.movie-meta {
    display: flex;
    gap: 1.5rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
}

.movie-meta span {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.9rem;
}

.rating {
    color: #ff6b35 !important;
}

.quality-badge {
    background: #ff6b35;
    color: white;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: 600;
}

.movie-description {
    color: rgba(255, 255, 255, 0.8);
    line-height: 1.6;
    max-width: 600px;
}

/* Player Actions */
.player-actions {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.action-btn {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    padding: 0.8rem 1.5rem;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
    text-decoration: none;
    font-size: 0.9rem;
    min-width: 160px;
}

.action-btn:hover {
    background: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.3);
}

.favorite-btn:hover {
    background: rgba(255, 107, 53, 0.2);
    border-color: #ff6b35;
}

/* Episodes Section */
.episodes-section {
    padding: 3rem 2rem;
    background: #0a0a0a;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

.episodes-section h2 {
    color: #ff6b35;
    margin-bottom: 2rem;
    font-size: 1.8rem;
}

.seasons-tabs {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
}

.season-tab {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    padding: 0.8rem 1.5rem;
    border-radius: 25px;
    cursor: pointer;
    transition: all 0.3s ease;
}

.season-tab:hover {
    background: rgba(255, 255, 255, 0.2);
}

.season-tab.active {
    background: #ff6b35;
    border-color: #ff6b35;
}

.episodes-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1.5rem;
}

/* Related Section */
.related-section {
    padding: 3rem 2rem;
    background: #0a0a0a;
}

.related-section h2 {
    color: #ff6b35;
    margin-bottom: 2rem;
    font-size: 1.8rem;
}

.related-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 2rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    .player-info {
        flex-direction: column;
        padding: 1.5rem;
    }
    
    .player-actions {
        flex-direction: row;
        flex-wrap: wrap;
    }
    
    .action-btn {
        flex: 1;
        min-width: auto;
        justify-content: center;
    }
    
    .movie-title {
        font-size: 1.5rem;
    }
    
    .movie-meta {
        gap: 1rem;
    }
    
    .controls-row {
        flex-wrap: wrap;
        gap: 0.5rem;
    }
    
    .episodes-section,
    .related-section {
        padding: 2rem 1rem;
    }
    
    .related-grid {
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 1rem;
    }
}

@media (max-width: 480px) {
    .big-play-btn {
        width: 60px;
        height: 60px;
        font-size: 1.5rem;
    }
    
    .player-controls {
        padding: 0.8rem;
    }
    
    .volume-slider {
        width: 60px;
    }
    
    .movie-meta {
        flex-direction: column;
        gap: 0.5rem;
    }
    
    .seasons-tabs {
        justify-content: center;
    }
    
    .season-tab {
        padding: 0.6rem 1.2rem;
        font-size: 0.9rem;
    }
}

/* Fullscreen Styles */
.video-player.fullscreen {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: 10000;
    background: #000;
}

.video-player.fullscreen .video-player-wrapper {
    border-radius: 0;
}

/* Hidden Controls */
.player-overlay.hidden {
    opacity: 0;
    pointer-events: none;
}

.player-overlay.hidden .big-play-btn,
.player-overlay.hidden .player-controls {
    pointer-events: none;
}
</style>

<script>
// Video Player Controller
class VideoPlayer {
    constructor() {
        this.video = document.getElementById('videoElement');
        this.overlay = document.getElementById('playerOverlay');
        this.loading = document.getElementById('playerLoading');
        this.bigPlayBtn = document.getElementById('bigPlayBtn');
        this.playPauseBtn = document.getElementById('playPauseBtn');
        this.progressBar = document.getElementById('progressBar');
        this.progressFilled = document.getElementById('progressFilled');
        this.currentTime = document.getElementById('currentTime');
        this.totalTime = document.getElementById('totalTime');
        this.volumeRange = document.getElementById('volumeRange');
        this.volumeIcon = document.getElementById('volumeIcon');
        
        this.isPlaying = false;
        this.isMuted = false;
        this.hideTimeout = null;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.hideLoading();
    }
    
    setupEventListeners() {
        // Video events
        this.video.addEventListener('loadedmetadata', () => {
            this.updateDuration();
        });
        
        this.video.addEventListener('timeupdate', () => {
            this.updateProgress();
        });
        
        this.video.addEventListener('play', () => {
            this.isPlaying = true;
            this.updatePlayButton();
        });
        
        this.video.addEventListener('pause', () => {
            this.isPlaying = false;
            this.updatePlayButton();
        });
        
        this.video.addEventListener('ended', () => {
            this.isPlaying = false;
            this.updatePlayButton();
            this.showControls();
        });
        
        // Progress bar
        this.progressBar.addEventListener('click', (e) => {
            this.seek(e);
        });
        
        // Volume
        this.volumeRange.addEventListener('input', () => {
            this.setVolume(this.volumeRange.value / 100);
        });
        
        // Player overlay
        this.overlay.addEventListener('click', (e) => {
            if (e.target === this.overlay) {
                this.togglePlay();
            }
        });
        
        // Mouse movement
        this.overlay.addEventListener('mousemove', () => {
            this.showControls();
            this.autoHideControls();
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            this.handleKeydown(e);
        });
        
        // Quality selector
        document.querySelectorAll('.quality-option').forEach(option => {
            option.addEventListener('click', () => {
                this.changeQuality(option.dataset.quality);
            });
        });
        
        // Speed selector
        document.querySelectorAll('.speed-option').forEach(option => {
            option.addEventListener('click', () => {
                this.changeSpeed(parseFloat(option.dataset.speed));
            });
        });
    }
    
    togglePlay() {
        if (this.isPlaying) {
            this.video.pause();
        } else {
            this.video.play();
        }
    }
    
    updatePlayButton() {
        const icon = this.isPlaying ? 'fas fa-pause' : 'fas fa-play';
        this.bigPlayBtn.querySelector('i').className = icon;
        this.playPauseBtn.querySelector('i').className = icon;
        
        if (this.isPlaying) {
            this.bigPlayBtn.style.display = 'none';
            this.autoHideControls();
        } else {
            this.bigPlayBtn.style.display = 'flex';
            this.showControls();
        }
    }
    
    updateProgress() {
        const progress = (this.video.currentTime / this.video.duration) * 100;
        this.progressFilled.style.width = progress + '%';
        this.currentTime.textContent = this.formatTime(this.video.currentTime);
    }
    
    updateDuration() {
        this.totalTime.textContent = this.formatTime(this.video.duration);
    }
    
    seek(e) {
        const rect = this.progressBar.getBoundingClientRect();
        const pos = (e.clientX - rect.left) / rect.width;
        this.video.currentTime = pos * this.video.duration;
    }
    
    setVolume(volume) {
        this.video.volume = volume;
        this.updateVolumeIcon(volume);
    }
    
    toggleMute() {
        if (this.isMuted) {
            this.video.volume = this.volumeRange.value / 100;
            this.isMuted = false;
        } else {
            this.video.volume = 0;
            this.isMuted = true;
        }
        this.updateVolumeIcon(this.video.volume);
    }
    
    updateVolumeIcon(volume) {
        let icon;
        if (volume === 0) {
            icon = 'fas fa-volume-mute';
        } else if (volume < 0.5) {
            icon = 'fas fa-volume-down';
        } else {
            icon = 'fas fa-volume-up';
        }
        this.volumeIcon.className = icon;
    }
    
    changeQuality(quality) {
        const currentTime = this.video.currentTime;
        const source = this.video.querySelector(`source[data-quality="${quality}"]`);
        
        if (source) {
            this.video.src = source.src;
            this.video.currentTime = currentTime;
            document.getElementById('currentQuality').textContent = quality;
            
            // Update active quality
            document.querySelectorAll('.quality-option').forEach(opt => {
                opt.classList.toggle('active', opt.dataset.quality === quality);
            });
        }
        
        this.hideQualityMenu();
    }
    
    changeSpeed(speed) {
        this.video.playbackRate = speed;
        document.getElementById('currentSpeed').textContent = speed + 'x';
        
        // Update active speed
        document.querySelectorAll('.speed-option').forEach(opt => {
            opt.classList.toggle('active', parseFloat(opt.dataset.speed) === speed);
        });
        
        this.hideSpeedMenu();
    }
    
    showControls() {
        this.overlay.classList.remove('hidden');
    }
    
    hideControls() {
        if (this.isPlaying) {
            this.overlay.classList.add('hidden');
        }
    }
    
    autoHideControls() {
        clearTimeout(this.hideTimeout);
        this.hideTimeout = setTimeout(() => {
            this.hideControls();
        }, 3000);
    }
    
    hideLoading() {
        this.loading.style.display = 'none';
    }
    
    showLoading() {
        this.loading.style.display = 'flex';
    }
    
    formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    
    handleKeydown(e) {
        switch(e.code) {
            case 'Space':
                e.preventDefault();
                this.togglePlay();
                break;
            case 'ArrowLeft':
                e.preventDefault();
                this.video.currentTime = Math.max(0, this.video.currentTime - 10);
                break;
            case 'ArrowRight':
                e.preventDefault();
                this.video.currentTime = Math.min(this.video.duration, this.video.currentTime + 10);
                break;
            case 'ArrowUp':
                e.preventDefault();
                this.setVolume(Math.min(1, this.video.volume + 0.1));
                this.volumeRange.value = this.video.volume * 100;
                break;
            case 'ArrowDown':
                e.preventDefault();
                this.setVolume(Math.max(0, this.video.volume - 0.1));
                this.volumeRange.value = this.video.volume * 100;
                break;
            case 'KeyM':
                e.preventDefault();
                this.toggleMute();
                break;
            case 'KeyF':
                e.preventDefault();
                toggleFullscreen();
                break;
        }
    }
}

// Global functions
function togglePlay() {
    window.player.togglePlay();
}

function rewind() {
    window.player.video.currentTime = Math.max(0, window.player.video.currentTime - 10);
}

function forward() {
    window.player.video.currentTime = Math.min(window.player.video.duration, window.player.video.currentTime + 10);
}

function toggleMute() {
    window.player.toggleMute();
}

function toggleQualityMenu() {
    const menu = document.getElementById('qualityMenu');
    menu.classList.toggle('show');
}

function toggleSpeedMenu() {
    const menu = document.getElementById('speedMenu');
    menu.classList.toggle('show');
}

function toggleSubtitles() {
    const tracks = window.player.video.textTracks;
    for (let track of tracks) {
        track.mode = track.mode === 'showing' ? 'hidden' : 'showing';
    }
}

function togglePictureInPicture() {
    if (document.pictureInPictureElement) {
        document.exitPictureInPicture();
    } else {
        window.player.video.requestPictureInPicture();
    }
}

function toggleFullscreen() {
    const player = document.querySelector('.video-player');
    
    if (!document.fullscreenElement) {
        player.requestFullscreen().then(() => {
            player.classList.add('fullscreen');
        });
    } else {
        document.exitFullscreen().then(() => {
            player.classList.remove('fullscreen');
        });
    }
}

function toggleFavorite() {
    const btn = document.querySelector('.favorite-btn');
    const icon = btn.querySelector('i');
    
    if (icon.classList.contains('fas')) {
        icon.className = 'far fa-heart';
        btn.style.background = 'rgba(255, 255, 255, 0.1)';
    } else {
        icon.className = 'fas fa-heart';
        btn.style.background = 'rgba(255, 107, 53, 0.2)';
        btn.style.borderColor = '#ff6b35';
    }
}

function shareMovie() {
    if (navigator.share) {
        navigator.share({
            title: document.querySelector('.movie-title').textContent,
            url: window.location.href
        });
    } else {
        navigator.clipboard.writeText(window.location.href);
        alert('Ссылка скопирована в буфер обмена!');
    }
}

function reportIssue() {
    // Implement issue reporting
    alert('Функция сообщения о проблеме будет добавлена позже');
}

// Initialize player
document.addEventListener('DOMContentLoaded', function() {
    window.player = new VideoPlayer();
    
    // Hide menus when clicking outside
    document.addEventListener('click', function(e) {
        if (!e.target.closest('.quality-selector')) {
            document.getElementById('qualityMenu').classList.remove('show');
        }
        if (!e.target.closest('.speed-btn')) {
            document.getElementById('speedMenu').classList.remove('show');
        }
    });
});
</script>