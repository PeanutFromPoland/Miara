const recipes = [
  {
    id: "oats", name: "Owsianka z malinami", type: "Śniadanie", art: "oats",
    time: 12, kcal: 420, protein: 18, carbs: 56, fat: 13, portions: 1,
    vegetarian: true, allergens: ["mleko", "gluten"],
    ingredients: ["Płatki owsiane — 60 g", "Jogurt naturalny — 150 g", "Maliny — 80 g", "Nasiona chia — 10 g"],
    why: "Proste śniadanie z dużą ilością węglowodanów i umiarkowaną ilością białka."
  },
  {
    id: "bowl", name: "Bowl z tofu i ryżem", type: "Obiad", art: "bowl",
    time: 25, kcal: 610, protein: 32, carbs: 72, fat: 21, portions: 1,
    vegetarian: true, allergens: ["soja"],
    ingredients: ["Tofu naturalne — 150 g", "Ryż — 80 g (suchy)", "Brokuł — 120 g", "Marchew — 80 g", "Oliwa — 10 g"],
    why: "Porcja z wyraźnym udziałem białka roślinnego."
  },
  {
    id: "pasta", name: "Makaron z pomidorami", type: "Obiad", art: "pasta",
    time: 20, kcal: 540, protein: 21, carbs: 73, fat: 17, portions: 1,
    vegetarian: true, allergens: ["gluten", "mleko"],
    ingredients: ["Makaron pełnoziarnisty — 80 g (suchy)", "Pomidory — 200 g", "Mozzarella — 60 g", "Oliwa — 8 g"],
    why: "Szybki posiłek mieszczący się w umiarkowanym zakresie energii."
  },
  {
    id: "salad", name: "Sałatka z ciecierzycą", type: "Kolacja", art: "salad",
    time: 15, kcal: 465, protein: 20, carbs: 48, fat: 19, portions: 1,
    vegetarian: true, allergens: [],
    ingredients: ["Ciecierzyca — 150 g", "Pomidor — 120 g", "Ogórek — 100 g", "Oliwa — 10 g", "Sok z cytryny — 10 ml"],
    why: "Szybka propozycja bez składników z demonstracyjnej listy alergenów."
  }
];

const state = {
  view: "home",
  detailId: null,
  search: "",
  filter: "all",
  target: 2000,
  allergens: [],
  plan: [{ key: 1, recipeId: "oats" }, { key: 2, recipeId: "bowl" }],
  diary: [{ key: 1, recipeId: "oats" }],
  nextKey: 3,
  toast: ""
};

const screen = document.getElementById("screen");
const nav = document.querySelector(".bottom-nav");
const fmt = value => new Intl.NumberFormat("pl-PL").format(value);
const recipe = id => recipes.find(item => item.id === id);
const escapeHtml = value => String(value).replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
const conflict = item => item.allergens.some(allergen => state.allergens.includes(allergen));
const totals = entries => entries.reduce((sum, entry) => {
  const item = recipe(entry.recipeId);
  if (!item) return sum;
  sum.kcal += item.kcal;
  sum.protein += item.protein;
  sum.carbs += item.carbs;
  sum.fat += item.fat;
  return sum;
}, { kcal: 0, protein: 0, carbs: 0, fat: 0 });

function title(eyebrow, heading, subtext = "") {
  return `<p class="eyebrow">${eyebrow}</p><h2 class="page-title">${heading}</h2>${subtext ? `<p class="subtext">${subtext}</p>` : ""}`;
}

function macro(label, amount, target, unit) {
  const progress = Math.min(100, Math.round(amount / target * 100));
  return `<div class="card macro"><b>${fmt(amount)} ${unit}</b><small>${label}</small><div class="macro-track"><i style="width:${progress}%"></i></div></div>`;
}

function mealRow(item, suffix = "") {
  return `<div class="meal-row"><span class="meal-art ${item.art}" aria-hidden="true"></span><span class="meal-copy"><strong>${item.name}</strong><small>${item.type} · ${item.time} min</small></span><span class="meal-val">${item.kcal} kcal${suffix}</span></div>`;
}

