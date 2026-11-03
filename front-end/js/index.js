import { preloadFonts } from "./utils";
import { TypeShuffle } from "./typeShuffle";

const API = process.env.LAMBDA_FUNCTION_URL;

// Short links look like /r/<id>. Pass the id to the views Lambda (which
// alerts Slack), then show the plain homepage URL in the address bar.
function viewsUrl() {
  const match = window.location.pathname.match(/^\/r\/([a-z0-9]{4,16})\/?$/);
  if (!match) return API;
  history.replaceState(null, "", "/" + window.location.hash);
  const url = new URL(API);
  url.searchParams.set("ref", match[1]);
  return url.toString();
}

async function getViews() {
  try {
    let res = await fetch(viewsUrl());
    if (!res.ok) throw new Error(`views request failed: ${res.status}`);
    let views = await res.json();
    if (typeof views !== "number") throw new Error("unexpected views response");
    return views;
  } catch (error) {
    let viewContainer = document.querySelector("#views");
    viewContainer.innerHTML = "Couldn't load views (◡︵◡)";
    console.log(error);
  }
}

async function renderViews() {
  let views = await getViews();
  if (views !== undefined) {
    let viewContainer = document.querySelector("#views");
    viewContainer.innerHTML = views + " •ᴗ•";
  }
}

renderViews();

preloadFonts("biu0hfr").then(() => {
  document.body.classList.remove("loading");

  [...document.querySelectorAll(".content")].forEach((content) => {
    const ts = new TypeShuffle(content);
    ts.trigger("fx1");
  });

  [...document.querySelectorAll(".effects > button")].forEach((button) => {
    button.addEventListener("click", () => {
      ts.trigger(`fx${button.dataset.fx}`);
    });
  });
});

function diff_years(dt2, dt1) {
  var diff = (dt2.getTime() - dt1.getTime()) / 1000;
  diff /= 60 * 60 * 24;
  return Math.abs(Math.round(diff / 365.25));
}

if (document.querySelector("#year-of-experience")) {
  var dt1 = new Date(2016, 1, 1);
  var dt2 = new Date();
  document.querySelector("#year-of-experience").innerHTML =
    diff_years(dt1, dt2) + "+";
}
