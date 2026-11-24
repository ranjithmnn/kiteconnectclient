# Kite Connect Client

A Flutter app for Android and iOS that connects to your Zerodha account through the official Kite Connect API. You sign in securely on Zerodha's own login page, and the app stores your session safely on your device.

> **Status:** Early development. More trading features are on the way.

---

## Setting up your `.env` file

The app needs your own Kite Connect API key and secret to run. They go in a `.env` file that stays on your machine and is never committed to the repository.

### Where to add it

Create a file named `.env` in the **root of the project**, the same folder that contains `pubspec.yaml`:

```
kiteconnectclient/
├── android/
├── ios/
├── lib/
├── .env          ← create it here
├── pubspec.yaml
└── README.md
```

### What it should contain

```env
API_KEY=your_kite_api_key
API_SECRET=your_kite_api_secret
```

- Use exactly the names `API_KEY` and `API_SECRET`.
- Don't put quotes or spaces around the `=`.
- The app won't start if this file is missing.

### Where to get your API key and secret

1. Sign in to the [Kite Connect developer console](https://developers.kite.trade/) and create an app.
2. Set the app's **Redirect URL** to exactly `https://127.0.0.1/success`.
3. Copy the **API key** and **API secret** from the app's page into your `.env` file.

---

## ⚠️ Keep your credentials private

- `.env` is already in `.gitignore`. Never commit it or share it.
- Your API secret gets packaged into any app you build, so don't share or publish builds made with your credentials.

---

*This is an unofficial project and isn't affiliated with Zerodha.*