function renderHome() {
  const planned = totals(state.plan);
  const eaten = totals(state.diary);
  const percent = Math.min(100, Math.round(planned.kcal / state.target * 100));
  const date = new Intl.DateTimeFormat("pl-PL", { day: "numeric", month: "long" }).format(new Date());
  return `<div class="page home-page">
    <div class="home-hero"><p class="eyebrow">Sobą / ${date}</p><h2 class="page-title">Dziś jest<br>dobry dzień<br><em>na jedzenie.</em></h2><span class="hero-scribble" aria-hidden="true">✳</span></div>
    <div class="ledger"><div class="ledger-head"><span>01 / BILANS DNIA</span><span>PLANOWANE</span></div><div class="ledger-main"><strong>${fmt(planned.kcal)}</strong><span>z ${fmt(state.target)}<br>kcal na dziś</span></div><div class="ledger-bar"><i style="width:${percent}%"></i></div><p>${percent}% celu w planie · ${fmt(eaten.kcal)} kcal w dzienniku</p></div>
    <div class="macro-row">
      ${macro("Białko", planned.protein, 100, "g")}
      ${macro("Węglowodany", planned.carbs, 250, "g")}
      ${macro("Tłuszcze", planned.fat, 67, "g")}
    </div>
    <button class="action-banner" type="button" data-action="go-discover"><span class="spark" aria-hidden="true">↗</span><span><strong>Co mogę dziś zjeść?</strong><small>Odkryj przepis dopasowany do Ciebie</small></span><span class="arrow" aria-hidden="true">→</span></button>
    <div class="section-head"><h3 class="section-title">Na dziś zapisane</h3><button class="text-button" type="button" data-action="go-plan">Cały plan ↗</button></div>
    <div class="meal-sheet">${state.plan.map(entry => mealRow(recipe(entry.recipeId))).join("") || '<div class="empty">Plan jest pusty. Odkryj pierwszy przepis.</div>'}</div>
    <p class="inline-note">Wartości na ekranie są przykładowymi szacunkami, a cele makroskładników służą tylko do prezentacji układu.</p>
  </div>`;
}

function filteredRecipes() {
  const q = state.search.toLocaleLowerCase("pl-PL");
  return recipes.filter(item => {
    const matchesSearch = !q || item.name.toLocaleLowerCase("pl-PL").includes(q) || item.ingredients.join(" ").toLocaleLowerCase("pl-PL").includes(q);
    const matchesFilter = state.filter === "all" ||
      (state.filter === "fast" && item.time <= 15) ||
      (state.filter === "protein" && item.protein >= 25) ||
      (state.filter === "vegetarian" && item.vegetarian);
    return matchesSearch && matchesFilter;
  });
}

function renderDiscover() {
  const found = filteredRecipes();
  const filters = [["all", "Wszystkie"], ["fast", "Do 15 min"], ["protein", "Więcej białka"], ["vegetarian", "Roślinne"]];
  return `<div class="page discover-page">
    ${title("02 / ODKRYWAJ", "Przepisy,<br><em>które pasują.</em>", "Otwórz, porównaj, wybierz po swojemu.")}
    <form class="search-box" id="search-form"><input name="query" aria-label="Szukaj przepisu lub składnika" placeholder="Danie lub składnik" value="${escapeHtml(state.search)}"><button type="submit">Szukaj</button></form>
    <div class="chips" aria-label="Filtry">${filters.map(([value, label]) => `<button type="button" class="chip ${state.filter === value ? "active" : ""}" data-action="filter" data-value="${value}" aria-pressed="${state.filter === value}">${label}</button>`).join("")}</div>
    <p class="result-count">${found.length} ${found.length === 1 ? "propozycja" : "propozycje"} · dane demonstracyjne</p>
    ${found.map((item, index) => `<article class="card recipe-card">
      <div class="recipe-art ${item.art}" role="img" aria-label="Ilustracja dania"><span class="art-tag">${conflict(item) ? "Niezgodny z profilem" : "Propozycja"}</span></div>
      <div class="recipe-content"><span class="recipe-index">№ ${String(index + 1).padStart(2, "0")}</span><h3>${item.name}</h3><div class="recipe-meta"><span>${item.time} min</span><span>${item.protein} g białka</span><span>1 porcja</span></div>
      ${conflict(item) ? '<div class="warning">Zawiera składnik wykluczony w profilu</div>' : ""}
      <div class="recipe-bottom"><strong>≈ ${item.kcal} kcal / porcję</strong><button type="button" data-action="open-recipe" data-id="${item.id}">Zobacz ›</button></div></div>
    </article>`).join("") || '<div class="card empty">Nie znaleziono przepisu. Spróbuj innej nazwy lub filtra.</div>'}
    <p class="inline-note">Docelowo tu będą wyniki z publicznych stron, wraz z linkiem, datą odczytu i źródłami danych żywieniowych.</p>
  </div>`;
}

