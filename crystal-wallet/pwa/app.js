const MAX_VALUE = 9_999_999_999;
const STORAGE_KEY = "crystal_wallet_v1";

const coinsValue = document.getElementById("coins-value");
const crystalsValue = document.getElementById("crystals-value");
const editorDialog = document.getElementById("editor-dialog");
const editorForm = document.getElementById("editor-form");
const coinsInput = document.getElementById("coins-input");
const crystalsInput = document.getElementById("crystals-input");

function clamp(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.max(0, Math.min(Math.trunc(number), MAX_VALUE));
}

function loadWallet() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { coins: 0, crystals: 0 };
    const data = JSON.parse(raw);
    return {
      coins: clamp(data.coins),
      crystals: clamp(data.crystals)
    };
  } catch {
    return { coins: 0, crystals: 0 };
  }
}

function saveWallet(wallet) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(wallet));
}

function formatNumber(value) {
  return new Intl.NumberFormat("ru-RU").format(value);
}

function render() {
  const wallet = loadWallet();
  coinsValue.textContent = formatNumber(wallet.coins);
  crystalsValue.textContent = formatNumber(wallet.crystals);
}

function updateWallet(updater) {
  const wallet = loadWallet();
  const next = updater(wallet);
  saveWallet({
    coins: clamp(next.coins),
    crystals: clamp(next.crystals)
  });
  render();
}

document.getElementById("open-editor").addEventListener("click", () => {
  const wallet = loadWallet();
  coinsInput.value = wallet.coins;
  crystalsInput.value = wallet.crystals;
  editorDialog.showModal();
});

document.getElementById("cancel-editor").addEventListener("click", () => {
  editorDialog.close();
});

editorForm.addEventListener("submit", (event) => {
  event.preventDefault();
  updateWallet(() => ({
    coins: clamp(coinsInput.value),
    crystals: clamp(crystalsInput.value)
  }));
  editorDialog.close();
});

document.querySelectorAll("[data-add]").forEach((button) => {
  button.addEventListener("click", () => {
    const amount = Number(button.dataset.add);
    updateWallet((wallet) => ({
      coins: wallet.coins + amount,
      crystals: wallet.crystals + amount
    }));
  });
});

document.getElementById("reset-wallet").addEventListener("click", () => {
  if (confirm("Сбросить баланс до нуля?")) {
    saveWallet({ coins: 0, crystals: 0 });
    render();
  }
});

document.querySelectorAll(".preset").forEach((button) => {
  button.addEventListener("click", () => {
    coinsInput.value = button.dataset.coins;
    crystalsInput.value = button.dataset.crystals;
  });
});

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch(() => {});
  });
}

render();
