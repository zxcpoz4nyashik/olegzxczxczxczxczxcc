/* ============================================================
   База Polesye для приложения «Работа с заказами» (M7_app)
   Собрано из модулей: М1 (пользователь sa), М4 (таблицы и
   тестовые данные), М5 (триггер итогов заказа).
   Запуск: MySQL Workbench под root -> Query -> Execute All
   или:    mysql -u root -p < Polesye.sql
   ============================================================ */

/* ---------- М1. Пользователь sa с паролем De_05 ---------- */
CREATE USER IF NOT EXISTS 'sa'@'localhost' IDENTIFIED BY 'De_05';
ALTER USER 'sa'@'localhost' IDENTIFIED BY 'De_05';
GRANT ALL PRIVILEGES ON *.* TO 'sa'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

/* ============================================================
   Модуль 4. Создание базы данных (3НФ, ссылочная целостность)
   Предметная область: молочный комбинат «Полесье» выпускает
   продукцию по спецификациям (нормы расхода материалов)
   и реализует её заказчикам.
   ============================================================ */
CREATE DATABASE IF NOT EXISTS Polesye CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE Polesye;

/* Повторный запуск: удаляем таблицы в порядке, обратном зависимостям */
DROP TABLE IF EXISTS OrderItems, Orders,
                     ProductionMaterials, ProductionProducts, Productions,
                     SpecificationMaterials, Specifications,
                     Products, Materials,
                     Customers, Cities, Units;

/* ---------- Справочники ---------- */

-- Единицы измерения (шт, кг)
CREATE TABLE Units
(
    UnitID   INT AUTO_INCREMENT,
    UnitName VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Units PRIMARY KEY (UnitID),
    CONSTRAINT UQ_Units_UnitName UNIQUE (UnitName)
);

-- Города
CREATE TABLE Cities
(
    CityID   INT AUTO_INCREMENT,
    CityName VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Cities PRIMARY KEY (CityID),
    CONSTRAINT UQ_Cities_CityName UNIQUE (CityName)
);

-- Контрагенты: заказчики (покупатели) и поставщики
CREATE TABLE Customers
(
    CustomerID   INT AUTO_INCREMENT,
    CustomerCode VARCHAR(20)  NOT NULL,
    CustomerName VARCHAR(150) NOT NULL,
    INN          VARCHAR(12)  NULL,
    CityID       INT          NOT NULL,
    Address      VARCHAR(200) NULL,
    Phone        VARCHAR(20)  NULL,
    IsSupplier   BOOLEAN NOT NULL DEFAULT FALSE,
    IsBuyer      BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customers_Code UNIQUE (CustomerCode),
    CONSTRAINT FK_Customers_Cities FOREIGN KEY (CityID) REFERENCES Cities (CityID)
);

-- Материалы (сырьё)
CREATE TABLE Materials
(
    MaterialID   INT AUTO_INCREMENT,
    MaterialCode VARCHAR(20)  NOT NULL,
    MaterialName VARCHAR(150) NOT NULL,
    UnitID       INT NOT NULL,
    Price        DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Materials PRIMARY KEY (MaterialID),
    CONSTRAINT UQ_Materials_Code UNIQUE (MaterialCode),
    CONSTRAINT FK_Materials_Units FOREIGN KEY (UnitID) REFERENCES Units (UnitID),
    CONSTRAINT CK_Materials_Price CHECK (Price >= 0)
);

-- Продукция
CREATE TABLE Products
(
    ProductID   INT AUTO_INCREMENT,
    ProductCode VARCHAR(20)  NOT NULL,
    ProductName VARCHAR(150) NOT NULL,
    UnitID      INT NOT NULL,
    Price       DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Products PRIMARY KEY (ProductID),
    CONSTRAINT UQ_Products_Code UNIQUE (ProductCode),
    CONSTRAINT FK_Products_Units FOREIGN KEY (UnitID) REFERENCES Units (UnitID),
    CONSTRAINT CK_Products_Price CHECK (Price >= 0)
);

/* ---------- Спецификации (нормы расхода) ---------- */