function renderDetail() {
  const item = recipe(state.detailId);
  if (!item) { state.view = "discover"; return renderDiscover(); }
  return `<div class="page detail-page">
    <button class="back-button" type="button" data-action="back-discover">‹ Wróć do przepisów</button>
    <div class="recipe-art detail-art ${item.art}" role="img" aria-label="Ilustracja dania"><span class="art-tag">Przepis demonstracyjny</span></div>
    ${title("PRZEPIS / " + item.type.toUpperCase(), item.name, item.why)}
    <div class="detail-meta"><span>${item.time} min</span><span>${item.portions} porcja</span><span>${item.ingredients.length} składniki</span></div>
    ${conflict(item) ? '<span class="tag warn">Zawiera wykluczony składnik</span>' : '<span class="tag">Zgodny z ustawionymi wykluczeniami</span>'}
    <div class="card nutrition"><div class="nutrition-head"><span>WARTOŚCI / 1 PORCJA</span><span>SZACUNEK</span></div><div class="nutrition-kcal">≈ ${item.kcal}<small> kcal</small></div>
      <div class="nutrition-grid"><div><b>${item.protein} g</b><small>Białko</small></div><div><b>${item.carbs} g</b><small>Węglowodany</small></div><div><b>${item.fat} g</b><small>Tłuszcz</small></div></div>
    </div>
    <div class="section-head"><h3 class="section-title">Składniki</h3><span class="tag">1 porcja</span></div>
    <ul class="ingredient-list">${item.ingredients.map(line => `<li>${escapeHtml(line)}</li>`).join("")}</ul>
    <div class="source-note"><strong>Skąd te liczby?</strong><br>To przykładowe dane UI. W działającej aplikacji każda pozycja otrzyma link do przepisu, źródło wartości odżywczych, datę odczytu i oznaczenie braków danych.</div>
    <button type="button" class="primary-button full-button" data-action="add-plan" data-id="${item.id}" ${conflict(item) ? "disabled" : ""}>${conflict(item) ? "Niezgodny z profilem" : "Dodaj do planu"}</button>
  </div>`;
}

function weekStrip() {
  const today = new Date();
  const monday = new Date(today);
  monday.setDate(today.getDate() - (today.getDay() + 6) % 7);
  return `<div class="day-strip">${Array.from({ length: 7 }, (_, i) => {
    const date = new Date(monday);
    date.setDate(monday.getDate() + i);
    const selected = date.toDateString() === today.toDateString();
    const day = ["Pn", "Wt", "Śr", "Cz", "Pt", "So", "Nd"][i];
    return `<span class="${selected ? "selected" : ""}" ${selected ? 'aria-current="date"' : ""}>${day}<b>${date.getDate()}</b></span>`;
  }).join("")}</div>`;
}

