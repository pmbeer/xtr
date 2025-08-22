-- MySQL schema for Wink Clone
SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
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
  is_featured TINYINT(1) NOT NULL DEFAULT 0,
  is_kids TINYINT(1) NOT NULL DEFAULT 0,
  is_paid TINYINT(1) NOT NULL DEFAULT 0,
  poster_url VARCHAR(255) NULL,
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
  url VARCHAR(255) NOT NULL,
  mime VARCHAR(100) NOT NULL,
  CONSTRAINT fk_src_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_images (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  url VARCHAR(255) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_img_content FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_cast (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id INT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(100) NULL,
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
  CONSTRAINT fk_episode_season FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS banners (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  image_url VARCHAR(255) NOT NULL,
  link_url VARCHAR(255) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tv_channels (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  logo_url VARCHAR(255) NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS view_history (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  content_id INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user(user_id),
  INDEX idx_content(content_id),
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
  price DECIMAL(10,2) NOT NULL,
  period_days INT UNSIGNED NOT NULL,
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

-- Seed data
INSERT INTO genres (name) VALUES ('Драма'),('Комедия'),('Фантастика'),('Мультфильм') ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO subscription_plans (name, price, period_days, sort_order, is_active) VALUES
 ('Месяц', 399.00, 30, 1, 1),
 ('Год', 2990.00, 365, 2, 1)
ON DUPLICATE KEY UPDATE name=VALUES(name), price=VALUES(price), period_days=VALUES(period_days), sort_order=VALUES(sort_order), is_active=VALUES(is_active);

INSERT INTO users (name, email, password_hash, role, subscription_status, created_at)
VALUES ('Admin', 'admin@example.com', '$2y$10$gSh0Vsg8kqC0pP6y0mOuee2xG7p26r1bA7S2IFywmxA1sAXVq5J26', 'admin', 'active', NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO content (type,title,description,year,country,genre_id,is_featured,is_kids,is_paid,poster_url,created_at)
VALUES
('movie','Демо фильм','Описание демо фильма',2023,'Россия',1,1,0,0,'https://via.placeholder.com/300x450?text=Movie',NOW()),
('series','Демо сериал','Описание демо сериала',2022,'США',2,1,0,1,'https://via.placeholder.com/300x450?text=Series',NOW());

INSERT INTO content_sources (content_id,quality,url,mime) VALUES
(1,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL'),
(1,720,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL'),
(2,1080,'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8','application/x-mpegURL');

INSERT INTO content_images (content_id,url,sort_order) VALUES
(1,'https://via.placeholder.com/800x450?text=Shot+1',1),
(1,'https://via.placeholder.com/800x450?text=Shot+2',2);

INSERT INTO content_cast (content_id,name,role,sort_order) VALUES
(1,'Иван Иванов','Актер',1),
(1,'Петр Петров','Режиссер',2);

INSERT INTO seasons (content_id,season_number,title) VALUES
(2,1,'Сезон 1');

INSERT INTO episodes (season_id,episode_number,title,duration,is_paid) VALUES
(1,1,'Серия 1',2800,1),
(1,2,'Серия 2',2800,1);

INSERT INTO banners (title,image_url,link_url,sort_order,is_active) VALUES
('Большая премьера','https://via.placeholder.com/1240x360?text=Banner','/media/1',1,1);

INSERT INTO tv_channels (name,logo_url,sort_order,is_active) VALUES
('Первый','https://via.placeholder.com/300x120?text=1TV',1,1),
('Россия 1','https://via.placeholder.com/300x120?text=R1',2,1);