CREATE TABLE Specifications
(
    SpecificationID   INT AUTO_INCREMENT,
    SpecificationName VARCHAR(150) NOT NULL,
    ProductID         INT NOT NULL,
    Quantity          DECIMAL(12,3) NOT NULL DEFAULT 1,   -- на сколько единиц продукции
    CONSTRAINT PK_Specifications PRIMARY KEY (SpecificationID),
    CONSTRAINT FK_Specifications_Products FOREIGN KEY (ProductID) REFERENCES Products (ProductID),
    CONSTRAINT CK_Specifications_Qty CHECK (Quantity > 0)
);

CREATE TABLE SpecificationMaterials
(
    SpecificationID INT NOT NULL,
    MaterialID      INT NOT NULL,
    Quantity        DECIMAL(12,3) NOT NULL,               -- норма расхода
    CONSTRAINT PK_SpecificationMaterials PRIMARY KEY (SpecificationID, MaterialID),
    CONSTRAINT FK_SpecMaterials_Specifications FOREIGN KEY (SpecificationID)
        REFERENCES Specifications (SpecificationID) ON DELETE CASCADE,
    CONSTRAINT FK_SpecMaterials_Materials FOREIGN KEY (MaterialID) REFERENCES Materials (MaterialID),
    CONSTRAINT CK_SpecMaterials_Qty CHECK (Quantity > 0)
);

/* ---------- Производство ---------- */

CREATE TABLE Productions
(
    ProductionID     INT AUTO_INCREMENT,
    ProductionNumber VARCHAR(20) NOT NULL,
    ProductionDate   DATE NOT NULL,
    CONSTRAINT PK_Productions PRIMARY KEY (ProductionID),
    CONSTRAINT UQ_Productions_Number UNIQUE (ProductionNumber)
);

CREATE TABLE ProductionProducts
(
    ProductionID INT NOT NULL,
    ProductID    INT NOT NULL,
    Quantity     DECIMAL(12,3) NOT NULL,
    CONSTRAINT PK_ProductionProducts PRIMARY KEY (ProductionID, ProductID),
    CONSTRAINT FK_ProdProducts_Productions FOREIGN KEY (ProductionID)
        REFERENCES Productions (ProductionID) ON DELETE CASCADE,
    CONSTRAINT FK_ProdProducts_Products FOREIGN KEY (ProductID) REFERENCES Products (ProductID),
    CONSTRAINT CK_ProdProducts_Qty CHECK (Quantity > 0)
);

CREATE TABLE ProductionMaterials
(
    ProductionID INT NOT NULL,
    MaterialID   INT NOT NULL,
    Quantity     DECIMAL(12,3) NOT NULL,
    CONSTRAINT PK_ProductionMaterials PRIMARY KEY (ProductionID, MaterialID),
    CONSTRAINT FK_ProdMaterials_Productions FOREIGN KEY (ProductionID)
        REFERENCES Productions (ProductionID) ON DELETE CASCADE,
    CONSTRAINT FK_ProdMaterials_Materials FOREIGN KEY (MaterialID) REFERENCES Materials (MaterialID),
    CONSTRAINT CK_ProdMaterials_Qty CHECK (Quantity > 0)
);

/* ---------- Заказы покупателей ---------- */

CREATE TABLE Orders
(
    OrderID       INT AUTO_INCREMENT,
    OrderNumber   VARCHAR(20) NOT NULL,
    OrderDate     DATE NOT NULL,
    CustomerID    INT  NOT NULL,
    TotalQuantity DECIMAL(12,3) NOT NULL DEFAULT 0,   -- считает триггер (модуль 5)
    TotalSum      DECIMAL(14,2) NOT NULL DEFAULT 0,   -- считает триггер (модуль 5)
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT UQ_Orders_Number UNIQUE (OrderNumber),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers (CustomerID)
);