function renderPlan() {
  const sum = totals(state.plan);
  const progress = Math.min(100, Math.round(sum.kcal / state.target * 100));
  return `<div class="page plan-page">
    ${title("03 / PLAN", "Ułóż swój<br><em>dzień.</em>", "Posiłki czekają tutaj. Ty decydujesz o kolejności.")}
    ${weekStrip()}
    <div class="summary-card"><small>Zaplanowana energia</small><strong>${fmt(sum.kcal)} / ${fmt(state.target)} kcal</strong><div class="bar"><i style="width:${progress}%"></i></div><p>Białko ${sum.protein} g · Węglowodany ${sum.carbs} g · Tłuszcz ${sum.fat} g</p></div>
    <div class="section-head"><h3 class="section-title">Posiłki</h3><button type="button" class="text-button" data-action="go-discover">Dodaj przepis +</button></div>
    ${state.plan.map(entry => {
      const item = recipe(entry.recipeId);
      return `<div class="meal-group-title">${item.type}</div><div class="card plan-card"><div class="meal-row"><span class="meal-art ${item.art}" aria-hidden="true"></span><span class="meal-copy"><strong>${item.name}</strong><small>1 porcja · ${item.kcal} kcal</small></span><div class="row-actions"><button type="button" class="remove" data-action="remove-plan" data-key="${entry.key}" aria-label="Usuń ${item.name} z planu">×</button></div></div></div>`;
    }).join("") || '<div class="card empty">Brak posiłków. Dodaj przepis z ekranu Odkrywaj.</div>'}
    <p class="inline-note">Plan pokazuje zamiar. Faktyczne spożycie zapisujesz osobno w Dzienniku.</p>
  </div>`;
}

function renderDiary() {
  const sum = totals(state.diary);
  const unlogged = state.plan.filter(entry => !state.diary.some(log => log.recipeId === entry.recipeId));
  return `<div class="page diary-page">
    ${title("04 / DZIENNIK", "Zjedzone.<br><em>Zapisane.</em>", "Tu liczymy tylko to, co rzeczywiście zjedzono.")}
    <div class="card diary-add"><div class="row"><strong style="font-size:13px">Dodaj z planu</strong><span class="tag">${unlogged.length} do zapisania</span></div>
      ${unlogged.length ? `<select id="diary-choice" aria-label="Wybierz posiłek z planu">${unlogged.map(entry => `<option value="${entry.recipeId}">${recipe(entry.recipeId).name}</option>`).join("")}</select><button class="primary-button" type="button" data-action="log-meal">Oznacz jako zjedzone</button>` : '<p class="subtext">Wszystkie posiłki z planu zostały zapisane.</p>'}
    </div>
    <div class="diary-total"><div><small>Spożycie dzisiaj</small><br><b>${fmt(sum.kcal)} kcal</b></div><span class="tag">Cel ${fmt(state.target)} kcal</span></div>
    <div class="macro-row">${macro("Białko", sum.protein, 100, "g")}${macro("Węglowodany", sum.carbs, 250, "g")}${macro("Tłuszcze", sum.fat, 67, "g")}</div>
    <div class="section-head"><h3 class="section-title">Zapisane posiłki</h3></div>
    <div class="meal-sheet">${state.diary.map(entry => {
      const item = recipe(entry.recipeId);
      return `<div class="meal-row"><span class="meal-art ${item.art}" aria-hidden="true"></span><span class="meal-copy"><strong>${item.name}</strong><small>${item.type} · 1 porcja</small></span><div class="row-actions"><button type="button" class="remove" data-action="remove-diary" data-key="${entry.key}" aria-label="Usuń ${item.name} z dziennika">×</button></div></div>`;
    }).join("") || '<div class="empty">Brak zapisanych posiłków.</div>'}</div>
    <div class="source-note">Odczyt etykiety aparatem jest przewidziany w wymaganiach MVP. Ten widok pokazuje przepływ zapisu posiłku z planu; rozpoznawanie obrazu wymaga osobnej implementacji.</div>
  </div>`;
}

