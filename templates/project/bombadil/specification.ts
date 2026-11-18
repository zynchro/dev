import { extract, always, now, eventually } from "@antithesishq/bombadil";
export * from "@antithesishq/bombadil/browser/defaults";

const title = extract((state) => state.document.title || "");
export const hasTitle = always(() => title.current !== "");

const alert = extract(
  (state) => state.document.body.querySelector("[role=alert]")?.textContent ?? null,
);
export const alertsClear = always(
  now(() => alert.current !== null).implies(
    eventually(() => alert.current === null).within(10, "seconds"),
  ),
);
