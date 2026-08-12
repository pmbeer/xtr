-- Wink Clone — Full Database Schema
SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(190) NULL UNIQUE,
  phone VARCHAR(20) NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user','admin') NOT NULL DEFAULT 'user',
  subscription_status ENUM('none','active','expired') NOT NULL DEFAULT 'none',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS genres (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  type ENUM('movie','series') NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  year SMALLINT UNSIGNED NULL,
  country VARCHAR(100) NULL,
  genre_id INT UNSIGNED NULL,
  rating DECIMAL(3,1) NULL DEFAULT 0,
  duration_minutes SMALLINT UNSIGNED NULL,
  age_rating VARCHAR(10) NULL DEFAULT '16+',
  kinopoisk_rating DECIMAL(3,1) NULL,
  imdb_rating DECIMAL(3,1) NULL,
  tags VARCHAR(255) NULL,
  is_featured TINYINT(1) NOT NULL DEFAULT 0,
  is_original TINYINT(1) NOT NULL DEFAULT 0,
  is_kids TINYINT(1) NOT NULL DEFAULT 0,
  is_paid TINYINT(1) NOT NULL DEFAULT 0,
  poster_url VARCHAR(512) NULL,
  backdrop_url VARCHAR(512) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NULL,
  INDEX idx_type(type),
  INDEX idx_genre(genre_id),
  CONSTRAINT fk_content_genre FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_sources (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  quality SMALLINT UNSIGNED NOT NULL,
  url VARCHAR(512) NOT NULL,
  mime VARCHAR(100) NOT NULL,
  CONSTRAINT fk_src_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_images (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  url VARCHAR(512) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_img_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_cast (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(100) NULL,
  photo_url VARCHAR(512) NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_cast_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS seasons (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  season_number INT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  CONSTRAINT fk_season_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS episodes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  season_id INT UNSIGNED NOT NULL,
  episode_number INT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  duration INT UNSIGNED NULL,
  is_paid TINYINT(1) NOT NULL DEFAULT 0,
  video_url VARCHAR(512) NULL,
  CONSTRAINT fk_episode_season FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS banners (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  subtitle VARCHAR(512) NULL,
  image_url VARCHAR(512) NOT NULL,
  link_url VARCHAR(255) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tv_channels (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  logo_url VARCHAR(512) NULL,
  channel_number VARCHAR(10) NULL,
  current_program VARCHAR(255) NULL,
  program_end TIME NULL,
  stream_url VARCHAR(512) NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS watch_progress (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  content_id INT UNSIGNED NOT NULL,
  progress_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_content (user_id, content_id),
  CONSTRAINT fk_wp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wp_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS view_history (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  content_id INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user(user_id),
  CONSTRAINT fk_history_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_history_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wishlist (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  content_id INT UNSIGNED NOT NULL,
  UNIQUE KEY uniq_user_content (user_id, content_id),
  CONSTRAINT fk_wishlist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wishlist_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS subscription_plans (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT NULL,
  price DECIMAL(10,2) NOT NULL,
  period_days INT UNSIGNED NOT NULL,
  tv_channels INT UNSIGNED DEFAULT 241,
  titles_count INT UNSIGNED DEFAULT 50000,
  trial_days INT UNSIGNED DEFAULT 7,
  badge VARCHAR(100) NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS subscriptions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  plan_id INT UNSIGNED NOT NULL,
  started_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  status ENUM('active','expired','cancelled') NOT NULL DEFAULT 'active',
  CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_plan FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed
INSERT INTO genres (id, name) VALUES
(1,'Драма'),(2,'Комедия'),(3,'Фантастика'),(4,'Боевик'),(5,'Семейный'),(6,'Триллер')
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO subscription_plans (name, description, price, period_days, tv_channels, titles_count, trial_days, badge, sort_order) VALUES
('Wink Всё в одном', 'ТВ-каналы, фильмы и сериалы в одной подписке', 399.00, 30, 241, 50000, 7, '7 дней бесплатно', 1),
('Wink Всё в одном + START', 'Расширенная подписка с START и AMEDIATEKA', 799.00, 30, 251, 55000, 3, '3 дня бесплатно', 2),
('Премиум', 'Максимальный каталог и 4K', 1800.00, 30, 299, 80000, 0, NULL, 3),
('Всё в одном на год', 'Годовая подписка со скидкой', 2399.00, 365, 241, 50000, 0, '6 месяцев в подарок', 4);

-- admin@example.com / admin123
INSERT INTO users (name, email, phone, password_hash, role, subscription_status, created_at) VALUES
('Admin', 'admin@example.com', '+79001234567', '$2y$10$gSh0Vsg8kqC0pP6y0mOuee2xG7p26r1bA7S2IFywmxA1sAXVq5J26', 'admin', 'active', NOW());

INSERT INTO content (type, title, description, year, country, genre_id, rating, duration_minutes, age_rating, kinopoisk_rating, imdb_rating, is_featured, is_original, is_kids, is_paid, poster_url, backdrop_url) VALUES
('movie','Дюна: Часть вторая','Пол Атрейдес объединяется с фрименами.',2024,'США',3,8.7,166,'16+',8.2,8.4,1,0,0,0,'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400&q=80','https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1920&q=80'),
('series','Ландыши','Романтическая драма о любви и предательстве.',2025,'Россия',1,9.4,0,'16+',8.8,8.5,1,1,0,1,'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400&q=80','https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=1920&q=80'),
('series','Слово пацана. Кровь на асфальте','Культовый сериал о бандитских разборках 80-х.',2023,'Россия',1,8.9,0,'18+',8.7,8.6,1,1,0,1,'https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=400&q=80','https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=1920&q=80'),
('movie','Буратино','Новая экранизация сказки.',2026,'Россия',5,8.6,102,'6+',7.8,7.5,1,0,1,0,'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=400&q=80','https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=1920&q=80'),
('series','Отмороженные','Криминальная комедия о бывших заключённых.',2024,'Россия',2,8.3,0,'18+',8.0,7.9,1,1,0,1,'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=400&q=80','https://images.unsplash.com/photo-1485846234645-a62644f84728?w=1920&q=80'),
('movie','Холод','Психологический триллер.',2025,'Россия',6,7.8,118,'18+',7.2,7.0,0,0,0,0,'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=400&q=80',NULL),
('series','Фишер','Детектив о следователе особого назначения.',2023,'Россия',6,8.5,0,'16+',8.3,8.1,0,1,0,1,'https://images.unsplash.com/photo-1509281373149-e957c6296403?w=400&q=80',NULL),
('movie','Оппенгеймер','Биографическая драма Кристофера Нолана.',2023,'США',1,8.9,180,'18+',8.4,8.6,0,0,0,0,'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=400&q=80',NULL);

INSERT INTO content_sources (content_id, quality, url, mime) VALUES
(1,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL'),
(2,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL'),
(3,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL'),
(4,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL');

INSERT INTO content_cast (content_id, name, role, sort_order) VALUES
(1,'Тимоти Шаламе','Актёр',1),(1,'Зендея','Актриса',2),(1,'Дени Вильнёв','Режиссёр',3),
(2,'Александра Бортич','Актриса',1),(3,'Юра Борисов','Актёр',1);

INSERT INTO seasons (content_id, season_number, title) VALUES (2,1,'Такая нежная любовь'),(2,2,'Вторая весна'),(3,1,'Сезон 1');

INSERT INTO episodes (season_id, episode_number, title, duration, is_paid) VALUES
(1,1,'Серия 1',2800,1),(1,2,'Серия 2',2800,1),(1,3,'Серия 3',2800,1),
(3,1,'Серия 1',3200,1),(3,2,'Серия 2',3200,1);

INSERT INTO banners (title, subtitle, image_url, link_url, sort_order) VALUES
('Любовь Аксёнова в криминальной драме о графе Монте-Кристо нашего времени','Смотрите в подписке','https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=1920&q=80','/media/2',1),
('Дюна: Часть вторая','Эпическое продолжение в 4K','https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1920&q=80','/media/1',2),
('Слово пацана','Культовый сериал на Wink','https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=1920&q=80','/media/3',3);

INSERT INTO tv_channels (name, logo_url, channel_number, current_program, program_end, sort_order) VALUES
('Первый канал',NULL,'001','Большая игра','18:00:00',1),
('Россия 1',NULL,'002','Вечер с Владимиром Соловьёвым','23:00:00',2),
('НТВ',NULL,'003','Сегодня',NULL,3),
('СТС',NULL,'004','Молодёжка',NULL,4),
('ТНТ',NULL,'005','Танцы',NULL,5),
('Матч ТВ',NULL,'006','Футбол. Лига чемпионов',NULL,6),
('Карусель',NULL,'007','Смешарики',NULL,7),
('2x2',NULL,'008','Симпсоны',NULL,8);

INSERT INTO watch_progress (user_id, content_id, progress_pct) VALUES (1, 2, 45), (1, 3, 72);
