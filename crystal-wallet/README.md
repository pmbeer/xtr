# Crystal Wallet

Локальное iOS-приложение с монетами и кристаллами. Баланс хранится на устройстве в `UserDefaults` и может быть изменён в любой момент.

## Возможности

- Просмотр текущего баланса монет и кристаллов
- Редактор баланса — введи любое число до 9 999 999 999
- Быстрые кнопки: +1 000, +100 000
- Пресеты в редакторе: 1 000, 100 000, 1 000 000, максимум
- Сброс баланса до нуля

## Требования

- macOS с Xcode 15+
- iPhone или симулятор iOS 16+

## Быстрая установка на iPhone (без Mac)

Скачай готовый архив: **`releases/crystal-wallet-ios-pwa.zip`**

Подробная инструкция: [INSTALL.md](INSTALL.md)

Кратко:
1. Распакуй архив и загрузи папку `pwa` на HTTPS-хостинг.
2. Открой ссылку в **Safari** на iPhone.
3. **Поделиться → На экран Домой**.

## Установка нативного приложения (Xcode)

1. Склонируй репозиторий и открой проект:

```bash
open crystal-wallet/CrystalWallet.xcodeproj
```

2. В Xcode выбери свой **Team** в Signing & Capabilities (Target → CrystalWallet).
3. Подключи iPhone или выбери симулятор.
4. Нажми **Run** (⌘R).

## Структура

```
crystal-wallet/
├── CrystalWallet.xcodeproj
└── CrystalWallet/
    ├── CrystalWalletApp.swift    # Точка входа
    ├── ContentView.swift         # Главный экран
    ├── Models/PlayerWallet.swift # Модель баланса
    ├── Services/
    │   ├── WalletStore.swift     # Логика изменения баланса
    │   └── WalletStorage.swift   # Сохранение в UserDefaults
    └── Views/WalletEditorView.swift
```

## Как работает хранение

Данные сохраняются локально через `UserDefaults`:

- `player_coins` — монеты
- `player_crystals` — кристаллы

При перезапуске приложения баланс восстанавливается автоматически.

## Лицензия

Учебный проект. Используй свободно.