function renderProfile() {
  const choices = [["mleko", "Mleko"], ["gluten", "Gluten"], ["soja", "Soja"]];
  return `<div class="page profile-page">
    ${title("05 / PROFIL", "Twoja miara,<br><em>Twoje zasady.</em>", "Kilka wskazówek dla agenta. Zawsze możesz je zmienić.")}
    <div class="field"><label for="target-input">Dzienny cel energii</label><input id="target-input" type="number" min="800" max="5000" step="50" value="${state.target}" aria-describedby="target-help"><p id="target-help" class="subtext">Wpisz własny cel. Prototyp nie wyznacza go medycznie.</p></div>
    <button type="button" class="primary-button" data-action="save-target">Zapisz cel</button>
    <div class="section-head"><h3 class="section-title">Wykluczane składniki</h3></div>
    <p class="subtext">Wybierz składniki, których agent nie powinien oznaczać jako zgodnych z Twoim profilem.</p>
    <div class="choice-list">${choices.map(([value, label]) => `<button type="button" class="toggle-chip ${state.allergens.includes(value) ? "active" : ""}" data-action="toggle-allergen" data-value="${value}" aria-pressed="${state.allergens.includes(value)}">${label}</button>`).join("")}</div>
    <div class="privacy-note"><strong>Uwaga o alergiach</strong><br>Brak alergenu w odczytanym składzie nie potwierdza bezpieczeństwa potrawy. W działającej aplikacji wyniki z niepełnym składem muszą być oznaczone jako niepewne.</div>
    <div class="section-head"><h3 class="section-title">Jak działa dobór?</h3></div>
    <p class="subtext">Agent wyszukuje publiczne przepisy, porównuje składniki z Twoimi ograniczeniami i szacuje wartości odżywcze z danych żywieniowych produktów. Pokazuje brakujące dane oraz źródła.</p>
  </div>`;
}

function render() {
  nav.querySelectorAll("button").forEach(button => {
    const active = button.dataset.nav === state.view || (state.view === "detail" && button.dataset.nav === "discover");
    button.classList.toggle("active", active);
    button.setAttribute("aria-current", active ? "page" : "false");
  });
  const views = { home: renderHome, discover: renderDiscover, detail: renderDetail, plan: renderPlan, diary: renderDiary, profile: renderProfile };
  screen.innerHTML = views[state.view]();
  screen.scrollTop = 0;
  if (state.toast) {
    const toast = document.createElement("div");
    toast.className = "toast";
    toast.setAttribute("role", "status");
    toast.textContent = state.toast;
    document.querySelector(".phone").append(toast);
    state.toast = "";
    setTimeout(() => toast.remove(), 2300);
  }
}

function show(view) { state.view = view; render(); }
nav.addEventListener("click", event => {
  const button = event.target.closest("[data-nav]");
  if (button) show(button.dataset.nav);
});
screen.addEventListener("submit", event => {
  if (event.target.id !== "search-form") return;
  event.preventDefault();
  state.search = event.target.elements.query.value.trim();
  render();
});
screen.addEventListener("click", event => {
  const button = event.target.closest("[data-action]");
  if (!button) return;
  const action = button.dataset.action;
  if (action === "go-discover" || action === "back-discover") return show("discover");
  if (action === "go-plan") return show("plan");
  if (action === "filter") { state.filter = button.dataset.value; return render(); }
  if (action === "open-recipe") { state.detailId = button.dataset.id; return show("detail"); }
  if (action === "add-plan") {
    const item = recipe(button.dataset.id);
    if (!item || conflict(item)) return;
    state.plan.push({ key: state.nextKey++, recipeId: item.id });
    state.toast = "Posiłek dodany do planu";
    return show("plan");
  }
  if (action === "remove-plan") { state.plan = state.plan.filter(entry => entry.key !== Number(button.dataset.key)); return render(); }
  if (action === "log-meal") {
    const select = document.getElementById("diary-choice");
    if (!select) return;
    state.diary.push({ key: state.nextKey++, recipeId: select.value });
    state.toast = "Posiłek zapisany w dzienniku";
    return render();
  }
  if (action === "remove-diary") { state.diary = state.diary.filter(entry => entry.key !== Number(button.dataset.key)); return render(); }
  if (action === "toggle-allergen") {
    const value = button.dataset.value;
    state.allergens = state.allergens.includes(value) ? state.allergens.filter(item => item !== value) : [...state.allergens, value];
    return render();
  }
  if (action === "save-target") {
    const value = Number(document.getElementById("target-input").value);
    if (value < 800 || value > 5000 || !Number.isFinite(value)) {
      document.getElementById("target-input").setCustomValidity("Wpisz wartość od 800 do 5000 kcal.");
      document.getElementById("target-input").reportValidity();
      return;
    }
    document.getElementById("target-input").setCustomValidity("");
    state.target = value;
    state.toast = "Cel został zapisany";
    return render();
  }
});

render();
