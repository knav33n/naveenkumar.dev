import { preloadFonts } from "./utils";
import { TypeShuffle } from "./typeShuffle";
import dotenv from "dotenv";

dotenv.config({ path: "../.env" });
const API = process.env.LAMBDA_FUNCTION_URL;

async function getViews() {
  try {
    let res = await fetch(API);
    return await res.json();
  } catch (error) {
    console.log(error);
  }
}

async function renderViews() {
  let views = await getViews();
  if (views) {
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
