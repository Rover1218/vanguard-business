-- Vanguard Business - database tables, created automatically on start.

DB = {}

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `vbiz_businesses` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(64) NOT NULL,
        `type` VARCHAR(32) NOT NULL,
        `balance` BIGINT NOT NULL DEFAULT 0,
        `blip` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `vbiz_staff` (
        `business_id` INT UNSIGNED NOT NULL,
        `identifier` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `rank` TINYINT UNSIGNED NOT NULL,
        PRIMARY KEY (`business_id`, `identifier`),
        CONSTRAINT `vbiz_staff_business` FOREIGN KEY (`business_id`) REFERENCES `vbiz_businesses` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `vbiz_stations` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `business_id` INT UNSIGNED NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `heading` DOUBLE NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        CONSTRAINT `vbiz_stations_business` FOREIGN KEY (`business_id`) REFERENCES `vbiz_businesses` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `vbiz_doors` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `business_id` INT UNSIGNED NOT NULL,
        `model` INT NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `pair_id` INT UNSIGNED NULL,
        `locked` TINYINT(1) NOT NULL DEFAULT 1,
        `heading` DOUBLE NULL,
        PRIMARY KEY (`id`),
        CONSTRAINT `vbiz_doors_business` FOREIGN KEY (`business_id`) REFERENCES `vbiz_businesses` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `vbiz_transactions` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `business_id` INT UNSIGNED NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `amount` BIGINT NOT NULL,
        `actor` VARCHAR(64) NOT NULL,
        `note` VARCHAR(160) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `vbiz_transactions_business` (`business_id`, `id`),
        CONSTRAINT `vbiz_transactions_business` FOREIGN KEY (`business_id`) REFERENCES `vbiz_businesses` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

--- Adds a column to a table from an older version (works on MySQL and MariaDB).
local function addColumnIfMissing(tableName, column, definition)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tableName, column })
    if count == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition))
    end
end

function DB.init()
    for _, statement in ipairs(TABLES) do MySQL.query.await(statement) end
    addColumnIfMissing('vbiz_doors', 'heading', '`heading` DOUBLE NULL') -- 1.0.0 had no closed-door heading
end
