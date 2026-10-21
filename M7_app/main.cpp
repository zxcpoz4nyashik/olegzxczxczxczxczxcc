#include <QtWidgets>
#include <QtSql>
#include <exception>

static void showError(QWidget *parent, const QString &message)
{
    QMessageBox::critical(parent, "Ошибка", message);
}

// Выполняет действие с перехватом исключений: ошибка показывается, программа не падает
template <typename F>
static void safely(QWidget *parent, const QString &what, F action)
{
    try {
        action();
    } catch (const std::exception &e) {
        showError(parent, QString("%1: %2").arg(what, e.what()));
    } catch (...) {
        showError(parent, what + ": неизвестная ошибка.");
    }
}

// Подключение к MySQL (база Polesye, пользователь sa из модуля 1)
static bool connectToDatabase(QWidget *parent)
{
    if (!QSqlDatabase::isDriverAvailable("QMYSQL")) {
        showError(parent, "Драйвер MySQL (QMYSQL) не найден. Подключение к базе невозможно.");
        return false;
    }

    QSqlDatabase db = QSqlDatabase::addDatabase("QMYSQL");
    db.setHostName("127.0.0.1");
    db.setPort(3306);
    db.setDatabaseName("Polesye");
    db.setUserName("sa");
    db.setPassword("De_05");
    if (!db.open()) {
        showError(parent, "Не удалось подключиться к базе данных Polesye:\n" + db.lastError().text());
        return false;
    }
    return true;
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setStyle("Fusion");                          // одинаковый вид на любой ОС
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    app.styleHints()->setColorScheme(Qt::ColorScheme::Light);   // светлая тема даже при тёмной Windows
#endif

    // ---------- Элементы окна ----------
    QWidget w;
    w.setWindowTitle("Работа с заказами");
    w.resize(960, 420);

    auto *customers = new QComboBox;
    customers->setMinimumWidth(200);
    auto *btnFilter = new QPushButton("Фильтровать");
    auto *btnAll = new QPushButton("Показать все");
    auto *search = new QLineEdit;
    search->setPlaceholderText("например, Калуга");
    auto *btnFind = new QPushButton("Найти");
    auto *sortField = new QListWidget;
    sortField->addItems({"Заказчик", "Дата заказа", "Сумма заказа"});
    sortField->setCurrentRow(0);
    sortField->setFixedHeight(sortField->sizeHintForRow(0) * 3 + 6);
    auto *asc = new QRadioButton("По возрастанию");
    auto *desc = new QRadioButton("По убыванию");
    asc->setChecked(true);
    auto *table = new QTableWidget(0, 5);
    table->setHorizontalHeaderLabels({"Заказчик", "Город", "Телефон", "Дата заказа", "Сумма заказа"});
    table->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    table->setSelectionBehavior(QAbstractItemView::SelectRows);
    table->setAlternatingRowColors(true);
    auto *lblCount = new QLabel("Всего заказов: 0");
    auto *lblSum = new QLabel("Общая сумма: 0,00");
    QFont bold = lblCount->font();
    bold.setBold(true);
    lblCount->setFont(bold);
    lblSum->setFont(bold);

    // ---------- Компоновка: три блока сверху, таблица, итоги ----------
    auto *filterBox = new QGroupBox("Фильтр");
    auto *filterLay = new QGridLayout(filterBox);
    filterLay->addWidget(new QLabel("Выберите заказчика"), 0, 0, 1, 2);
    filterLay->addWidget(customers, 1, 0, 1, 2);
    filterLay->addWidget(btnFilter, 2, 0);
    filterLay->addWidget(btnAll, 2, 1);

    auto *searchBox = new QGroupBox("Поиск");
    auto *searchLay = new QGridLayout(searchBox);
    searchLay->addWidget(new QLabel("Введите строку поиска"), 0, 0, 1, 2);
    searchLay->addWidget(search, 1, 0);
    searchLay->addWidget(btnFind, 1, 1);
    searchLay->setRowStretch(2, 1);

    auto *sortBox = new QGroupBox("Сортировка");
    auto *sortLay = new QGridLayout(sortBox);
    sortLay->addWidget(new QLabel("Выберите поле для сортировки"), 0, 0, 1, 2);
    sortLay->addWidget(sortField, 1, 0, 2, 1);
    sortLay->addWidget(asc, 1, 1);
    sortLay->addWidget(desc, 2, 1);

    auto *top = new QHBoxLayout;
    top->addWidget(filterBox);
    top->addWidget(searchBox);
    top->addWidget(sortBox);
    auto *totals = new QHBoxLayout;
    totals->addWidget(lblCount);
    totals->addSpacing(40);
    totals->addWidget(lblSum);
    totals->addStretch();
    auto *root = new QVBoxLayout(&w);
    root->addLayout(top);
    root->addWidget(table, 1);   // всё свободное место по высоте — таблице
    root->addLayout(totals);

    // без базы работать нечем: блокируем элементы, но программа не закрывается
    if (!connectToDatabase(&w)) {
        w.setEnabled(false);
        w.show();
        return app.exec();
    }

    // ---------- Список заказчиков: только закупщики, у которых есть заказы ----------
    safely(&w, "Ошибка загрузки заказчиков", [&] {
        QSqlQuery q;
        if (!q.exec("SELECT DISTINCT c.CustomerID, c.CustomerName FROM Customers c "
                    "JOIN Orders o ON o.CustomerID = c.CustomerID "
                    "WHERE c.IsBuyer = 1 ORDER BY c.CustomerName")) {
            showError(&w, "Не удалось загрузить список заказчиков:\n" + q.lastError().text());
            return;
        }
        while (q.next())
            customers->addItem(q.value(1).toString(), q.value(0));
    });

    // ---------- Поиск: подсветка ячеек, содержащих строку ----------
    auto highlight = [&] {
        const QString text = search->text().trimmed();
        int found = 0;
        for (int r = 0; r < table->rowCount(); ++r)
            for (int c = 0; c < table->columnCount(); ++c) {
                QTableWidgetItem *it = table->item(r, c);
                bool m = !text.isEmpty() && it->text().contains(text, Qt::CaseInsensitive);
                it->setBackground(m ? QColor(255, 230, 100) : QBrush());
                it->setForeground(m ? QBrush(Qt::black) : QBrush());
                found += m;
            }
        return found;
    };

    // ---------- Загрузка заказов (фильтр и сортировка — в SQL) ----------
    int filterId = 0;   // 0 — показывать всех заказчиков

    auto load = [&] {
        const QStringList cols = {"c.CustomerName", "o.OrderDate", "o.TotalSum"};
        QString sql = "SELECT c.CustomerName, ci.CityName, c.Phone, o.OrderDate, o.TotalSum "
                      "FROM Orders o "
                      "JOIN Customers c ON c.CustomerID = o.CustomerID "
                      "JOIN Cities ci   ON ci.CityID    = c.CityID "
                      "WHERE c.IsBuyer = 1";
        if (filterId)
            sql += " AND c.CustomerID = " + QString::number(filterId);
        sql += " ORDER BY " + cols.value(sortField->currentRow(), "c.CustomerName") + (desc->isChecked() ? " DESC" : " ASC");

        QSqlQuery q;
        if (!q.exec(sql)) {
            showError(&w, "Не удалось загрузить заказы:\n" + q.lastError().text());
            return;
        }
        table->setRowCount(0);
        double sum = 0;
        while (q.next()) {
            int r = table->rowCount();
            table->insertRow(r);
            table->setItem(r, 0, new QTableWidgetItem(q.value(0).toString()));
            table->setItem(r, 1, new QTableWidgetItem(q.value(1).toString()));
            table->setItem(r, 2, new QTableWidgetItem(q.value(2).toString()));
            table->setItem(r, 3, new QTableWidgetItem(q.value(3).toDate().toString("dd.MM.yyyy")));
            auto *money = new QTableWidgetItem(QString::number(q.value(4).toDouble(), 'f', 2).replace('.', ','));
            money->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
            table->setItem(r, 4, money);
            sum += q.value(4).toDouble();
        }
        lblCount->setText("Всего заказов: " + QString::number(table->rowCount()));
        lblSum->setText("Общая сумма: " + QString::number(sum, 'f', 2).replace('.', ','));
        highlight();    // подсветка поиска сохраняется после фильтра и сортировки
    };

    auto find = [&] {
        safely(&w, "Ошибка поиска", [&] {
            if (highlight() == 0 && !search->text().trimmed().isEmpty())
                QMessageBox::information(&w, "Поиск", "Совпадений не найдено");
        });
    };

    QObject::connect(asc, &QRadioButton::toggled, [&] { safely(&w, "Ошибка сортировки", load); });
    QObject::connect(sortField, &QListWidget::currentRowChanged, [&] { safely(&w, "Ошибка сортировки", load); });
    QObject::connect(btnFilter, &QPushButton::clicked, [&] {
        safely(&w, "Ошибка фильтрации", [&] { filterId = customers->currentData().toInt(); load(); });
    });
    QObject::connect(btnAll, &QPushButton::clicked, [&] {
        safely(&w, "Ошибка", [&] { filterId = 0; load(); });
    });
    QObject::connect(btnFind, &QPushButton::clicked, find);
    QObject::connect(search, &QLineEdit::returnPressed, find);

    safely(&w, "Ошибка при запуске", load);
    w.show();
    return app.exec();
}
