-- MySQL dump for Wink Clone
-- Compatible with MySQL 8.0+/MariaDB 10.4+
-- Charset: utf8mb4

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `wink_clone` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `wink_clone`;

-- Roles
CREATE TABLE IF NOT EXISTS roles (
	id TINYINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT IGNORE INTO roles (id, name) VALUES (1,'admin'),(2,'editor'),(3,'user');

-- Users
CREATE TABLE IF NOT EXISTS users (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	email VARCHAR(191) NOT NULL UNIQUE,
	password_hash VARCHAR(255) NOT NULL,
	name VARCHAR(120) NOT NULL,
	role_id TINYINT UNSIGNED NOT NULL DEFAULT 3,
	is_active TINYINT(1) NOT NULL DEFAULT 1,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX (role_id),
	CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Auth tokens (password reset)
CREATE TABLE IF NOT EXISTS password_resets (
	id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	user_id INT UNSIGNED NOT NULL,
	token CHAR(64) NOT NULL UNIQUE,
	expires_at DATETIME NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX (user_id),
	CONSTRAINT fk_pw_user FOREIGN KEY (user_id) REFERENCES users(id)
		ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Genres
CREATE TABLE IF NOT EXISTS genres (
	id SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Countries
CREATE TABLE IF NOT EXISTS countries (
	id SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Movies
CREATE TABLE IF NOT EXISTS movies (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	title VARCHAR(255) NOT NULL,
	slug VARCHAR(255) NOT NULL UNIQUE,
	description TEXT,
	release_year SMALLINT UNSIGNED,
	release_date DATE NULL,
	country_id SMALLINT UNSIGNED NULL,
	poster_url VARCHAR(500) NULL,
	backdrop_url VARCHAR(500) NULL,
	trailer_url VARCHAR(500) NULL,
	video_url VARCHAR(500) NULL,
	is_premium TINYINT(1) NOT NULL DEFAULT 0,
	is_featured TINYINT(1) NOT NULL DEFAULT 0,
	views_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
	views_last_7d INT UNSIGNED NOT NULL DEFAULT 0,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX (country_id),
	INDEX (is_featured),
	INDEX (is_premium),
	INDEX (release_year),
	FULLTEXT INDEX ft_movies (title, description),
	CONSTRAINT fk_movies_country FOREIGN KEY (country_id) REFERENCES countries(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Series
CREATE TABLE IF NOT EXISTS series (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	title VARCHAR(255) NOT NULL,
	slug VARCHAR(255) NOT NULL UNIQUE,
	description TEXT,
	release_year SMALLINT UNSIGNED,
	country_id SMALLINT UNSIGNED NULL,
	poster_url VARCHAR(500) NULL,
	backdrop_url VARCHAR(500) NULL,
	is_premium TINYINT(1) NOT NULL DEFAULT 0,
	is_featured TINYINT(1) NOT NULL DEFAULT 0,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX (country_id),
	INDEX (is_featured),
	INDEX (is_premium),
	FULLTEXT INDEX ft_series (title, description),
	CONSTRAINT fk_series_country FOREIGN KEY (country_id) REFERENCES countries(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Seasons
CREATE TABLE IF NOT EXISTS seasons (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	series_id INT UNSIGNED NOT NULL,
	season_number SMALLINT UNSIGNED NOT NULL,
	title VARCHAR(255) NULL,
	UNIQUE KEY uniq_series_season (series_id, season_number),
	INDEX (series_id),
	CONSTRAINT fk_seasons_series FOREIGN KEY (series_id) REFERENCES series(id)
		ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Episodes
CREATE TABLE IF NOT EXISTS episodes (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	season_id INT UNSIGNED NOT NULL,
	episode_number SMALLINT UNSIGNED NOT NULL,
	title VARCHAR(255) NOT NULL,
	description TEXT,
	trailer_url VARCHAR(500) NULL,
	video_url VARCHAR(500) NULL,
	release_date DATE NULL,
	views_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
	UNIQUE KEY uniq_season_episode (season_id, episode_number),
	INDEX (season_id),
	CONSTRAINT fk_episodes_season FOREIGN KEY (season_id) REFERENCES seasons(id)
		ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Pivots
CREATE TABLE IF NOT EXISTS movie_genre (
	movie_id INT UNSIGNED NOT NULL,
	genre_id SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (movie_id, genre_id),
	CONSTRAINT fk_mg_movie FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_mg_genre FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS series_genre (
	series_id INT UNSIGNED NOT NULL,
	genre_id SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (series_id, genre_id),
	CONSTRAINT fk_sg_series FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_sg_genre FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Actors
CREATE TABLE IF NOT EXISTS actors (
	id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(255) NOT NULL,
	photo_url VARCHAR(500) NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movie_actor (
	movie_id INT UNSIGNED NOT NULL,
	actor_id INT UNSIGNED NOT NULL,
	PRIMARY KEY (movie_id, actor_id),
	CONSTRAINT fk_ma_movie FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_ma_actor FOREIGN KEY (actor_id) REFERENCES actors(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS series_actor (
	series_id INT UNSIGNED NOT NULL,
	actor_id INT UNSIGNED NOT NULL,
	PRIMARY KEY (series_id, actor_id),
	CONSTRAINT fk_sa_series FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_sa_actor FOREIGN KEY (actor_id) REFERENCES actors(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Subscriptions
CREATE TABLE IF NOT EXISTS plans (
	id TINYINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(80) NOT NULL UNIQUE,
	price_cents INT UNSIGNED NOT NULL,
	duration_days SMALLINT UNSIGNED NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_subscriptions (
	id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	user_id INT UNSIGNED NOT NULL,
	plan_id TINYINT UNSIGNED NOT NULL,
	status ENUM('active','expired','canceled') NOT NULL DEFAULT 'active',
	start_at DATETIME NOT NULL,
	end_at DATETIME NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX (user_id),
	INDEX (plan_id),
	INDEX (status),
	CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_sub_plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Payment stub (demo)
CREATE TABLE IF NOT EXISTS payments (
	id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	user_id INT UNSIGNED NOT NULL,
	plan_id TINYINT UNSIGNED NOT NULL,
	amount_cents INT UNSIGNED NOT NULL,
	status ENUM('pending','succeeded','failed') NOT NULL DEFAULT 'succeeded',
	provider VARCHAR(50) NOT NULL DEFAULT 'demo',
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX (user_id),
	INDEX (plan_id),
	CONSTRAINT fk_pay_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_pay_plan FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- User content interactions
CREATE TABLE IF NOT EXISTS watch_history (
	id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	user_id INT UNSIGNED NOT NULL,
	content_type ENUM('movie','episode') NOT NULL,
	content_id INT UNSIGNED NOT NULL,
	progress_seconds INT UNSIGNED NOT NULL DEFAULT 0,
	watched_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX (user_id, content_type, content_id),
	CONSTRAINT fk_wh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS watchlist (
	user_id INT UNSIGNED NOT NULL,
	content_type ENUM('movie','series') NOT NULL,
	content_id INT UNSIGNED NOT NULL,
	added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (user_id, content_type, content_id),
	INDEX (user_id),
	CONSTRAINT fk_wl_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Settings
CREATE TABLE IF NOT EXISTS settings (
	id TINYINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	k VARCHAR(100) NOT NULL UNIQUE,
	v TEXT NULL
) ENGINE=InnoDB;

-- Seeds
INSERT IGNORE INTO countries (id, name) VALUES
	(1,'США'),(2,'Россия'),(3,'Великобритания'),(4,'Франция'),(5,'Канада');

INSERT IGNORE INTO genres (id, name) VALUES
	(1,'Драма'),(2,'Комедия'),(3,'Боевик'),(4,'Фантастика'),(5,'Триллер'),(6,'Семейный');

INSERT IGNORE INTO plans (id, name, price_cents, duration_days) VALUES
	(1,'Базовая', 29900, 30),
	(2,'Стандарт', 59900, 30),
	(3,'Премиум', 89900, 30);

-- Default admin user (password: admin123)
INSERT IGNORE INTO users (id, email, password_hash, name, role_id) VALUES
	(1, 'admin@example.com', '$2y$10$7pW0m5nQk0gD3g7k8qkS1u1Ckqv9rZikq5b3Xg8a.3d3bB8q8yJ9S', 'Administrator', 1);

-- Sample movies
INSERT IGNORE INTO movies (id, title, slug, description, release_year, release_date, country_id, poster_url, backdrop_url, trailer_url, video_url, is_premium, is_featured, views_total, views_last_7d)
VALUES
	(1,'Город огней','city-of-lights','Неоновый триллер о ночной жизни мегаполиса.',2024,'2024-06-10',1,'/assets/sample/posters/city.jpg','/assets/sample/backdrops/city.jpg','https://vjs.zencdn.net/v/oceans.mp4','https://vjs.zencdn.net/v/oceans.mp4',1,1,10234,1200),
	(2,'Космический путь','space-journey','Эпическое путешествие сквозь галактики.',2023,'2023-12-20',1,'/assets/sample/posters/space.jpg','/assets/sample/backdrops/space.jpg','https://vjs.zencdn.net/v/oceans.mp4','https://vjs.zencdn.net/v/oceans.mp4',0,1,45789,5400),
	(3,'Семейные тайны','family-secrets','Тёплая история о ценностях и выборе.',2022,'2022-03-15',2,'/assets/sample/posters/family.jpg','/assets/sample/backdrops/family.jpg','https://vjs.zencdn.net/v/oceans.mp4','https://vjs.zencdn.net/v/oceans.mp4',0,0,1200,150);

INSERT IGNORE INTO movie_genre (movie_id, genre_id) VALUES
	(1,5),(1,3),(2,4),(2,3),(3,1),(3,6);

-- Sample series
INSERT IGNORE INTO series (id, title, slug, description, release_year, country_id, poster_url, backdrop_url, is_premium, is_featured)
VALUES
	(1,'Тени прошлого','shadows-of-the-past','Детективный сериал о расследованиях в маленьком городке.',2024,2,'/assets/sample/posters/shadows.jpg','/assets/sample/backdrops/shadows.jpg',1,1);

INSERT IGNORE INTO seasons (id, series_id, season_number, title) VALUES
	(1,1,1,'Сезон 1');

INSERT IGNORE INTO episodes (id, season_id, episode_number, title, description, trailer_url, video_url, release_date, views_total)
VALUES
	(1,1,1,'Начало','Первая загадка выводит героя на след давно забытого дела.','https://vjs.zencdn.net/v/oceans.mp4','https://vjs.zencdn.net/v/oceans.mp4','2024-07-01',500),
	(2,1,2,'Следы','Новые улики меняют ход расследования.','https://vjs.zencdn.net/v/oceans.mp4','https://vjs.zencdn.net/v/oceans.mp4','2024-07-08',420);

INSERT IGNORE INTO series_genre (series_id, genre_id) VALUES (1,1),(1,5);

-- Settings
INSERT IGNORE INTO settings (id, k, v) VALUES
	(1,'site_name','Wink Clone'),
	(2,'support_email','support@example.com');

SET FOREIGN_KEY_CHECKS = 1;