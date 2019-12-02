CREATE TABLE `classifier` (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `level` INT(11) NOT NULL,
  `left_key` INT(11) NOT NULL,
  `right_key` INT(11) NOT NULL,
  `chang_data_time` TIMESTAMP NULL DEFAULT NULL,
  `start_data_active` TIMESTAMP NULL DEFAULT NULL,
  `name` TEXT NOT NULL,
  `code` VARCHAR(45) NOT NULL,
  `parent_code` VARCHAR(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `right_key` (`right_key`),
  KEY `left_key` (`left_key`)
) ENGINE=INNODB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8 COMMENT='Классификатор ОКДП'


DELIMITER $$

DROP PROCEDURE IF EXISTS rebuild_nested_set_tree$$

CREATE PROCEDURE rebuild_nested_set_tree()
tutu: BEGIN
    #SELECT @current_left AS '** DEBUG **';
    -- Изначально сбрасываем все границы
    UPDATE classifier SET LEVEL = 0, left_key = 0, right_key = 0;

    -- Устанавливаем границы корневым элементам
    SET @i := 0;
    UPDATE classifier SET left_key = (@i := @i + 1), right_key = (@i := @i + 1)
    WHERE parent_code IS NULL;
    	
    SET @parent_code  := NULL;
    SET @parent_right := NULL;
    SET @step := 0;	
    forever: LOOP	
        -- Находим элемент с минимальной правой границей - самый левый в дереве
        SET @parent_code := NULL;

        SELECT t.`code`, t.`right_key` FROM `classifier` t, `classifier` tc
        WHERE t.`code` = tc.`parent_code` AND tc.`left_key` = 0 AND t.`right_key` <> 0
        ORDER BY t.`right_key`, t.`code` LIMIT 1 INTO @parent_code, @parent_right;
	
        -- Выходим из бесконечности, когда у нас уже нет незаполненных элементов
        IF @parent_code IS NULL THEN
            LEAVE forever;
        END IF;

        -- Сохраняем левую границу текущего ряда
        SET @current_left := @parent_right;

        -- Вычисляем максимальную правую границу текущего ряда
        SELECT @current_left + COUNT(*) * 2 FROM `classifier`
        WHERE `parent_code` = @parent_code INTO @parent_right;

        -- Вычисляем длину текущего ряда
        SET @current_length := @parent_right - @current_left;

        -- Обновляем правые границы всех элементов, которые правее
        UPDATE `classifier` SET `right_key` = `right_key` + @current_length
        WHERE `right_key` >= @current_left ORDER BY `right_key`;

        -- Обновляем левые границы всех элементов, которые правее
        UPDATE `classifier` SET `left_key` = `left_key` + @current_length
        WHERE `left_key` > @current_left ORDER BY left_key;

        -- И только сейчас обновляем границы текущего ряда

        SET @i := @current_left - 1;
        UPDATE `classifier` SET `left_key` = (@i := @i + 1), `right_key` = (@i := @i + 1)
        WHERE `parent_code` = @parent_code ORDER BY `id`;
	SET @step := @step + 1;
    END LOOP;

    -- Дальше заполняем поля level

    -- Устанавливаем 1-й уровень всем корневым категориям классификатора
    UPDATE `classifier` SET `level` = 1 WHERE `parent_code` IS NULL;

    SET @unprocessed_rows_count = 100500;

    WHILE @unprocessed_rows_count > 0 DO

        UPDATE `classifier` AS top, `classifier` AS bottom 
        SET bottom.`level` = top.`level` + 1
        WHERE bottom.`level` = 0 AND top.`level` <> 0 AND top.`code` = bottom.`parent_code`;

        SELECT COUNT(*) FROM `classifier` WHERE `level` = 0 LIMIT 1 INTO @unprocessed_rows_count;

    END WHILE;

END$$





