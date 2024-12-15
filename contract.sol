// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Контракт для проведения аукциона
contract AuctionContract {
    // --- Структуры данных ---
    // Структура, представляющая параметры аукциона
    struct Auction {
        string lotName;           // Название лота
        uint256 startPrice;       // Начальная цена аукциона
        uint256 startTime;        // Время начала аукциона (timestamp)
        uint256 endTime;          // Время окончания аукциона (timestamp)
        bool isActive;            // Статус аукциона (активен или завершен)
        address organizer;        // Адрес организатора аукциона
        address winner;           // Адрес победителя аукциона
        uint256 maxBid;           // Максимальная ставка на данный момент
    }

    // Хранение залогов участников (адрес -> сумма)
    mapping(address => uint256) public deposits;

    // Хранение ставок участников (адрес -> сумма ставки)
    mapping(address => uint256) public bids;

    // Информация об аукционе
    Auction public auction;

    // Список участников аукциона
    address[] public participants;

    // --- События ---
    // Событие для создания аукциона
    event AuctionCreated(string lotName, uint256 startPrice, uint256 startTime, uint256 endTime);

    // Событие для регистрации залога участника
    event DepositMade(address indexed participant, uint256 amount);

    // Событие для размещения ставки
    event BidPlaced(address indexed participant, uint256 amount);

    // Событие для завершения аукциона
    event AuctionEnded(address winner, uint256 maxBid);

    // Событие для возврата залогов
    event DepositReturned(address indexed participant, uint256 amount);

    // --- Модификаторы ---
    // Проверка, что вызывающий функцию является организатором аукциона
    modifier onlyOrganizer() {
        require(msg.sender == auction.organizer, "Not authorized");
        _;
    }

    // Проверка, что аукцион активен (текущее время находится в пределах периода аукциона)
    modifier auctionActive() {
        require(block.timestamp >= auction.startTime && block.timestamp <= auction.endTime, "Auction not active");
        _;
    }

    // Проверка, что аукцион завершен (текущее время больше времени окончания)
    modifier afterAuction() {
        require(block.timestamp > auction.endTime, "Auction not ended");
        _;
    }

    // --- Создание аукциона ---
    // Конструктор для создания аукциона с параметрами: название лота, начальная цена, время начала и окончания
    constructor(
        string memory _lotName,
        uint256 _startPrice,
        uint256 _startTime,
        uint256 _endTime
    ) {
        // Инициализация структуры аукциона
        auction = Auction({
            lotName: _lotName,
            startPrice: _startPrice,
            startTime: _startTime,
            endTime: _endTime,
            isActive: true,
            organizer: msg.sender, // Организатор - это адрес, который вызывает конструктор
            winner: address(0),    // Изначально победитель не определен
            maxBid: 0              // Изначально максимальная ставка равна 0
        });

        // Генерация события о создании аукциона
        emit AuctionCreated(_lotName, _startPrice, _startTime, _endTime);
    }

    // --- Регистрация участников ---
    // Функция для внесения залога участником
    function deposit() external payable {
        require(msg.value > 0, "Deposit required");            // Проверка, что внесена ненулевая сумма
        require(deposits[msg.sender] == 0, "Already registered"); // Проверка, что участник еще не внес залог

        deposits[msg.sender] = msg.value; // Сохранение залога участника
        participants.push(msg.sender);    // Добавление участника в список

        emit DepositMade(msg.sender, msg.value); // Генерация события о внесении залога
    }

    // --- Делать ставки ---
    // Функция для размещения ставки участником
    function placeBid(uint256 _amount) external auctionActive {
        require(deposits[msg.sender] > 0, "No deposit made"); // Проверка, что участник внес залог
        require(_amount > auction.maxBid, "Bid too low");     // Проверка, что ставка выше текущей максимальной

        auction.maxBid = _amount;    // Обновление максимальной ставки
        auction.winner = msg.sender; // Обновление победителя
        bids[msg.sender] = _amount;  // Сохранение ставки участника

        emit BidPlaced(msg.sender, _amount); // Генерация события о размещении ставки
    }

    // --- Завершение аукциона ---
    // Функция для завершения аукциона (доступна только организатору)
    function finalizeAuction() external onlyOrganizer afterAuction {
        auction.isActive = false; // Обновление статуса аукциона
        emit AuctionEnded(auction.winner, auction.maxBid); // Генерация события о завершении аукциона
    }

    // --- Возврат залогов ---
    // Функция для возврата залогов участникам (кроме победителя)
    function refundDeposits() external afterAuction {
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (participant != auction.winner) { // Возвращаем залог всем, кроме победителя
                uint256 amount = deposits[participant];
                deposits[participant] = 0;      // Обнуляем залог участника
                payable(participant).transfer(amount); // Возвращаем средства

                emit DepositReturned(participant, amount); // Генерация события о возврате залога
            }
        }
    }

    // --- Внесение оставшейся суммы победителем ---
    // Функция для оплаты победителем оставшейся суммы
    function payFinalAmount() external payable afterAuction {
        require(msg.sender == auction.winner, "Not the winner"); // Проверка, что вызывающий - победитель
        require(msg.value == auction.maxBid - deposits[msg.sender], "Incorrect amount"); // Проверка суммы

        // Передача полной суммы организатору аукциона
        payable(auction.organizer).transfer(msg.value + deposits[msg.sender]);
    }
}