CREATE TABLE OrderItems
(
    OrderItemID INT AUTO_INCREMENT,
    OrderID     INT NOT NULL,
    ProductID   INT NOT NULL,
    Quantity    DECIMAL(12,3) NOT NULL,
    UnitCost    DECIMAL(12,2) NOT NULL DEFAULT 0,     -- себестоимость ед., считает триггер
    CONSTRAINT PK_OrderItems PRIMARY KEY (OrderItemID),
    CONSTRAINT UQ_OrderItems_OrderProduct UNIQUE (OrderID, ProductID),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderID) REFERENCES Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductID) REFERENCES Products (ProductID),
    CONSTRAINT CK_OrderItems_Qty CHECK (Quantity > 0)
);

SHOW TABLES;


/* ============================================================
   Модуль 4. Начальные тестовые данные (не менее 3 записей в таблице)
   Значения взяты по образцу документов заказчика.
   ============================================================ */
USE Polesye;

INSERT INTO Units (UnitName) VALUES ('шт'), ('кг'), ('л');

INSERT INTO Cities (CityName) VALUES
    ('Пятигорск'), ('Железноводск'), ('Омск'), ('Уфа'), ('Калуга');

INSERT INTO Customers (CustomerCode, CustomerName, INN, CityID, Address, Phone, IsSupplier, IsBuyer) VALUES
    ('000000001', 'ООО "Поставка"',         NULL,          1, NULL,                    '+79198634592', 1, 1),
    ('000000002', 'ООО "Кинотеатр Квант"',  '26320045123', 2, 'ул. Мира, 123',        '+79884581555', 1, 0),
    ('000000003', 'ООО "Ромашка"',          '4140784214',  3, 'ул. Строителей, 294',  '+79882584546', 0, 1),
    ('000000009', 'ООО "Ипподром"',         '5874045632',  4, 'ул. Набережная, 37',   '+79627486389', 1, 1),
    ('000000010', 'ООО "Ассоль"',           '2629011278',  5, 'ул. Пушкина, 94',      '+79184572398', 0, 1);

INSERT INTO Materials (MaterialCode, MaterialName, UnitID, Price) VALUES
    ('НФ-00000004', 'Молоко нормализованное', 2, 40.00),
    ('НФ-00000005', 'Закваска сметанная',     2, 10.00),
    ('НФ-00000011', 'Закваска кефирная',      2, 12.00),
    ('НФ-00000012', 'Тара (бутылка 900 г)',   1,  5.00),
    ('НФ-00000013', 'Тара (стакан 540 г)',    1,  4.00);

INSERT INTO Products (ProductCode, ProductName, UnitID, Price) VALUES
    ('НФ-00000006', 'Сметана классическая 15% 540г.', 1, 89.00),
    ('НФ-00000007', 'Сметана классическая 20% 540г.', 1, 92.00),
    ('НФ-00000008', 'Кефир 2,5% 900г.',               1, 80.00),
    ('НФ-00000009', 'Кефир 3,2% 900г.',               1, 82.00),
    ('НФ-00000010', 'Молоко 2,5% 900г.',              1, 70.00),
    ('НФ-00000014', 'Молоко 3,2% 900г.',              1, 76.00);

INSERT INTO Specifications (SpecificationName, ProductID, Quantity) VALUES
    ('Основная Сметана 15%', 1, 1),
    ('Основная Сметана 20%', 2, 1),
    ('Основная Кефир 2,5%',  3, 1),
    ('Основная Кефир 3,2%',  4, 1),
    ('Основная Молоко 2,5%', 5, 1),
    ('Основная Молоко 3,2%', 6, 1);

-- нормы расхода на 1 шт.
INSERT INTO SpecificationMaterials (SpecificationID, MaterialID, Quantity) VALUES
    (1, 1, 0.900), (1, 2, 0.070),                 -- сметана 15%: 0,9*40 + 0,07*10 = 36,70
    (2, 1, 1.000), (2, 2, 0.080), (2, 5, 1),
    (3, 1, 0.950), (3, 3, 0.050), (3, 4, 1),
    (4, 1, 0.960), (4, 3, 0.050), (4, 4, 1),
    (5, 1, 0.930), (5, 4, 1),
    (6, 1, 0.940), (6, 4, 1);

