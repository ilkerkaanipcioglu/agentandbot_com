# GovernanceCore

**GovernanceCore**, agentandbot.com platformunun Elixir/Phoenix LiveView tabanlı backend yönetim çekirdeğidir. AI agent kimlik yönetimi, görev orkestrasyon ve platform governance katmanını sağlar.

## 🏗️ Teknoloji Stack

- **Backend**: Elixir 1.15+ / Phoenix 1.8 (LiveView)
- **Veritabanı**: SQLite (geliştirme) / PostgreSQL (prodüksiyon)
- **Stil**: Tailwind CSS v4
- **HTTP Client**: Req
- **CI/CD**: GitHub Actions + Jules AI Code Review

## 🚀 Hızlı Başlangıç

### Gereksinimler

- Elixir ~> 1.15
- Erlang/OTP 26+
- Node.js 18+ (asset build için)

### Kurulum

```bash
# Bağımlılıkları yükle ve veritabanını hazırla
mix setup

# Geliştirme sunucusunu başlat
mix phx.server
```

Sunucu başladıktan sonra [`localhost:4001`](http://localhost:4001) adresinden erişebilirsiniz.

Alternatif olarak IEx içinde başlatabilirsiniz:

```bash
iex -S mix phx.server
```

### Ortam Değişkenleri

```bash
cp .env.example .env
# .env dosyasını kendi değerlerinizle doldurun
```

Gerekli değişkenler için `.env.example` dosyasına bakın.

## 🔧 Geliştirme Komutları

```bash
# Testleri çalıştır
mix test

# Kod kalite kontrolü (commit öncesi)
mix precommit

# Veritabanını sıfırla
mix ecto.reset

# Asset build
mix assets.build
```

## 📁 Proje Yapısı

```
governance_core/
├── lib/
│   ├── governance_core/        # İş mantığı (contexts, schemas)
│   └── governance_core_web/    # Phoenix web katmanı (LiveViews, controllers)
├── priv/
│   ├── repo/migrations/        # Ecto migration dosyaları
│   └── static/                 # Statik dosyalar
├── test/                       # ExUnit testleri
├── config/                     # Ortam konfigürasyonları
└── assets/                     # JS/CSS kaynakları
```

## 🤖 Jules AI Code Review

Bu proje, otomatik kod review için **Jules** entegrasyonu içerir:

- **Günlük review**: Her gece 00:00 TR saatinde çalışır
- **Güvenlik taraması**: Her Pazartesi sabahı
- **Push trigger**: `main` branch'e her push'ta

GitHub Actions workflow'ları `.github/workflows/` altında bulunur.  
`JULES_API_KEY` secret'ını GitHub repo ayarlarından eklemeniz gerekmektedir.

## 📋 Geliştirme Kuralları

Detaylı geliştirme kuralları için [`AGENTS.md`](AGENTS.md) dosyasına bakın.

Önemli notlar:
- HTTP istekleri için **her zaman** `Req` kullanın (HTTPoison kullanmayın)
- Commit öncesi `mix precommit` çalıştırın
- LiveView stream'leri büyük koleksiyonlar için zorunludur

## 🐳 Docker ile Çalıştırma

```bash
docker-compose up
```

## 🔗 Kaynaklar

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
- [agentandbot.com](https://agentandbot.com)
