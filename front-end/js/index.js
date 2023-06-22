import { preloadFonts } from "./utils";
import { TypeShuffle } from "./typeShuffle";

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