INSERT INTO Productions (ProductionNumber, ProductionDate) VALUES
    ('1', '2025-06-09'), ('2', '2025-06-10'), ('3', '2025-07-01');

INSERT INTO ProductionProducts (ProductionID, ProductID, Quantity) VALUES
    (1, 1, 1), (2, 3, 50), (2, 5, 40), (3, 2, 30);

INSERT INTO ProductionMaterials (ProductionID, MaterialID, Quantity) VALUES
    (1, 1, 0.900), (1, 2, 0.070),
    (2, 1, 84.700), (2, 3, 2.500), (2, 4, 90),
    (3, 1, 30.000), (3, 2, 2.400), (3, 5, 30);

INSERT INTO Orders (OrderNumber, OrderDate, CustomerID) VALUES
    ('1', '2025-06-02', 3),
    ('2', '2025-06-06', 5),
    ('3', '2025-06-15', 2),
    ('4', '2025-06-21', 1),
    ('5', '2025-07-03', 4),
    ('6', '2025-07-21', 1),
    ('7', '2025-07-25', 5);

INSERT INTO OrderItems (OrderID, ProductID, Quantity) VALUES
    (1, 1, 20), (1, 6, 15),
    (2, 3, 12), (2, 4, 9), (2, 5, 10),            -- как в «Заказ покупателя № 2»
    (3, 2, 40), (3, 4, 25),
    (4, 5, 100), (4, 6, 60),
    (5, 1, 30),
    (6, 3, 200), (6, 5, 150), (6, 1, 50),
    (7, 2, 18);

-- Итоги заказов (TotalQuantity, TotalSum) заполнит триггер из модуля 5:
-- скрипт модуля 5 после создания триггеров пересчитывает все существующие заказы.
SELECT 'Units' AS TableName, COUNT(*) AS RowsCount FROM Units
UNION ALL SELECT 'Cities', COUNT(*) FROM Cities
UNION ALL SELECT 'Customers', COUNT(*) FROM Customers
UNION ALL SELECT 'Materials', COUNT(*) FROM Materials
UNION ALL SELECT 'Products', COUNT(*) FROM Products
UNION ALL SELECT 'Specifications', COUNT(*) FROM Specifications
UNION ALL SELECT 'SpecificationMaterials', COUNT(*) FROM SpecificationMaterials
UNION ALL SELECT 'Productions', COUNT(*) FROM Productions
UNION ALL SELECT 'ProductionProducts', COUNT(*) FROM ProductionProducts
UNION ALL SELECT 'ProductionMaterials', COUNT(*) FROM ProductionMaterials
UNION ALL SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM OrderItems;


/* ============================================================
   Модуль 5. Триггер: итоговая сумма заказа покупателя
   Срабатывает при добавлении, изменении и удалении строк заказа.
   1) Себестоимость единицы продукции =
         Σ (норма материала по спецификации × цена материала)
         / количество продукции в спецификации.
      Если спецификации нет, берётся цена продукции.
   2) Итог заказа:
         TotalQuantity = Σ количество продукции
         TotalSum      = Σ (количество × себестоимость единицы)

   В MySQL триггер не может изменять свою же таблицу, поэтому:
   - BEFORE INSERT/UPDATE  — записывает себестоимость в NEW.UnitCost;
   - AFTER INSERT/UPDATE/DELETE — пересчитывает итоги заказа в Orders.
   ============================================================ */
USE Polesye;
SET SQL_SAFE_UPDATES = 0;                       -- Workbench по умолчанию запрещает UPDATE без WHERE по ключу

DROP TRIGGER   IF EXISTS trg_OrderItems_BeforeInsert;
DROP TRIGGER   IF EXISTS trg_OrderItems_BeforeUpdate;
DROP TRIGGER   IF EXISTS trg_OrderItems_AfterInsert;
DROP TRIGGER   IF EXISTS trg_OrderItems_AfterUpdate;
DROP TRIGGER   IF EXISTS trg_OrderItems_AfterDelete;
DROP FUNCTION  IF EXISTS fn_ProductUnitCost;
DROP PROCEDURE IF EXISTS sp_RecalcOrderTotal;

