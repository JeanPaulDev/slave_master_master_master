CREATE DATABASE IF NOT EXISTS test;
USE test;

CREATE TABLE `test` (
  `id` int(255) NOT NULL,
  `text` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

INSERT INTO `test` (`id`, `text`) VALUES
(1, 'hola'),
(2, 'hello');

ALTER TABLE `test` ADD PRIMARY KEY (`id`);
ALTER TABLE `test` MODIFY `id` int(255) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;