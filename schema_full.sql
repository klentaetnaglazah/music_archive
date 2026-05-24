DROP DATABASE IF EXISTS music_archive;

CREATE DATABASE music_archive
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Russian_Russia.1251'
    LC_CTYPE = 'Russian_Russia.1251'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    TEMPLATE template0;

COMMENT ON DATABASE music_archive IS 'База данных для музыкального сайта-энциклопедии с интеграцией стриминговых сервисов';

\c music_archive

CREATE TABLE genres (
    genre_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    slug VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE artists (
    artist_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    bio TEXT,
    photo_url VARCHAR(500),
    country VARCHAR(100),
    formed_year INTEGER,
    website VARCHAR(255),
    slug VARCHAR(255) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE artist_genres (
    artist_id INTEGER NOT NULL,
    genre_id INTEGER NOT NULL,
    PRIMARY KEY (artist_id, genre_id),
    FOREIGN KEY (artist_id) 
        REFERENCES artists(artist_id) 
        ON DELETE CASCADE,
    FOREIGN KEY (genre_id) 
        REFERENCES genres(genre_id) 
        ON DELETE CASCADE
);

CREATE TABLE albums (
    album_id SERIAL PRIMARY KEY,
    artist_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    release_date DATE,
    cover_url VARCHAR(500),
    description TEXT,
    type VARCHAR(50) CHECK (type IN ('album', 'single', 'ep', 'compilation', 'live')),
    label VARCHAR(255),
    slug VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (artist_id) 
        REFERENCES artists(artist_id) 
        ON DELETE CASCADE,
    UNIQUE(artist_id, title)
);

CREATE TABLE tracks (
    track_id SERIAL PRIMARY KEY,
    album_id INTEGER,
    title VARCHAR(255) NOT NULL,
    duration INTEGER,
    track_number INTEGER,
    lyrics TEXT,
    is_instrumental BOOLEAN DEFAULT false,
    explicit BOOLEAN DEFAULT false,
    slug VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (album_id) 
        REFERENCES albums(album_id) 
        ON DELETE SET NULL
);

CREATE TABLE track_details (
    detail_id SERIAL PRIMARY KEY,
    track_id INTEGER NOT NULL UNIQUE,
    history_story TEXT,
    interesting_facts TEXT,
    recording_info TEXT,
    credits TEXT,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (track_id) 
        REFERENCES tracks(track_id) 
        ON DELETE CASCADE
);

CREATE TABLE streaming_links (
    link_id SERIAL PRIMARY KEY,
    track_id INTEGER NOT NULL,
    platform VARCHAR(50) NOT NULL 
        CHECK (platform IN ('spotify', 'soundcloud', 'yandex_music', 'zvuk', 'apple_music', 'youtube_music')),
    url VARCHAR(500) NOT NULL,
    embed_code TEXT,
    external_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (track_id) 
        REFERENCES tracks(track_id) 
        ON DELETE CASCADE,
    UNIQUE(track_id, platform)
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'editor' 
        CHECK (role IN ('admin', 'editor', 'viewer')),
    avatar_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_artists_name ON artists(name);
CREATE INDEX idx_albums_title ON albums(title);
CREATE INDEX idx_albums_release_date ON albums(release_date);
CREATE INDEX idx_tracks_title ON tracks(title);
CREATE INDEX idx_genres_name ON genres(name);
CREATE INDEX idx_streaming_platform ON streaming_links(platform);
CREATE INDEX idx_users_email ON users(email);

CREATE INDEX idx_artists_bio_search 
    ON artists USING gin(to_tsvector('russian', bio));
CREATE INDEX idx_tracks_lyrics_search 
    ON tracks USING gin(to_tsvector('russian', COALESCE(lyrics, '')));
CREATE INDEX idx_track_details_search 
    ON track_details USING gin(to_tsvector('russian', 
        COALESCE(history_story, '') || ' ' || COALESCE(interesting_facts, '')));

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_artists_updated_at 
    BEFORE UPDATE ON artists 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_albums_updated_at 
    BEFORE UPDATE ON albums 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tracks_updated_at 
    BEFORE UPDATE ON tracks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_track_details_updated_at 
    BEFORE UPDATE ON track_details 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

INSERT INTO genres (name, description, slug) VALUES
('Rock', 'Рок-музыка - обобщающее название ряда направлений популярной музыки', 'rock'),
('Electronic', 'Электронная музыка - широкий жанр, создаваемый с использованием электронных инструментов', 'electronic'),
('Jazz', 'Джаз - род музыкального искусства, сложившийся под влиянием африканских ритмов', 'jazz'),
('Classical', 'Классическая музыка - образцовые музыкальные произведения', 'classical'),
('Hip-Hop', 'Хип-хоп - музыкальный жанр, зародившийся в афроамериканском сообществе', 'hip-hop');

INSERT INTO artists (name, bio, photo_url, country, formed_year, website, slug) VALUES
('Daft Punk', 
 'Daft Punk — французский электронный дуэт, состоявший из Тома Бангальтера и Ги-Мануэля де Омем-Кристо. Группа распалась в 2021 году.', 
 '/images/artists/daft-punk.jpg', 'France', 1993, 'https://daftpunk.com', 'daft-punk'),
('Radiohead', 
 'Radiohead — британская рок-группа из Оксфордшира, сформированная в 1985 году. Одна из самых влиятельных групп своего поколения.', 
 '/images/artists/radiohead.jpg', 'United Kingdom', 1985, 'https://radiohead.com', 'radiohead'),
('Kendrick Lamar', 
 'Kendrick Lamar — американский рэпер, один из самых влиятельных артистов своего поколения, лауреат Пулитцеровской премии.', 
 '/images/artists/kendrick-lamar.jpg', 'United States', 2003, 'https://oklama.com', 'kendrick-lamar'),
('Miles Davis', 
 'Miles Davis — американский джазовый трубач, бэнд-лидер и композитор, один из самых значительных музыкантов XX века.', 
 '/images/artists/miles-davis.jpg', 'United States', 1944, NULL, 'miles-davis');

INSERT INTO artist_genres (artist_id, genre_id) VALUES
(1, 2),
(2, 1),
(2, 2),
(3, 5),
(4, 3);

INSERT INTO albums (artist_id, title, release_date, cover_url, description, type, label, slug) VALUES
(1, 'Random Access Memories', '2013-05-17', '/images/albums/ram.jpg', 
 'Четвертый и последний студийный альбом французского дуэта Daft Punk. Получил премию Грэмми как лучший альбом года.', 
 'album', 'Columbia', 'random-access-memories'),
(1, 'Discovery', '2001-03-12', '/images/albums/discovery.jpg', 
 'Второй студийный альбом Daft Punk, который стал поворотным моментом в электронной музыке.', 
 'album', 'Virgin', 'discovery'),
(2, 'OK Computer', '1997-05-21', '/images/albums/ok-computer.jpg', 
 'Третий студийный альбом Radiohead, считающийся одним из величайших альбомов в истории музыки.', 
 'album', 'Parlophone', 'ok-computer'),
(3, 'DAMN.', '2017-04-14', '/images/albums/damn.jpg', 
 'Четвертый студийный альбом Кендрика Ламара, получивший Пулитцеровскую премию — первый рэп-альбом, удостоенный этой награды.', 
 'album', 'Top Dawg', 'damn'),
(4, 'Kind of Blue', '1959-08-17', '/images/albums/kind-of-blue.jpg', 
 'Самый продаваемый джазовый альбом всех времен, записанный всего за две сессии. Шедевр модального джаза.', 
 'album', 'Columbia', 'kind-of-blue');

INSERT INTO tracks (album_id, title, duration, track_number, lyrics, slug) VALUES
(1, 'Get Lucky', 369, 8, 
 'Like the legend of the phoenix, all ends with beginnings...', 
 'get-lucky'),
(1, 'Instant Crush', 337, 5, 
 'I didn''t want to be the one to forget...', 
 'instant-crush'),
(2, 'One More Time', 320, 1, 
 'One more time, we''re gonna celebrate...', 
 'one-more-time'),
(2, 'Harder, Better, Faster, Stronger', 225, 4, 
 'Work it harder, make it better, do it faster, makes us stronger...', 
 'harder-better-faster-stronger'),
(3, 'Paranoid Android', 383, 2, 
 'Please could you stop the noise, I''m trying to get some rest...', 
 'paranoid-android'),
(3, 'Karma Police', 261, 6, 
 'Karma police, arrest this man, he talks in maths...', 
 'karma-police'),
(4, 'HUMBLE.', 177, 8, 
 'Nobody pray for me, it''s been that day for me...', 
 'humble'),
(5, 'So What', 562, 1, 
 NULL, 
 'so-what');

INSERT INTO track_details (track_id, history_story, interesting_facts, recording_info, credits) VALUES
(1, 
 'История создания Get Lucky началась, когда Daft Punk пригласили легендарного гитариста Найла Роджерса на запись. Встреча произошла на вечеринке в Нью-Йорке, где музыканты обсудили совместную работу. Позже к записи присоединился Фаррелл Уильямс, который написал вокальную партию.', 
 '• Песня получила Грэмми за лучшую запись года (2014)
• Найл Роджерс сыграл гитарную партию с первого дубля
• Трек возглавил чарты более чем в 50 странах
• На создание ушло более года работы', 
 'Запись проходила в студиях Henson Recording и Conway Recording в Калифорнии. Для записи использовались винтажные синтезаторы и живая ритм-секция.', 
 'Авторы: Thomas Bangalter, Guy-Manuel de Homem-Christo, Nile Rodgers, Pharrell Williams'),
(5, 
 'Paranoid Android — одна из самых амбициозных композиций Radiohead. Том Йорк написал песню после неприятного опыта в баре Лос-Анджелеса. Композиция состоит из четырех различных частей, написанных в разное время и объединенных в единое целое.', 
 '• Длительность песни — 6 минут 23 секунды
• Названа в честь робота Марвина из книги "Автостопом по галактике"
• В записи использовался компьютерный голос
• Заняла 256 место в списке 500 величайших песен по версии Rolling Stone', 
 'Записана в студии St. Catherine''s Court в Бате, Англия. Продюсером выступил Найджел Годрич. Для записи использовались акустические гитары, синтезаторы и оркестровые аранжировки.', 
 'Авторы: Thom Yorke, Jonny Greenwood, Ed O''Brien, Colin Greenwood, Philip Selway'),
(7, 
 'Kendrick написал HUMBLE. как манифест скромности в мире хип-хопа. Изначально трек предназначался для Gucci Mane, но Кендрик решил оставить его себе. Песня стала его первым сольным синглом №1 в Billboard Hot 100.', 
 '• Видеоклип набрал более 900 миллионов просмотров на YouTube
• Содержит множество отсылок к религиозным образам
• Вызвал дискуссию о стандартах красоты в музыкальной индустрии
• Получил Грэмми за лучшее рэп-исполнение', 
 'Спродюсировано Mike Will Made-It. Запись проходила на студии Top Dawg Entertainment. Бит построен на минималистичном пианино и тяжелом басе.', 
 'Автор: Kendrick Duckworth. Продюсер: Mike Will Made-It');

INSERT INTO streaming_links (track_id, platform, url, external_id) VALUES
(1, 'spotify', 'https://open.spotify.com/track/69kOkLUCkxIZYexIgSG8rq', '69kOkLUCkxIZYexIgSG8rq'),
(1, 'yandex_music', 'https://music.yandex.ru/track/25457668', '25457668'),
(2, 'spotify', 'https://open.spotify.com/track/6unAy8fjBYPx1JFNb7xQ8o', '6unAy8fjBYPx1JFNb7xQ8o'),
(5, 'spotify', 'https://open.spotify.com/track/0HdPVFhRBdPVmXUOwAYROE', '0HdPVFhRBdPVmXUOwAYROE'),
(7, 'spotify', 'https://open.spotify.com/track/1D08iGk2cAC2toezGJ9FmK', '1D08iGk2cAC2toezGJ9FmK'),
(7, 'yandex_music', 'https://music.yandex.ru/track/42005220', '42005220');

INSERT INTO users (username, email, password_hash, role) VALUES
('admin', 'admin@musicarchive.com', '$2b$10$hashedpassword1234567890abcdef', 'admin'),
('editor1', 'editor@musicarchive.com', '$2b$10$hashedpassword0987654321fedcba', 'editor');

SELECT 'База данных успешно создана!' AS status;

SELECT 
    'Статистика наполнения базы данных' AS info,
    (SELECT COUNT(*) FROM genres) AS "Жанры",
    (SELECT COUNT(*) FROM artists) AS "Исполнители",
    (SELECT COUNT(*) FROM albums) AS "Альбомы",
    (SELECT COUNT(*) FROM tracks) AS "Треки",
    (SELECT COUNT(*) FROM track_details) AS "Детали треков",
    (SELECT COUNT(*) FROM streaming_links) AS "Ссылки на стриминг",
    (SELECT COUNT(*) FROM users) AS "Пользователи",
    (SELECT COUNT(*) FROM artist_genres) AS "Связи жанров";