DELIMITER $$

/* Себестоимость единицы продукции по первой спецификации */
CREATE FUNCTION fn_ProductUnitCost(pProductID INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE vCost DECIMAL(12,2);

    SELECT CAST(SUM(sm.Quantity * m.Price) / s.Quantity AS DECIMAL(12,2))
      INTO vCost
    FROM Specifications s
    JOIN SpecificationMaterials sm ON sm.SpecificationID = s.SpecificationID
    JOIN Materials m               ON m.MaterialID       = sm.MaterialID
    WHERE s.ProductID = pProductID
    GROUP BY s.SpecificationID, s.Quantity
    ORDER BY s.SpecificationID
    LIMIT 1;

    IF vCost IS NULL THEN                       -- спецификации нет: цена продукции
        SELECT Price INTO vCost FROM Products WHERE ProductID = pProductID;
    END IF;

    RETURN vCost;
END$$

/* Итоги одного заказа */
CREATE PROCEDURE sp_RecalcOrderTotal(IN pOrderID INT)
BEGIN
    UPDATE Orders o
    SET o.TotalQuantity = (SELECT IFNULL(SUM(Quantity), 0)
                           FROM OrderItems WHERE OrderID = pOrderID),
        o.TotalSum      = (SELECT IFNULL(SUM(Quantity * UnitCost), 0)
                           FROM OrderItems WHERE OrderID = pOrderID)
    WHERE o.OrderID = pOrderID;
END$$

/* 1. Себестоимость единицы для новой/изменённой строки */
CREATE TRIGGER trg_OrderItems_BeforeInsert
BEFORE INSERT ON OrderItems
FOR EACH ROW
BEGIN
    SET NEW.UnitCost = fn_ProductUnitCost(NEW.ProductID);
END$$

CREATE TRIGGER trg_OrderItems_BeforeUpdate
BEFORE UPDATE ON OrderItems
FOR EACH ROW
BEGIN
    SET NEW.UnitCost = fn_ProductUnitCost(NEW.ProductID);
END$$

/* 2. Итоги затронутых заказов */
CREATE TRIGGER trg_OrderItems_AfterInsert
AFTER INSERT ON OrderItems
FOR EACH ROW
BEGIN
    CALL sp_RecalcOrderTotal(NEW.OrderID);
END$$

CREATE TRIGGER trg_OrderItems_AfterUpdate
AFTER UPDATE ON OrderItems
FOR EACH ROW
BEGIN
    CALL sp_RecalcOrderTotal(NEW.OrderID);
    IF OLD.OrderID <> NEW.OrderID THEN          -- строку перенесли в другой заказ
        CALL sp_RecalcOrderTotal(OLD.OrderID);
    END IF;
END$$

CREATE TRIGGER trg_OrderItems_AfterDelete
AFTER DELETE ON OrderItems
FOR EACH ROW
BEGIN
    CALL sp_RecalcOrderTotal(OLD.OrderID);
END$$

DELIMITER ;

/* Пересчёт уже существующих заказов (тестовые данные внесены до триггера):
   UPDATE запускает триггеры для каждой строки */
UPDATE OrderItems SET Quantity = Quantity WHERE OrderItemID > 0;

/* ---------- Проверка ---------- */
SELECT o.OrderNumber, o.OrderDate, c.CustomerName, o.TotalQuantity, o.TotalSum
FROM Orders o
JOIN Customers c ON c.CustomerID = o.CustomerID
ORDER BY o.OrderID;

-- новый заказ: 10 шт. сметаны 15% (себестоимость 36,70) => итог 367,00
START TRANSACTION;
    INSERT INTO Orders (OrderNumber, OrderDate, CustomerID) VALUES ('TEST', '2025-08-01', 3);
    INSERT INTO OrderItems (OrderID, ProductID, Quantity) VALUES (LAST_INSERT_ID(), 1, 10);
    SELECT OrderNumber, TotalQuantity, TotalSum FROM Orders WHERE OrderNumber = 'TEST';
ROLLBACK;   -- тестовый заказ не сохраняем
