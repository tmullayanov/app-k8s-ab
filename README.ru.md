# Canary Deployment & Argo Rollouts Demo

Демонстрация различных стратегий деплоя Kubernetes с использованием Istio и Argo Rollouts.

## 📋 О приложении

Простое FastAPI-приложение с одним основным эндпоинтом:

| Эндпоинт | Описание |
|----------|----------|
| `/` | Возвращает версию приложения и информацию о заголовках |
| `/health` | Health check для Kubernetes |
| `/metrics` | Prometheus-метрики для Argo Rollouts |

## 🚀 Быстрый старт

### 1. Проверка окружения

```bash
make check-deps
```

### 2. Одноразовая настройка (только первый запуск)

```bash
make one-time-setup
```

Установит: Istio, Argo Rollouts, Prometheus Stack

### 3. Запуск демо

```bash
# Demo 01: Ручное управление трафиком через Virtual Service
make 01-up
# or 
make docker-desktop 01-up # for Docker Desktop k8s

# Demo 02: Argo Rollouts (canary)
make 02-up
# or 
make docker-desktop 02-up # for Docker Desktop k8s

# Demo 03: Разделение по заголовку через Argo Rollouts
make 03-up
# or 
make docker-desktop 03-up # for Docker Desktop k8s


# Demo 04: Роллаут на основе метрик и заголовков через Argo Rollouts
make 04-up
# or 
make docker-desktop 04-up # for Docker Desktop k8s
```

### 4. Очистка

```bash
# Удалить конкретное демо
make 01-down

# Удалить все демо
make all-down
```

## 🖥 Типичный рабочий процесс

Рекомендуется использовать **два терминала**:

### Терминал 1: Наблюдение (watch)

```bash
# Для демо 02
make 02-up
make 02-watch

# Для демо 03
make 03-up
make 03-watch

# Для демо 04
make 04-up
make 04-watch
```

### Терминал 2: Управление деплоем

```bash
# Деплой новой версии
make 02-deploy-v2

# Промоут роллаута (если paused)
make 03-deploy-v2
make 03-promote-deploy

# Деплой v3 (для демо 04)
make 04-deploy-v2 # переход на v2 симулирует автоматический откат при сбое
# затем, для демонстрации последующего успешного деплоя:
make 04-deploy-v3 # до перехода в состояние paused
make 04-promote-deploy
```

### Терминал 3: Генерация трафика (опционально)

```bash
# Получить адрес сервиса 
kubectl get svc -n <namespace>

# Запустить скрипт генерации запросов
./run-requests.sh 02 -a http://<address> # адрес istio ingress.
```

## 📦 Платформы

Makefile автоматически определяет платформу. Поддерживаются:

| Платформа | Команда |
|-----------|---------|
| Minikube (авто) | `make 01-up` |
| Minikube (явно) | `make minikube 01-up` |
| Docker Desktop | `make docker-desktop 01-up` |
| Явно указать | `make K8S_PLATFORM=minikube 01-up` |

## 🎯 Описание демо

| Демо | Стратегия | Описание |
|------|-----------|----------|
| **01** | Manual A/B | Ручное управление трафиком через Istio VirtualService |
| **02** | Canary | Автоматический canary-деплой с Argo Rollouts |
| **03** | Header-based | Разделение трафика по заголовку (beta-тестирование) |
| **04** | Metrics-based | Rollout на основе метрик (error rate, latency) |

## 🛠 Доступные команды

```bash
make help              # Показать все доступные таргеты
make check-deps        # Проверить установленные зависимости
make one-time-setup    # Установить все компоненты (Istio, Argo, Prometheus)
make build-all         # Собрать все версии приложения (v1, v2, v3)
make all-down          # Удалить все демо-неймспейсы
```

## 📁 Структура

```
.
├── Makefile                    # Основные команды
├── run-requests.sh            # Скрипт генерации трафика
├── app/                       # FastAPI приложение
└── manifests/
    ├── 01-manual-ab/          # Демо 01
    ├── 02-argo-rollout/       # Демо 02
    ├── 03-argo-rollout-manual-beta/  # Демо 03
    └── 04-argo-rollout-metrics/      # Демо 04
```

## 🔧 Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `K8S_PLATFORM` | `auto` | `minikube`, `docker-desktop`, или `auto` |
| `APP_NAME` | `myapp` | Имя приложения для образов |
| `VERSIONS` | `v1 v2 v3` | Версии для сборки |
| `MINIKUBE_CPUS` | `4` | CPU для Minikube |
| `MINIKUBE_MEMORY` | `8192` | Memory для Minikube (MB) |

Пример использования:
```bash
make K8S_PLATFORM=docker-desktop APP_NAME=mydemo 02-up
```

## ⚠️ Требования

- `kubectl`
- `docker`
- `istioctl`
- `helm`
- `minikube` (только для Minikube)
- `kubectl-argo-rollouts` (для watch/promote команд)

## 🎬 Пример сессии (Демо 02)

```bash
# Терминал 1 - наблюдение
$ make 02-watch

# Терминал 2 - деплой
$ make 02-up
$ make 02-deploy-v2
# Наблюдайте в Терминале 1 как rollout прогрессирует

# Терминал 3 - трафик (опционально)
$ ./run-requests.sh 02 http://localhost:8080
```

---

**Happy rolling! 🚀**